//
//  WatchConnectivityManager.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/2.
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    
    static let shared = WatchConnectivityManager()
    override init() {
        super.init()
        activateSession()
    }

    // 有趣的是，你这里不能用 session.applicationContext
    var receivedApplicationContext: [String: Any]? { session?.receivedApplicationContext }
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private func activateSession() {
        session?.delegate = self
        session?.activate()
    }

    // Send a message to the iPhone
    func sendMessageToPhone(message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            print("Phone not reachable")
            errorHandler?(NSError(domain: "WC", code: 1, userInfo: [NSLocalizedDescriptionKey: "Phone not reachable"]))
            return
        }
        session.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation did complete. State: \(activationState.rawValue), error: \(String(describing: error))")
    }

    // Called when Watch receives a message from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Watch received message: \(message)")
//        NotificationCenter.default.post(
//            name: .didReceivePhoneMessage,
//            object: nil,
//            userInfo: message
//        )
        replyHandler(["response": "Hello, iPhone!"])
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received context:", applicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("Session reachability changed: \(session.isReachable)")
    }
}

extension Notification.Name {
    static let didReceivePhoneMessage = Notification.Name("didReceivePhoneMessage")
}
