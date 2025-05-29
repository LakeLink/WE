//
//  DebugView.swift
//  WatchWE Watch App
//
//  Created by Yifei Jia on 2025/5/4.
//

import SwiftUI
import UIKit
import QRCode

struct DebugView: View {
    @StateObject var vm = DebugViewModel()
    var body: some View {
        VStack {
            Spacer()
            if let c = vm.qrCodeContent {
                generateQRCode(from: c)?
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.9 }
            } else {
                Text("请在 iPhone 上同步 SessionID")
                Button(action: {
                }) {
                    Text("Refresh")
                }
            }
            Spacer()
        }
        .ignoresSafeArea()
        .onTapGesture {
            Task {
                await vm.refreshUserProfile()
            }
        }
        .onAppear() {
            Task {
                await vm.refreshUserProfile()
            }
        }
    }

    func generateQRCode(from string: String) -> Image? {
        let qrDoc = try? QRCode.Document(utf8String: string)
        let img = try? qrDoc?.imageUI(CGSizeMake(400, 400), label: Text("payment QR code"))
        
        return img
    }
}

#Preview {
    DebugView()
}
