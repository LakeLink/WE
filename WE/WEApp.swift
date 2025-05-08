//
//  WEApp.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/2.
//

import SwiftUI

@main
struct WEApp: App {
    @Environment(\.scenePhase) var scenePhase
    init() {
        BGRefreshManager.shared.registerBackgroundTasks()
    }
    var body: some Scene {
        WindowGroup {
            DebugView()
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                print("App is active")
                BGRefreshManager.shared.registerActiveTasks()
            case .inactive:
                print("App is inactive")
            case .background:
                print("App is backgrounded")
            @unknown default:
                break
            }
        }
    }
}
