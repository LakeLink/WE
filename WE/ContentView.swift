//
//  ContentView.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/2.
//

import SwiftUI

struct WatchConnectivityTestView: View {
    @State private var status: String = "No message received."
    @State private var lastReply: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Watch Connectivity Test")
                    .font(.title)
                    .bold()
                
                Text("Last received message:")
                    .font(.headline)
                Text(status)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if !lastReply.isEmpty {
                    Text("Reply from Watch:")
                        .font(.headline)
                    Text(lastReply)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button("Send Message To Watch") {
                    sendTestMessage()
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .onAppear(perform: setupObservers)
            .navigationTitle("WC Test")
        }
    }

    func sendTestMessage() {
        let msg = ["ios_message": "Hello from iOS! 👋"]
        WatchConnectivityManager.shared.sendMessageToWatch(message: msg) { reply in
            // Called on main thread
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
        NotificationCenter.default.addObserver(forName: .didReceiveWatchMessage, object: nil, queue: .main) { notification in
            if let message = notification.userInfo as? [String: Any] {
                status = "\(message)"
            }
        }
    }
}

// MARK: - Notification Post from WatchConnectivityManager

extension Notification.Name {
    static let didReceiveWatchMessage = Notification.Name("didReceiveWatchMessage")
}

// ---- Update WatchConnectivityManager.swift ----

// In WatchConnectivityManager's didReceiveMessage, add after printing:
// Post received message to update the UI
/*
func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    print("iOS Received message: \(message)")
    NotificationCenter.default.post(
        name: .didReceiveWatchMessage,
        object: nil,
        userInfo: message
    )
    replyHandler(["response": "Hello, Watch!"])
}
*/

// -----------------

#Preview {
    WatchConnectivityTestView()
}
