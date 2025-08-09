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
        VStack(alignment: .leading, spacing: 0) {
            // Hover menu
            if showMenu || !document.hasDocument {
                MenuBarView(document: document)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if document.hasDocument {
                EditorView(document: document)
                    .padding(.bottom)
                    .background(Color(document.backgroundColor))
                    .onAppear {
                        document.loadLastDocument()
                    }
            } else {
                Spacer()
                HStack{
                    Spacer()
                    Text("Click on Open or New which are buttons")
                        .foregroundColor(document.textColor.opacity(0.5))
                    Spacer()
                }
                Spacer()
            }
            
        }
        .background(document.backgroundColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.2), value: showMenu)
        .onContinuousHover { phase in
            if document.hasDocument {
                switch phase {
                case .active(let location):
                    mouseLocation = location
                    checkMenuVisibility(location: location)
                case .ended:
                    hideMenu()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func checkMenuVisibility(location: CGPoint) {
        if location.y < 20 {
            showMenu = true
        } else if showMenu {
            hideMenu()
        }
    }
    
    private func hideMenu() {
        if mouseLocation.y > 80 {
            showMenu = false
        }
    }
}

#Preview {
    ContentView()
}
