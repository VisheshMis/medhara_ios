import Foundation

// MARK: - Auto-Note Pipeline Configuration
public struct AutoNotePipelineConfig: Codable, Sendable, Equatable {
    public var max_depth: Int
    public var min_children: Int
    public var max_children: Int
    public var max_nodes: Int
    public var leaf_word_target: Int
    public var api_calls_per_node: Int
    public var api_calls_per_node_expert: Int
    public var min_evidence_score: Int
    public var cache: String
    public var fill_order: String
    public var writer_retries: Int

    public init(
        max_depth: Int = 4,
        min_children: Int = 3,
        max_children: Int = 9,
        max_nodes: Int = 120,
        leaf_word_target: Int = 800,
        api_calls_per_node: Int = 6,
        api_calls_per_node_expert: Int = 10,
        min_evidence_score: Int = 4,
        cache: String = "by (api, normalized_query)",
        fill_order: String = "bottom_up",
        writer_retries: Int = 2
    ) {
        self.max_depth = max_depth
        self.min_children = min_children
        self.max_children = max_children
        self.max_nodes = max_nodes
        self.leaf_word_target = leaf_word_target
        self.api_calls_per_node = api_calls_per_node
        self.api_calls_per_node_expert = api_calls_per_node_expert
        self.min_evidence_score = min_evidence_score
        self.cache = cache
        self.fill_order = fill_order
        self.writer_retries = writer_retries
    }
}

// MARK: - 1.1 Grounding Record (Root)
public struct GroundingRecord: Codable, Sendable, Equatable {
    public var root_title: String
    public var chosen_sense: String
    public var rejected_senses: [String]
    public var qid: String?
    public var wikipedia_title: String?
    public var domain: String
    public var entity_type: String
    public var audience_level: String
    public var language: String
    public var freshness: String
    public var needs_user_clarification: Bool
    public var clarification_question: String?

    public init(
        root_title: String,
        chosen_sense: String,
        rejected_senses: [String] = [],
        qid: String? = nil,
        wikipedia_title: String? = nil,
        domain: String = "other",
        entity_type: String = "concept",
        audience_level: String = "intermediate",
        language: String = "en",
        freshness: String = "slow_changing",
        needs_user_clarification: Bool = false,
        clarification_question: String? = nil
    ) {
        self.root_title = root_title
        self.chosen_sense = chosen_sense
        self.rejected_senses = rejected_senses
        self.qid = qid
        self.wikipedia_title = wikipedia_title
        self.domain = domain
        self.entity_type = entity_type
        self.audience_level = audience_level
        self.language = language
        self.freshness = freshness
        self.needs_user_clarification = needs_user_clarification
        self.clarification_question = clarification_question
    }
}

// MARK: - 1.2 Node Status & State Machine
public enum NodeStatus: String, Codable, Sendable, CaseIterable {
    case proposed
    case edited
    case approved
    case filling
    case filled
    case needs_review
    case unverified
    case failed

    public var isTerminalFilled: Bool {
        self == .filled || self == .needs_review || self == .unverified
    }
}

// MARK: - 1.2 Node Record
public struct NoteNodeRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var parent_id: String?
    public var level: Int
    public var title: String
    public var scope_note: String
    public var why: String
    public var split_principle: String
    public var entity_type: String
    public var expected_depth: String
    public var leaf: Bool
    public var reading_order: Int
    public var prerequisites: [String]
    public var source_support: [String]
    public var confidence: String
    public var risk_flags: [String]
    public var user_locked: [String]
    public var status: NodeStatus

    // Persistent payloads
    public var markdown_content: String?
    public var writer_metadata: WriterOutputMetadata?
    public var blocks: [HierarchicalBlockItem]?

    public init(
        id: String,
        parent_id: String? = nil,
        level: Int = 1,
        title: String,
        scope_note: String,
        why: String = "",
        split_principle: String = "none",
        entity_type: String = "concept",
        expected_depth: String = "working",
        leaf: Bool = false,
        reading_order: Int = 1,
        prerequisites: [String] = [],
        source_support: [String] = ["wikipedia_toc"],
        confidence: String = "high",
        risk_flags: [String] = [],
        user_locked: [String] = [],
        status: NodeStatus = .proposed,
        markdown_content: String? = nil,
        writer_metadata: WriterOutputMetadata? = nil,
        blocks: [HierarchicalBlockItem]? = nil
    ) {
        self.id = id
        self.parent_id = parent_id
        self.level = level
        self.title = title
        self.scope_note = scope_note
        self.why = why
        self.split_principle = split_principle
        self.entity_type = entity_type
        self.expected_depth = expected_depth
        self.leaf = leaf
        self.reading_order = reading_order
        self.prerequisites = prerequisites
        self.source_support = source_support
        self.confidence = confidence
        self.risk_flags = risk_flags
        self.user_locked = user_locked
        self.status = status
        self.markdown_content = markdown_content
        self.writer_metadata = writer_metadata
        self.blocks = blocks
    }

    public mutating func lockField(_ fieldName: String) {
        if !user_locked.contains(fieldName) {
            user_locked.append(fieldName)
        }
    }

    public func isFieldLocked(_ fieldName: String) -> Bool {
        user_locked.contains(fieldName)
    }
}

