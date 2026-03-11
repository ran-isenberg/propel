import SwiftUI

struct NoteEditorView: View {
    let note: Note
    let onUpdate: (Note) -> Void

    @State private var title: String
    @State private var attributedContent: NSAttributedString
    @State private var textColor: Color = .white
    @State private var selectedFontFamily: String = "System Font"
    @State private var fontSizeText: String = "16"

    private static let fontFamilies: [String] = {
        let families = [
            "System Font",
            "Arial",
            "Georgia",
            "Helvetica Neue",
            "Menlo",
            "Monaco",
            "SF Mono",
            "Times New Roman",
            "Courier New",
            "Verdana",
            "Palatino",
            "Avenir",
            "Futura",
        ]
        let available = Set(NSFontManager.shared.availableFontFamilies)
        return families.filter { $0 == "System Font" || available.contains($0) }
    }()

    init(note: Note, onUpdate: @escaping (Note) -> Void) {
        self.note = note
        self.onUpdate = onUpdate
        _title = State(initialValue: note.title)
        _attributedContent = State(initialValue: Self.loadAttributedContent(from: note))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Note title", text: $title)
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .onChange(of: title) { saveChanges() }

            Divider()

            // Formatting toolbar
            HStack(spacing: 3) {
                // Font family + size (left-aligned)
                Picker("", selection: $selectedFontFamily) {
                    ForEach(Self.fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                .controlSize(.small)
                .onChange(of: selectedFontFamily) { applyFontFamily(selectedFontFamily) }

                TextField("", text: $fontSizeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 36)
                    .controlSize(.small)
                    .multilineTextAlignment(.center)
                    .onSubmit { applyTypedFontSize() }

                Button { adjustFontSize(by: -1) } label: {
                    Image(systemName: "minus").font(.caption2).frame(width: 18, height: 18)
                }
                Button { adjustFontSize(by: 1) } label: {
                    Image(systemName: "plus").font(.caption2).frame(width: 18, height: 18)
                }

                Divider().frame(height: 14)

                Button { applyTrait(.boldFontMask) } label: {
                    Image(systemName: "bold").frame(width: 22, height: 18)
                }
                Button { applyTrait(.italicFontMask) } label: {
                    Image(systemName: "italic").frame(width: 22, height: 18)
                }
                Button { toggleUnderline() } label: {
                    Image(systemName: "underline").frame(width: 22, height: 18)
                }
                Button { toggleStrikethrough() } label: {
                    Image(systemName: "strikethrough").frame(width: 22, height: 18)
                }

                Divider().frame(height: 14)

                ColorPicker("", selection: $textColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 22, height: 18)
                    .onChange(of: textColor) { applyColor(NSColor(textColor)) }

                ForEach(quickColors, id: \.name) { item in
                    Button {
                        textColor = item.color
                        applyColor(NSColor(item.color))
                    } label: {
                        Circle().fill(item.color).frame(width: 12, height: 12)
                    }
                }

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            RichTextEditor(attributedText: $attributedContent)
                .onChange(of: attributedContent) { saveChanges() }

            // Video/link embeds using same logic as card descriptions
            RichDescriptionView(text: attributedContent.string)
        }
        .padding(16)
        .id(note.id)
    }

    private var quickColors: [(name: String, color: Color)] {
        [
            ("White", .white),
            ("Yellow", .yellow),
            ("Green", .green),
            ("Cyan", .cyan),
            ("Orange", .orange),
            ("Red", .red),
            ("Purple", .purple),
        ]
    }

    private func saveChanges() {
        var updated = note
        updated.title = title
        updated.content = attributedContent.string
        updated.rtfData = try? attributedContent.data(
            from: NSRange(location: 0, length: attributedContent.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        onUpdate(updated)
    }

    private static func loadAttributedContent(from note: Note) -> NSAttributedString {
        if let rtfData = note.rtfData,
           let attributed = try? NSAttributedString(
               data: rtfData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           )
        {
            return RichTextEditor.fixDarkModeColors(attributed)
        }
        return NSAttributedString(
            string: note.content,
            attributes: [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.white,
            ]
        )
    }

    // MARK: - Font Helpers

    private func applyFontFamily(_ family: String) {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let size = font.pointSize
            let manager = NSFontManager.shared
            let traits = manager.traits(of: font)

            let newFont: NSFont
            if family == "System Font" {
                var base = NSFont.systemFont(ofSize: size)
                if traits.contains(.boldFontMask) {
                    base = manager.convert(base, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    base = manager.convert(base, toHaveTrait: .italicFontMask)
                }
                newFont = base
            } else if let base = NSFont(name: family, size: size) {
                var converted = base
                if traits.contains(.boldFontMask) {
                    converted = manager.convert(converted, toHaveTrait: .boldFontMask)
                }
                if traits.contains(.italicFontMask) {
                    converted = manager.convert(converted, toHaveTrait: .italicFontMask)
                }
                newFont = converted
            } else {
                newFont = manager.convert(font, toFamily: family)
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        attributedContent = textView.attributedString()
    }

    private func applyTrait(_ trait: NSFontTraitMask) {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let manager = NSFontManager.shared
            let newFont: NSFont
            if manager.traits(of: font).contains(trait) {
                newFont = manager.convert(font, toNotHaveTrait: trait)
            } else {
                newFont = manager.convert(font, toHaveTrait: trait)
            }
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        attributedContent = textView.attributedString()
    }

    private func toggleUnderline() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        var hasUnderline = false
        textStorage.enumerateAttribute(.underlineStyle, in: range) { value, _, stop in
            if let style = value as? Int, style != 0 {
                hasUnderline = true
                stop.pointee = true
            }
        }
        let newValue = hasUnderline ? 0 : NSUnderlineStyle.single.rawValue
        textStorage.addAttribute(.underlineStyle, value: newValue, range: range)
        textStorage.endEditing()
        attributedContent = textView.attributedString()
    }

    private func toggleStrikethrough() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        var hasStrike = false
        textStorage.enumerateAttribute(.strikethroughStyle, in: range) { value, _, stop in
            if let style = value as? Int, style != 0 {
                hasStrike = true
                stop.pointee = true
            }
        }
        let newValue = hasStrike ? 0 : NSUnderlineStyle.single.rawValue
        textStorage.addAttribute(.strikethroughStyle, value: newValue, range: range)
        textStorage.endEditing()
        attributedContent = textView.attributedString()
    }

    private func applyTypedFontSize() {
        guard let size = Double(fontSizeText), size >= 8, size <= 96 else {
            fontSizeText = "16"
            return
        }
        setFontSize(CGFloat(size))
    }

    private func setFontSize(_ size: CGFloat) {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let newFont = NSFontManager.shared.convert(font, toSize: size)
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        fontSizeText = "\(Int(size))"
        attributedContent = textView.attributedString()
    }

    private func adjustFontSize(by delta: CGFloat) {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        var lastSize: CGFloat = 14
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let font = value as? NSFont else { return }
            let newSize = max(8, min(font.pointSize + delta, 96))
            lastSize = newSize
            let newFont = NSFontManager.shared.convert(font, toSize: newSize)
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
        fontSizeText = "\(Int(lastSize))"
        attributedContent = textView.attributedString()
    }

    private func applyColor(_ color: NSColor) {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
              let textStorage = textView.textStorage,
              textView.selectedRange().length > 0
        else { return }

        let range = textView.selectedRange()
        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: color, range: range)
        textStorage.endEditing()
        attributedContent = textView.attributedString()
    }
}
