//
//  DebugView.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/4.
//

import SwiftUI


func moneyText(_ amountString: String, currencyCode: String = "CNY") -> Text {
    // 尝试将字符串转换为 Double
    if let amount = Double(amountString) {
        return Text(amount, format: .currency(code: currencyCode))
    } else {
        // 不能转换时直接显示原字符串
        return Text(amountString)
    }
}

func string(for value: Any) -> String {
    if let uuid = value as? UUID {
        return uuid.uuidString
    } else if let str = value as? String {
        return str
    } else if let num = value as? NSNumber {
        return num.stringValue
    } else if let bool = value as? Bool {
        return bool ? "true" : "false"
    }
    return String(describing: value)
}

struct DebugView: View {
    @StateObject private var vm = DebugViewModel()
    @AppStorage("isBackgroundRefreshEnabled") private var isBackgroundRefreshEnabled: Bool = false

    var body: some View {
        NavigationView {

            Form {
                Section() {
                    if let qrImage = vm.qrCodeImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text("Here goes our QR code.")
                    }
                }
                .sensoryFeedback(.impact, trigger: vm.qrCodeImage)

                Button(action: {
                    Task {
                        await vm.refreshUserProfile()
                    }
                }) {
                    HStack {
                        Text("Refresh")
                        Spacer()

                        Text(vm.qrCodeTimeLeftString)
                            .foregroundStyle(.gray)
                            .monospacedDigit()
                            .bold()
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.default, value: vm.qrCodeTimeLeftString)
                    }
                }
                
                HStack {
                    Text("账户余额")
                    Spacer()
                    moneyText(vm.balance)
                }

                Section("设置") {
                    HStack {
                        Text("SessionID")
                        TextField("Required", text: $vm.sessionID)
                            .monospaced()
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.asciiCapable)
                    }
                    Button(action: {
                        vm.toWatch()
                    }) {
                        HStack {
                            Text("同步到 Apple Watch")
                        }
                    }
                    Toggle("推送交易通知", isOn: $isBackgroundRefreshEnabled)
                        .onChange(of: isBackgroundRefreshEnabled) {
                            if isBackgroundRefreshEnabled {
                                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                                    if granted {
                                        BGRefreshManager.shared.scheduleAppRefresh()
                                    }
                                    logger.debug("request notification: \(granted) \(error)")
                                }
                            } else {
                                BGRefreshManager.shared.cancelAppRefresh()
                            }
                        }
                }
                
                Section("User Profile") {
                    ForEach(vm.userProfile.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key)
                            Spacer()
                            Text(string(for: value))
                                // .lineLimit(1)
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                    }
                }
            }
        }
        .alert(
            vm.alertMessage,
            isPresented: $vm.showAlert
        ) {
            Button("好的", role: .cancel) {}
        }.sensoryFeedback(.error, trigger: vm.showAlert, condition: {
            oldValue, newValue in
            return newValue ? true : false
        })
        
        .sheet(isPresented: $vm.showQRCodeResultSheet) {
            SheetView(qrCodeResult: vm.qrCodeResult)
            // size is a problem
            .presentationDetents([.medium])
        }
        .sensoryFeedback(.success, trigger: vm.showQRCodeResultSheet, condition: {
            oldValue, newValue in
            return newValue ? true : false
        })
    }
}

struct SheetView: View {
    @State var qrCodeResult: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            Spacer()
            Label("支付成功", systemImage: "arrow.up")
                .font(.title)
            moneyText(qrCodeResult)
                .font(.system(size: 48, weight: .bold))
                .monospacedDigit()
            Spacer()
            Button(action: {
                dismiss()
            }) {
                Text("OK")
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    DebugView()
}
