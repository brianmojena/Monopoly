//
//  ContentView.swift
//  Monopoly
//
//  Created by Brian on 9/21/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            // The game replaces the start screen instead of being pushed onto it, so
            // there is no back button or swipe that leaves it by accident.
            if let game = appModel.activeGame {
                ActiveGameView(model: game)
                    .id(ObjectIdentifier(game))
            } else {
                StartView()
            }
        }
        .environmentObject(appModel)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appModel.sceneDidBecomeActive()
            }
        }
    }
}

#Preview {
    ContentView()
}
