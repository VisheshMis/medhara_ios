import Foundation

public enum LinkParser {
    public static let blockRefRegex = try! NSRegularExpression(pattern: #"\(\((b-[a-zA-Z0-9\-]+)\)\)"#)
    public static let wikiLinkRegex = try! NSRegularExpression(pattern: #"\[\[(.*?)\]\]"#)

    public struct InlineRef: Identifiable, Equatable, Sendable {
        public var id: String { blockId }
        public let blockId: String
        public let range: NSRange
    }

    public struct WikiLinkRef: Identifiable, Equatable, Sendable {
        public var id: String { "\(target)-\(range.location)" }
        public let target: String
        public let range: NSRange

        public init(target: String, range: NSRange) {
            self.target = target
            self.range = range
        }
    }

    public static func extractBlockRefs(from text: String) -> [InlineRef] {
        let nsText = text as NSString
        let matches = blockRefRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let idRange = match.range(at: 1)
            let blockId = nsText.substring(with: idRange)
            return InlineRef(blockId: blockId, range: match.range)
        }
    }

    public static func extractWikiLinks(from text: String) -> [WikiLinkRef] {
        let nsText = text as NSString
        let matches = wikiLinkRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let targetRange = match.range(at: 1)
            let rawTarget = nsText.substring(with: targetRange).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawTarget.isEmpty else { return nil }
            return WikiLinkRef(target: rawTarget, range: match.range)
        }
    }

    public static func containsBlockRef(_ text: String, targetId: String) -> Bool {
        text.contains("((\(targetId)))")
    }

    public static func containsWikiLink(_ text: String, target: String) -> Bool {
        text.contains("[[\(target)]]")
    }
}
