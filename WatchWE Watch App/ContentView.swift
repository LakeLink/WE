//
//  ContentView.swift
//  WatchWE Watch App
//
//  Created by Yifei Jia on 2025/5/2.
//
import SwiftUI

struct WatchConnectivityTestView: View {
    @State private var status: String = "No message received."
    @State private var lastReply: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("WC Test (Watch)")
                    .font(.headline)
                Text("Last received message:")
                    .font(.caption)
                Text(status)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .cornerRadius(8)

                if !lastReply.isEmpty {
                    Text("Reply from Phone:")
                        .font(.caption)
                    Text(lastReply)
                        .foregroundColor(.cyan)
                }

                Button("Send Message To iPhone") {
                    sendTestMessage()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .onAppear { setupObservers() }
        }
    }
    

    func formattedCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }

    func sendTestMessage() {

        let currentTime = formattedCurrentTime()
        let msg = [
            "watch_message": "Hello from Watch! ⌚️",
            "sent_at": currentTime
        ]
        WatchConnectivityManager.shared.sendMessageToPhone(message: msg) { reply in
            let replyText = reply.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            DispatchQueue.main.async {
                lastReply = replyText
            }
        } errorHandler: { error in
            DispatchQueue.main.async {
                lastReply = "Error: \(error.localizedDescription)"
            }
        }
    }

    func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: .didReceivePhoneMessage,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                status = "\(userInfo)"
            }
        }
    }
}

#Preview {
    WatchConnectivityTestView()
}
