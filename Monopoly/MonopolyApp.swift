//
//  MonopolyApp.swift
//  Monopoly
//
//  Created by Brian on 9/21/26.
//

import SwiftUI

@main
struct MonopolyApp: App {
    init() {
#if os(iOS)
        AppFont.applyToUIKit()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .font(.app(.body))
        }
    }
}
