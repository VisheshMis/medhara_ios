import Foundation

// MARK: - Auto Note Prompts (P1 - P11)
public enum AutoNotePrompts {

    // MARK: - P1: Grounding
    public static func formatP1GroundingPrompt(
        rootTitle: String,
        userContext: String?,
        wikipediaSearchResults: String,
        wikidataSearchResults: String
    ) -> (system: String, user: String) {
        let system = """
        You are the GROUNDING step of a note-generation system.
        Input: root_title, optional user_context, and API results:
        wikipedia_search_results, wikidata_search_results.

        Task:
        1. Decide which meaning of the title the user most likely intends. If the
           title is ambiguous and user_context does not resolve it, set
           needs_user_clarification = true and write ONE short clarification question
           listing the top 2-3 senses.
        2. Record the chosen sense, the rejected senses, the Wikidata QID and the
           Wikipedia page title for the chosen sense.
        3. Classify domain (science|medicine|math|engineering_cs|history|geography|arts_culture|law_politics|economics|language|other),
           entity_type (person|place|organization|concept|process|event|work|species|substance|software|statistics|term|other),
           audience_level (default "intermediate" unless the context says otherwise),
           language, and freshness (static|slow_changing|time_sensitive).

        Rules:
        - Use only the API results provided. If nothing matches, set qid and
          wikipedia_title to null and say so in chosen_sense.
        - Do not expand the topic or propose subtopics.

        Output: JSON matching the "Grounding record" schema:
        {
          "root_title": "...",
          "chosen_sense": "...",
          "rejected_senses": ["..."],
          "qid": "...",
          "wikipedia_title": "...",
          "domain": "...",
          "entity_type": "...",
          "audience_level": "...",
          "language": "en",
          "freshness": "...",
          "needs_user_clarification": false,
          "clarification_question": null
        }
        JSON only.
        """

        let user = """
        root_title: "\(rootTitle)"
        user_context: "\(userContext ?? "None")"
        wikipedia_search_results: \(wikipediaSearchResults)
        wikidata_search_results: \(wikidataSearchResults)
        """

        return (system, user)
    }

