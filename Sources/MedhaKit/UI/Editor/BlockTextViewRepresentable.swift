import SwiftUI
import AppKit

public struct BlockTextViewRepresentable: NSViewRepresentable {
    @Binding public var text: String
    public var isFocused: Bool
    public var font: NSFont
    public var textColor: NSColor
    public var placeholder: String
    public var onCommitReturn: () -> Void
    public var onDeleteEmpty: () -> Void
    public var onDeleteAtStart: () -> Void
    public var onTab: () -> Void
    public var onShiftTab: () -> Void
    public var onArrowUp: () -> Void
    public var onArrowDown: () -> Void
    public var onSlashTrigger: () -> Void
    public var onAutoConvertToBullet: () -> Void
    public var onFocus: () -> Void

    public init(
        text: Binding<String>,
        isFocused: Bool,
        font: NSFont = .systemFont(ofSize: 14),
        textColor: NSColor = .labelColor,
        placeholder: String = "",
        onCommitReturn: @escaping () -> Void = {},
        onDeleteEmpty: @escaping () -> Void = {},
        onDeleteAtStart: @escaping () -> Void = {},
        onTab: @escaping () -> Void = {},
        onShiftTab: @escaping () -> Void = {},
        onArrowUp: @escaping () -> Void = {},
        onArrowDown: @escaping () -> Void = {},
        onSlashTrigger: @escaping () -> Void = {},
        onAutoConvertToBullet: @escaping () -> Void = {},
        onFocus: @escaping () -> Void = {}
    ) {
        self._text = text
        self.isFocused = isFocused
        self.font = font
        self.textColor = textColor
        self.placeholder = placeholder
        self.onCommitReturn = onCommitReturn
        self.onDeleteEmpty = onDeleteEmpty
        self.onDeleteAtStart = onDeleteAtStart
        self.onTab = onTab
        self.onShiftTab = onShiftTab
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onSlashTrigger = onSlashTrigger
        self.onAutoConvertToBullet = onAutoConvertToBullet
        self.onFocus = onFocus
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private var customParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4.0
        return style
    }

    public func makeNSView(context: Context) -> CustomNSTextView {
        let textView = CustomNSTextView(frame: NSRect(x: 0, y: 0, width: 700, height: 24))
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        if let container = textView.textContainer {
            container.widthTracksTextView = false
            container.lineFragmentPadding = 0
            container.containerSize = NSSize(width: 700, height: CGFloat.greatestFiniteMagnitude)
        }
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.placeholderString = placeholder
        textView.coordinator = context.coordinator

        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let style = customParagraphStyle
        textView.defaultParagraphStyle = style
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]

        textView.string = text
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: storage.length))
            storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))
            storage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: storage.length))
        }
        return textView
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: CustomNSTextView, context: Context) -> CGSize? {
        let proposedWidth = proposal.width ?? 0
        let targetWidth = max(proposedWidth > 0 ? proposedWidth : (nsView.bounds.width > 0 ? nsView.bounds.width : 700), 100)
        let fontHeight = ceil(font.pointSize * 1.35)
        let defaultSingleLineHeight = max(24, fontHeight + 4)

        guard let container = nsView.textContainer, let layoutManager = nsView.layoutManager else {
            return CGSize(width: targetWidth, height: defaultSingleLineHeight)
        }

        container.widthTracksTextView = false
        container.containerSize = CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)

        let usedRect = layoutManager.usedRect(for: container)
        if usedRect.height <= 0 || nsView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CGSize(width: targetWidth, height: defaultSingleLineHeight)
        }

        let totalHeight = max(defaultSingleLineHeight, ceil(usedRect.height) + nsView.textContainerInset.height * 2)
        return CGSize(width: targetWidth, height: totalHeight)
    }

    public func updateNSView(_ nsView: CustomNSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
            let style = customParagraphStyle
            if let storage = nsView.textStorage, storage.length > 0 {
                storage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: storage.length))
                storage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: storage.length))
                storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))
            }
            nsView.invalidateIntrinsicContentSize()
        }

        if nsView.font != font {
            nsView.font = font
            if let storage = nsView.textStorage, storage.length > 0 {
                storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))
            }
            nsView.invalidateIntrinsicContentSize()
        }
        if nsView.textColor != textColor {
            nsView.textColor = textColor
            if let storage = nsView.textStorage, storage.length > 0 {
                storage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: storage.length))
            }
        }
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }

        let style = customParagraphStyle
        nsView.defaultParagraphStyle = style
        nsView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]

        context.coordinator.parent = self

        if isFocused {
            if !context.coordinator.wasFocused {
                context.coordinator.wasFocused = true
                DispatchQueue.main.async {
                    if nsView.window?.firstResponder != nsView {
                        nsView.window?.makeFirstResponder(nsView)
                    }
                }
            }
        } else {
            context.coordinator.wasFocused = false
        }
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockTextViewRepresentable
        var wasFocused: Bool = false

        init(_ parent: BlockTextViewRepresentable) {
            self.parent = parent
        }

        public func textDidBeginEditing(_ notification: Notification) {
            wasFocused = true
            parent.onFocus()
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CustomNSTextView else { return }
            let string = textView.string

            // Auto-convert "- " or "* " at start of paragraph into a bullet list
            if string.hasPrefix("- ") || string.hasPrefix("* ") {
                let trimmed = String(string.dropFirst(2))
                parent.text = trimmed
                textView.string = trimmed
                textView.invalidateIntrinsicContentSize()
                parent.onAutoConvertToBullet()
                return
            }

            parent.text = string
            textView.invalidateIntrinsicContentSize()
            if string.hasSuffix("/") {
                parent.onSlashTrigger()
            }
        }
    }
}

