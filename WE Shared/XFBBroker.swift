//
//  XFBBroker.swift
//  WE
//
//  Created by Yifei Jia on 2025/5/4.
//

import Foundation
import os

let logger = Logger(subsystem: "tech.lklk.WE", category: "network")
let XFB_PAY = URL(string: "https://pay.xiaofubao.com")!
let XFB_WEBAPP = URL(string: "https://webapp.xiaofubao.com")!
let XFB_APP = URL(string: "https://application.xiaofubao.com")!

enum BrokerError: Error, LocalizedError {
    case badBaseURL
    case networkError(Error)
    case httpStatusError(code: Int)
    case respStatusError(code: Int, message: String)
    case invalidJSONBody(message: String)
    
    var errorDescription: String? {
        switch self {
        case .badBaseURL:
            return "未设置核心服务器地址或者地址不正确"
        case .networkError(let error):
            return "请求核心服务器时出错（Network，\(error.localizedDescription)）"
        case .httpStatusError(let code):
            return "请求核心服务器时出错（HTTP，\(code)）"
        case .respStatusError(let code, let message):
            return "核心服务器返回了错误信息：\(message)（JSON，\(code)）"
        case .invalidJSONBody(let message):
            return "核心服务器返回了无法解读的内容（JSON，\(message)）"
        }
    }
}

protocol XFBResponse: Decodable {
    var statusCode: Int { get }
    var message: String? { get }
}

struct XFBDataResponse<T: Decodable>: XFBResponse {
    var statusCode: Int
    var message: String?
    let data: T?
}

struct XFBTrans: Decodable {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CNY"
        return f
    }()

    var type: String
    var time: String
    var dealtime: String
    var address: String
    var feeName: String
    var serialno: String
    var money: String
    var businessName: String
    var businessNum: String
    var feeNum: String
    var accName: String
    var accNum: String
    var perCode: String
    var eWalletId: String
    var monCard: String
    var afterMon: String
    var concessionsMon: String
    
    var shortDescription: String {
        
        var moneyString: String = money
        if let moneyDouble = Double(money) {
            moneyString = XFBTrans.formatter.string(from: moneyDouble as NSNumber) ?? money
        }
        
        var afterMonString: String = afterMon
        if let afterMonDouble = Double(afterMon) {
            afterMonString = XFBTrans.formatter.string(from: afterMonDouble as NSNumber) ?? afterMon
        }
        
        return "于 \(address) \(feeName) \(moneyString)，余额 \(afterMonString)"
    }
}

struct XFBQueryTransResponse: XFBResponse {
    var statusCode: Int
    var message: String?
    
    var total: Int
    var rows: [XFBTrans]
}

struct QRCodeResult: Decodable {
    var userCard: String
    var realName: String
    var dealTime: String
    var recflag: String
    var payTypeName: String
    var monDealCur: String?
}

final class RedirectHandler: NSObject, URLSessionTaskDelegate {
    var continuation: CheckedContinuation<URL?, Never>?

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Pass back the redirect location via the continuation
        continuation?.resume(returning: request.url)
        continuation = nil
        // Don't follow the redirect
        completionHandler(nil)
    }
}

func fetchRedirectLocationAsync(url: URL) async -> URL? {
    let handler = RedirectHandler()
    let session = URLSession(configuration: .default, delegate: handler, delegateQueue: nil)

    // Use continuation to suspend until redirect or task finishes
    return await withCheckedContinuation { continuation in
        handler.continuation = continuation
        let task = session.dataTask(with: url) { _, response, error in
            // If no redirect, resume with nil (done)
            if handler.continuation != nil {
                continuation.resume(returning: nil)
                handler.continuation = nil
            }
        }
        task.resume()
    }
}

class XFBBroker {

