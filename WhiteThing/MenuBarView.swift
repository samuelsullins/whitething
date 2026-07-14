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
    @State private var didCopy = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            
            HStack(alignment: .center, spacing: 0) {
                
                // Folder + filename
                if document.hasDocument {
                    Button(action: { document.selectFolder() }) {
                        Text(document.folderName + "/")
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)

                    if isEditingFilename {
                        // fixedSize so the field hugs its text (same footprint as
                        // the label) and grows as you type, pushing later controls.
                        TextField("filename", text: $tempFilename, onCommit: { commitFilename() })
                            .textFieldStyle(.plain)
                            .lineLimit(1)
                            .fixedSize()
                            .focused($isTextFieldFocused)
                            .onAppear { isTextFieldFocused = true }
                            .onExitCommand {
                                isEditingFilename = false
                                tempFilename = document.filename
                            }
                            .fontWeight(.bold)
                    } else {
                        Text(document.filename)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .fixedSize()
                            .onTapGesture { startEditingFilename() }
                    }

                }
                
            }
            
            menuDivider

            // File actions
            Button("New") { document.newFile() }
                .buttonStyle(.plain)
            Button("Open") { document.openFile() }
                .buttonStyle(.plain)

            if document.hasDocument {
                menuDivider

                // Appearance: font toggle, dark-mode toggle, size stepper.
                // Each label shows what a click switches *to*.
                Button(document.isMono ? "Serif" : "Mono") { document.toggleFont() }
                    .buttonStyle(.plain)

                Button(document.isDarkMode ? "Light" : "Dark") { document.toggleDarkMode() }
                    .buttonStyle(.plain)

                CustomIncrementer(
                    value: Binding(
                        get: { document.fontSize },
                        set: { document.updateFontSize($0) }
                    ),
                    range: 8...72,
                    step: 1,
                    format: "%.0f"
                )

                menuDivider

                // Text column width: 500–1500 in steps of 100.
                Slider(
                    value: Binding(
                        get: { document.textAreaWidth },
                        set: { document.updateTextAreaWidth($0) }
                    ),
                    in: 500...1500,
                    step: 100
                )
                .controlSize(.mini)
                .frame(width: 90)
                .tint(document.textColor)
                Text("\(Int(document.textAreaWidth))")
                    .frame(minWidth: 32)

                menuDivider

                Button(document.isMaximized ? "Make it littler" : "Make it big instead") {
                    document.toggleMaximize()
                }
                .buttonStyle(.plain)
                .help("Resize Window")
            }

            Spacer()

            // Right end: word count + copy button
            if document.hasDocument {
                Text("\(document.wordCount) words")

                Button(action: copyAll) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy all text")
            }
        }
        .opacity(0.7)
        .font(.system(size: 12, design: .monospaced))
        .padding(.leading, 92)   // clear + breathe past the traffic-light controls
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .background(Color(document.backgroundColor))
        .foregroundStyle(document.textColor)
    }

    private var menuDivider: some View {
        Divider().frame(height: 12)
    }

    private func copyAll() {
        document.copyAll()
        withAnimation { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation { didCopy = false }
        }
    }

    private func startEditingFilename() {
        tempFilename = document.filename
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
                    .frame(width: 10, height: 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Text(String(format: format, value))
                .font(.system(size: 12, design: .monospaced))
                .frame(minWidth: 24)
            
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
