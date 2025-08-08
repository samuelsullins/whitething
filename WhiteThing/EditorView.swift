import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorView: NSViewRepresentable {
    @ObservedObject var document: DocumentManager
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = CustomTextView()
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = NSColor(document.backgroundColor)
        textView.drawsBackground = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.importsGraphics = false
        
        // Enable text formatting
        textView.usesFontPanel = true
        textView.usesRuler = false
        textView.usesInspectorBar = false
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(document.backgroundColor)
        scrollView.drawsBackground = true
        
        context.coordinator.textView = textView
        document.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        print("EditorView updateNSView - Font: \(document.fontName) \(document.fontSize)pt")
        
        // Update padding
        textView.textContainerInset = NSSize(width: document.horizontalPadding, height: 20)

        // Handle document loading FIRST, before applying colors
        if document.needsLoad {
            print("Loading document content...")
            textView.textStorage?.setAttributedString(document.attributedContent)
            
            // Set needsLoad to false asynchronously to avoid SwiftUI warning
            DispatchQueue.main.async {
                self.document.needsLoad = false
            }
        }

        // ALWAYS apply colors and fonts after any document loading
        let newTextColor = NSColor(document.textColor)
        let newBackgroundColor = NSColor(document.backgroundColor)
        let newFont = document.font
        
        print("Applying font to all text: \(newFont)")
        
        // Update text view colors
        textView.backgroundColor = newBackgroundColor
        textView.textColor = newTextColor
        scrollView.backgroundColor = newBackgroundColor
//        
//        // Update window background color to match document background
//        // This helps prevent the "strange background" issue
//        DispatchQueue.main.async {
//            if let window = textView.window {
//                if self.document.isFullscreen {
//                    window.backgroundColor = newBackgroundColor
//                } else {
//                    // For windowed mode, keep it clear for transparency effects
//                    window.backgroundColor = NSColor.clear
//                }
//            }
//        }

        // Set up default text attributes for new text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 20

        let attributes: [NSAttributedString.Key: Any] = [
            .font: newFont,
            .foregroundColor: newTextColor,
            .paragraphStyle: paragraphStyle
        ]

        textView.typingAttributes = attributes
        
        // Apply viewer settings to ALL existing text (this is the key part!)
        if let textStorage = textView.textStorage, textStorage.length > 0 {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            print("Applying font \(newFont) to range: \(fullRange)")
            
            // Begin editing to batch changes
            textStorage.beginEditing()
            
            // Remove old attributes that might conflict with viewer settings
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            textStorage.removeAttribute(.font, range: fullRange)
            
            // Apply ALL viewer settings to existing text
            textStorage.addAttribute(.foregroundColor, value: newTextColor, range: fullRange)
            textStorage.addAttribute(.font, value: newFont, range: fullRange)
            
            // End editing to commit changes
            textStorage.endEditing()
            
            print("Font application completed")
        }
        
        // Force visual update
        textView.needsDisplay = true
        scrollView.needsDisplay = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let document: DocumentManager
        weak var textView: NSTextView?
        
        init(document: DocumentManager) {
            self.document = document
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            document.attributedContent = textView.attributedString()
            document.scheduleAutosave()
        }
    }
}

// CustomTextView class remains the same
class CustomTextView: NSTextView {
    private var isBoldActive = false
    private var isItalicActive = false
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "b" {
            toggleBold()
            return true
        }
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
            toggleItalic()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    private func toggleBold() {
        isBoldActive.toggle()
        applyToggleAttributes()
    }
    
    private func toggleItalic() {
        isItalicActive.toggle()
        applyToggleAttributes()
    }
    
    private func applyToggleAttributes() {
        if let currentFont = typingAttributes[.font] as? NSFont {
            let bolded = isBoldActive ? addBoldTrait(to: currentFont) : removeBoldTrait(from: currentFont)
            let italicized = isItalicActive ? addItalicTrait(to: bolded) : removeItalicTrait(from: bolded)
            typingAttributes[.font] = italicized
        }
        
        // Also apply to selection if text is selected
        let range = selectedRange()
        if range.length > 0 {
            textStorage?.enumerateAttribute(.font, in: range) { value, subRange, _ in
                if let font = value as? NSFont {
                    let bolded = isBoldActive ? self.addBoldTrait(to: font) : self.removeBoldTrait(from: font)
                    let italicized = self.isItalicActive ? self.addItalicTrait(to: bolded) : self.removeItalicTrait(from: bolded)
                    textStorage?.addAttribute(.font, value: italicized, range: subRange)
                }
            }
        }
    }
    
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        applyToggleAttributes()
        super.insertText(insertString, replacementRange: replacementRange)
    }
    
    private func addBoldTrait(to font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    }
    private func removeBoldTrait(from font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
    }
    private func addItalicTrait(to font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
    private func removeItalicTrait(from font: NSFont) -> NSFont {
        NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
    }
}
