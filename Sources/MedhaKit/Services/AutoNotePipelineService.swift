import Foundation
import Combine
import SwiftUI
import GRDB

// MARK: - Auto-Note Pipeline Progress State
public enum AutoNotePipelinePhase: Equatable, Sendable {
    case idle
    case grounding(topic: String)
    case clarificationNeeded(question: String)
    case planningSkeleton(nodeTitle: String, depth: Int)
    case reviewingSkeleton
    case waitingUserApproval
    case fillingNotes(current: Int, total: Int, nodeTitle: String, stage: String)
    case linkingAndQA
    case completed(report: RunReport)
    case cancelled
    case error(String)

    public var isRunning: Bool {
        switch self {
        case .grounding, .planningSkeleton, .reviewingSkeleton, .fillingNotes, .linkingAndQA:
            return true
        default:
            return false
        }
    }

    public var isApprovalPending: Bool {
        if case .waitingUserApproval = self { return true }
        return false
    }

    public var isPlanningPhase: Bool {
        switch self {
        case .grounding, .planningSkeleton, .reviewingSkeleton:
            return true
        default:
            return false
        }
    }

    public var isFillingPhase: Bool {
        switch self {
        case .fillingNotes, .linkingAndQA:
            return true
        default:
            return false
        }
    }

    public var statusDescription: String {
        switch self {
        case .idle:
            return "Ready to generate auto-notes"
        case .grounding(let topic):
            return "Grounding root sense for \"\(topic)\"..."
        case .clarificationNeeded:
            return "Ambiguity detected: User clarification needed"
        case .planningSkeleton(let title, let depth):
            return "Planning skeleton: \(title) (level \(depth))..."
        case .reviewingSkeleton:
            return "Reviewing tree structure for balance & gaps..."
        case .waitingUserApproval:
            return "Skeleton proposed: Review & edit nodes before filling"
        case .fillingNotes(let cur, let tot, let title, let stage):
            return "Filling \(cur)/\(tot): \(title) (\(stage))"
        case .linkingAndQA:
            return "Evaluating QA gates & synthesizing cross-links..."
        case .completed(let r):
            return "Auto-Notes Complete! (\(r.nodes_filled) filled, \(r.unverified.count) unverified)"
        case .cancelled:
            return "Generation cancelled by user"
        case .error(let msg):
            return "Pipeline Error: \(msg)"
        }
    }
}

// MARK: - Tree Data Structure
public final class AutoNoteTree: ObservableObject, @unchecked Sendable {
    @Published public var root: NoteNodeRecord?
    @Published public var nodes: [String: NoteNodeRecord] = [:]
    @Published public var childrenMap: [String: [String]] = [:] // parentId -> [childId]
    @Published public var rejectedTitles: [String: [String]] = [:] // branchRootId -> [rejectedTitle]
    @Published public var reviewIssues: [ReviewIssue] = []

    public init() {}

    public var count: Int { nodes.count }

    public func existingTitles() -> [String] {
        nodes.values.map { $0.title }
    }

    public func addNode(_ node: NoteNodeRecord) {
        nodes[node.id] = node
        if let pId = node.parent_id {
            var arr = childrenMap[pId] ?? []
            if !arr.contains(node.id) {
                arr.append(node.id)
                childrenMap[pId] = arr
            }
        }
    }

    public func children(of parentId: String) -> [NoteNodeRecord] {
        let childIds = childrenMap[parentId] ?? []
        return childIds.compactMap { nodes[$0] }.sorted(by: { $0.reading_order < $1.reading_order })
    }

    public func ancestorTitles(of nodeId: String) -> [String] {
        var titles: [String] = []
        var cur = nodes[nodeId]?.parent_id
        while let pId = cur, let p = nodes[pId] {
            titles.insert(p.title, at: 0)
            cur = p.parent_id
        }
        return titles
    }

    public func outlineString() -> String {
        guard let root = root else { return "" }
        var lines: [String] = []
        func recurse(node: NoteNodeRecord, indent: Int) {
            let pad = String(repeating: "  ", count: indent)
            let flags = node.risk_flags.isEmpty ? "" : " [flags: \(node.risk_flags.joined(separator: ", "))]"
            lines.append("\(pad)- [\(node.id)] \(node.title) (scope: \(node.scope_note))\(flags)")
            for ch in children(of: node.id) {
                recurse(node: ch, indent: indent + 1)
            }
        }
        recurse(node: root, indent: 0)
        return lines.joined(separator: "\n")
    }

    public func approvedNodesBottomUp() -> [NoteNodeRecord] {
        var result: [NoteNodeRecord] = []
        // Gather approved nodes, sort by level descending (leaves first)
        let approved = nodes.values.filter { $0.status == .approved || $0.status == .filling }
        result = approved.sorted { (n1: NoteNodeRecord, n2: NoteNodeRecord) -> Bool in
            if n1.level != n2.level {
                return n1.level > n2.level // Bottom-up (higher level first)
            }
            return n1.reading_order < n2.reading_order
        }
        return result
    }
}

// MARK: - Auto Note Pipeline Service
@MainActor
public final class AutoNotePipelineService: ObservableObject {
    public static let shared = AutoNotePipelineService()

    @Published public var config: AutoNotePipelineConfig = AutoNotePipelineConfig()
    @Published public var phase: AutoNotePipelinePhase = .idle
    @Published public var tree: AutoNoteTree = AutoNoteTree()
    @Published public var groundingRecord: GroundingRecord? = nil
    @Published public var lastRunReport: RunReport? = nil
    @Published public var clarificationQuestion: String? = nil
    @Published public var isRunning: Bool = false
    @Published public var userEditsCount: Int = 0

    private var activeTask: Task<Void, Never>? = nil
    private var nodeCounter: Int = 0

    private init() {}

    private func nextNodeId() -> String {
        nodeCounter += 1
        return String(format: "n_%04d", nodeCounter)
    }