public final class CustomNSTextView: NSTextView {
    weak var coordinator: BlockTextViewRepresentable.Coordinator?
    public var placeholderString: String = ""

    public override var intrinsicContentSize: NSSize {
        let fallbackWidth: CGFloat = 700
        let w = bounds.width > 0 ? bounds.width : fallbackWidth
        let f = font ?? NSFont.systemFont(ofSize: 14)
        let defaultLineHeight = max(24, ceil(f.pointSize * 1.35) + textContainerInset.height * 2)

        guard let container = textContainer, let layoutManager = layoutManager else {
            return NSSize(width: NSView.noIntrinsicMetric, height: defaultLineHeight)
        }
        container.widthTracksTextView = false
        container.containerSize = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        if used.height <= 0 || string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NSSize(width: NSView.noIntrinsicMetric, height: defaultLineHeight)
        }
        let h = max(defaultLineHeight, ceil(used.height) + textContainerInset.height * 2)
        return NSSize(width: NSView.noIntrinsicMetric, height: h)
    }

    public override func setFrameSize(_ newSize: NSSize) {
        let oldWidth = bounds.width
        super.setFrameSize(newSize)
        if let container = textContainer {
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: newSize.width, height: CGFloat.greatestFiniteMagnitude)
        }
        if abs(oldWidth - newSize.width) > 1 {
            invalidateIntrinsicContentSize()
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholderString.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            let rect = NSRect(x: 2, y: 2, width: bounds.width - 4, height: bounds.height)
            (placeholderString as NSString).draw(in: rect, withAttributes: attrs)
        }
    }

    public override func keyDown(with event: NSEvent) {
        guard let parent = coordinator?.parent else {
            super.keyDown(with: event)
            return
        }

        // Return / Enter (Keycode 36)
        if event.keyCode == 36 {
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event) // Shift+Return inserts newline
            } else {
                parent.onCommitReturn()
            }
            return
        }

        // Backspace / Delete (Keycode 51)
        if event.keyCode == 51 {
            if string.isEmpty {
                parent.onDeleteEmpty()
                return
            } else if selectedRange().location == 0 && selectedRange().length == 0 {
                parent.onDeleteAtStart()
                return
            }
        }

        // Tab (Keycode 48)
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                parent.onShiftTab()
            } else {
                parent.onTab()
            }
            return
        }

        // Up Arrow (Keycode 126)
        if event.keyCode == 126 {
            if selectedRange().location == 0 {
                parent.onArrowUp()
                return
            }
        }

        // Down Arrow (Keycode 125)
        if event.keyCode == 125 {
            if selectedRange().location >= string.count {
                parent.onArrowDown()
                return
            }
        }

        super.keyDown(with: event)
    }

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            coordinator?.wasFocused = true
            coordinator?.parent.onFocus()
        }
        return result
    }
}
