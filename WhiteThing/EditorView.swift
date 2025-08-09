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
        let baseFont = document.font
        
        print("Applying font to all text: \(baseFont)")
        
        // Update text view colors
        textView.backgroundColor = newBackgroundColor
        textView.textColor = newTextColor
        scrollView.backgroundColor = newBackgroundColor

        // PRESERVE current font traits (bold/italic) when updating typing attributes
        var typingFont = baseFont
        
        // Check if current typing attributes have bold or italic traits
        if let currentFont = textView.typingAttributes[.font] as? NSFont {
            let currentTraits = currentFont.fontDescriptor.symbolicTraits
            
            if currentTraits.contains(.bold) {
                typingFont = NSFontManager.shared.convert(typingFont, toHaveTrait: .boldFontMask)
            }
            if currentTraits.contains(.italic) {
                typingFont = NSFontManager.shared.convert(typingFont, toHaveTrait: .italicFontMask)
            }
        }

        // Set up default text attributes for new text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 20
        paragraphStyle.alignment = .justified

        let attributes: [NSAttributedString.Key: Any] = [
            .font: typingFont,  // Use the font with preserved traits
            .foregroundColor: newTextColor,
            .paragraphStyle: paragraphStyle
        ]

        textView.typingAttributes = attributes
        
        // Apply viewer settings to ALL existing text BUT PRESERVE bold/italic traits
        if let textStorage = textView.textStorage, textStorage.length > 0 {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            
            print("Applying colors and updating fonts while preserving formatting")
            
            // Begin editing to batch changes
            textStorage.beginEditing()
            
            // Update colors and paragraph style for all text
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            textStorage.removeAttribute(.paragraphStyle, range: fullRange)
            
            let justifiedParagraphStyle = NSMutableParagraphStyle()
            justifiedParagraphStyle.firstLineHeadIndent = 20
            justifiedParagraphStyle.alignment = .justified
            
            textStorage.addAttribute(.foregroundColor, value: newTextColor, range: fullRange)
            textStorage.addAttribute(.paragraphStyle, value: justifiedParagraphStyle, range: fullRange)
            
            // Update fonts while preserving bold/italic traits
            textStorage.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                if let currentFont = value as? NSFont {
                    let currentTraits = currentFont.fontDescriptor.symbolicTraits
                    var newFont = baseFont
                    
                    // Preserve bold and italic traits
                    if currentTraits.contains(.bold) {
                        newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .boldFontMask)
                    }
                    if currentTraits.contains(.italic) {
                        newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .italicFontMask)
                    }
                    
                    textStorage.addAttribute(.font, value: newFont, range: range)
                } else {
                    // No existing font, use base font
                    textStorage.addAttribute(.font, value: baseFont, range: range)
                }
            }
            
            // End editing to commit changes
            textStorage.endEditing()
            
            print("Font application completed with preserved formatting")
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

class CustomTextView: NSTextView {
    
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
        let range = selectedRange()
        
        if range.length > 0 {
            // Text is selected - toggle bold for selection
            toggleBoldForRange(range)
        } else {
            // No selection - toggle bold for typing attributes
            toggleBoldForTyping()
        }
    }
    
    private func toggleItalic() {
        let range = selectedRange()
        
        if range.length > 0 {
            // Text is selected - toggle italic for selection
            toggleItalicForRange(range)
        } else {
            // No selection - toggle italic for typing attributes
            toggleItalicForTyping()
        }
    }
    
    private func toggleBoldForRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        textStorage.beginEditing()
        
        textStorage.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let font = value as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                let newFont: NSFont
                
                if traits.contains(.bold) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
                
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        textStorage.endEditing()
        
        // Also update typing attributes based on the font at cursor position
        updateTypingAttributesAtCursor()
    }
    
    private func toggleItalicForRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        textStorage.beginEditing()
        
        textStorage.enumerateAttribute(.font, in: range) { value, subRange, _ in
            if let font = value as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                let newFont: NSFont
                
                if traits.contains(.italic) {
                    newFont = NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                }
                
                textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        textStorage.endEditing()
        
        // Also update typing attributes based on the font at cursor position
        updateTypingAttributesAtCursor()
    }
    
    private func toggleBoldForTyping() {
        guard let currentFont = typingAttributes[.font] as? NSFont else { return }
        
        let traits = currentFont.fontDescriptor.symbolicTraits
        let newFont: NSFont
        
        if traits.contains(.bold) {
            newFont = NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
        } else {
            newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
        }
        
        typingAttributes[.font] = newFont
        print("Bold toggled for typing: \(traits.contains(.bold) ? "OFF" : "ON")")
    }
    
    private func toggleItalicForTyping() {
        guard let currentFont = typingAttributes[.font] as? NSFont else { return }
        
        let traits = currentFont.fontDescriptor.symbolicTraits
        let newFont: NSFont
        
        if traits.contains(.italic) {
            newFont = NSFontManager.shared.convert(currentFont, toNotHaveTrait: .italicFontMask)
        } else {
            newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
        }
        
        typingAttributes[.font] = newFont
        print("Italic toggled for typing: \(traits.contains(.italic) ? "OFF" : "ON")")
    }
    
    private func updateTypingAttributesAtCursor() {
        let cursorPosition = selectedRange().location
        
        if cursorPosition > 0 && cursorPosition <= textStorage?.length ?? 0 {
            // Get the font at the cursor position
            if let fontAtCursor = textStorage?.attribute(.font, at: cursorPosition - 1, effectiveRange: nil) as? NSFont {
                typingAttributes[.font] = fontAtCursor
            }
        }
    }
    
    // Override to maintain formatting when moving cursor
    override func setSelectedRange(_ charRange: NSRange) {
        super.setSelectedRange(charRange)
        
        // When cursor moves, update typing attributes to match the character before cursor
        if charRange.length == 0 && charRange.location > 0 {
            updateTypingAttributesAtCursor()
        }
    }
}
