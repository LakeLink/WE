//
//  BGWorker.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/8.
//


import BackgroundTasks
import Foundation
import UserNotifications
import UIKit

class BGRefreshManager {
    private var taskIdentifier = "tech.lklk.WE.refresh"
    static let shared = BGRefreshManager()

    var isBackgroundRefreshEnabled: Bool {
        UserDefaults.standard.bool(forKey: "isBackgroundRefreshEnabled")
    }
    var ymSessionID: String? {
        UserDefaults.standard.string(forKey: "ymSessionID")
    }

    private var transLastSerial: Int = UserDefaults.standard.integer(forKey: "transLastSerial") {
        didSet {
            UserDefaults.standard.set(transLastSerial, forKey: "transLastSerial")
        }

//        get {
//            UserDefaults.standard.integer(forKey: "transLastSerial")
//        }
    }
//    private var transLastSerial: Int = UserDefaults.standard.integer(forKey: "transLastSerial")
    private var activeTimer: Timer?

    func refreshXFBTrans(completion: @escaping (Bool) -> Void) {
        if let s = ymSessionID, isBackgroundRefreshEnabled {
            Task {
                do {
                    let broker = try await XFBBroker(sessionID: s)
                    let trans = try await broker.cardQuerynoPage()
                    
                    var latestTrans: XFBTrans?
                    for t in trans {
                        if let s = Int(t.serialno), s > transLastSerial {
                            transLastSerial = s
                            latestTrans = t
                        }
                    }
                    
                    if let t = latestTrans {
                        sendLocalNotification(title: "Gugugu", body: t.shortDescription)
                    }
                    completion(true)
                } catch {
                    logger.error("refreshXFBTrans failed: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    func registerActiveTasks() {
        activeTimer?.invalidate()
        activeTimer = Timer.scheduledTimer(withTimeInterval: 60 * 2, repeats: true) { _ in
            self.refreshXFBTrans { success in
                logger.debug("active task refreshXFBTrans completed: \(success)")
            }
        }
        activeTimer?.fire()
        logger.info("active task timer started")
    }
    
    // 注册后台任务
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        if isBackgroundRefreshEnabled {
            scheduleAppRefresh()
        }
    }
    
    // 调度下次刷新
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2*60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("App refresh submitted")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    // Cancels all pending tasks (call when disabling)
    func cancelAppRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("App refresh canceled.")
    }

    // 处理后台任务
    func handleAppRefresh(task: BGAppRefreshTask) {
        activeTimer?.invalidate() // we are at Background Refresh state, timer not needed.

        scheduleAppRefresh() // 任务执行后再次调度
        
        // ==== 这里实现你的刷新逻辑 ====
        refreshXFBTrans { success in
            task.setTaskCompleted(success: success)
        }
        
        // 任务超时的处理
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
    }
    
    // 发送本地通知
    func sendLocalNotification(title: String, body: String) {
        // 需先在APP请求用户通知授权
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }

}
