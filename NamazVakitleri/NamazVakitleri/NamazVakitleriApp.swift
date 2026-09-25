//
//  NamazVakitleriApp.swift
//  NamazVakitleri
//
//  Created by sefa on 26.08.2026.
//

import SwiftUI
import FirebaseCore

@main
struct NamazVakitleriApp: App {
    init () {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
