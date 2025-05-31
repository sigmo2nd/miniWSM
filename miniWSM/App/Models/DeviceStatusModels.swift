//
//  DeviceStatusModels.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Foundation
import SwiftUI

// Import the DeviceModels file to access MicStateType and DeviceInfo

// MARK: - 데이터 모델 - 마이크 상태
struct MicStatus: Identifiable, Codable {
    var id: Int
    var name: String
    var batteryPercentage: Int
    var signalStrength: Int
    var batteryRuntime: Int
    var warning: Bool
    var state: MicStateType = .disconnected
    var sourceDevice: DeviceInfo? = nil // 이 마이크 정보의 출처 장치
    
    var signalImage: String {
        if signalStrength > 70 {
            return "wifi.high"
        } else if signalStrength > 40 {
            return "wifi.medium"
        } else {
            return "wifi.low"
        }
    }
    
    static func empty(id: Int) -> MicStatus {
        var status = MicStatus()
        status.id = id
        status.name = "마이크 \(id+1)"
        status.batteryPercentage = 0
        status.signalStrength = 0
        status.batteryRuntime = 0
        status.warning = false
        status.state = .disconnected
        status.sourceDevice = nil
        return status
    }
    
    // 마이크가 disconnected 상태로 변경되면 마지막 배터리 상태는 유지하되 state만 변경
    mutating func setDisconnected() {
        self.state = .disconnected
        self.signalStrength = 0
        self.batteryRuntime = 0
    }
    
    // Codable 구현
    enum CodingKeys: String, CodingKey {
        case id, name, batteryPercentage, signalStrength, batteryRuntime, warning, state, sourceDevice
    }
    
    // Default initializer
    init() {
        self.id = 0
        self.name = ""
        self.batteryPercentage = 0
        self.signalStrength = 0
        self.batteryRuntime = 0
        self.warning = false
        self.state = .disconnected
        self.sourceDevice = nil
    }
    
    init(id: Int, name: String, batteryPercentage: Int, signalStrength: Int, batteryRuntime: Int, warning: Bool, state: MicStateType = .disconnected, sourceDevice: DeviceInfo? = nil) {
        self.id = id
        self.name = name
        self.batteryPercentage = batteryPercentage
        self.signalStrength = signalStrength
        self.batteryRuntime = batteryRuntime
        self.warning = warning
        self.state = state
        self.sourceDevice = sourceDevice
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        batteryPercentage = try container.decode(Int.self, forKey: .batteryPercentage)
        signalStrength = try container.decode(Int.self, forKey: .signalStrength)
        batteryRuntime = try container.decode(Int.self, forKey: .batteryRuntime)
        warning = try container.decode(Bool.self, forKey: .warning)
        state = try container.decode(MicStateType.self, forKey: .state)
        sourceDevice = try container.decodeIfPresent(DeviceInfo.self, forKey: .sourceDevice)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(batteryPercentage, forKey: .batteryPercentage)
        try container.encode(signalStrength, forKey: .signalStrength)
        try container.encode(batteryRuntime, forKey: .batteryRuntime)
        try container.encode(warning, forKey: .warning)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(sourceDevice, forKey: .sourceDevice)
    }
}

// MARK: - 데이터 모델 - 충전 베이 상태
struct ChargingBayStatus: Identifiable, Codable {
    var id: Int
    var deviceType: String
    var batteryPercentage: Int
    var batteryHealth: Int
    var timeToFull: Int  // 분 단위
    var batteryCycles: Int
    var sourceDevice: DeviceInfo? = nil // 이 베이 정보의 출처 장치
    
    var batteryImage: String {
        if batteryPercentage > 70 {
            return "battery.100"
        } else if batteryPercentage > 40 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    var deviceTypeDisplay: String {
        return deviceType.isEmpty ? "없음" : deviceType
    }
    
    static func empty(id: Int) -> ChargingBayStatus {
        return ChargingBayStatus(
            id: id,
            deviceType: "",
            batteryPercentage: 0,
            batteryHealth: 0,
            timeToFull: 0,
            batteryCycles: 0
        )
    }
    
    // 장치가 베이에 있는지 확인
    var hasDevice: Bool {
        // "NONE"이 아니고 비어있지 않은 경우에만 장치가 있는 것으로 간주
        // 추가로 "EW-DX"로 시작하는 문자열이 있는지 확인하여 마이크인지 검증
        return deviceType != "NONE" && !deviceType.isEmpty && deviceType.contains("EW-DX")
    }
    
    // Codable 구현
    enum CodingKeys: String, CodingKey {
        case id, deviceType, batteryPercentage, batteryHealth, timeToFull, batteryCycles, sourceDevice
    }
}