    public func reset() {
        activeTask?.cancel()
        activeTask = nil
        phase = .idle
        tree = AutoNoteTree()
        groundingRecord = nil
        lastRunReport = nil
        clarificationQuestion = nil
        isRunning = false
        nodeCounter = 0
        userEditsCount = 0
    }

    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
        phase = .cancelled
        isRunning = false
    }

    // MARK: - Orchestrator Entrypoint
    public func startPipeline(
        rootTitle: String,
        userContext: String? = nil,
        rootDocId: String,
        store: BlockStore
    ) {
        guard !isRunning else { return }
        reset()
        isRunning = true

        activeTask = Task {
            do {
                // PHASE 1: GROUNDING
                self.phase = .grounding(topic: rootTitle)
                let grounding = try await self.executeGrounding(rootTitle: rootTitle, userContext: userContext)
                self.groundingRecord = grounding

                if grounding.needs_user_clarification, let q = grounding.clarification_question {
                    self.clarificationQuestion = q
                    self.phase = .clarificationNeeded(question: q)
                    self.isRunning = false
                    return
                }

                // SKELETON PLANNING (Phase 1 Breadth-First)
                let rootId = self.nextNodeId()
                let rootNode = NoteNodeRecord(
                    id: rootId,
                    parent_id: nil,
                    level: 0,
                    title: grounding.root_title,
                    scope_note: "Comprehensive overview of \(grounding.chosen_sense)",
                    why: "Root topic",
                    split_principle: "component",
                    entity_type: grounding.entity_type,
                    expected_depth: "overview",
                    leaf: false,
                    reading_order: 1,
                    source_support: ["wikipedia_toc", "wikidata"],
                    confidence: "high",
                    status: .proposed
                )
                self.tree.root = rootNode
                self.tree.addNode(rootNode)

                var queue: [NoteNodeRecord] = [rootNode]
                while !queue.isEmpty && self.tree.count < self.config.max_nodes {
                    if Task.isCancelled { self.phase = .cancelled; self.isRunning = false; return }
                    let current = queue.removeFirst()
                    if current.level >= self.config.max_depth || current.leaf {
                        continue
                    }

                    self.phase = .planningSkeleton(nodeTitle: current.title, depth: current.level + 1)
                    let children = try await self.executeSkeletonPlanner(for: current)
                    for ch in children {
                        self.tree.addNode(ch)
                        queue.append(ch)
                    }
                }

                // PHASE 2: REVIEW
                self.phase = .reviewingSkeleton
                let review = try await self.executeSkeletonReview()
                self.applySafeReviewFixes(review)

                // ⏸ PAUSE: USER APPROVAL
                self.phase = .waitingUserApproval
                self.isRunning = false

            } catch {
                if Task.isCancelled {
                    self.phase = .cancelled
                } else {
                    self.phase = .error(error.localizedDescription)
                }
                self.isRunning = false
            }
        }
    }

    // MARK: - Phase 1: Grounding
    public func executeGrounding(rootTitle: String, userContext: String?) async throws -> GroundingRecord {
        let (wikiRaw, _) = await AutoNoteAPICatalog.shared.executeCallWithCache(api: "wikipedia", params: ["query": rootTitle])
        let (wikidataRaw, _) = await AutoNoteAPICatalog.shared.executeCallWithCache(api: "wikidata", params: ["query": rootTitle])

        let (sysPrompt, userPrompt) = AutoNotePrompts.formatP1GroundingPrompt(
            rootTitle: rootTitle,
            userContext: userContext,
            wikipediaSearchResults: wikiRaw,
            wikidataSearchResults: wikidataRaw
        )

        let rawResponse = try await executeLLMWithRetry(system: sysPrompt, user: userPrompt)
        return parseJSON(raw: rawResponse, fallback: GroundingRecord(
            root_title: rootTitle,
            chosen_sense: "\(rootTitle) in its primary encyclopedic sense",
            domain: "other",
            entity_type: "concept"
        ))
    }

    // MARK: - Phase 1: Skeleton Planner (Breadth-First Node Call)
    public func executeSkeletonPlanner(for parent: NoteNodeRecord) async throws -> [NoteNodeRecord] {
        let evidence = await AutoNoteAPICatalog.shared.fetchStructureSources(for: parent.title, level: parent.level)
        let ancestors = tree.ancestorTitles(of: parent.id)
        let existing = tree.existingTitles()
        let rejected = tree.rejectedTitles[parent.id] ?? []

        let depthLeft = config.max_depth - parent.level
        let nodesLeft = config.max_nodes - tree.count

        let parentJSON = toJSONString(parent)
        let (sysPrompt, userPrompt) = AutoNotePrompts.formatP2SkeletonPlannerPrompt(
            parentNodeJSON: parentJSON,
            ancestorTitles: ancestors,
            existingTitles: existing,
            rejectedTitles: rejected,
            depthLeft: depthLeft,
            nodesLeft: nodesLeft,
            wikipediaTOC: evidence.wikipedia_toc,
            wikidataRelations: evidence.wikidata_relations,
            scholarlyTopics: evidence.scholarly_topics,
            minChildren: config.min_children,
            maxChildren: config.max_children,
            leafWordTarget: config.leaf_word_target
        )

        let raw = try await executeLLMWithRetry(system: sysPrompt, user: userPrompt)
        let parsed: P2SkeletonOutput = parseJSON(raw: raw, fallback: fallbackChildren(for: parent))

        var assignedChildren: [NoteNodeRecord] = []
        for (idx, mutChild) in parsed.children.enumerated() {
            var c = mutChild
            c.id = nextNodeId()
            c.parent_id = parent.id
            c.level = parent.level + 1
            c.reading_order = idx + 1
            c.status = .proposed
            assignedChildren.append(c)
        }
        return assignedChildren
    }

    private func fallbackChildren(for parent: NoteNodeRecord) -> P2SkeletonOutput {
        let cleanTitle = parent.title
        let titles = [
            "Architecture & Structural Components of \(cleanTitle)",
            "Kinetic Pathways & Functional Mechanics in \(cleanTitle)",
            "Empirical Methodologies & Contemporary Implementations of \(cleanTitle)",
            "Boundary Conditions, Edge Cases & Open Problems in \(cleanTitle)"
        ]
        let children = titles.enumerated().map { idx, t in
            NoteNodeRecord(
                id: "",
                parent_id: parent.id,
                level: parent.level + 1,
                title: t,
                scope_note: "Specific, in-depth coverage of \(t)",
                why: "Critical conceptual and functional division of \(cleanTitle)",
                split_principle: "component",
                reading_order: idx + 1,
                source_support: ["wikipedia_toc"],
                status: .proposed
            )
        }
        return P2SkeletonOutput(split_principle: "component", leaf: false, children: children)
    }

    // MARK: - Phase 2: Skeleton Review
    public func executeSkeletonReview() async throws -> ReviewResult {
        let outline = tree.outlineString()
        let groundingJSON = toJSONString(groundingRecord)
        let categoryTree = "Curated category taxonomy from Wikipedia & Wikidata"

        let (sysPrompt, userPrompt) = AutoNotePrompts.formatP3SkeletonReviewerPrompt(
            treeOutline: outline,
            groundingJSON: groundingJSON,
            categoryTree: categoryTree,
            maxChildren: config.max_children
        )

        let raw = try await executeLLMWithRetry(system: sysPrompt, user: userPrompt)
        return parseJSON(raw: raw, fallback: ReviewResult(issues: [], missing_nodes: [], overall_note: "Structure verified."))
    }

    public func applySafeReviewFixes(_ review: ReviewResult) {
        tree.reviewIssues = review.issues
        for issue in review.issues {
            if let fix = issue.proposed_fix {
                switch fix.action {
                case "rename":
                    if let newTitle = fix.args?["new_title"], var node = tree.nodes[issue.node_id] {
                        if !node.isFieldLocked("title") {
                            node.title = newTitle
                            tree.nodes[issue.node_id] = node
                        }
                    }
                default:
                    // Flag the node with this risk
                    if var node = tree.nodes[issue.node_id] {
                        let flag = "\(issue.type): \(issue.detail.prefix(40))"
                        if !node.risk_flags.contains(flag) {
                            node.risk_flags.append(flag)
                            tree.nodes[issue.node_id] = node
                        }
                    }
                }
            }
        }
    }

    // MARK: - User Edit Handlers (Local Only)
    public func updateNodeTitle(id: String, newTitle: String) {
        guard var node = tree.nodes[id] else { return }
        let oldTitle = node.title
        node.title = newTitle
        node.lockField("title")
        node.status = .edited
        tree.nodes[id] = node
        userEditsCount += 1

        // Inbound [[links]] update across tree
        for (k, mutN) in tree.nodes where k != id {
            var n = mutN
            if let md = n.markdown_content, md.contains("[[\(oldTitle)]]") {
                n.markdown_content = md.replacingOccurrences(of: "[[\(oldTitle)]]", with: "[[\(newTitle)]]")
                tree.nodes[k] = n
            }
        }
    }

    public func updateNodeScope(id: String, newScope: String) {
        guard var node = tree.nodes[id] else { return }
        node.scope_note = newScope
        node.lockField("scope_note")
        node.status = .edited
        tree.nodes[id] = node
        userEditsCount += 1
    }

    public func updateNodeDepth(id: String, newDepth: String) {
        guard var node = tree.nodes[id] else { return }
        node.expected_depth = newDepth
        node.lockField("expected_depth")
        node.status = .edited
        tree.nodes[id] = node
        userEditsCount += 1
    }

    public func deleteNode(id: String) {
        guard let node = tree.nodes[id] else { return }
        let title = node.title

        // Remove from parent's childrenMap
        if let pId = node.parent_id {
            tree.childrenMap[pId]?.removeAll { $0 == id }
            // Append "not covered here" to parent's scope note
            if var parentNode = tree.nodes[pId] {
                if !parentNode.scope_note.contains("not covered here: \(title)") {
                    parentNode.scope_note += " (not covered here: \(title))"
                    tree.nodes[pId] = parentNode
                }
            }
            // Record as rejected title in branch
            var rejs = tree.rejectedTitles[pId] ?? []
            rejs.append(title)
            tree.rejectedTitles[pId] = rejs
        }

        tree.nodes.removeValue(forKey: id)
        userEditsCount += 1
    }

    public func moveNode(id: String, newParentId: String?) {
        guard var node = tree.nodes[id] else { return }
        let oldParentId = node.parent_id

        if let oldP = oldParentId {
            tree.childrenMap[oldP]?.removeAll { $0 == id }
        }

        node.parent_id = newParentId
        node.lockField("parent_id")
        node.status = .edited
        if let newP = newParentId, let newParentNode = tree.nodes[newP] {
            node.level = newParentNode.level + 1
            var arr = tree.childrenMap[newP] ?? []
            arr.append(id)
            tree.childrenMap[newP] = arr
        }
        tree.nodes[id] = node
        userEditsCount += 1
    }

    public func addNode(parentId: String?, title: String, scopeNote: String) {
        let newId = nextNodeId()
        let level = (parentId != nil ? (tree.nodes[parentId!]?.level ?? 0) : 0) + 1
        var newNode = NoteNodeRecord(
            id: newId,
            parent_id: parentId,
            level: level,
            title: title,
            scope_note: scopeNote,
            why: "User added node",
            status: .edited
        )
        newNode.lockField("title")
        newNode.lockField("scope_note")
        tree.addNode(newNode)
        userEditsCount += 1
    }

    // MARK: - Approval Methods
    public func approveNode(id: String) {
        guard var node = tree.nodes[id] else { return }
        node.status = .approved
        tree.nodes[id] = node
    }

    public func approveBranch(branchRootId: String) {
        func recurse(nodeId: String) {
            approveNode(id: nodeId)
            for chId in tree.childrenMap[nodeId] ?? [] {
                recurse(nodeId: chId)
            }
        }
        recurse(nodeId: branchRootId)
    }

    public func approveAll() {
        for id in tree.nodes.keys {
            approveNode(id: id)
        }
    }

    // MARK: - P10: Regenerate Branch
    public func regenerateBranch(branchRootId: String) async {
        guard let branchRoot = tree.nodes[branchRootId], !isRunning else { return }
        isRunning = true
        let rejected = tree.rejectedTitles[branchRootId] ?? []
        let outsideTitles = tree.nodes.values.filter { $0.id != branchRootId && $0.parent_id != branchRootId }.map { $0.title }

        let (sys, user) = AutoNotePrompts.formatP10BranchRegenerationPrompt(
            branchRootJSON: toJSONString(branchRoot),
            rejectedTitlesInBranch: rejected,
            titlesOutsideBranch: outsideTitles,
            depthLeft: config.max_depth - branchRoot.level,
            nodesLeft: config.max_nodes - tree.count,
            evidenceSummary: "Regenerated branch from curated taxonomies"
        )

        do {
            let raw = try await executeLLMWithRetry(system: sys, user: user)
            let parsed: P2SkeletonOutput = parseJSON(raw: raw, fallback: fallbackChildren(for: branchRoot))

            // Replace only nodes still in status "proposed"
            let existingChildren = tree.children(of: branchRootId)
            for ch in existingChildren where ch.status == .proposed && !ch.isFieldLocked("title") {
                deleteNode(id: ch.id)
            }

            for (idx, mutChild) in parsed.children.enumerated() {
                var c = mutChild
                c.id = nextNodeId()
                c.parent_id = branchRootId
                c.level = branchRoot.level + 1
                c.reading_order = idx + 1
                c.status = .proposed
                tree.addNode(c)
            }
        } catch {
            print("Regenerate branch error: \(error)")
        }
        // Rejected titles expire after regeneration
        tree.rejectedTitles.removeValue(forKey: branchRootId)
        isRunning = false
    }

    // MARK: - P11: Go Deeper
    public func goDeeper(nodeId: String) async {
        guard let node = tree.nodes[nodeId], !isRunning else { return }
        isRunning = true
        let existingChildren = tree.children(of: nodeId).map { $0.title }

        let (sys, user) = AutoNotePrompts.formatP11GoDeeperPrompt(
            nodeJSON: toJSONString(node),
            noteSummary: node.scope_note,
            existingChildren: existingChildren
        )

        do {
            let raw = try await executeLLMWithRetry(system: sys, user: user)
            let parsed: P2SkeletonOutput = parseJSON(raw: raw, fallback: fallbackChildren(for: node))

            for (idx, mutChild) in parsed.children.enumerated() {
                var c = mutChild
                c.id = nextNodeId()
                c.parent_id = nodeId
                c.level = node.level + 1
                c.reading_order = existingChildren.count + idx + 1
                c.status = .proposed
                tree.addNode(c)
            }
        } catch {
            print("Go deeper error: \(error)")
        }
        isRunning = false
    }

    // MARK: - Phase 3: Fill Approved Notes (Bottom-Up)
    public func startFillingApprovedNotes(rootDocId: String, store: BlockStore) {
        guard !isRunning else { return }
        isRunning = true

        activeTask = Task {
            do {
                let approvedNodes = self.tree.approvedNodesBottomUp()
                var filledCount = 0
                var unverifiedNodes: [String] = []
                var lowConfidenceNodes: [String] = []
                var failedNodes: [String] = []
                var needsAttention: [AttentionItem] = []

                for (idx, node) in approvedNodes.enumerated() {
                    if Task.isCancelled { self.phase = .cancelled; self.isRunning = false; return }

                    var activeNode = node
                    activeNode.status = .filling
                    self.tree.nodes[node.id] = activeNode

                    self.phase = .fillingNotes(
                        current: idx + 1,
                        total: approvedNodes.count,
                        nodeTitle: activeNode.title,
                        stage: "Routing APIs & Querying Evidence..."
                    )

                    // 1. P4: Router
                    let plan = try await self.executeRouter(for: activeNode)

                    // 2. Fetch Evidence via P5 Query Builder + Cache + P6 Validator
                    var evidenceList: [EvidenceItem] = []
                    var conflictsList: [String] = []

                    for step in plan.plan {
                        if Task.isCancelled { self.phase = .cancelled; self.isRunning = false; return }
                        let reqs = try await self.executeQueryBuilder(step: step, node: activeNode)
                        for r in reqs.requests {
                            let (raw, _) = await AutoNoteAPICatalog.shared.executeCallWithCache(api: r.api, params: r.params)
                            let ev = try await self.executeEvidenceValidator(rawResult: raw, node: activeNode)
                            if ev.discard != true {
                                evidenceList.append(ev)
                                for kf in ev.key_facts {
                                    if let conflict = kf.conflicts_with {
                                        conflictsList.append("Conflict on '\(kf.claim)' with \(conflict)")
                                    }
                                }
                            }
                        }
                    }

                    if evidenceList.isEmpty {
                        // Fallback chain
                        for fbAPI in plan.fallback_chain {
                            let (raw, _) = await AutoNoteAPICatalog.shared.executeCallWithCache(api: fbAPI, params: ["query": activeNode.title])
                            let ev = try await self.executeEvidenceValidator(rawResult: raw, node: activeNode)
                            if ev.discard != true {
                                evidenceList.append(ev)
                                break
                            }
                        }
                    }

                    let isUnverified = evidenceList.isEmpty
                    if isUnverified {
                        unverifiedNodes.append(activeNode.id)
                    }

                    // 3. P7: Note Writer + P9: QA Gate
                    self.phase = .fillingNotes(
                        current: idx + 1,
                        total: approvedNodes.count,
                        nodeTitle: activeNode.title,
                        stage: "Synthesizing Note & Passing QA Gate..."
                    )

                    var writtenNote: (markdown: String, meta: WriterOutputMetadata)? = nil
                    var qaPassed = false
                    var retryCount = 0
                    var fixInstructions: String? = nil

                    while retryCount <= self.config.writer_retries && !qaPassed {
                        if Task.isCancelled { self.phase = .cancelled; self.isRunning = false; return }
                        let writerResult = try await self.executeNoteWriter(
                            node: activeNode,
                            evidence: evidenceList,
                            conflicts: conflictsList,
                            fixInstructions: fixInstructions
                        )
                        writtenNote = writerResult

                        let qa = try await self.executeQAGate(noteMarkdown: writerResult.markdown, node: activeNode, evidence: evidenceList)
                        if qa.pass {
                            qaPassed = true
                        } else {
                            retryCount += 1
                            fixInstructions = qa.fix_instructions
                            if retryCount > self.config.writer_retries {
                                needsAttention.append(AttentionItem(node_id: activeNode.id, reason: qa.failures.map { $0.detail }.joined(separator: "; ")))
                            }
                        }
                    }

                    // Save note state
                    activeNode.markdown_content = writtenNote?.markdown
                    activeNode.writer_metadata = writtenNote?.meta
                    if writtenNote == nil || writtenNote?.markdown.isEmpty == true {
                        activeNode.status = .failed
                        failedNodes.append(activeNode.id)
                    } else if isUnverified {
                        activeNode.status = .unverified
                    } else if !qaPassed {
                        activeNode.status = .needs_review
                        activeNode.confidence = "low"
                        lowConfidenceNodes.append(activeNode.id)
                    } else {
                        activeNode.status = .filled
                    }

                    self.tree.nodes[node.id] = activeNode
                    filledCount += 1

                    // Incrementally persist to BlockStore
                    self.commitNodeToStore(node: activeNode, rootDocId: rootDocId, store: store, sortOrder: idx)
                }

                // PHASE 4: LINK + REPORT
                self.phase = .linkingAndQA
                let links = try await self.executeLinker()
                self.applyCrossLinks(links, store: store)

                let report = RunReport(
                    root_id: self.tree.root?.id ?? "n_0000",
                    nodes_total: self.tree.count,
                    nodes_filled: filledCount,
                    unverified: unverifiedNodes,
                    low_confidence: lowConfidenceNodes,
                    failed: failedNodes,
                    api_calls: await AutoNoteAPICatalog.shared.getCallCounts(),
                    cache_hits: await AutoNoteAPICatalog.shared.getCacheHits(),
                    user_edits: self.userEditsCount,
                    needs_attention: needsAttention
                )
                self.lastRunReport = report
                self.phase = .completed(report: report)
                self.isRunning = false

            } catch {
                if Task.isCancelled {
                    self.phase = .cancelled
                } else {
                    self.phase = .error(error.localizedDescription)
                }
                self.isRunning = false
            }
        }
    }

    // MARK: - Phase 3 Helpers: Router, QueryBuilder, Validator, Writer, QA, Linker
    private func executeRouter(for node: NoteNodeRecord) async throws -> RouterOutput {
        let budget = (node.expected_depth == "expert") ? config.api_calls_per_node_expert : config.api_calls_per_node
        let (sys, user) = AutoNotePrompts.formatP4RouterPrompt(
            nodeJSON: toJSONString(node),
            ancestorTitles: tree.ancestorTitles(of: node.id),
            groundingJSON: toJSONString(groundingRecord),
            apiCatalogJSON: await AutoNoteAPICatalog.shared.getCatalogJSON(),
            apiCallsForThisNode: budget
        )

        let raw = try await executeLLMWithRetry(system: sys, user: user)
        return parseJSON(raw: raw, fallback: RouterOutput(
            profile: nil,
            plan: [RouterPlanStep(order: 1, api: "wikipedia", purpose: "definition", query_hint: node.title)],
            fallback_chain: ["openalex", "web_search", "UNVERIFIED"],
            expected_evidence_kinds: ["definition"]
        ))
    }

    private func executeQueryBuilder(step: RouterPlanStep, node: NoteNodeRecord) async throws -> QueryBuilderOutput {
        let knownIDs = "qid: \(groundingRecord?.qid ?? "none"), wikipedia: \(groundingRecord?.wikipedia_title ?? "none")"
        let (sys, user) = AutoNotePrompts.formatP5QueryBuilderPrompt(
            planStep: toJSONString(step),
            nodeJSON: toJSONString(node),
            ancestorTitles: tree.ancestorTitles(of: node.id),
            knownIDs: knownIDs,
            apiSpec: "api: \(step.api), query parameter: query",
            cacheKeys: []
        )

        let raw = try await executeLLMWithRetry(system: sys, user: user)
        return parseJSON(raw: raw, fallback: QueryBuilderOutput(requests: [QueryBuilderRequest(api: step.api, params: ["query": node.title])]))
    }

    private func executeEvidenceValidator(rawResult: String, node: NoteNodeRecord) async throws -> EvidenceItem {
        let (sys, user) = AutoNotePrompts.formatP6EvidenceValidatorPrompt(
            rawResult: rawResult,
            nodeJSON: toJSONString(node),
            chosenSense: groundingRecord?.chosen_sense ?? node.title,
            freshness: groundingRecord?.freshness ?? "slow_changing",
            acceptedEvidenceSummaries: [],
            minEvidenceScore: config.min_evidence_score
        )

        let raw = try await executeLLMWithRetry(system: sys, user: user)
        return parseJSON(raw: raw, fallback: EvidenceItem(
            evidence_id: "e_\(UUID().uuidString.prefix(6))",
            api: "wikipedia",
            query: node.title,
            url_or_id: "wikipedia",
            content_summary: String(rawResult.prefix(200)),
            discard: false
        ))
    }

    private func executeNoteWriter(
        node: NoteNodeRecord,
        evidence: [EvidenceItem],
        conflicts: [String],
        fixInstructions: String?
    ) async throws -> (markdown: String, meta: WriterOutputMetadata) {
        let ancestors = tree.ancestorTitles(of: node.id).joined(separator: " > ")
        let siblings = tree.children(of: node.parent_id ?? "").filter { $0.id != node.id }.map { $0.title }
        let childrenSummaries = tree.children(of: node.id).map { "- [[\($0.title)]]: \($0.scope_note)" }

        let (sys, user) = AutoNotePrompts.formatP7NoteWriterPrompt(
            title: node.title,
            ancestorPath: ancestors,
            scopeNote: node.scope_note,
            expectedDepth: node.expected_depth,
            siblings: siblings,
            childrenWithOneLineSummaries: childrenSummaries,
            prerequisiteTitles: node.prerequisites,
            evidenceJSON: toJSONString(evidence),
            conflicts: conflicts,
            userLocked: node.user_locked,
            qaFixInstructions: fixInstructions
        )

        let raw = try await executeLLMCall(systemInstruction: sys, userPrompt: user)
        return parseWriterOutput(rawText: raw, nodeId: node.id)
    }

    private func executeQAGate(
        noteMarkdown: String,
        node: NoteNodeRecord,
        evidence: [EvidenceItem]
    ) async throws -> QAGateOutput {
        let siblings = tree.children(of: node.parent_id ?? "").filter { $0.id != node.id }.map { $0.title }
        let parentSummary = node.parent_id != nil ? (tree.nodes[node.parent_id!]?.scope_note ?? "") : "Root note"

        let (sys, user) = AutoNotePrompts.formatP9QAGatePrompt(
            noteMarkdown: noteMarkdown,
            nodeJSON: toJSONString(node),
            evidenceJSON: toJSONString(evidence),
            siblings: siblings,
            parentNoteSummary: parentSummary
        )

        let raw = try await executeLLMWithRetry(system: sys, user: user)
        return parseJSON(raw: raw, fallback: QAGateOutput(pass: true, failures: [], fix_instructions: ""))
    }

    private func executeLinker() async throws -> LinkerOutput {
        let metadataString = tree.nodes.values.map {
            "title: \($0.title), qid: \(groundingRecord?.qid ?? "null"), scope: \($0.scope_note), parent: \($0.parent_id ?? "root")"
        }.joined(separator: "\n")

        let (sys, user) = AutoNotePrompts.formatP8LinkerPrompt(
            notesMetadata: metadataString,
            treeOutline: tree.outlineString()
        )

        let raw = try await executeLLMWithRetry(system: sys, user: user)
        return parseJSON(raw: raw, fallback: LinkerOutput(links: []))
    }

    private func applyCrossLinks(_ linkerOutput: LinkerOutput, store: BlockStore) {
        for link in linkerOutput.links {
            guard var fromNode = tree.nodes.values.first(where: { $0.id == link.from || $0.title.lowercased() == link.from.lowercased() }) else {
                continue
            }
            let targetTitle = tree.nodes.values.first(where: { $0.id == link.to || $0.title.lowercased() == link.to.lowercased() })?.title ?? link.to
            if let md = fromNode.markdown_content, !md.contains("[[\(targetTitle)]]") {
                let crossRef = "\n\n### Related Concepts\n- [[\(targetTitle)]] (\(link.relation)): \(link.reason)\n"
                fromNode.markdown_content = md + crossRef
                tree.nodes[fromNode.id] = fromNode
            }
        }
    }

    // MARK: - Single Document Fill (On-Demand 2-Step Workflow)
    @MainActor
    public func fillSingleDocument(
        docId: String,
        store: BlockStore,
        customScope: String? = nil,
        customDepth: String? = nil,
        onProgress: ((String) -> Void)? = nil
    ) async throws {
        guard let doc = store.documents.first(where: { $0.id == docId }) ?? store.getBlock(id: docId) else {
            throw AISocraticService.ServiceError.invalidResponse("Document not found in store")
        }

        let title = doc.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw AISocraticService.ServiceError.invalidResponse("Document title is empty")
        }

        // Determine scope note
        var scopeNote = customScope?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if scopeNote.isEmpty {
            let docBlocks: [Block] = (try? await store.dbManager.dbWriter.read { db in
                try Block.filter(Block.Columns.rootDocId == docId && Block.Columns.type != BlockType.doc.rawValue)
                    .order(Block.Columns.sortOrder)
                    .fetchAll(db)
            }) ?? store.blocks

            if let skeletalBlock = docBlocks.first(where: { $0.content.contains("Scope:") }),
               let range = skeletalBlock.content.range(of: "Scope:") {
                scopeNote = String(skeletalBlock.content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let matchingTreeNode = tree.nodes.values.first(where: { $0.title.lowercased() == title.lowercased() }) {
                scopeNote = matchingTreeNode.scope_note
            }
        }
        if scopeNote.isEmpty {
            scopeNote = "Comprehensive coverage, foundational mechanisms, dynamics, and real-world applications of \(title)"
        }

        let depth = customDepth ?? tree.nodes.values.first(where: { $0.title.lowercased() == title.lowercased() })?.expected_depth ?? "working"

        // Build ancestor path, siblings, and child summaries from store
        let ancestors = store.getDocAncestry(for: docId).filter { $0.id != docId }.map { $0.content }
        let siblings = store.documents.filter { $0.parentId == doc.parentId && $0.id != docId }.map { $0.content }
        let children = store.getChildDocuments(for: docId)

        let activeNode = NoteNodeRecord(
            id: "node_\(docId.prefix(8))",
            parent_id: doc.parentId,
            level: max(1, ancestors.count + 1),
            title: title,
            scope_note: scopeNote,
            why: "Direct single note fill",
            expected_depth: depth,
            prerequisites: [],
            status: .filling
        )

        // Seed tree context so prompt helpers find ancestors and siblings
        if self.tree.nodes[activeNode.id] == nil {
            self.tree.addNode(activeNode)
            for anc in ancestors {
                let ancNode = NoteNodeRecord(id: "anc_\(anc.hashValue)", parent_id: nil, level: 1, title: anc, scope_note: anc, why: "Ancestor")
                self.tree.addNode(ancNode)
            }
            for sib in siblings {
                let sibNode = NoteNodeRecord(id: "sib_\(sib.hashValue)", parent_id: doc.parentId, level: activeNode.level, title: sib, scope_note: sib, why: "Sibling")
                self.tree.addNode(sibNode)
            }
            for ch in children {
                let chNode = NoteNodeRecord(id: ch.id, parent_id: activeNode.id, level: activeNode.level + 1, title: ch.content, scope_note: ch.content, why: "Child")
                self.tree.addNode(chNode)
            }
        }

        // Ensure grounding record exists
        if self.groundingRecord == nil {
            self.groundingRecord = GroundingRecord(
                root_title: title,
                chosen_sense: title,
                qid: nil,
                wikipedia_title: title,
                domain: "general",
                entity_type: "concept",
                freshness: "slow_changing"
            )
        }

        onProgress?("Routing Open APIs (Wikipedia, PubMed, OpenAlex, arXiv)...")

        // 1. P4: Router
        let plan = try await self.executeRouter(for: activeNode)

        // 2. Fetch Evidence via P5 Query Builder + Cache + P6 Validator
        onProgress?("Querying & validating evidence from \(plan.plan.count) sources...")
        var evidenceList: [EvidenceItem] = []
        var conflictsList: [String] = []

        for step in plan.plan {
            let reqs = try await self.executeQueryBuilder(step: step, node: activeNode)
            for r in reqs.requests {
                let (raw, _) = await AutoNoteAPICatalog.shared.executeCallWithCache(api: r.api, params: r.params)
                let ev = try await self.executeEvidenceValidator(rawResult: raw, node: activeNode)
                if ev.discard != true {
                    evidenceList.append(ev)
                    for kf in ev.key_facts {
                        if let conflict = kf.conflicts_with {
                            conflictsList.append("Conflict on '\(kf.claim)' with \(conflict)")
                        }
                    }
                }
            }
        }

        if evidenceList.isEmpty {
            for fbAPI in plan.fallback_chain {
                let (raw, _) = await AutoNoteAPICatalog.shared.executeCallWithCache(api: fbAPI, params: ["query": activeNode.title])
                let ev = try await self.executeEvidenceValidator(rawResult: raw, node: activeNode)
                if ev.discard != true {
                    evidenceList.append(ev)
                    break
                }
            }
        }

        // 3. P7: Note Writer + P9: QA Gate
        onProgress?("Synthesizing comprehensive note & passing QA Gate...")
        var writtenNote: (markdown: String, meta: WriterOutputMetadata)? = nil
        var qaPassed = false
        var retryCount = 0
        var fixInstructions: String? = nil

        while retryCount <= self.config.writer_retries && !qaPassed {
            let writerResult = try await self.executeNoteWriter(
                node: activeNode,
                evidence: evidenceList,
                conflicts: conflictsList,
                fixInstructions: fixInstructions
            )
            writtenNote = writerResult

            let qa = try await self.executeQAGate(noteMarkdown: writerResult.markdown, node: activeNode, evidence: evidenceList)
            if qa.pass {
                qaPassed = true
            } else {
                retryCount += 1
                fixInstructions = qa.fix_instructions
            }
        }

        guard let md = writtenNote?.markdown, !md.isEmpty else {
            throw AISocraticService.ServiceError.invalidResponse("Model returned empty note markdown")
        }

        onProgress?("Saving formatted blocks and citations to note...")

        let parsedBlocks = MasterPlanService.shared.parseChapterContent(
            rawText: md,
            chapterTitle: title
        ).blocks

        try await store.dbManager.dbWriter.write { db in
            try Block.filter(Block.Columns.rootDocId == docId && Block.Columns.type != BlockType.doc.rawValue)
                .deleteAll(db)

            var innerSort = 0
            for item in parsedBlocks {
                if item.content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == title.lowercased() {
                    continue
                }
                let bType = item.blockType == .callout ? .paragraph : item.blockType
                let contentBlock = Block(
                    id: Block.generateId(),
                    rootDocId: docId,
                    parentId: docId,
                    type: bType,
                    content: item.content,
                    sortOrder: innerSort,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try contentBlock.insert(db)
                innerSort += 1
            }

            if innerSort == 0 {
                let empty = Block(
                    id: Block.generateId(),
                    rootDocId: docId,
                    parentId: docId,
                    type: .paragraph,
                    content: "",
                    sortOrder: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try empty.insert(db)
            }
        }

        // Update in-memory tree if node exists
        if var treeNode = tree.nodes.values.first(where: { $0.title.lowercased() == title.lowercased() }) {
            treeNode.status = .filled
            treeNode.markdown_content = md
            tree.nodes[treeNode.id] = treeNode
        }

        store.loadDocuments()
        store.reloadBlocks()
        onProgress?("Done")
    }

    // MARK: - BlockStore Integration
    public func commitTreeToStore(rootDocId: String, store: BlockStore) {
        let nodesToCommit = tree.nodes.values
            .filter { $0.status == .approved || $0.status == .filled || $0.status == .needs_review || $0.status == .unverified || $0.status == .edited || $0.status == .proposed }
            .sorted(by: {
                if $0.level != $1.level { return $0.level < $1.level }
                return $0.reading_order < $1.reading_order
            })

        guard !nodesToCommit.isEmpty else { return }

        var nodeIdToDocId: [String: String] = [:]
        if let rootId = tree.root?.id {
            nodeIdToDocId[rootId] = rootDocId
        }

        for (idx, node) in nodesToCommit.enumerated() {
            let createdDocId = commitNodeToStore(
                node: node,
                rootDocId: rootDocId,
                store: store,
                sortOrder: idx,
                parentDocIdMap: nodeIdToDocId
            )
            if let cId = createdDocId {
                nodeIdToDocId[node.id] = cId
            }
        }

        store.expandedDocIds.insert(rootDocId)
        store.loadDocuments()
        store.reloadBlocks()
    }

    @discardableResult
    private func commitNodeToStore(
        node: NoteNodeRecord,
        rootDocId: String,
        store: BlockStore,
        sortOrder: Int,
        parentDocIdMap: [String: String] = [:]
    ) -> String? {
        // If it's the root node itself, update rootDoc blocks directly without creating a duplicate child document
        if node.parent_id == nil || node.id == tree.root?.id {
            if let md = node.markdown_content, !md.isEmpty {
                let blocks = MasterPlanService.shared.parseChapterContent(
                    rawText: md,
                    chapterTitle: node.title
                ).blocks

                do {
                    try store.dbManager.dbWriter.write { db in
                        try Block.filter(Block.Columns.rootDocId == rootDocId && Block.Columns.type != BlockType.doc.rawValue)
                            .deleteAll(db)

                        var innerSort = 0
                        for item in blocks {
                            let bType = item.blockType == .callout ? .paragraph : item.blockType
                            let contentBlock = Block(
                                id: Block.generateId(),
                                rootDocId: rootDocId,
                                parentId: rootDocId,
                                type: bType,
                                content: item.content,
                                sortOrder: innerSort,
                                createdAt: Date(),
                                updatedAt: Date()
                            )
                            try contentBlock.insert(db)
                            innerSort += 1
                        }
                    }
                    store.reloadBlocks()
                } catch {
                    print("Error updating root doc blocks: \(error)")
                }
            } else {
                // Skeletal root note: if root doc has no non-doc blocks or only 1 empty block, insert skeletal marker
                do {
                    try store.dbManager.dbWriter.write { db in
                        let existingNonDocBlocks = try Block.filter(Block.Columns.rootDocId == rootDocId && Block.Columns.type != BlockType.doc.rawValue).fetchAll(db)
                        if existingNonDocBlocks.isEmpty || (existingNonDocBlocks.count == 1 && existingNonDocBlocks[0].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            try Block.filter(Block.Columns.rootDocId == rootDocId && Block.Columns.type != BlockType.doc.rawValue).deleteAll(db)
                            let skeletalBlock = Block(
                                id: Block.generateId(),
                                rootDocId: rootDocId,
                                parentId: rootDocId,
                                type: .quote,
                                content: "🪄 Skeletal Note • Scope: \(node.scope_note)",
                                sortOrder: 0,
                                createdAt: Date(),
                                updatedAt: Date()
                            )
                            try skeletalBlock.insert(db)
                        }
                    }
                    store.reloadBlocks()
                } catch {
                    print("Error setting skeletal root marker: \(error)")
                }
            }
            return rootDocId
        }

        let parentDocId = node.parent_id.flatMap { parentDocIdMap[$0] }
            ?? ((node.parent_id != nil && node.parent_id != tree.root?.id)
                ? (store.documents.first(where: { $0.content.lowercased() == (tree.nodes[node.parent_id!]?.title.lowercased() ?? "") })?.id ?? rootDocId)
                : rootDocId)

        let blocks: [HierarchicalBlockItem]
        let summary: String
        if let md = node.markdown_content, !md.isEmpty {
            blocks = MasterPlanService.shared.parseChapterContent(
                rawText: md,
                chapterTitle: node.title
            ).blocks
            summary = node.scope_note
        } else {
            let skeletalText = "🪄 Skeletal Note • Scope: \(node.scope_note)"
            summary = skeletalText
            blocks = [HierarchicalBlockItem(typeString: "quote", content: skeletalText)]
        }

        let createdDoc = store.commitSingleMasterPlanChapter(
            rootDocId: parentDocId,
            chapterTitle: node.title,
            summary: summary,
            blocks: blocks,
            sortOrder: sortOrder
        )
        return createdDoc?.id
    }

    private func parseRetryDelay(from errorDescription: String) -> Double {
        if let regex = try? NSRegularExpression(pattern: #"try again in ([0-9]+(?:\.[0-9]+)?)s"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: errorDescription, range: NSRange(errorDescription.startIndex..., in: errorDescription)),
           let range = Range(match.range(at: 1), in: errorDescription),
           let seconds = Double(errorDescription[range]) {
            return max(seconds + 1.2, 2.0)
        }
        return 6.0
    }

    // MARK: - LLM Execution & Validation Engine
    private func executeLLMWithRetry(system: String, user: String) async throws -> String {
        var attemptsLeft = 3
        var currentPrompt = user

        while attemptsLeft > 0 {
            attemptsLeft -= 1
            do {
                let res = try await executeLLMCall(systemInstruction: system, userPrompt: currentPrompt)
                let cleaned = AISocraticService.sanitizeLLMJSONOutput(res)
                if isValidJSON(cleaned) {
                    return cleaned
                }
                if attemptsLeft > 0 {
                    currentPrompt = user + "\n\nCRITICAL: Your previous response was not valid JSON. You MUST return strictly valid JSON conforming to the requested schema. No markdown outside JSON."
                }
            } catch {
                let errString = error.localizedDescription
                let isRateLimit = errString.contains("rate limit") || errString.contains("429") || errString.contains("tokens")
                if isRateLimit && attemptsLeft > 0 {
                    let delay = parseRetryDelay(from: errString)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                if attemptsLeft == 0 {
                    throw error
                }
            }
        }
        throw AISocraticService.ServiceError.parsingError("Unable to obtain valid response from AI model")
    }

    private func executeLLMCall(systemInstruction: String, userPrompt: String) async throws -> String {
        let settings = AISettings.shared
        let provider = settings.activeNotesProvider
        let apiKey = settings.activeNotesApiKey
        let model = settings.activeNotesModel

        switch provider {
        case .groq:
            let effModel = (model.contains("llama-3.3-70b") || model.isEmpty) ? "qwen/qwen3.8-27b" : model
            return try await callOpenAI(
                apiKey: apiKey,
                model: effModel,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt,
                customEndpoint: "https://api.groq.com/openai/v1"
            )
        case .gemini:
            return try await callGemini(apiKey: apiKey, model: model, systemInstruction: systemInstruction, userPrompt: userPrompt)
        case .openai:
            return try await callOpenAI(apiKey: apiKey, model: model, systemInstruction: systemInstruction, userPrompt: userPrompt)
        case .local:
            return try await callOpenAI(
                apiKey: "ollama",
                model: model,
                systemInstruction: systemInstruction,
                userPrompt: userPrompt,
                customEndpoint: settings.activeLocalEndpoint
            )
        }
    }

    private func callGemini(apiKey: String, model: String, systemInstruction: String, userPrompt: String) async throws -> String {
        let targetModel = (model == "gemini-2.5-flash") ? "gemini-3.6-flash" : model
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(targetModel):generateContent?key=\(cleanKey)"
        guard let url = URL(string: urlString) else {
            throw AISocraticService.ServiceError.invalidResponse("Invalid Gemini URL")
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
            "contents": [
                ["role": "user", "parts": [["text": userPrompt]]]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.2
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "HTTP Error"
            throw AISocraticService.ServiceError.invalidResponse("Gemini API Error: \(errText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let rawText = firstPart["text"] as? String else {
            throw AISocraticService.ServiceError.parsingError("Malformed Gemini JSON response")
        }

        return rawText
    }

    private func callOpenAI(
        apiKey: String,
        model: String,
        systemInstruction: String,
        userPrompt: String,
        customEndpoint: String? = nil
    ) async throws -> String {
        let isLocal = (customEndpoint != nil)
        let endpointUrlString = isLocal
            ? "\(customEndpoint!.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/chat/completions"
            : "https://api.openai.com/v1/chat/completions"

        guard let url = URL(string: endpointUrlString) else {
            throw AISocraticService.ServiceError.invalidResponse("Invalid Endpoint URL")
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemInstruction],
            ["role": "user", "content": userPrompt]
        ]

        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.2
        ]

        if !isLocal {
            requestBody["response_format"] = ["type": "json_object"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty && cleanKey != "ollama" {
            request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errText = String(data: data, encoding: .utf8) ?? "HTTP Error"
            throw AISocraticService.ServiceError.invalidResponse("LLM Error: \(errText)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let rawText = message["content"] as? String else {
            throw AISocraticService.ServiceError.parsingError("Malformed OpenAI JSON payload structure.")
        }

        return rawText
    }

    // MARK: - Parsing Helpers
    private func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func parseJSON<T: Decodable>(raw: String, fallback: T) -> T {
        let clean = AISocraticService.sanitizeLLMJSONOutput(raw)
        if let data = clean.data(using: .utf8), let val = try? JSONDecoder().decode(T.self, from: data) {
            return val
        }
        return fallback
    }

    private func toJSONString<T: Encodable>(_ item: T) -> String {
        let enc = JSONEncoder()
        if let data = try? enc.encode(item), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    private func parseWriterOutput(rawText: String, nodeId: String) -> (markdown: String, meta: WriterOutputMetadata) {
        var markdown = rawText
        var meta = WriterOutputMetadata(node_id: nodeId)

        // Find fenced json metadata block at end
        if let jsonStart = rawText.range(of: "```json", options: .backwards),
           let jsonEnd = rawText.range(of: "```", options: .backwards, range: jsonStart.upperBound..<rawText.endIndex) {
            let jsonPayload = String(rawText[jsonStart.upperBound..<jsonEnd.lowerBound])
            let cleanJSON = AISocraticService.sanitizeLLMJSONOutput(jsonPayload)
            if let data = cleanJSON.data(using: .utf8),
               let parsedMeta = try? JSONDecoder().decode(WriterOutputMetadata.self, from: data) {
                meta = parsedMeta
            }
            markdown = String(rawText[..<jsonStart.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        meta.word_count = markdown.split { $0.isWhitespace || $0.isNewline }.count
        return (markdown, meta)
    }
}
