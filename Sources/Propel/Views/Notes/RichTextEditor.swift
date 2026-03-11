import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Create scroll view manually so we use our DarkModeTextView subclass
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = DarkModeTextView(
            frame: NSRect(origin: .zero, size: contentSize),
            textContainer: textContainer
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = true
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.importsGraphics = false
        textView.isAutomaticLinkDetectionEnabled = true

        // Dark mode appearance
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.white,
        ]

        textView.registerForDraggedTypes(textView.readablePasteboardTypes)

        scrollView.documentView = textView

        if attributedText.length > 0 {
            let fixed = Self.fixDarkModeColors(attributedText)
            textView.textStorage?.setAttributedString(fixed)
        }

        textView.checkTextInDocument(nil)
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if context.coordinator.isUpdating { return }

        let current = textView.attributedString()
        if current != attributedText {
            context.coordinator.isUpdating = true
            let selectedRange = textView.selectedRange()
            let fixed = Self.fixDarkModeColors(attributedText)
            textView.textStorage?.setAttributedString(fixed)
            let newLength = textView.textStorage?.length ?? 0
            if selectedRange.location <= newLength {
                let safeLoc = min(selectedRange.location, newLength)
                let safeLen = min(selectedRange.length, newLength - safeLoc)
                textView.setSelectedRange(NSRange(location: safeLoc, length: safeLen))
            }
            context.coordinator.isUpdating = false
        }
    }

    /// Convert black/very dark text colors to white for dark mode.
    static func fixDarkModeColors(_ input: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: input)
        let fullRange = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if let color = value as? NSColor {
                if isColorDark(color) {
                    result.addAttribute(.foregroundColor, value: NSColor.white, range: range)
                }
            } else {
                result.addAttribute(.foregroundColor, value: NSColor.white, range: range)
            }
        }
        return result
    }

    static func isColorDark(_ color: NSColor) -> Bool {
        if let rgb = color.usingColorSpace(.sRGB) {
            return rgb.brightnessComponent < 0.3
        }
        if let rgb = color.usingColorSpace(.deviceRGB) {
            return rgb.brightnessComponent < 0.3
        }
        if let rgb = color.usingColorSpace(.genericGray) {
            return rgb.whiteComponent < 0.3
        }
        return true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var isUpdating = false
        weak var textView: NSTextView?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            textView.checkTextInDocument(nil)
            parent.attributedText = textView.attributedString()
            isUpdating = false
        }

        func textView(
            _ textView: NSTextView,
            clickedOnLink link: Any,
            at charIndex: Int
        ) -> Bool {
            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return true
            }
            if let urlString = link as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}

// MARK: - Custom NSTextView that forces white text on paste

final class DarkModeTextView: NSTextView {
    override func paste(_ sender: Any?) {
        super.paste(sender)
        fixDarkColors()
    }

    override func pasteAsRichText(_ sender: Any?) {
        super.pasteAsRichText(sender)
        fixDarkColors()
    }

    override func pasteAsPlainText(_ sender: Any?) {
        super.pasteAsPlainText(sender)
        fixDarkColors()
    }

    private func fixDarkColors() {
        guard let storage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        guard fullRange.length > 0 else { return }

        storage.beginEditing()
        storage.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if let color = value as? NSColor, RichTextEditor.isColorDark(color) {
                storage.addAttribute(.foregroundColor, value: NSColor.white, range: range)
            } else if value == nil {
                storage.addAttribute(.foregroundColor, value: NSColor.white, range: range)
            }
        }
        storage.endEditing()
    }
}
