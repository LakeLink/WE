//
//  DebugViewModel.swift
//  WatchWE Watch App
//
//  Created by Yifei Jia on 2025/5/4.
//

import Foundation

class DebugViewModel: ObservableObject {
    @Published var qrCodeContent: String? = nil
    @Published var balance: String = "- - -"
    
    @Published var alertMessage: String = "今日无事发生。"
    @Published var showAlert: Bool = false
    
    private var wc = WatchConnectivityManager.shared
    private var sessionID: String {
        didSet {
            UserDefaults.standard.set(sessionID, forKey: "ymSessionID")
        }
    }

    private var xfb: XFBBroker? = nil
    
    init() {
        // sessionID = UserDefaults.standard.string(forKey: "ymSessionID") ?? ""
        sessionID = wc.receivedApplicationContext?["sessionID"] as? String ?? UserDefaults.standard.string(forKey: "ymSessionID") ?? ""
    }
    
    func refreshUserProfile() async {
        do {
            if let s = wc.receivedApplicationContext?["sessionID"] as? String {
                sessionID = s
                xfb = try await XFBBroker(sessionID: sessionID)
                let b = try await xfb!.getCardMoney()
                let c = try await xfb!.getQRCode()
                await MainActor.run {
                    balance = b
                    qrCodeContent = c
                }
            } else {
                await MainActor.run {
                    alertMessage = "请在 iPhone 上同步 SessionID"
                    showAlert = true
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
