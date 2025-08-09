//
//  MenuBarView.swift
//  WhiteThing
//
//  Created by Samuel Sullins on 8/7/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MenuBarView: View {
    @ObservedObject var document: DocumentManager
    @State private var isEditingFilename = false
    @State private var tempFilename = ""
    @FocusState private var isTextFieldFocused: Bool
    
    let commonFonts = [
        "Roboto Mono",
        "Helvetica Neue",
        "Times New Roman",
        "Georgia",
        "Avenir",
        "Futura",
        "Gill Sans",
        "Baskerville",
        "Palatino",
        "Courier",
        "Monaco",
        "Menlo"
    ]
    
    var body: some View {
        
        VStack(alignment: .leading) {
                
            if document.hasDocument {
                
                // Folder selector
                HStack (spacing: 0) {
                    Button(action: { document.selectFolder() }) {
                        Text(document.folderName + "/")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 20, design: .monospaced))
                    
                    // Filename
                    Group {
                        if isEditingFilename {
                            TextField("filename", text: $tempFilename, onCommit: {
                                commitFilename()
                            })
                            .textFieldStyle(.plain)
                            .frame(width: 200)
                            .focused($isTextFieldFocused)
                            .onAppear {
                                isTextFieldFocused = true
                            }
                            // Add escape key handling
                            .onExitCommand {
                                isEditingFilename = false
                                tempFilename = document.filename
                            }
                        } else {
                            Text(document.filename)
                                .onTapGesture {
                                    startEditingFilename()
                                }
                        }
                    }
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    
                    Divider().frame(height: 12)
                        .padding(8)
                    
                    Button(document.isMaximized ? "Make it littler" : "Make it big instead") {
                        document.toggleMaximize()
                        if document.isMaximized {
                            document.updatePadding(350)
                        } else {
                            document.updatePadding(100)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .help("Resize Window")
                }
                
                
                
            }
            
            HStack(alignment: .center, spacing: 10) {
                
                Button(action: { document.newFile() }) {
                    Text("New")
                }
                .buttonStyle(.plain)
                
                Button(action: { document.openFile() }) {
                    Text("Open")
                }
                .buttonStyle(.plain)
                
                Divider().frame(height: 10)
                
                HexColorField(
                    color: $document.textColor,
                    label: "Text Color",
                    onColorChange: { newColor in
                        document.updateTextColor(newColor)
                    }
                )
                
                HexColorField(
                    color: $document.backgroundColor,
                    label: "Background Color",
                    onColorChange: { newColor in
                        document.updateBackgroundColor(newColor)
                    }
                )
                
                Divider().frame(height: 10)
                
                Menu {
                    ForEach(commonFonts, id: \.self) { fontName in
                        Button(fontName) {
                            print("Font menu: changing to \(fontName)")
                            document.updateFontName(fontName)
                        }
                        .frame(width: 100)
                        .font(.system(size: 12, design: .monospaced))
                    }
                    Divider()
                    Button("More Fonts...") {
                        document.showFontPicker()
                    }
                    .font(.system(size: 12, design: .monospaced))
                } label: {
                    Text(document.fontName)
                        .foregroundStyle(document.textColor)
                        .font(.system(size: 12, design: .monospaced))
                }
                .menuStyle(.borderlessButton)
                .tint(document.textColor)
                .fixedSize()
                
                // Font size
                CustomIncrementer(
                    value: Binding(
                        get: { document.fontSize },
                        set: { newSize in
                            print("Font size incrementer: changing to \(newSize)")
                            document.updateFontSize(newSize)
                        }
                    ),
                    range: 8...72,
                    step: 1,
                    format: "%.0f"
                )
                
                CustomIncrementer(
                    value: Binding(
                        get: { document.horizontalPadding },
                        set: { newValue in
                            print("Padding incrementer: changing to \(newValue)")
                            document.updatePadding(newValue)
                        }
                    ),
                    range: 0...500,
                    step: 50,
                    format: "%.0f"
                )
                .tint(Color(document.textColor))
                
                Spacer()
                
            }
            .font(.system(size: 12, design: .monospaced))
            
        }
        .padding()
        .background(Color(document.backgroundColor))
        .foregroundStyle(document.textColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func startEditingFilename() {
        tempFilename = (document.filename == "no file") ? "" : document.filename
        isEditingFilename = true
    }
    
    private func commitFilename() {
        if !tempFilename.isEmpty && tempFilename != document.filename {
            document.renameFile(to: tempFilename)
        }
        isEditingFilename = false
    }
    
}

struct CustomIncrementer: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var onChanged: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: {
                let newValue = max(range.lowerBound, value - step)
                print("CustomIncrementer: decreasing from \(value) to \(newValue)")
                value = newValue
                onChanged?()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 10))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(String(format: format, value))
                .font(.system(size: 12, design: .monospaced))
                .frame(minWidth: 35)
            
            Button(action: {
                let newValue = min(range.upperBound, value + step)
                print("CustomIncrementer: increasing from \(value) to \(newValue)")
                value = newValue
                onChanged?()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MenuBarView(document: DocumentManager())
}

// MARK: - Simple Hex Color Field

struct HexColorField: View {
    @Binding var color: Color
    let label: String
    let onColorChange: (Color) -> Void
    @State private var hexText: String = ""
    
    var body: some View {
        TextField("#FFFFFF", text: $hexText)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .monospaced))
            .frame(width: 60)
            .onChange(of: hexText) { _, newValue in
                updateColorFromHex()
            }
            .onTapGesture {
                // Select all text when clicked
                DispatchQueue.main.async {
                    if let textField = NSApp.keyWindow?.firstResponder as? NSTextField {
                        textField.selectText(nil)
                    }
                }
            }
            .onAppear {
                updateHexFromColor()
            }
            .onChange(of: color) { _, _ in
                updateHexFromColor()
            }
    }
    
    private func updateColorFromHex() {
        let cleanHex = hexText.replacingOccurrences(of: "#", with: "")
        
        // Validate hex string (6 characters, valid hex digits)
        guard cleanHex.count == 6,
              cleanHex.allSatisfy({ $0.isHexDigit }) else {
            return
        }
        
        // Convert hex to Color
        let scanner = Scanner(string: cleanHex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            let red = Double((hexNumber & 0xFF0000) >> 16) / 255.0
            let green = Double((hexNumber & 0x00FF00) >> 8) / 255.0
            let blue = Double(hexNumber & 0x0000FF) / 255.0
            
            let newColor = Color(.sRGB, red: red, green: green, blue: blue)
            
            // Only update if the color actually changed
            if newColor != color {
                print("Color updated from hex: \(hexText)")
                onColorChange(newColor)
            }
        }
    }
    
    private func updateHexFromColor() {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let red = Int(nsColor.redComponent * 255)
        let green = Int(nsColor.greenComponent * 255)
        let blue = Int(nsColor.blueComponent * 255)
        
        hexText = String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// Helper extension for hex digit validation
extension Character {
    var isHexDigit: Bool {
        return isNumber || ("a"..."f").contains(lowercased()) || ("A"..."F").contains(self)
    }
}