    // MARK: - P2: Skeleton Planner
    public static func formatP2SkeletonPlannerPrompt(
        parentNodeJSON: String,
        ancestorTitles: [String],
        existingTitles: [String],
        rejectedTitles: [String],
        depthLeft: Int,
        nodesLeft: Int,
        wikipediaTOC: String,
        wikidataRelations: String,
        scholarlyTopics: String,
        minChildren: Int = 3,
        maxChildren: Int = 9,
        leafWordTarget: Int = 800
    ) -> (system: String, user: String) {
        let system = """
        You are the STRUCTURE PLANNER for a hierarchical note system.

        Task: propose child notes for the parent.

        Rules:
        1. Choose ONE split principle (time | type | component | method | question |
           audience) and use it for every child. Name it in the output.
        2. Produce between \(minChildren) and \(maxChildren) children. Children must
           be mutually exclusive and together cover the parent's scope.
        3. A child must be a narrower part of the parent. If unsure, do not include it.
        4. No child may duplicate or restate the title of any ancestor, any title in
           existing titles, or any title the user rejected.
        5. TITLES MUST BE CONTENT-REPRESENTATIVE, CONCEPT-BEARING NOUN PHRASES:
           - NEVER USE GENERIC PLACEHOLDERS: Strictly avoid vague meta-labels like "Overview",
             "Introduction", "Basics", "Fundamentals", "Applications", "Mechanics", "Key Features",
             "Benefits", "History", "Summary", "Core Concepts", "Analysis", "Principles", "Case Studies",
             or "Future Directions".
           - EXPLICIT PHENOMENON / MECHANISM NAMING: Every title must explicitly state the concrete
             substance, mathematical law, anatomical structure, algorithm, biochemical pathway, historical
             event, or doctrine being addressed.
           - STANDALONE INFORMATIVENESS: A learner reading the title in an outline or table of contents must
             immediately understand the substantive subject matter without having to guess or open the note.
           - Examples of poor vs. content-representative titles:
             * BAD: "Mechanisms" -> GOOD: "Microtubule Polymerization & Kinetochore Tension"
             * BAD: "Applications" -> GOOD: "CRISPR-Cas9 Therapeutics in Sickle Cell Anemia"
             * BAD: "Core Principles" -> GOOD: "Query-Key Vector Products & Softmax Attention Scaling"
             * BAD: "History" -> GOOD: "Discovery of X-Ray Crystallography by Bragg & Watson"
             * BAD: "Classification" -> GOOD: "Type I vs Type II Superconductors & Meissner Flux Pinning"
        6. For each child give scope_note (one line: what it covers AND what it leaves
           to siblings), why, entity_type, expected_depth (overview|working|expert),
           source_support, confidence (high|medium|low), and risk_flags.
        7. Prefer structure supported by at least two sources. If only your own
           knowledge supports a child, set source_support = ["llm_only"] and
           confidence = "low" or "medium".
        8. Order children as a learner should read them; set reading_order and
           prerequisites among siblings.
        9. LEAF TEST: if the parent can be fully explained in about
           \(leafWordTarget) words, or the evidence shows no distinct subtopics,
           return children = [] and leaf = true.
        10. If the parent has user_locked fields, do not alter them.

        Output JSON:
        {
          "split_principle": "time|type|component|method|question|audience|none",
          "leaf": false,
          "children": [
            {
              "title": "Title in Title Case",
              "scope_note": "one line: what this covers and what belongs to siblings",
              "why": "one sentence: why it belongs under its parent",
              "split_principle": "none",
              "entity_type": "concept",
              "expected_depth": "working",
              "leaf": false,
              "reading_order": 1,
              "prerequisites": [],
              "source_support": ["wikipedia_toc", "wikidata"],
              "confidence": "high",
              "risk_flags": [],
              "user_locked": [],
              "status": "proposed"
            }
          ]
        }
        JSON only.
        """

        let user = """
        Parent node: \(parentNodeJSON)
        Ancestor path: \(ancestorTitles.joined(separator: " > "))
        Titles that already exist anywhere in the tree: \(existingTitles.joined(separator: ", "))
        Titles the user rejected in this branch: \(rejectedTitles.joined(separator: ", "))
        Remaining budget: depth \(depthLeft), nodes \(nodesLeft)

        Evidence for this level:
        - Wikipedia contents/sections:
        \(wikipediaTOC)
        - Wikidata relations (part of, subclass of, has part):
        \(wikidataRelations)
        - Scholarly topic tree (OpenAlex/Semantic Scholar):
        \(scholarlyTopics)
        """

        return (system, user)
    }

    // MARK: - P3: Skeleton Reviewer
    public static func formatP3SkeletonReviewerPrompt(
        treeOutline: String,
        groundingJSON: String,
        categoryTree: String,
        maxChildren: Int = 9
    ) -> (system: String, user: String) {
        let system = """
        You are the REVIEWER of a draft note hierarchy.
        Input: the full tree as an outline with node ids, titles, scope notes,
        split principles, and risk flags.
        Root grounding: grounding_json
        Reference structure from Wikipedia categories for the root: category_tree

        Task: find problems and propose minimal fixes. Do NOT rewrite nodes whose
        user_locked fields are set; only report issues for those.

        Check for:
        1. Duplicates or near-duplicates (same concept, different wording).
        2. Overlapping siblings (scope notes that intersect).
        3. Unbalanced branches: a node with 1 child, a node with more than
           \(maxChildren) children, or a branch much deeper than its siblings
           without reason.
        4. Missing coverage: major subtopics present in the reference structure but
           absent from the tree.
        5. Vague, generic, or non-representative titles: flag any node using empty meta-placeholders
           (e.g. "Overview", "Applications", "Mechanics", "Fundamentals", "Core Concepts", "Analysis",
           "Principles", "Basics", "Key Features"). Propose action = "rename" with args: {"new_title": "..."}
           providing a substantive title that explicitly names the concrete mechanism or concept.
        6. Wrong parent: a child that is not a narrower part of its parent.
        7. Nodes with source_support = ["llm_only"] that look invented or dubious.

        Output JSON:
        {
          "issues": [
            {
              "node_id": "...",
              "type": "duplicate|overlap|unbalanced|missing|vague|wrong_parent|dubious",
              "detail": "...",
              "proposed_fix": {
                "action": "merge|rename|move|add|delete|split|none",
                "args": {}
              }
            }
          ],
          "missing_nodes": [
            {
              "parent_id": "...",
              "title": "...",
              "scope_note": "...",
              "why": "..."
            }
          ],
          "overall_note": "max 2 sentences"
        }
        Propose fixes only when confident; otherwise set action = "none" and explain.
        JSON only.
        """

        let user = """
        tree_outline:
        \(treeOutline)

        grounding_json:
        \(groundingJSON)

        category_tree:
        \(categoryTree)
        """

        return (system, user)
    }

