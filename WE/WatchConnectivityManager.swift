//
//  WatchConnectivityManager.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/2.
//

import Foundation
import WatchConnectivity

// Singleton manager for handling Watch Connectivity
class WatchConnectivityManager: NSObject, WCSessionDelegate {

    static let shared = WatchConnectivityManager()
    private override init() {
        super.init()
        activateSession()
    }

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private func activateSession() {
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Sending Message Example

    /// Send a message to the Watch app
    func sendMessageToWatch(message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            logger.warning("Watch not paired or app not installed")
            return
        }

        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    /// 推送需要同步的数据到 Apple Watch
    func syncContext(context: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        do {
            try WCSession.default.updateApplicationContext(context)
            logger.info("ApplicationContext synced to watch")
        } catch {
            logger.error("cannot sync ApplicationContext to watch: \(error)")
        }
    }
    // MARK: - WCSessionDelegate

    // Called when iOS receives a message from the Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("iOS Received message: \(message)")
        NotificationCenter.default.post(
            name: .didReceiveWatchMessage,
            object: nil,
            userInfo: message
        )
        replyHandler(["response": "Hello, Watch!"])
    }

    // Called when activation state changes
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation did complete. State: \(activationState.rawValue), error: \(String(describing: error))")
    }

    // Called if the companion watch state changes (like paired/unpaired)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }

    // For iOS, these are not needed, but must still be implemented.
    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) { }
    #endif

    // MARK: - Application Lifecycle Call

    /// Call this from AppDelegate or SceneDelegate to ensure WCSession is active
    func handleAppLaunch() {
        activateSession()
    }
}

// In AppDelegate.swift or SceneDelegate.swift, initialize if desired:
// WatchConnectivityManager.shared.handleAppLaunch()
