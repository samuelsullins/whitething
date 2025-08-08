//
//  WhiteThingApp.swift
//  WhiteThing
//
//  Created by Samuel Sullins on 8/7/25.
//

import SwiftUI

@main
struct WhiteThingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z")

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
            
            // Remove the conflicting fullscreen command since we handle it custom
            // This prevents conflicts with our custom fullscreen implementation
        }
    }
}
