import Foundation

public struct DocTreeNode: Identifiable, Equatable, Sendable {
    public var id: String { doc.id }
    public let doc: Block
    public let level: Int
    public var children: [DocTreeNode]

    public init(doc: Block, level: Int = 0, children: [DocTreeNode] = []) {
        self.doc = doc
        self.level = level
        self.children = children
    }

    public var hasChildren: Bool {
        !children.isEmpty
    }
}

public struct DocOutlineItem: Identifiable, Equatable, Sendable {
    public var id: String { blockId }
    public let blockId: String
    public let title: String
    public let level: Int // 1, 2, or 3
    public let sortOrder: Int

    public init(blockId: String, title: String, level: Int, sortOrder: Int) {
        self.blockId = blockId
        self.title = title
        self.level = level
        self.sortOrder = sortOrder
    }
}

public struct SearchResult: Identifiable, Equatable, Sendable {
    public var id: String { blockId }
    public let blockId: String
    public let rootDocId: String
    public let docTitle: String
    public let blockType: BlockType
    public let snippet: String
    public let rawContent: String

    public init(
        blockId: String,
        rootDocId: String,
        docTitle: String,
        blockType: BlockType,
        snippet: String,
        rawContent: String
    ) {
        self.blockId = blockId
        self.rootDocId = rootDocId
        self.docTitle = docTitle
        self.blockType = blockType
        self.snippet = snippet
        self.rawContent = rawContent
    }
}

public enum LinkEdgeType: String, Codable, Sendable {
    case wikiLink = "WikiLink [[...]]"
    case blockRef = "Block Transclusion ((...))"
}

public struct BacklinkItem: Identifiable, Equatable, Sendable {
    public var id: String { "\(block.id)-\(linkType.rawValue)" }
    public let block: Block
    public let sourceDocTitle: String
    public let contextSnippet: String
    public let linkType: LinkEdgeType
    public let isUnresolved: Bool

    public init(
        block: Block,
        sourceDocTitle: String,
        contextSnippet: String,
        linkType: LinkEdgeType = .blockRef,
        isUnresolved: Bool = false
    ) {
        self.block = block
        self.sourceDocTitle = sourceDocTitle
        self.contextSnippet = contextSnippet
        self.linkType = linkType
        self.isUnresolved = isUnresolved
    }
}

public struct GraphNode: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let isCurrentDoc: Bool
    public let blockCount: Int

    public init(id: String, title: String, isCurrentDoc: Bool = false, blockCount: Int = 1) {
        self.id = id
        self.title = title
        self.isCurrentDoc = isCurrentDoc
        self.blockCount = blockCount
    }
}

public struct GraphEdge: Identifiable, Equatable, Hashable, Sendable {
    public var id: String { "\(sourceId)->\(targetId)" }
    public let sourceId: String
    public let targetId: String

    public init(sourceId: String, targetId: String) {
        self.sourceId = sourceId
        self.targetId = targetId
    }
}