    static func obtainWeChatLoginState() async throws -> String {
        var components = URLComponents(string: "https://auth.xiaofubao.com/auth/user/third/getCode")!
        components.queryItems = [
            URLQueryItem(name: "callBackUrl", value: "https://nonexsiting.xiaofubao.com/?platform=WECHAT_H5&schoolCode=20090820&thirdAppid=wx8fddf03d92fd6fa9")
        ]

        if let u = await fetchRedirectLocationAsync(url: components.url!) {
            logger.info("从 auth.xiaofubao.com 处获悉，我们需要前往 \(u)")
            
            var state: String?
            if let components = URLComponents(url: u, resolvingAgainstBaseURL: true) {
                for item in components.queryItems ?? [] {
                    print("Key: \(item.name), Value: \(item.value ?? "")")
                    switch item.name {
                    case "state":
                        state = item.value!
                    default:
                        logger.warning("未知的 queryItem: Key: \(item.name), Value: \(item.value ?? "")")
                    }
                }
            }
            return state!
        } else {
            throw BrokerError.respStatusError(code: -10, message: "无法获得 Redirect 目的地")
        }
    }

    let baseHeaders: [String: String] = [:]
    let okRange = 200 ..< 300
    
    var sessionID: String = ""
    var ymID: String = ""
    var userInfo: [String: Any] = [:]
    
    init(sessionID: String, ymID: String) {
        self.sessionID = sessionID
        self.ymID = ymID
    }
    
    convenience init(sessionID: String) async throws {
        self.init(sessionID: sessionID, ymID: "")
        userInfo = try await getDefaultLoginInfo()
        ymID = userInfo["id"] as! String
    }
    
    convenience init(weChatState: String, weChatCode: String) async throws {
        var components = URLComponents(string: "https://auth.xiaofubao.com/wechat/open/oauth/callback/wx8fddf03d92fd6fa9/20090820")!
        components.queryItems = [
            URLQueryItem(name: "code", value: weChatCode),
            URLQueryItem(name: "state", value: weChatState)
        ]

        if let u = await fetchRedirectLocationAsync(url: components.url!) {
            logger.info("使用微信处获得的 code 得到了URL: \(u)")
        } else {
            throw BrokerError.respStatusError(code: -10, message: "无法获得 Redirect 目的地")
        }

        self.init(sessionID: "", ymID: "")

    }
    
    func getCardMoney() async throws -> String {
        let resp: XFBDataResponse<String> = try await post(url: XFB_WEBAPP.appending(path: "/card/getCardMoney"), body: ["ymId": ymID], sessionID: sessionID)
        let val = resp.data!
        if val == "- - -" {
            logger.debug("What's wrong with you? How much is '- - -'")
        }
        
        return val
    }
    
    func cardQuerynoPage(queryTime: Date? = nil) async throws -> [XFBTrans] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        
        let qt = formatter.string(from: queryTime ?? Date())
        let resp: XFBQueryTransResponse = try await post(
            url: XFB_WEBAPP.appending(path: "/routeauth/auth/route/user/cardQuerynoPage"),
            body: [
                "ymId": ymID,
                "queryTime": qt,
            ],
            sessionID: sessionID
        )
        
