//
//  SSCResponseModels.swift
//  miniWSM
//
//  Created on 4/27/25.
//

import Foundation

// MARK: - Base SSC Response Structure

/// Root structure that matches JSON responses
struct SSCResponse: Codable {
    // Top-level objects that can appear in responses
    let device: DeviceData?
    let audio1: AudioInfo?
    let rx1: ReceiverChannel?
    let rx2: ReceiverChannel?
    let m: MeterInfo?
    let mates: MatesInfo?
    let bays: BaysInfo?
    let osc: OSCInfo?
    
    // SSC Generic error handling
    var hasError: Bool {
        return osc?.error != nil
    }
    
    var errorCode: Int? {
        if let errorData = osc?.error, !errorData.isEmpty {
            return errorData[0]
        }
        return nil
    }
    
    func isErrorCode(_ code: Int) -> Bool {
        return errorCode == code
    }
}

// MARK: - Device Information (기존 DeviceInfo 사용을 위한 중간 구조체)

/// 서버 응답에서 오는 장치 데이터를 담는 구조체
struct DeviceData: Codable {
    // Identity properties from SSC
    let name: String?
    let identity: DeviceIdentity?
    let frequency_code: String?
    let location: String?
    
    // Network properties
    let network: DeviceNetwork?
    
    // 기존 DeviceInfo로 변환하는 메서드
    func toDeviceInfo(ipAddress: String) -> DeviceInfo {
        return DeviceInfo(
            name: name ?? "Unknown Device",
            ipAddress: ipAddress,
            type: "unknown", // 적절한 타입 결정 필요
            lastSeen: Date()
        )
    }
}

// MARK: - OSC Information

struct OSCInfo: Codable {
    // 단순화된 오류 정보 - 오류 코드만 저장
    let error: [Int]?
    let xid: String?
    let version: String?
    
    // 디코딩 문제를 피하기 위해 특정 CodingKeys만 사용
    private enum CodingKeys: String, CodingKey {
        case xid, version, error
    }
    
    // Decodable 단순 구현 - 필요한 필드만 디코딩
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 기본 필드들은 직접 디코딩
        xid = try container.decodeIfPresent(String.self, forKey: .xid)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        
        // error 필드는 존재 여부만 확인하고 고정값 사용
        if container.contains(.error) {
            // 실제 오류 코드를 추출하는 대신 기본값 사용
            error = [424]  // failed dependency
        } else {
            error = nil
        }
    }
}

struct DeviceIdentity: Codable {
    let version: String?
    let vendor: String?
    let serial: String?
    let product: String?
}

struct DeviceNetwork: Codable {
    let ipv4: DeviceIPv4?
    let ether: DeviceEthernet?
    let mdns: Bool?
}

struct DeviceIPv4: Codable {
    let auto: Bool?
    let ipaddr: String?
    let netmask: String?
    let gateway: String?
    let manual_ipaddr: String?
    let manual_netmask: String?
    let manual_gateway: String?
    let interfaces: [String]?
}

struct DeviceEthernet: Codable {
    let macs: [String]?
    let interfaces: [String]?
}

// MARK: - Audio Information

struct AudioInfo: Codable {
    let out1: AudioOutput?
    let out2: AudioOutput?
}

struct AudioOutput: Codable {
    let level: Int?
}

// MARK: - Receiver Channel

struct ReceiverChannel: Codable {
    // Basic info
    let name: String?
    let frequency: Int?
    let gain: Int?
    let mute: Bool?
    
    // Warnings
    let warnings: [String]?
    
    // Sync settings
    let sync_settings: SyncSettings?
    
    // Presets
    let presets: PresetsInfo?
    
    // References
    let mates: [String]?
    let audio: [String]?
}

struct SyncSettings: Codable {
    // Settings that can be synced
    let led: Bool?
    let led_ignore: Bool?
    let lock: Bool?
    let lock_ignore: Bool?
    let lowcut: String?
    let lowcut_ignore: Bool?
    let mute_config: String?
    let mute_config_ignore: Bool?
    let name_ignore: Bool?
    let trim: Int?
    let trim_ignore: Bool?
    let frequency_ignore: Bool?
    let cable_emulation: String?
    let cable_emulation_ignore: Bool?
}

struct PresetsInfo: Codable {
    let active: String?
    let user: [String: [Int]]?
}

// MARK: - Meter Information

struct MeterInfo: Codable {
    let rx1: RxMeter?
    let rx2: RxMeter?
}

struct RxMeter: Codable {
    let rssi: Double?
    let rsqi: Int?
    let divi: Int?
    let af: Double?
}

// MARK: - Mates Information

struct MatesInfo: Codable {
    let tx1: TransmitterInfo?
    let tx2: TransmitterInfo?
    let active: [String]?
}

struct TransmitterInfo: Codable {
    // Basic info
    let name: String?
    let type: String?
    let version: String?
    
    // Settings
    let trim: Int?
    let mute: Bool?
    let mute_config: String?
    let lowcut: String?
    let lock: Bool?
    let led: Bool?
    let cable_emulation: String?
    
    // Status
    let warnings: [String]?
    let identification: Bool?
    let capsule: String?
    
    // Battery info
    let battery: BatteryInfo?
}

struct BatteryInfo: Codable {
    let type: String?
    let gauge: Int?
    let lifetime: Int?
}

// MARK: - Bays Information (Charger)

