//
//  WEApp.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/2.
//

import SwiftUI

@main
struct WEApp: App {
    init() {
        BGRefreshManager.shared.registerBackgroundTasks()
    }
    var body: some Scene {

        WindowGroup {
            DebugView()
        }
    }
}
