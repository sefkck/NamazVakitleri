//
//  NamazVakitleriApp.swift
//  NamazVakitleri
//
//  Created by sefa on 26.08.2026.
//

import SwiftUI

@main
struct NamazVakitleriApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init () {
        // Bildirim delegesi uygulama açılışı bitmeden atanmalı; yoksa
        // kapalı uygulamayı açan bildirim dokunuşu kaybolabilir.
        NotificationManager.shared.prepare()
        // Arka plan görevi de açılış bitmeden kaydedilmeli (Apple kuralı).
        BackgroundRefresh.register()
        // Apple Watch'a konum ve ayarları gönder.
        WatchSync.shared.activate()
        #if DEBUG
        if CommandLine.arguments.contains("-selfTest") {
            SelfTests.runAndExit()
        }
        DebugSnapshot.scheduleIfRequested()
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefresh.schedule()
            } else if newPhase == .active {
                IftarLiveActivity.refresh()
            }
        }
    }
}
