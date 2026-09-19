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
        onSlashTrigger: @escaping () -> Void = {}
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
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.placeholderString = placeholder
        textView.coordinator = context.coordinator

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

    public func updateNSView(_ nsView: CustomNSTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
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
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            if textView.string.hasSuffix("/") {
                parent.onSlashTrigger()
            }
        }
    }
}

public final class CustomNSTextView: NSTextView {
    weak var coordinator: BlockTextViewRepresentable.Coordinator?
    public var placeholderString: String = ""

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