        return resp.rows
    }
    
    func getQRCode() async throws -> String {
        let resp: XFBDataResponse<String> = try await post(url: XFB_WEBAPP.appending(path: "/card/getQRCode"), body: nil, sessionID: sessionID)

        let val = resp.data!
        
        return val
    }
    
    func getQRCodeResult(code: String) async throws -> QRCodeResult {
        let resp: XFBDataResponse<QRCodeResult> = try await post(
            url: XFB_WEBAPP.appending(path: "/card/getQRCodeResult"),
            body: [
                "qrCode": code,
                "platform": "WECHAT_H5"
            ],
            sessionID: sessionID
        )
        
        return resp.data!
    }
    
    func getDefaultLoginInfo() async throws -> [String: Any] {
        let resp: [String: Any] = try await post(url: XFB_WEBAPP.appending(path: "/user/defaultLogin"), body: ["deviceId": "1234567890", "platform": "WECHAT_H5"], sessionID: sessionID)
        let data = resp["data"] as! [String: Any]
        return data
    }

    func createRequest(httpMethod: String, url: URL, sessionID: String?) -> URLRequest? {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        
        for (field, value) in baseHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        
        if let s = sessionID {
            request.setValue("shiroJID=\(s)", forHTTPHeaderField: "Cookie")
        }

        return request
    }

    func get<T: XFBResponse>(url: URL, sessionID: String? = nil) async throws -> T {
        guard let req = createRequest(httpMethod: "GET", url: url, sessionID: sessionID) else {
            logger.error("URL \(url) is invalid")
            throw BrokerError.badBaseURL
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let resp = response as? HTTPURLResponse else {
            throw BrokerError.httpStatusError(code: 0)
        }
        
        if !okRange.contains(resp.statusCode) {
            logger.error("GET \(url): bad HTTP statusCode \(resp.statusCode)")
            throw BrokerError.httpStatusError(code: resp.statusCode)
        }
        
        let result: T
        do {
            let v = try JSONDecoder().decode(T.self, from: data)
            result = v
        } catch {
            throw BrokerError.invalidJSONBody(message: error.localizedDescription)
        }

        if result.statusCode != 0 {
            logger.error("GET \(url): bad JSON statusCode \(result.statusCode), \(result.message ?? "nil")")
            throw BrokerError.respStatusError(code: result.statusCode, message: result.message ?? "nil")
        }
        
        logger.debug("GET \(url): success, \(data)")
        return result
    }
    
    func post<T: XFBResponse>(url: URL, body: Encodable?, sessionID: String? = nil) async throws -> T {
        guard var req = createRequest(httpMethod: "POST", url: url, sessionID: sessionID) else {
            logger.error("URL \(url) is invalid")
            throw BrokerError.badBaseURL
        }
        
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if body != nil {
            req.httpBody = try JSONSerialization.data(withJSONObject: body!)
        } else {
            req.httpBody = "null".data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let resp = response as? HTTPURLResponse else {
            throw BrokerError.httpStatusError(code: 0)
        }
        
        if !okRange.contains(resp.statusCode) {
            logger.error("POST \(url): bad HTTP statusCode \(resp.statusCode)")
            throw BrokerError.httpStatusError(code: resp.statusCode)
        }
        
        let result: T
        do {
            let v = try JSONDecoder().decode(T.self, from: data)
            result = v
        } catch {
            throw BrokerError.invalidJSONBody(message: error.localizedDescription)
        }

        if result.statusCode != 0 {
            logger.error("GET \(url): bad JSON statusCode \(result.statusCode), \(result.message ?? "nil")")
            throw BrokerError.respStatusError(code: result.statusCode, message: result.message ?? "nil")
        }
        
        logger.debug("POST \(url): success, \(data)")
        return result
    }

    func post(url: URL, body: Encodable, sessionID: String? = nil) async throws -> [String: Any] {
        guard var req = createRequest(httpMethod: "POST", url: url, sessionID: sessionID) else {
            logger.error("URL \(url) is invalid")
            throw BrokerError.badBaseURL
        }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        guard let resp = response as? HTTPURLResponse else {
            throw BrokerError.httpStatusError(code: 0)
        }
        
        if !okRange.contains(resp.statusCode) {
            logger.error("POST \(url): bad HTTP statusCode \(resp.statusCode)")
            throw BrokerError.httpStatusError(code: resp.statusCode)
        }
        
        let result: [String: Any]
        
        let statusCode: Int
        let message: String
        do {
            result = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            statusCode = result["statusCode"] as! Int
            message = result["message"] as! String
        } catch {
            throw BrokerError.invalidJSONBody(message: error.localizedDescription)
        }

        if statusCode != 0 {
            logger.error("POST \(url): bad JSON statusCode \(statusCode), \(message)")
            throw BrokerError.respStatusError(code: statusCode, message: message)
        }
        
        logger.debug("POST \(url): success, \(data)")
        return result
    }
}