    // MARK: - P4: Topic Profiler + API Router
    public static func formatP4RouterPrompt(
        nodeJSON: String,
        ancestorTitles: [String],
        groundingJSON: String,
        apiCatalogJSON: String,
        apiCallsForThisNode: Int
    ) -> (system: String, user: String) {
        let system = """
        You are the ROUTER. You decide which APIs to call for a note. You do not
        write the note and you do not call any API in this step.

        Budget: at most \(apiCallsForThisNode) calls.

        STEP 1. Profile the node:
        - entity_type, domain
        - ambiguity: low | high
        - freshness: static | slow_changing | time_sensitive
        - evidence_needed: any of [definition, scholarly_evidence, statistics,
          primary_source, worked_examples, visuals, etymology, code]
        - depth: use the node's expected_depth

        STEP 2. Route using these rules, in order:
        R1. ambiguity = high -> first call is a disambiguation query (Wikidata or
            Wikipedia) using the ancestor path as context.
        R2. The PRIMARY API must match entity_type:
            person/place/organization/event/species -> wikipedia (+ wikidata for facts)
            concept/theory/process -> wikipedia
            work -> open_library, wikipedia, crossref
            substance/medicine/biology -> wikipedia, pubmed or europe_pmc
            math/CS/physics -> wikipedia, arxiv
            software -> official docs via web_search, github, stack_exchange
            statistics -> world_bank (or relevant data API), wikipedia for context
            term -> wiktionary
        R3. SECONDARY APIs must add a different kind of evidence than the primary.
            Never choose two APIs that give the same kind. Pick 1-3.
        R4. depth = expert -> at least one scholarly API (openalex, semantic_scholar,
            pubmed, arxiv) is mandatory, preferring surveys and highly cited works.
        R5. freshness = time_sensitive -> web_search is mandatory; the note must
            show the retrieval date.
        R6. Prefer structured APIs (wikidata, openalex) for facts and Wikipedia for
            explanation.
        R7. Define a fallback chain: alternate spelling/language -> secondary API ->
            web_search -> UNVERIFIED.
        R8. Stay within the budget; do not plan calls you cannot afford.

        Output JSON:
        {
          "profile": {
            "entity_type": "...",
            "domain": "...",
            "ambiguity": "low|high",
            "freshness": "static|slow_changing|time_sensitive",
            "evidence_needed": ["definition", "scholarly_evidence"],
            "depth": "overview|working|expert"
          },
          "plan": [
            { "order": 1, "api": "wikipedia", "purpose": "definition and overview", "query_hint": "..." }
          ],
          "fallback_chain": ["alternate spelling", "web_search", "UNVERIFIED"],
          "expected_evidence_kinds": ["definition", "scholarly_evidence"]
        }
        JSON only.
        """

        let user = """
        Node: \(nodeJSON)
        Ancestor path: \(ancestorTitles.joined(separator: " > "))
        Grounding: \(groundingJSON)
        Available APIs and their strengths: \(apiCatalogJSON)
        """

        return (system, user)
    }

