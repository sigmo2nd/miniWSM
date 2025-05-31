//
//  LoggingSystem.swift
//  miniWSM
//
//  Created by Sieg on 4/27/25.
//

import Foundation

/// Enhanced logging system for SSC protocol communication
class SSCLogger {
    static let shared = SSCLogger()
    // Log categories
    enum Category: String {
        case network = "📡"
        case device = "📱"
        case battery = "🔋"
        case audio = "🔊"
        case error = "❌"
        case warning = "⚠️"
        case success = "✅"
        case info = "ℹ️"
        case debug = "🔍"
        case cycle = "🔄"
    }
    
    // Log levels
    enum Level: Int {
        case error = 0
        case warning = 1
        case info = 2
        case debug = 3
        case verbose = 4
        
        var shouldLog: Bool {
            return self.rawValue <= SSCLogger.logLevel.rawValue
        }
    }
    
    // MARK: - Configuration
    
    /// Current log level (can be changed at runtime)
    static var logLevel: Level = .info
    
    /// Whether to display timestamps
    static var showTimestamps = true
    
    /// Whether to collapse duplicate messages
    static var collapseDuplicates = true
    
    /// Whether to compress network messages
    static var compressNetworkMessages = true
    
    // MARK: - State Tracking
    
    /// Queue for thread-safe logging operations
    private static let logQueue = DispatchQueue(label: "com.ssclogger.queue", attributes: .concurrent)
    
    /// Last log message for duplicate detection
    private static var lastMessage: String?
    
    /// Count of repeated messages
    private static var repeatCount = 0
    
    /// Active network requests for progress tracking
    private static var activeRequests: [String: String] = [:]
    
    /// 도트 애니메이션 관련 변수 추가
    private static var isProgressLine = false
    private static var dotCount = 0
    
    /// Format a timestamp
    private static var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    // MARK: - Public Logging Methods
    
    /// Log a message with a category and level
    static func log(_ message: String, category: Category = .info, level: Level = .info) {
        guard level.shouldLog else { return }
        
        logQueue.async(flags: .barrier) {
            // 진행중인 점 애니메이션이 있으면 줄 바꿈
            if isProgressLine {
                print("")
                isProgressLine = false
                dotCount = 0
            }
            
            let prefix = showTimestamps ? "\(timestamp) \(category.rawValue) " : "\(category.rawValue) "
            let fullMessage = "\(prefix)\(message)"
            
            if collapseDuplicates && fullMessage == lastMessage {
                // Duplicate message detected
                repeatCount += 1
                
                // Replace the last line in the console with the updated count
                print("\r\(fullMessage) (x\(repeatCount))", terminator: "")
            } else {
                // New message
                if repeatCount > 0 {
                    // Start a new line if we were tracking duplicates
                    print("")
                }
                print(fullMessage)
                lastMessage = fullMessage
                repeatCount = 1
            }
        }
    }
    
    /// Log network request with special handling for multiple similar requests
    static func logNetworkRequest(_ address: String, message: String, requestId: String) {
        logQueue.async(flags: .barrier) {
            // Store request for progress tracking
            activeRequests[requestId] = address
            
            if compressNetworkMessages {
                // 첫 번째 요청만 전체 로그 출력, 이후는 진행 표시 점만 찍음
                if !isProgressLine {
                    // 첫 요청일 경우 줄 시작
                    print("\(timestamp) 📡 전송 중", terminator: "")
                    isProgressLine = true
                    dotCount = 0
                } else {
                    // 기존 줄에 점만 추가
                    print(".", terminator: "")
                    dotCount += 1
                    
                    // 너무 많은 점이 쌓이면 새 줄 시작
                    if dotCount > 30 {
                        print("")
                        print("\(timestamp) 📡 전송 계속 중", terminator: "")
                        dotCount = 0
                    }
                }
            } else {
                SSCLogger.log("Sending to \(address): \(message)", category: .network, level: .debug)
            }
        }
    }
    
    /// Log network progress (for long operations)
    static func logNetworkProgress(_ requestId: String) {
        SSCLogger.logQueue.async {
            guard SSCLogger.compressNetworkMessages else { return }
            guard SSCLogger.activeRequests[requestId] != nil else { return }
            
            // Just print a dot to show progress
            if SSCLogger.isProgressLine {
                print(".", terminator: "")
                SSCLogger.dotCount += 1
            }
        }
    }
    
    /// Log network response
    static func logNetworkResponse(_ requestId: String, response: String, error: Error? = nil) {
        SSCLogger.logQueue.async(flags: .barrier) {
            // Get the original request address
            guard let address = SSCLogger.activeRequests.removeValue(forKey: requestId) else {
                // If no matching request found, just log the response
                if let error = error {
                    // Call log on main thread to avoid nested async calls
                    DispatchQueue.main.async {
                        SSCLogger.log("Response error: \(error.localizedDescription)", category: .error, level: .warning)
                    }
                } else {
                    DispatchQueue.main.async {
                        SSCLogger.log("Response: \(response)", category: .network, level: .debug)
                    }
                }
                return
            }
            
            if let error = error {
                // 에러 시 현재 프로그레스 줄 종료
                if SSCLogger.isProgressLine {
                    print(" ❌")
                    SSCLogger.isProgressLine = false
                    SSCLogger.dotCount = 0
                }
                
                DispatchQueue.main.async {
                    SSCLogger.log("Failed [\(requestId.prefix(4))] \(address): \(error.localizedDescription)", category: .error, level: .warning)
                }
            } else if SSCLogger.compressNetworkMessages {
                // 마지막 요청 응답인 경우 점 애니메이션 줄 완료
                if SSCLogger.activeRequests.isEmpty && SSCLogger.isProgressLine {
                    print(" ✓")
                    SSCLogger.isProgressLine = false
                    SSCLogger.dotCount = 0
                }
            } else {
                DispatchQueue.main.async {
                    SSCLogger.log("Received from \(address): \(response)", category: .network, level: .debug)
                }
            }
        }
    }
    
    // Specific logging helpers
    
    static func logBatteryStatus(deviceName: String, level: Int, isCharging: Bool = false) {
        let status = isCharging ? "charging" : "discharging"
        let emoji = getBatteryEmoji(level: level, charging: isCharging)
        SSCLogger.log("\(deviceName): \(emoji) \(level)% (\(status))", category: .battery, level: .info)
    }
    
    static func logCycleStart(cycleNumber: Int) {
        SSCLogger.log("Cycle #\(cycleNumber) started", category: .cycle, level: .info)
    }
    
    static func logCycleComplete(cycleNumber: Int, successful: Bool) {
        let category: Category = successful ? .success : .error
        SSCLogger.log("Cycle #\(cycleNumber) completed \(successful ? "successfully" : "with errors")", category: category, level: .info)
    }
    
    // MARK: - Helper Methods
    
    /// Get battery emoji based on level and charging status
    private static func getBatteryEmoji(level: Int, charging: Bool) -> String {
        let batterySymbol: String
        
        if charging {
            batterySymbol = "⚡"
        } else if level <= 5 {
            batterySymbol = "🪫"
        } else if level <= 20 {
            batterySymbol = "🔴"
        } else if level <= 50 {
            batterySymbol = "🟡"
        } else {
            batterySymbol = "🟢"
        }
        
        return batterySymbol
    }
}
