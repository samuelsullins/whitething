//
//  ContentView.swift
//  WhiteThing
//
//  Created by Samuel Sullins on 8/7/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var document = DocumentManager()
    @State private var showMenu = false
    @State private var mouseLocation: CGPoint = .zero
    
    var body: some View {
        ZStack(alignment: .top) {
            // Content
            if document.hasDocument {
                EditorView(document: document)
                    .background(Color(document.backgroundColor))
            } else {
                HStack {
                    Spacer()
                    Text("Click on Open or New which are buttons")
                        .foregroundColor(document.textColor.opacity(0.5))
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }

            // Slim hover menu that floats in the title-bar strip at the top.
            if showMenu || !document.hasDocument {
                MenuBarView(document: document)
                    .transition(.opacity)
            }
        }
        .background(document.backgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Extend content into the title-bar strip so the menu sits at the very
        // top of the window, inline with the traffic lights, and reach the
        // bottom edge too.
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .background(WindowConfigurator(showControls: showMenu || !document.hasDocument))
        .animation(.easeInOut(duration: 0.2), value: showMenu)
        .onContinuousHover { phase in
            if document.hasDocument {
                switch phase {
                case .active(let location):
                    mouseLocation = location
                    checkMenuVisibility(location: location)
                case .ended:
                    showMenu = false
                }
            }
        }
        .preferredColorScheme(document.isDarkMode ? .dark : .light)
        .onAppear {
            // Reopen the last document on launch (must live on a view that is
            // always present, not on the editor which only exists once a
            // document is loaded).
            document.loadLastDocument()
        }
    }

    // Height of the top menu strip; the menu is only shown while the cursor is
    // actually over it (no larger "near" trigger zone).
    private let menuBarHeight: CGFloat = 30

    private func checkMenuVisibility(location: CGPoint) {
        showMenu = location.y < menuBarHeight
    }
}

#Preview {
    ContentView()
}

/// Reaches the hosting NSWindow to make the content view fill the entire
/// window (including the title-bar strip) so our top menu aligns with the
/// traffic-light controls.
struct WindowConfigurator: NSViewRepresentable {
    /// When false the traffic-light controls are hidden; they fade in while the
    /// cursor is over the top strip (mirroring the top menu's visibility).
    var showControls: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            applyControlVisibility(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            applyControlVisibility(to: window)
        }
    }

    /// Fade the three standard window buttons in/out with `showControls`.
    private func applyControlVisibility(to window: NSWindow) {
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ].compactMap { $0 }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            for button in buttons {
                button.animator().alphaValue = showControls ? 1 : 0
            }
        }
    }
}