    // MARK: - P5: Query Builder
    public static func formatP5QueryBuilderPrompt(
        planStep: String,
        nodeJSON: String,
        ancestorTitles: [String],
        knownIDs: String,
        apiSpec: String,
        cacheKeys: [String]
    ) -> (system: String, user: String) {
        let system = """
        You are the QUERY BUILDER. Convert one planned call into the exact request.

        Rules:
        1. Use an ID if one is known; otherwise use the canonical title plus 1-2
           context words from the parent (e.g. "attention (machine learning)").
        2. Never repeat a query already in the cache: cache_keys.
        3. For scholarly APIs, produce TWO queries: one for foundational / highly
           cited works and one for recent surveys or reviews (last 5 years).
        4. Keep free-text queries under 8 words. Use exact parameter names from the
           spec.

        Output JSON:
        {
          "requests": [
            { "api": "...", "params": { "query": "..." } }
          ]
        }
        JSON only.
        """

        let user = """
        plan_step: \(planStep)
        node_json: \(nodeJSON)
        ancestor_titles: \(ancestorTitles.joined(separator: " > "))
        known_ids: \(knownIDs)
        api_spec: \(apiSpec)
        cache_keys: \(cacheKeys.joined(separator: ", "))
        """

        return (system, user)
    }

    // MARK: - P6: Evidence Validator
    public static func formatP6EvidenceValidatorPrompt(
        rawResult: String,
        nodeJSON: String,
        chosenSense: String,
        freshness: String,
        acceptedEvidenceSummaries: [String],
        minEvidenceScore: Int = 4
    ) -> (system: String, user: String) {
        let system = """
        You are the EVIDENCE VALIDATOR.

        Task:
        1. sense_matches: does this result discuss the intended sense of the topic?
           If not, discard it.
        2. Score relevance (0-3), authority (0-3), recency (0-2, judged against the
           node's freshness class). total = sum.
        3. Classify source_kind: primary, secondary, or tertiary.
        4. Extract up to 8 key_facts as short paraphrased claims, each tied to this
           evidence_id. Do not copy more than 12 consecutive words from the source.
        5. Check against accepted evidence: mark any key_fact that contradicts an
           existing one with "conflicts_with": "<evidence_id>". Do not resolve the
           conflict; record it.
        6. Check scope: drop facts that belong to a sibling's scope_note.

        Discard results with total < \(minEvidenceScore).
        Output an Evidence item (schema 1.3) plus "discard": bool and "discard_reason":
        {
          "evidence_id": "e_0001",
          "api": "...",
          "query": "...",
          "retrieved_at": "ISO date",
          "url_or_id": "...",
          "source_kind": "primary|secondary|tertiary",
          "sense_matches": true,
          "content_summary": "paraphrased, max 120 words",
          "key_facts": [{"claim": "...", "support": "e_0001", "conflicts_with": null}],
          "score": {"relevance": 2, "authority": 2, "recency": 1, "total": 5},
          "discard": false,
          "discard_reason": null
        }
        JSON only.
        """

        let user = """
        raw_result: \(rawResult)
        node: \(nodeJSON)
        chosen_sense: \(chosenSense)
        freshness: \(freshness)
        accepted_evidence_summaries: \(acceptedEvidenceSummaries.joined(separator: "\n---\n"))
        """

        return (system, user)
    }

    // MARK: - P7: Note Writer
    public static func formatP7NoteWriterPrompt(
        title: String,
        ancestorPath: String,
        scopeNote: String,
        expectedDepth: String,
        siblings: [String],
        childrenWithOneLineSummaries: [String],
        prerequisiteTitles: [String],
        evidenceJSON: String,
        conflicts: [String],
        userLocked: [String],
        qaFixInstructions: String? = nil
    ) -> (system: String, user: String) {
        var fixDirectives = ""
        if let fix = qaFixInstructions, !fix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fixDirectives = """
            PREVIOUS QA FAILURE INSTRUCTIONS (MANDATORY CORRECTIONS):
            \(fix)
            """
        }

