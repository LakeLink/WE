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

struct XFBResponse<T: Decodable>: Decodable {
    var statusCode: Int
    var message: String
    let data: T?
}

struct QRCodeResult: Decodable {
    var userCard: String
    var realName: String
    var dealTime: String
    var recflag: String
    var payTypeName: String
    var monDealCur: String?
}

class XFBBroker {
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
    
    func getCardMoney() async throws -> String {
        let resp: XFBResponse<String> = try await post(url: XFB_WEBAPP.appending(path: "/card/getCardMoney"), body: ["ymId": ymID], sessionID: sessionID)
        let val = resp.data!
        if val == "- - -" {
            logger.debug("What's wrong with you? How much is '- - -'")
        }
        
        return val
    }
    
    func getQRCode() async throws -> String {
        let resp: XFBResponse<String> = try await post(url: XFB_WEBAPP.appending(path: "/card/getQRCode"), body: nil, sessionID: sessionID)

        let val = resp.data!
        
        return val
    }
    
    func getQRCodeResult(code: String) async throws -> QRCodeResult {
        let resp: XFBResponse<QRCodeResult> = try await post(
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

    func get<T: Decodable>(url: URL, sessionID: String? = nil) async throws -> XFBResponse<T> {
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
        
        let result: XFBResponse<T>
        do {
            let v = try JSONDecoder().decode(XFBResponse<T>.self, from: data)
            result = v
        } catch {
            throw BrokerError.invalidJSONBody(message: error.localizedDescription)
        }

        if result.statusCode != 0 {
            logger.error("GET \(url): bad JSON statusCode \(result.statusCode), \(result.message)")
            throw BrokerError.respStatusError(code: result.statusCode, message: result.message)
        }
        
        logger.debug("GET \(url): success, \(data)")
        return result
    }
    
    func post<T: Decodable>(url: URL, body: Encodable?, sessionID: String? = nil) async throws -> XFBResponse<T> {
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
        
        let result: XFBResponse<T>
        do {
            let v = try JSONDecoder().decode(XFBResponse<T>.self, from: data)
            result = v
        } catch {
            throw BrokerError.invalidJSONBody(message: error.localizedDescription)
        }

        if result.statusCode != 0 {
            logger.error("POST \(url): bad JSON statusCode \(result.statusCode), \(result.message)")
            throw BrokerError.respStatusError(code: result.statusCode, message: result.message)
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
