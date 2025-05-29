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
                .onOpenURL { url in
                    handle(url: url)
                }
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

    func handle(url: URL) {
        guard url.scheme == "wxf460724ebd84135d" else { return }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            var weChatCode: String?
            var weChatState: String?
            for item in components.queryItems ?? [] {
                print("Key: \(item.name), Value: \(item.value ?? "")")
                switch item.name {
                case "code":
                    weChatCode = item.value!
                case "state":
                    weChatState = item.value!
                default:
                    logger.warning("微信的 Callback 包含了未知的 queryItem: Key: \(item.name), Value: \(item.value ?? "")")
                }
            }
            Task {
                try! await XFBBroker(weChatState: weChatState!, weChatCode: weChatCode!)
            }
        }
    }
}