// MARK: - 1.3 Evidence Item
public struct KeyFact: Codable, Sendable, Equatable {
    public var claim: String
    public var support: String
    public var conflicts_with: String?

    public init(claim: String, support: String, conflicts_with: String? = nil) {
        self.claim = claim
        self.support = support
        self.conflicts_with = conflicts_with
    }
}

public struct EvidenceScore: Codable, Sendable, Equatable {
    public var relevance: Int
    public var authority: Int
    public var recency: Int
    public var total: Int

    public init(relevance: Int = 0, authority: Int = 0, recency: Int = 0, total: Int = 0) {
        self.relevance = relevance
        self.authority = authority
        self.recency = recency
        self.total = total != 0 ? total : (relevance + authority + recency)
    }
}

public struct EvidenceItem: Codable, Sendable, Identifiable, Equatable {
    public var id: String { evidence_id }
    public var evidence_id: String
    public var api: String
    public var query: String
    public var retrieved_at: String
    public var url_or_id: String
    public var source_kind: String
    public var sense_matches: Bool
    public var content_summary: String
    public var key_facts: [KeyFact]
    public var score: EvidenceScore
    public var discard: Bool?
    public var discard_reason: String?

    public init(
        evidence_id: String,
        api: String,
        query: String,
        retrieved_at: String = ISO8601DateFormatter().string(from: Date()),
        url_or_id: String,
        source_kind: String = "secondary",
        sense_matches: Bool = true,
        content_summary: String,
        key_facts: [KeyFact] = [],
        score: EvidenceScore = EvidenceScore(relevance: 2, authority: 2, recency: 1, total: 5),
        discard: Bool? = nil,
        discard_reason: String? = nil
    ) {
        self.evidence_id = evidence_id
        self.api = api
        self.query = query
        self.retrieved_at = retrieved_at
        self.url_or_id = url_or_id
        self.source_kind = source_kind
        self.sense_matches = sense_matches
        self.content_summary = content_summary
        self.key_facts = key_facts
        self.score = score
        self.discard = discard
        self.discard_reason = discard_reason
    }
}

// MARK: - 1.4 Writer Output Metadata
public struct WriterOutputMetadata: Codable, Sendable, Equatable {
    public var node_id: String
    public var confidence: String
    public var sources_count: Int
    public var retrieved_at: String
    public var word_count: Int
    public var unsupported_claims: [String]
    public var disputes_found: Bool
    public var evidence_ids_used: [String]

    public init(
        node_id: String,
        confidence: String = "high",
        sources_count: Int = 0,
        retrieved_at: String = ISO8601DateFormatter().string(from: Date()),
        word_count: Int = 0,
        unsupported_claims: [String] = [],
        disputes_found: Bool = false,
        evidence_ids_used: [String] = []
    ) {
        self.node_id = node_id
        self.confidence = confidence
        self.sources_count = sources_count
        self.retrieved_at = retrieved_at
        self.word_count = word_count
        self.unsupported_claims = unsupported_claims
        self.disputes_found = disputes_found
        self.evidence_ids_used = evidence_ids_used
    }
}

// MARK: - 1.5 Run Report
public struct AttentionItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(node_id):\(reason)" }
    public var node_id: String
    public var reason: String

    public init(node_id: String, reason: String) {
        self.node_id = node_id
        self.reason = reason
    }
}

public struct RunReport: Codable, Sendable, Equatable {
    public var root_id: String
    public var nodes_total: Int
    public var nodes_filled: Int
    public var unverified: [String]
    public var low_confidence: [String]
    public var failed: [String]
    public var api_calls: [String: Int]
    public var cache_hits: Int
    public var user_edits: Int
    public var needs_attention: [AttentionItem]

    public init(
        root_id: String,
        nodes_total: Int = 0,
        nodes_filled: Int = 0,
        unverified: [String] = [],
        low_confidence: [String] = [],
        failed: [String] = [],
        api_calls: [String: Int] = [:],
        cache_hits: Int = 0,
        user_edits: Int = 0,
        needs_attention: [AttentionItem] = []
    ) {
        self.root_id = root_id
        self.nodes_total = nodes_total
        self.nodes_filled = nodes_filled
        self.unverified = unverified
        self.low_confidence = low_confidence
        self.failed = failed
        self.api_calls = api_calls
        self.cache_hits = cache_hits
        self.user_edits = user_edits
        self.needs_attention = needs_attention
    }
}

// MARK: - Auxiliary Structures for Prompts P2, P3, P4, P5, P8, P9
public struct P2SkeletonOutput: Codable, Sendable, Equatable {
    public var split_principle: String
    public var leaf: Bool
    public var children: [NoteNodeRecord]

