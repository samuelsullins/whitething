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
        
        // Custom gliding caret, colored to match the text.
        textView.caretColor = NSColor(document.textColor)
        textView.insertionPointColor = NSColor(document.textColor)
        textView.setupCaret()

        context.coordinator.textView = textView
        document.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTextView else { return }

        // Keep the centered text column width in sync (cheap; the text view
        // recomputes its side insets in layout()).
        textView.textColumnWidth = CGFloat(document.textAreaWidth)

        // Handle document loading FIRST, before applying colors
        var didLoad = false
        if document.needsLoad {
            textView.textStorage?.setAttributedString(document.attributedContent)
            didLoad = true

            // Set needsLoad to false asynchronously to avoid SwiftUI warning
            DispatchQueue.main.async {
                self.document.needsLoad = false
            }
        }

        // Re-applying colors/fonts to the whole document is O(n), so only do it
        // when a document was just loaded or an appearance setting actually
        // changed — NOT on every keystroke (updateNSView runs on each edit).
        let appearanceChanged = context.coordinator.lastSettingsVersion != document.settingsVersion
        guard didLoad || appearanceChanged else { return }
        context.coordinator.lastSettingsVersion = document.settingsVersion

        // ALWAYS apply colors and fonts after any document loading
        let newTextColor = NSColor(document.textColor)
        let newBackgroundColor = NSColor(document.backgroundColor)
        let baseFont = document.font
        
        print("Applying font to all text: \(baseFont)")
        
        // Update text view colors
        textView.backgroundColor = newBackgroundColor
        textView.textColor = newTextColor
        textView.caretColor = newTextColor
        textView.insertionPointColor = newTextColor
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

        // Font/size/padding/color may have moved the caret; reposition it
        // without animating (this isn't a typing move).
        textView.refreshCaret(animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        let document: DocumentManager
        weak var textView: NSTextView?
        // Last appearance version applied to the full document; -1 forces the
        // first pass to apply.
        var lastSettingsVersion = -1

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

    // MARK: - Centered text column

    /// Desired width of the text column. The view centers it and grows the
    /// side insets to fill the rest of the window.
    var textColumnWidth: CGFloat = 700 {
        didSet {
            guard textColumnWidth != oldValue else { return }
            needsLayout = true
        }
    }
    private let minSideInset: CGFloat = 24
    private let topInset: CGFloat = 20

    override func layout() {
        let side = max(minSideInset, (bounds.width - textColumnWidth) / 2)
        if abs(textContainerInset.width - side) > 0.5 {
            textContainerInset = NSSize(width: side, height: topInset)
        }
        super.layout()
        refreshCaret(animated: false)
    }

    // MARK: - Gliding caret

    private let caretLayer = CALayer()
    private let caretWidth: CGFloat = 2
    private var blinkIdleTimer: Timer?
    private var caretReady = false

    var caretColor: NSColor = .black {
        didSet { caretLayer.backgroundColor = caretColor.cgColor }
    }

    /// Builds the custom caret. Called once from EditorView.makeNSView.
    func setupCaret() {
        guard !caretReady else { return }
        caretReady = true

        wantsLayer = true
        caretLayer.backgroundColor = caretColor.cgColor
        caretLayer.cornerRadius = 1
        caretLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // The layer position/size are driven manually; suppress implicit
        // animations except the ones we add explicitly.
        caretLayer.actions = ["position": NSNull(), "bounds": NSNull(), "hidden": NSNull(), "opacity": NSNull()]
        caretLayer.contentsScale = window?.backingScaleFactor ?? 2
        layer?.addSublayer(caretLayer)

        // Re-show/hide the caret as this view or its window gains/loses focus.
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(focusChanged),
                       name: NSWindow.didBecomeKeyNotification, object: nil)
        nc.addObserver(self, selector: #selector(focusChanged),
                       name: NSWindow.didResignKeyNotification, object: nil)

        updateCaret(animated: false)
    }

    func refreshCaret(animated: Bool) { updateCaret(animated: animated) }

    @objc private func focusChanged() { updateCaret(animated: false) }

    /// Suppress the native (jump-cut) caret; ours replaces it.
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) { }

    private func updateCaret(animated: Bool) {
        guard caretReady, caretLayer.superlayer != nil else { return }

        // Hide for ranged selections or when we're not the active insertion point.
        let hasSelection = selectedRange().length > 0
        let isActive = (window?.firstResponder === self) && (window?.isKeyWindow ?? false)
        caretLayer.isHidden = hasSelection || !isActive
        guard !caretLayer.isHidden else { return }

        if let tc = textContainer { layoutManager?.ensureLayout(for: tc) }
        let rect = caretRect()
        let newPos = CGPoint(x: rect.midX, y: rect.midY)

        stopBlink()

        if animated, let pres = caretLayer.presentation() {
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = pres.position
            move.toValue = newPos
            move.duration = 0.09
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)
            caretLayer.add(move, forKey: "move")
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        caretLayer.bounds = CGRect(x: 0, y: 0, width: caretWidth, height: rect.height)
        caretLayer.position = newPos
        caretLayer.opacity = 1
        CATransaction.commit()

        scheduleBlink()
    }

    /// The caret rectangle in this (flipped) view's coordinate space.
    private func caretRect() -> NSRect {
        let origin = textContainerOrigin
        guard let lm = layoutManager, let tc = textContainer, let ts = textStorage else {
            return NSRect(x: origin.x, y: origin.y, width: caretWidth, height: 20)
        }

        let charIndex = selectedRange().location
        let length = ts.length
        let fallbackHeight = lm.defaultLineHeight(for: font ?? .systemFont(ofSize: 14))

        // Empty document, or caret sitting on a trailing empty line.
        if length == 0 || charIndex >= length {
            let extra = lm.extraLineFragmentRect
            if extra.height > 0 {
                return NSRect(x: extra.minX + origin.x, y: extra.minY + origin.y,
                              width: caretWidth, height: extra.height)
            }
            if length > 0 {
                // Caret after the final glyph on its line.
                let lastGlyph = lm.numberOfGlyphs - 1
                let gr = lm.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: tc)
                return NSRect(x: gr.maxX + origin.x, y: gr.minY + origin.y,
                              width: caretWidth, height: gr.height)
            }
            return NSRect(x: origin.x, y: origin.y, width: caretWidth, height: fallbackHeight)
        }

        // Caret immediately before the glyph at charIndex.
        let glyphIndex = lm.glyphIndexForCharacter(at: charIndex)
        let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let loc = lm.location(forGlyphAt: glyphIndex)
        return NSRect(x: lineRect.minX + loc.x + origin.x,
                      y: lineRect.minY + origin.y,
                      width: caretWidth, height: lineRect.height)
    }

    // MARK: Blink (idle only, like a smooth writing caret)

    private func scheduleBlink() {
        blinkIdleTimer?.invalidate()
        blinkIdleTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.startBlink()
        }
    }

    private func startBlink() {
        guard !caretLayer.isHidden else { return }
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1
        blink.toValue = 0
        blink.duration = 0.53
        blink.autoreverses = true
        blink.repeatCount = .infinity
        blink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        caretLayer.add(blink, forKey: "blink")
    }

    private func stopBlink() {
        caretLayer.removeAnimation(forKey: "blink")
    }

    // MARK: Caret update hooks

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        caretLayer.contentsScale = window?.backingScaleFactor ?? 2
    }

    override func didChangeText() {
        super.didChangeText()
        updateCaret(animated: true)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        updateCaret(animated: true)
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.updateCaret(animated: false) }
        return ok
    }

    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        caretLayer.isHidden = true
        return ok
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

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

        // Route through shouldChangeText/didChangeText so the change registers
        // with the text view's undo manager and triggers autosave.
        guard shouldChangeText(in: range, replacementString: nil) else { return }

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
        didChangeText()

        // Also update typing attributes based on the font at cursor position
        updateTypingAttributesAtCursor()
    }

    private func toggleItalicForRange(_ range: NSRange) {
        guard let textStorage = textStorage else { return }

        // Route through shouldChangeText/didChangeText so the change registers
        // with the text view's undo manager and triggers autosave.
        guard shouldChangeText(in: range, replacementString: nil) else { return }

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
        didChangeText()

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
