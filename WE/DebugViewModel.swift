//
//  DebugViewModel.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/4.
//

import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

class DebugViewModel: ObservableObject {
    @Published var sessionID: String {
        didSet {
            UserDefaults.standard.set(sessionID, forKey: "ymSessionID")
        }
    }
    
    @Published var qrCodeImage: UIImage? = nil
    @Published var qrCodeCreatedAt: Date?
    @Published var qrCodeTimeLeftString: String = "00:00"
    @Published var balance: String = "- - -"
    @Published var userProfile: [String: Any] = [:]
    
    @Published var alertMessage: String = "今日无事发生。"
    @Published var showAlert: Bool = false
    
    @Published var qrCodeResult: String = "- - -"
    @Published var showQRCodeResultSheet: Bool = false
    
    private var wc = WatchConnectivityManager.shared
    private var xfb: XFBBroker? = nil
    private var qrCodeContent: String = ""
    private var qrCodeTimer: Timer?
    private var qrCodeValidUntil: Date?
    
    private let timeLeftFormatter: DateComponentsFormatter
    
    init() {
        sessionID = UserDefaults.standard.string(forKey: "ymSessionID") ?? ""

        timeLeftFormatter = DateComponentsFormatter()
        timeLeftFormatter.allowedUnits = [.minute, .second]
        timeLeftFormatter.zeroFormattingBehavior = [.pad]
        timeLeftFormatter.unitsStyle = .positional
        
        // 在哪里启动也有讲究吗？似乎需要在 Main 上
        DispatchQueue.main.async {
            self.startTimer()
        }
    }
    
    func startTimer() {
        qrCodeTimer?.invalidate()
        qrCodeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // logger.debug("timer: qrCodeTimeLeft=\(self.qrCodeTimeLeft)")
            if let validUntil = self.qrCodeValidUntil {
                let qrCodeTimeLeft = validUntil.timeIntervalSince(Date())
                DispatchQueue.main.async {
                    self.qrCodeTimeLeftString = self.timeLeftFormatter.string(from: qrCodeTimeLeft) ?? "ERROR"
                }
                if qrCodeTimeLeft > 0 { // if still valid
                    Task {
                        let resp = try await self.xfb?.getQRCodeResult(code: self.qrCodeContent)
                        if let money = resp?.monDealCur { // if used
                            await MainActor.run { // show payment result
                                self.qrCodeResult = money
                                self.showQRCodeResultSheet = true
                            }
                            await self.refreshUserProfile() // get a new one
                        }
                    }
                } else { // expired
                    Task {
                        await self.refreshUserProfile()
                    }
                }
            }
        }
    }

    func toWatch() {
        let context: [String: Any] = [
            "sessionID": sessionID
        ]
        wc.syncContext(context: context)
    }
    
    func refreshUserProfile() async {
        await MainActor.run {
            qrCodeCreatedAt = Date()
            qrCodeValidUntil = qrCodeCreatedAt! + 120
        }
        do {
            xfb = try await XFBBroker(sessionID: sessionID)
            let b = try await xfb!.getCardMoney()
            qrCodeContent = try await xfb!.getQRCode()
            let qrImage = generateQRCode(from: qrCodeContent)
            // startTimer()
            await MainActor.run {
                userProfile = xfb!.userInfo
                balance = b
                qrCodeImage = qrImage
            }
        } catch {
            await MainActor.run {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        if let outputImage = filter.outputImage,
           let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgimg)
        }
        return nil
    }
}
