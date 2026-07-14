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
    }
}