    public init(split_principle: String = "component", leaf: Bool = false, children: [NoteNodeRecord] = []) {
        self.split_principle = split_principle
        self.leaf = leaf
        self.children = children
    }
}

public struct ReviewProposedFix: Codable, Sendable, Equatable {
    public var action: String // merge|rename|move|add|delete|split|none
    public var args: [String: String]?

    public init(action: String, args: [String: String]? = nil) {
        self.action = action
        self.args = args
    }
}

public struct ReviewIssue: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(node_id):\(type):\(detail.prefix(20))" }
    public var node_id: String
    public var type: String // duplicate|overlap|unbalanced|missing|vague|wrong_parent|dubious
    public var detail: String
    public var proposed_fix: ReviewProposedFix?

    public init(node_id: String, type: String, detail: String, proposed_fix: ReviewProposedFix? = nil) {
        self.node_id = node_id
        self.type = type
        self.detail = detail
        self.proposed_fix = proposed_fix
    }
}

public struct MissingNodeSuggestion: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(parent_id):\(title)" }
    public var parent_id: String
    public var title: String
    public var scope_note: String
    public var why: String

    public init(parent_id: String, title: String, scope_note: String, why: String) {
        self.parent_id = parent_id
        self.title = title
        self.scope_note = scope_note
        self.why = why
    }
}

public struct ReviewResult: Codable, Sendable, Equatable {
    public var issues: [ReviewIssue]
    public var missing_nodes: [MissingNodeSuggestion]
    public var overall_note: String

    public init(issues: [ReviewIssue] = [], missing_nodes: [MissingNodeSuggestion] = [], overall_note: String = "") {
        self.issues = issues
        self.missing_nodes = missing_nodes
        self.overall_note = overall_note
    }
}

public struct RouterPlanStep: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(order):\(api)" }
    public var order: Int
    public var api: String
    public var purpose: String
    public var query_hint: String

    public init(order: Int, api: String, purpose: String, query_hint: String) {
        self.order = order
        self.api = api
        self.purpose = purpose
        self.query_hint = query_hint
    }
}

public struct RouterProfile: Codable, Sendable, Equatable {
    public var entity_type: String?
    public var domain: String?
    public var ambiguity: String?
    public var freshness: String?
    public var evidence_needed: [String]?
    public var depth: String?

    public init(
        entity_type: String? = nil,
        domain: String? = nil,
        ambiguity: String? = nil,
        freshness: String? = nil,
        evidence_needed: [String]? = nil,
        depth: String? = nil
    ) {
        self.entity_type = entity_type
        self.domain = domain
        self.ambiguity = ambiguity
        self.freshness = freshness
        self.evidence_needed = evidence_needed
        self.depth = depth
    }
}

public struct RouterOutput: Codable, Sendable, Equatable {
    public var profile: RouterProfile?
    public var plan: [RouterPlanStep]
    public var fallback_chain: [String]
    public var expected_evidence_kinds: [String]

    public init(
        profile: RouterProfile? = nil,
        plan: [RouterPlanStep] = [],
        fallback_chain: [String] = [],
        expected_evidence_kinds: [String] = []
    ) {
        self.profile = profile
        self.plan = plan
        self.fallback_chain = fallback_chain
        self.expected_evidence_kinds = expected_evidence_kinds
    }
}

public struct QueryBuilderRequest: Codable, Sendable, Equatable {
    public var api: String
    public var params: [String: String]

    public init(api: String, params: [String: String]) {
        self.api = api
        self.params = params
    }
}

public struct QueryBuilderOutput: Codable, Sendable, Equatable {
    public var requests: [QueryBuilderRequest]

    public init(requests: [QueryBuilderRequest]) {
        self.requests = requests
    }
}

public struct CrossLink: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(from)->\(to):\(relation)" }
    public var from: String
    public var to: String
    public var relation: String // prerequisite|contrast|application|example_of|related
    public var reason: String

    public init(from: String, to: String, relation: String, reason: String) {
        self.from = from
        self.to = to
        self.relation = relation
        self.reason = reason
    }
}

public struct LinkerOutput: Codable, Sendable, Equatable {
    public var links: [CrossLink]

    public init(links: [CrossLink] = []) {
        self.links = links
    }
}

public struct QAFailure: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(code):\(detail.prefix(20))" }
    public var code: String // F1..F8
    public var detail: String

    public init(code: String, detail: String) {
        self.code = code
        self.detail = detail
    }
}

public struct QAGateOutput: Codable, Sendable, Equatable {
    public var pass: Bool
    public var failures: [QAFailure]
    public var fix_instructions: String

    public init(pass: Bool = true, failures: [QAFailure] = [], fix_instructions: String = "") {
        self.pass = pass
        self.failures = failures
        self.fix_instructions = fix_instructions
    }
}
