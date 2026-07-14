import SwiftUI
import AppKit
import UniformTypeIdentifiers

class DocumentManager: NSObject, ObservableObject {
    @Published var filename = "untitled"
    @Published var folderName = "Desktop"
    @Published var fontSize: Double = 24
    @Published var horizontalPadding: Double = 100
    @Published var textAreaWidth: Double = 800   // width of the centered text column (pts)
    @Published var textColor = Color.black
    @Published var backgroundColor = Color.white
    @Published var fontName = "Palatino"
    @Published var isDarkMode = false

    // Bumped whenever an appearance setting changes so the editor knows to
    // re-apply attributes across the whole document (instead of on every keystroke).
    @Published var settingsVersion = 0
    @Published var attributedContent = NSAttributedString()
    @Published var needsLoad = false
    @Published var hasDocument = false
    @Published var isMaximized = false

    // The two bundled typefaces the font toggle switches between.
    private let monoFontName = "Courier"
    private let serifFontName = "Palatino"

    var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }

    var isMono: Bool { fontName == monoFontName }

    var wordCount: Int {
        attributedContent.string.split(whereSeparator: { $0.isWhitespace }).count
    }

    private var folderURL: URL?
    private var fileURL: URL?
    private var saveTimer: Timer?
    weak var textView: NSTextView?

    // Desktop is the default home for new documents when the user hasn't
    // picked a folder yet.
    private var defaultFolder: URL? {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    override init() {
        super.init()
        // Load settings immediately when DocumentManager is created
        loadSettings()

        // Flush any pending edits to disk before the app or window goes away.
        NotificationCenter.default.addObserver(self, selector: #selector(flushSave),
                                               name: NSApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(flushSave),
                                               name: NSWindow.willCloseNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func flushSave() {
        saveTimer?.invalidate()
        saveDocument()
    }
    
    // Explicit save methods that can be called when user changes settings
    func updateFontSize(_ newSize: Double) {
        fontSize = newSize
        settingsVersion += 1
        saveSettings()
    }

    func updatePadding(_ newPadding: Double) {
        horizontalPadding = newPadding
        settingsVersion += 1
        saveSettings()
    }

    func updateTextAreaWidth(_ newWidth: Double) {
        textAreaWidth = newWidth
        settingsVersion += 1
        saveSettings()
    }

    func updateFontName(_ newName: String) {
        fontName = newName
        settingsVersion += 1
        saveSettings()
    }

    // Toggle between the bundled mono (Courier) and serif (Palatino) faces.
    func toggleFont() {
        updateFontName(isMono ? serifFontName : monoFontName)
    }

    func toggleDarkMode() {
        isDarkMode.toggle()
        applyColorScheme()
        settingsVersion += 1
        saveSettings()
    }

    // Derives the editor's text/background colors from the current mode.
    // Custom palettes can be swapped in here later.
    func applyColorScheme() {
        if isDarkMode {
            // #0b1e1b background, #66ab93 text
            backgroundColor = Color(.sRGB, red: 0x0b / 255, green: 0x1e / 255, blue: 0x1b / 255)
            textColor = Color(.sRGB, red: 0x66 / 255, green: 0xab / 255, blue: 0x94 / 255)
        } else {
            backgroundColor = .white
            textColor = .black
        }
    }

    func copyAll() {
        let text = textView?.string ?? attributedContent.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    // MARK: - Window Controls
    func toggleMaximize() {
        if let window = NSApp.mainWindow {
            window.zoom(nil)
            isMaximized = window.isZoomed
        }
    }
    
    func minimizeWindow() {
        if let window = NSApp.mainWindow {
            window.miniaturize(nil)
        }
    }
    
    func closeWindow() {
        if let window = NSApp.mainWindow {
            window.performClose(nil)
        }
    }
    
    // MARK: - File Operations
    func loadLastDocument() {
        if let lastPath = UserDefaults.standard.string(forKey: "lastFilePath"),
           let url = URL(string: lastPath) {
            loadDocument(from: url)
        }
    }
    
    func saveDocument() {
        // Fall back to Desktop rather than silently dropping the user's work.
        guard let folder = folderURL ?? defaultFolder else {
            print("No folder available to save into")
            return
        }
        if folderURL == nil {
            folderURL = folder
            folderName = folder.lastPathComponent
        }

        // Create file URL if needed
        if fileURL == nil {
            if filename.isEmpty {
                filename = "untitled"
            }
            fileURL = folder.appendingPathComponent("\(filename).rtf")
        }
        
        guard let url = fileURL else { return }
        
        do {
            if let textView = textView {
                let mutableCopy = NSMutableAttributedString(attributedString: textView.attributedString())
                let fullRange = NSRange(location: 0, length: mutableCopy.length)
                
                // Remove viewer-specific attributes but PRESERVE bold/italic traits
                mutableCopy.removeAttribute(.foregroundColor, range: fullRange)
                mutableCopy.removeAttribute(.backgroundColor, range: fullRange)
                
                // Update fonts to preserve bold/italic but remove viewer-specific font settings
                mutableCopy.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                    if let currentFont = value as? NSFont {
                        let traits = currentFont.fontDescriptor.symbolicTraits
                        
                        // Use a standard font but preserve bold/italic traits
                        var baseFont = NSFont(name: "Times New Roman", size: 12) ?? NSFont.systemFont(ofSize: 12)
                        
                        if traits.contains(.bold) {
                            baseFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                        }
                        if traits.contains(.italic) {
                            baseFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                        }
                        
                        mutableCopy.addAttribute(.font, value: baseFont, range: range)
                    }
                }

                if let data = mutableCopy.rtf(from: fullRange, documentAttributes: [:]) {
                    try data.write(to: url)
                    print("Saved to: \(url.path) with preserved bold/italic formatting")
                }
            }
        } catch {
            print("Error saving document: \(error)")
        }
    }

    // Replace the loadDocument method in DocumentManager.swift
    func loadDocument(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let attrString = NSAttributedString(rtf: data, documentAttributes: nil) {
                let mutableCopy = NSMutableAttributedString(attributedString: attrString)
                let fullRange = NSRange(location: 0, length: mutableCopy.length)
                
                // Remove viewer-specific formatting but PRESERVE bold/italic traits
                mutableCopy.removeAttribute(.foregroundColor, range: fullRange)
                mutableCopy.removeAttribute(.backgroundColor, range: fullRange)
                
                // Update fonts to match viewer settings while preserving bold/italic
                mutableCopy.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                    if let currentFont = value as? NSFont {
                        let traits = currentFont.fontDescriptor.symbolicTraits
                        
                        // Apply viewer's font settings but preserve bold/italic traits
                        var viewerFont = self.font // Use the viewer's current font
                        
                        if traits.contains(.bold) {
                            viewerFont = NSFontManager.shared.convert(viewerFont, toHaveTrait: .boldFontMask)
                        }
                        if traits.contains(.italic) {
                            viewerFont = NSFontManager.shared.convert(viewerFont, toHaveTrait: .italicFontMask)
                        }
                        
                        mutableCopy.addAttribute(.font, value: viewerFont, range: range)
                    } else {
                        // No existing font, use viewer's base font
                        mutableCopy.addAttribute(.font, value: self.font, range: range)
                    }
                }

                // Set the content with preserved bold/italic formatting
                attributedContent = mutableCopy
                needsLoad = true
                fileURL = url
                filename = url.deletingPathExtension().lastPathComponent
                folderURL = url.deletingLastPathComponent()
                folderName = folderURL?.lastPathComponent ?? "Unknown"
                hasDocument = true
                UserDefaults.standard.set(url.absoluteString, forKey: "lastFilePath")
                print("Loaded document with preserved bold/italic formatting")
            }
        } catch {
            print("Error loading document: \(error)")
            hasDocument = false
        }
    }
    
    func newFile() {
        // Save current document if it exists
        if hasDocument {
            saveDocument()
        }
        
        // Reset for new file
        filename = "untitled"
        fileURL = nil
        attributedContent = NSAttributedString(string: "")
        needsLoad = true
        hasDocument = true
        
        // Clear the last file preference
        UserDefaults.standard.removeObject(forKey: "lastFilePath")

        // Ensure a destination folder exists (default to Desktop) so the new
        // document is actually written and autosaves have somewhere to go.
        if folderURL == nil {
            folderURL = defaultFolder
            folderName = folderURL?.lastPathComponent ?? "Desktop"
        }
        if let folder = folderURL {
            createNewFile(in: folder)
        }
    }
    
    func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.rtf]
        panel.message = "Select an RTF document to open"
        
        if panel.runModal() == .OK, let url = panel.url {
            loadDocument(from: url)
        }
    }
    
    func scheduleAutosave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.saveDocument()
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to move your document"
        panel.prompt = "Move Here"
        
        if panel.runModal() == .OK, let url = panel.url {
            // Remember the folder for future launches.
            UserDefaults.standard.set(url.absoluteString, forKey: "folderPath")

            // Move existing file if we have one
            if let currentFile = fileURL {
                let newFileURL = url.appendingPathComponent(currentFile.lastPathComponent)
                do {
                    // Save current content first
                    saveDocument()
                    
                    // Move the file
                    if FileManager.default.fileExists(atPath: currentFile.path) {
                        try FileManager.default.moveItem(at: currentFile, to: newFileURL)
                        fileURL = newFileURL
                        folderURL = url
                        folderName = url.lastPathComponent
                        UserDefaults.standard.set(newFileURL.absoluteString, forKey: "lastFilePath")
                        print("Moved file to: \(newFileURL.path)")
                    }
                } catch {
                    print("Error moving file: \(error)")
                }
            } else {
                // Just set the folder for new files
                folderURL = url
                folderName = url.lastPathComponent
                
                // Create new file if we're editing but haven't saved yet
                if hasDocument && fileURL == nil {
                    createNewFile(in: url)
                }
            }
        }
    }
    
    func createNewFile(in folder: URL) {
        if filename.isEmpty {
            filename = "untitled"
        }
        
        fileURL = folder.appendingPathComponent("\(filename).rtf")
        
        // Create empty RTF file
        let emptyRTF = NSAttributedString(string: "")
        if let data = emptyRTF.rtf(from: NSRange(location: 0, length: 0), documentAttributes: [:]) {
            do {
                try data.write(to: fileURL!)
                print("Created new file at: \(fileURL!.path)")
                hasDocument = true
            } catch {
                print("Error creating file: \(error)")
            }
        }
        
        UserDefaults.standard.set(fileURL?.absoluteString, forKey: "lastFilePath")
    }
    
    func renameFile(to newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        // If no file exists yet, just update the name
        if fileURL == nil {
            filename = cleanName
            if let folder = folderURL {
                fileURL = folder.appendingPathComponent("\(cleanName).rtf")
                saveDocument()
                UserDefaults.standard.set(fileURL?.absoluteString, forKey: "lastFilePath")
            }
            return
        }
        
        // Rename existing file
        guard let currentURL = fileURL,
              let folder = folderURL else { return }
        
        let newURL = folder.appendingPathComponent("\(cleanName).rtf")
        
        // Save current content first
        saveDocument()
        
        do {
            if FileManager.default.fileExists(atPath: currentURL.path) {
                try FileManager.default.moveItem(at: currentURL, to: newURL)
            }
            fileURL = newURL
            filename = cleanName
            UserDefaults.standard.set(newURL.absoluteString, forKey: "lastFilePath")
        } catch {
            print("Error renaming file: \(error)")
        }
    }
    
    // MARK: - Settings
    func saveSettings() {
        let defaults = UserDefaults.standard

        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(horizontalPadding, forKey: "padding")
        defaults.set(textAreaWidth, forKey: "textAreaWidth")
        defaults.set(fontName, forKey: "fontName")
        defaults.set(isDarkMode, forKey: "isDarkMode")
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        // Load numeric values
        let savedFontSize = defaults.double(forKey: "fontSize")
        fontSize = savedFontSize > 0 ? savedFontSize : 24

        if defaults.object(forKey: "padding") != nil {
            horizontalPadding = defaults.double(forKey: "padding")
        } else {
            horizontalPadding = 100
        }

        let savedWidth = defaults.double(forKey: "textAreaWidth")
        textAreaWidth = savedWidth > 0 ? min(max(savedWidth, 500), 1500) : 800

        // Load font name
        fontName = defaults.string(forKey: "fontName") ?? serifFontName

        // Load appearance mode and derive colors from it
        isDarkMode = defaults.bool(forKey: "isDarkMode")
        applyColorScheme()

        // Restore the saved folder if it still exists, otherwise default to Desktop.
        if let path = defaults.string(forKey: "folderPath"),
           let url = URL(string: path),
           FileManager.default.fileExists(atPath: url.path) {
            folderURL = url
            folderName = url.lastPathComponent
        } else {
            folderURL = defaultFolder
            folderName = folderURL?.lastPathComponent ?? "Desktop"
        }
    }
}
