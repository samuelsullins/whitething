//
//  WhiteThingApp.swift
//  WhiteThing
//
//  Created by Samuel Sullins on 8/7/25.
//

import SwiftUI
import CoreText

@main
struct WhiteThingApp: App {
    init() {
        Self.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }

    /// Register every font bundled in the app for this process, so the editor
    /// can use them by PostScript name whether or not they're installed
    /// system-wide. Scoped to `.process` — no system-wide installation, no
    /// admin prompt, no pollution of the user's Font Book.
    private static func registerBundledFonts() {
        for ext in ["ttf", "otf"] {
            let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            for url in urls {
                var error: Unmanaged<CFError>?
                if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                    print("Registered bundled font: \(url.lastPathComponent)")
                } else {
                    // An "already registered" failure is harmless; log the rest.
                    print("Font registration issue for \(url.lastPathComponent): \(String(describing: error?.takeUnretainedValue()))")
                }
            }
        }
    }
}