struct BaysInfo: Codable {
    let storage_mode: Bool?
    let identify: [Bool]?
    let device_type: [String]?
    let bat_timetofull: [Int]?
    let bat_health: [Int]?
    let bat_gauge: [Int]?
    let bat_cycles: [Int]?
    
    // 기존 ChargingBayStatus 배열로 변환
    func toChargingBayStatuses(sourceDevice: DeviceInfo) -> [ChargingBayStatus] {
        var result: [ChargingBayStatus] = []
        
        // 필요한 데이터 갯수 확인
        let count = max(
            device_type?.count ?? 0,
            bat_gauge?.count ?? 0,
            bat_health?.count ?? 0,
            bat_timetofull?.count ?? 0,
            bat_cycles?.count ?? 0
        )
        
        // 각 베이에 대한 상태 생성
        for i in 0..<count {
            let bay = ChargingBayStatus(
                id: i,
                deviceType: device_type?.count ?? 0 > i ? device_type![i] : "NONE",
                batteryPercentage: bat_gauge?.count ?? 0 > i ? bat_gauge![i] : 0,
                batteryHealth: bat_health?.count ?? 0 > i ? bat_health![i] : 0,
                timeToFull: bat_timetofull?.count ?? 0 > i ? bat_timetofull![i] : 0,
                batteryCycles: bat_cycles?.count ?? 0 > i ? bat_cycles![i] : 0,
                sourceDevice: sourceDevice
            )
            result.append(bay)
        }
        
        return result
    }
}

// MARK: - SSC Response Parser Methods

/// Helper class to parse SSC responses using the model structure
class SSCResponseParser {
    
    /// Parse a generic SSC response
    static func parse<T: Decodable>(data: Data) -> T? {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ Failed to parse SSC response: \(error)")
            return nil
        }
    }
    
    /// Parse device name from a response
    static func parseDeviceName(from data: Data) -> String? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        return response.device?.name
    }
    
    /// Parse RX channel name
    static func parseRXName(from data: Data, channel: Int) -> String? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        if channel == 1 {
            return response.rx1?.name
        } else {
            return response.rx2?.name
        }
    }
    
    /// Parse bay device types from a charger
    static func parseBaysDeviceTypes(from data: Data) -> [String]? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        return response.bays?.device_type
    }
    
    /// Parse bay battery gauge levels from a charger
    static func parseBaysBatteryGauge(from data: Data) -> [Int]? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        return response.bays?.bat_gauge
    }
    
    /// Parse TX battery gauge for a specific channel
    static func parseTXBatteryGauge(from data: Data, channel: Int) -> Int? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        
        // Check for error response
        if response.hasError {
            return nil
        }
        
        // Return appropriate channel data
        if channel == 1 {
            return response.mates?.tx1?.battery?.gauge
        } else {
            return response.mates?.tx2?.battery?.gauge
        }
    }
    
    /// Parse TX battery lifetime for a specific channel
    static func parseTXBatteryLifetime(from data: Data, channel: Int) -> Int? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        
        // Check for error response
        if response.hasError {
            return nil
        }
        
        // Return appropriate channel data
        if channel == 1 {
            return response.mates?.tx1?.battery?.lifetime
        } else {
            return response.mates?.tx2?.battery?.lifetime
        }
    }
    
    /// Parse signal strength for a specific channel
    static func parseSignalStrength(from data: Data, channel: Int) -> Int? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        
        if channel == 1 {
            return response.m?.rx1?.rsqi
        } else {
            return response.m?.rx2?.rsqi
        }
    }
    
    /// Parse TX warnings for a specific channel
    static func parseTXWarnings(from data: Data, channel: Int) -> [String]? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        
        // Check for error response
        if response.hasError {
            return nil
        }
        
        // Return appropriate channel data
        if channel == 1 {
            return response.mates?.tx1?.warnings
        } else {
            return response.mates?.tx2?.warnings
        }
    }
    
    /// Check if the response contains an error
    static func isErrorResponse(data: Data) -> Bool {
        guard let response: SSCResponse = parse(data: data) else { return false }
        return response.hasError
    }
    
    /// Parse error code from response
    static func parseErrorCode(from data: Data) -> Int? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        return response.errorCode
    }
    
    /// Parse charging bay statuses and convert to app model
    static func parseChargingBayStatuses(from data: Data, sourceDevice: DeviceInfo) -> [ChargingBayStatus]? {
        guard let response: SSCResponse = parse(data: data) else { return nil }
        return response.bays?.toChargingBayStatuses(sourceDevice: sourceDevice)
    }
    
    /// Create MicStatus from TX and RX information
    static func createMicStatus(
        id: Int,
        name: String?,
        batteryGauge: Int?,
        batteryLifetime: Int?,
        signalStrength: Int?,
        warnings: [String]?,
        sourceDevice: DeviceInfo
    ) -> MicStatus {
        return MicStatus(
            id: id,
            name: name ?? "마이크 \(id+1)",
            batteryPercentage: batteryGauge ?? 0,
            signalStrength: signalStrength ?? 0,
            batteryRuntime: batteryLifetime ?? 0,
            warning: warnings?.isEmpty == false,
            state: batteryGauge ?? 0 > 0 ? (signalStrength ?? 0 > 0 ? .active : .charging) : .disconnected,
            sourceDevice: sourceDevice
        )
    }
}
