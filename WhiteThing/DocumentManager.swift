import SwiftUI
import AppKit
import UniformTypeIdentifiers

class DocumentManager: NSObject, ObservableObject {
    @Published var filename = "new_file"
    @Published var folderName = "Select Folder"
    @Published var fontSize: Double = 14
    @Published var horizontalPadding: Double = 100
    @Published var textColor = Color.black
    @Published var backgroundColor = Color.white
    @Published var fontName = "Helvetica"
    
    // Flag to prevent saving during initial load
    private var isLoading = false
    @Published var attributedContent = NSAttributedString()
    @Published var needsLoad = false
    @Published var hasDocument = false
    @Published var isMaximized = false
    
    var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    }
    
    private var folderURL: URL?
    private var folderBookmark: Data?
    private var fileURL: URL?
    private var saveTimer: Timer?
    weak var textView: NSTextView?
    
    override init() {
        super.init()
        print("DocumentManager initializing...")
        // Load settings immediately when DocumentManager is created
        loadSettings()
        print("DocumentManager initialized with settings loaded")
    }
    
    // Explicit save methods that can be called when user changes settings
    func updateFontSize(_ newSize: Double) {
        fontSize = newSize
        saveSettings()
    }
    
    func updatePadding(_ newPadding: Double) {
        horizontalPadding = newPadding
        saveSettings()
    }
    
    func updateFontName(_ newName: String) {
        fontName = newName
        saveSettings()
    }
    
    func updateTextColor(_ newColor: Color) {
        textColor = newColor
        saveSettings()
    }
    
    func updateBackgroundColor(_ newColor: Color) {
        backgroundColor = newColor
        saveSettings()
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
        guard let folder = folderURL else {
            print("No folder selected")
            return
        }
        
        // Create file URL if needed
        if fileURL == nil {
            if filename == "no file" || filename.isEmpty {
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
                        var baseFont = NSFont(name: "Times New Roman", size: 12)!
                        
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
        
        // If we have a folder selected, create the file there
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
            // Save bookmark for future app launches
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "folderBookmark")
                folderBookmark = bookmark
            } catch {
                print("Failed to create bookmark: \(error)")
            }
            
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
        if filename == "no file" || filename.isEmpty {
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
    
    // MARK: - Font Picker
    func showFontPicker() {
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.setSelectedFont(font, isMultiple: false)
        fontManager.orderFrontFontPanel(nil)
    }
    
    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let newFont = fontManager.convert(font)
        updateFontName(newFont.fontName)
        updateFontSize(Double(newFont.pointSize))
    }
    
    // MARK: - Settings
    func saveSettings() {
        print("=== SAVING SETTINGS ===")
        let defaults = UserDefaults.standard
        
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(horizontalPadding, forKey: "padding")
        defaults.set(fontName, forKey: "fontName")
        
        print("Saved: fontSize=\(fontSize), padding=\(horizontalPadding), fontName=\(fontName)")
        
        // Save colors
        do {
            let textColorData = try NSKeyedArchiver.archivedData(withRootObject: NSColor(textColor), requiringSecureCoding: false)
            defaults.set(textColorData, forKey: "textColor")
            print("Saved text color successfully")
        } catch {
            print("Failed to save text color: \(error)")
        }
        
        do {
            let bgColorData = try NSKeyedArchiver.archivedData(withRootObject: NSColor(backgroundColor), requiringSecureCoding: false)
            defaults.set(bgColorData, forKey: "backgroundColor")
            print("Saved background color successfully")
        } catch {
            print("Failed to save background color: \(error)")
        }
        
        // Force synchronize to disk
        let success = defaults.synchronize()
        print("UserDefaults synchronize result: \(success)")
        print("=== SETTINGS SAVED ===")
    }

    func loadSettings() {
        print("=== LOADING SETTINGS ===")
        isLoading = true  // Prevent saves during loading
        
        let defaults = UserDefaults.standard
        
        // Load numeric values
        let savedFontSize = defaults.double(forKey: "fontSize")
        if savedFontSize > 0 {
            fontSize = savedFontSize
            print("Loaded fontSize: \(fontSize)")
        } else {
            fontSize = 14
            print("Using default fontSize: 14")
        }
        
        let savedPadding = defaults.double(forKey: "padding")
        if savedPadding >= 0 {
            horizontalPadding = savedPadding
            print("Loaded horizontalPadding: \(horizontalPadding)")
        } else {
            horizontalPadding = 100
            print("Using default horizontalPadding: 100")
        }
        
        // Load font name
        if let savedFontName = defaults.string(forKey: "fontName") {
            fontName = savedFontName
            print("Loaded fontName: \(fontName)")
        } else {
            fontName = "Helvetica"
            print("Using default fontName: Helvetica")
        }
        
        // Load colors
        if let colorData = defaults.data(forKey: "textColor") {
            do {
                if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                    textColor = Color(color)
                    print("Loaded textColor successfully")
                } else {
                    textColor = Color.black
                    print("Failed to unarchive textColor, using default")
                }
            } catch {
                textColor = Color.black
                print("Error loading textColor: \(error)")
            }
        } else {
            textColor = Color.black
            print("No saved textColor found, using default")
        }
        
        if let colorData = defaults.data(forKey: "backgroundColor") {
            do {
                if let color = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
                    backgroundColor = Color(color)
                    print("Loaded backgroundColor successfully")
                } else {
                    backgroundColor = Color.white
                    print("Failed to unarchive backgroundColor, using default")
                }
            } catch {
                backgroundColor = Color.white
                print("Error loading backgroundColor: \(error)")
            }
        } else {
            backgroundColor = Color.white
            print("No saved backgroundColor found, using default")
        }
        
        // Load saved folder URL if exists
        if let folderBookmark = defaults.data(forKey: "folderBookmark") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: folderBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if url.startAccessingSecurityScopedResource() {
                    folderURL = url
                    folderName = url.lastPathComponent
                    print("Loaded folder: \(folderName)")
                }
            } catch {
                print("Error loading folder bookmark: \(error)")
            }
        }
        
        isLoading = false  // Re-enable saves
        print("=== SETTINGS LOADED ===")
    }
}