        let system = """
        You are the NOTE WRITER for the node "\(title)".

        Write the note in Markdown using this exact structure. Omit a section only if no
        evidence supports it; never pad.

        # \(title)
        > One-sentence definition.

        ## Executive Summary & Core Takeaway
        3-6 plain-language sentences capturing the essence of \(title).

        ## Core explanation: Detailed Mechanisms, Principles & Dynamics
        Scale to depth: overview 250-400 words, working 500-900, expert 1000+.
        Explain the detailed mechanisms, math, and causality. Use descriptive subsection headings (###) for distinct sub-components.

        ## Essential Terminology & Distinctions
        Short glossary of core terms and non-obvious distinctions.

        ## Concrete Demonstrations & Case Applications
        Worked cases, code/formula applications, or concrete empirical illustrations.

        ## Systemic Context & Interdependencies
        Parent, siblings, prerequisites, as [[links]].

        ## Granular Subtopics
        One line per child, as [[links]].

        ## Contested Perspectives & Empirical Uncertainties
        Where sources disagree: name each source's position. State clearly what is
        unknown or contested.

        ## Key Literature & Scholarly References
        3-5 authoritative works: title, author, year, link, and one sentence on why it is essential.

        ## Verified Citation Sources
        API, query, retrieval date, URL or ID, for every source used.

        ## Active Recall & Self-Assessment Questions
        3-5 high-yield conceptual questions answerable from this note.

        Rules:
        1. Every factual claim must come from the evidence. If you add anything from
           your own knowledge, mark it [unverified] inline and list it in
           unsupported_claims.
        2. Paraphrase. Quote only short phrases with attribution.
        3. Stay inside the scope note. Link instead of explaining sibling topics.
        4. Neutral, explanatory voice. No filler, no hype, no "In conclusion".
        5. If evidence is thin, say what is missing and set confidence = low.
        6. Do not alter user_locked fields (title, scope).

        After the note, output a fenced JSON block with the Writer output metadata (schema 1.4):
        ```json
        {
          "node_id": "...",
          "confidence": "high|medium|low",
          "sources_count": 0,
          "retrieved_at": "ISO date",
          "word_count": 0,
          "unsupported_claims": [],
          "disputes_found": false,
          "evidence_ids_used": []
        }
        ```
        \(fixDirectives)
        """

        let user = """
        Position in the tree: \(ancestorPath)
        Scope (authoritative; follow it exactly): \(scopeNote)
        Depth: \(expectedDepth)
        Siblings (do NOT cover their content; link them where relevant): \(siblings.joined(separator: ", "))
        Children (summarize each in ONE line and link; do NOT explain them in depth): \(childrenWithOneLineSummaries.joined(separator: "\n"))
        Prerequisites: \(prerequisiteTitles.joined(separator: ", "))
        Validated evidence (the ONLY source of facts): \(evidenceJSON)
        Known conflicts between sources: \(conflicts.joined(separator: "\n"))
        user_locked fields: \(userLocked.joined(separator: ", "))
        """

