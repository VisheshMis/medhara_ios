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
    public var onTab: () -> Void
    public var onShiftTab: () -> Void
    public var onArrowUp: () -> Void
    public var onArrowDown: () -> Void
    public var onSlashTrigger: () -> Void
    public var onAutoConvertToBullet: () -> Void

    public init(
        text: Binding<String>,
        isFocused: Bool,
        font: NSFont = .systemFont(ofSize: 14),
        textColor: NSColor = .labelColor,
        placeholder: String = "",
        onCommitReturn: @escaping () -> Void = {},
        onDeleteEmpty: @escaping () -> Void = {},
        onTab: @escaping () -> Void = {},
        onShiftTab: @escaping () -> Void = {},
        onArrowUp: @escaping () -> Void = {},
        onArrowDown: @escaping () -> Void = {},
        onSlashTrigger: @escaping () -> Void = {},
        onAutoConvertToBullet: @escaping () -> Void = {}
    ) {
        self._text = text
        self.isFocused = isFocused
        self.font = font
        self.textColor = textColor
        self.placeholder = placeholder
        self.onCommitReturn = onCommitReturn
        self.onDeleteEmpty = onDeleteEmpty
        self.onTab = onTab
        self.onShiftTab = onShiftTab
        self.onArrowUp = onArrowUp
        self.onArrowDown = onArrowDown
        self.onSlashTrigger = onSlashTrigger
        self.onAutoConvertToBullet = onAutoConvertToBullet
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
        let textView = CustomNSTextView()
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
            container.widthTracksTextView = true
            container.lineFragmentPadding = 0
            container.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
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
        }
        return textView
    }

    public func sizeThatFits(_ proposal: ProposedViewSize, nsView: CustomNSTextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? (nsView.bounds.width > 0 ? nsView.bounds.width : 500)
        guard targetWidth > 0 else {
            return CGSize(width: targetWidth, height: 24)
        }

        if let container = nsView.textContainer, let layoutManager = nsView.layoutManager {
            container.containerSize = CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: container)
            let usedRect = layoutManager.usedRect(for: container)
            let totalHeight = max(24, ceil(usedRect.height) + nsView.textContainerInset.height * 2)
            return CGSize(width: targetWidth, height: totalHeight)
        }
        return CGSize(width: targetWidth, height: 24)
    }

    public func updateNSView(_ nsView: CustomNSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
            nsView.invalidateIntrinsicContentSize()
        }
        nsView.font = font
        nsView.textColor = textColor
        nsView.placeholderString = placeholder

        let style = customParagraphStyle
        nsView.defaultParagraphStyle = style
        nsView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]
        if let storage = nsView.textStorage, storage.length > 0 {
            storage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: storage.length))
        }

        context.coordinator.parent = self

        if isFocused && nsView.window?.firstResponder != nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockTextViewRepresentable

        init(_ parent: BlockTextViewRepresentable) {
            self.parent = parent
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
        guard let container = textContainer, let layoutManager = layoutManager else {
            return super.intrinsicContentSize
        }
        let w = bounds.width > 0 ? bounds.width : 500
        container.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        let h = max(22, ceil(used.height) + textContainerInset.height * 2)
        return NSSize(width: NSView.noIntrinsicMetric, height: h)
    }

    public override func setFrameSize(_ newSize: NSSize) {
        let oldWidth = bounds.width
        super.setFrameSize(newSize)
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
        if event.keyCode == 51 && string.isEmpty {
            parent.onDeleteEmpty()
            return
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
}