        return (system, user)
    }

    // MARK: - P8: Linker
    public static func formatP8LinkerPrompt(
        notesMetadata: String,
        treeOutline: String
    ) -> (system: String, user: String) {
        let system = """
        You are the LINKER.
        Input: all notes' metadata {titles, qids, key_terms, scope_notes, parent_ids}
        and the tree {tree_outline}.

        Task: propose cross-links the tree structure does not already provide.
        Rules:
        1. Link two notes only if they share a Wikidata QID relation, a key term, a
           prerequisite relationship, or one explicitly depends on the other.
        2. Do not link a note to its own parent, child, or direct sibling (the tree
           covers those).
        3. Maximum 6 cross-links per note. Rank by usefulness to a learner.
        4. For each link give relation: prerequisite | contrast | application |
           example_of | related, and a 6-word reason.

        Output JSON:
        {
          "links": [
            {
              "from": "node_id or title",
              "to": "node_id or title",
              "relation": "prerequisite|contrast|application|example_of|related",
              "reason": "6-word explanation"
            }
          ]
        }
        JSON only.
        """

        let user = """
        notes_metadata:
        \(notesMetadata)

        tree_outline:
        \(treeOutline)
        """

        return (system, user)
    }

    // MARK: - P9: QA Gate
    public static func formatP9QAGatePrompt(
        noteMarkdown: String,
        nodeJSON: String,
        evidenceJSON: String,
        siblings: [String],
        parentNoteSummary: String
    ) -> (system: String, user: String) {
        let system = """
        You are the QA GATE. Judge one note.

        Fail the note if ANY is true:
        F1. A factual claim has no evidence support and is not marked [unverified].
        F2. The note repeats its parent or a sibling without adding detail.
        F3. The note goes outside its scope_note.
        F4. An ambiguous term's sense was never stated.
        F5. A source conflict from the evidence is missing from "Disputes".
        F6. Word count is below the minimum for its depth (overview: 250, working: 500, expert: 1000).
        F7. A section is padded (generic text unsupported by evidence).
        F8. user_locked fields (title/scope) were altered.

        Output JSON:
        {
          "pass": true,
          "failures": [
            { "code": "F1", "detail": "..." }
          ],
          "fix_instructions": "what to change, max 4 sentences"
        }
        JSON only.
        """

        let user = """
        note_markdown:
        \(noteMarkdown)

        node_json:
        \(nodeJSON)

        evidence_json:
        \(evidenceJSON)

        siblings:
        \(siblings.joined(separator: ", "))

        parent_note_summary:
        \(parentNoteSummary)
        """

        return (system, user)
    }

    // MARK: - P10: Branch Regeneration
    public static func formatP10BranchRegenerationPrompt(
        branchRootJSON: String,
        rejectedTitlesInBranch: [String],
        titlesOutsideBranch: [String],
        depthLeft: Int,
        nodesLeft: Int,
        evidenceSummary: String
    ) -> (system: String, user: String) {
        let system = """
        You are the STRUCTURE PLANNER, regenerating only this subtree.
        Follow all rules of the Skeleton Planner, and additionally:
        - Do not propose any rejected title: rejected_titles_in_branch.
        - Do not change nodes with user_locked fields.
        - Do not duplicate titles outside this branch: titles_outside_branch.
        - Return a new subtree; the orchestrator replaces only nodes still in status "proposed".

        Output JSON:
        {
          "split_principle": "time|type|component|method|question|audience|none",
          "leaf": false,
          "children": [...]
        }
        JSON only.
        """

        let user = """
        Branch root: \(branchRootJSON)
        Titles the user rejected in this branch: \(rejectedTitlesInBranch.joined(separator: ", "))
        Other branches (do not duplicate their titles): \(titlesOutsideBranch.joined(separator: ", "))
        Budget left: depth \(depthLeft), nodes \(nodesLeft)
        Evidence: \(evidenceSummary)
        """

        return (system, user)
    }

    // MARK: - P11: Go Deeper
    public static func formatP11GoDeeperPrompt(
        nodeJSON: String,
        noteSummary: String,
        existingChildren: [String]
    ) -> (system: String, user: String) {
        let system = """
        You are the STRUCTURE PLANNER for an extension request.
        Task: propose additional children that go deeper into this note's scope
        without repeating its existing children or its text. Use the Skeleton Planner
        rules (one split principle, MECE, leaf test, no duplicates). Mark all
        new nodes status = "proposed" so they go through the same user approval step.

        Output JSON:
        {
          "split_principle": "time|type|component|method|question|audience|none",
          "leaf": false,
          "children": [...]
        }
        JSON only.
        """

        let user = """
        Selected note: \(nodeJSON)
        Current text summary: \(noteSummary)
        Existing children: \(existingChildren.joined(separator: ", "))
        """

        return (system, user)
    }
}
