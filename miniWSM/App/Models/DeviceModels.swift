//
//  DeviceModels.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Foundation
import SwiftUI

// MARK: - 디바이스 타입 열거형
enum DeviceType: String, Codable, CaseIterable {
    case receiver
    case charger
    
    var description: String {
        switch self {
        case .receiver: return "수신기"
        case .charger: return "충전기"
        }
    }
}

// MARK: - 마이크 상태 열거형
enum MicStateType: String, Codable, CaseIterable {
    case charging     // 충전 중
    case active       // 사용 중 (수신기에 연결됨)
    case disconnected // 꺼짐 (감지 안됨)
    
    var description: String {
        switch self {
        case .charging: return "충전 중"
        case .active: return "사용 중"
        case .disconnected: return "연결 안됨"
        }
    }
    
    var icon: String {
        switch self {
        case .charging: return "arrow.down.circle.fill"
        case .active: return "arrow.up.circle.fill"
        case .disconnected: return "power.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .charging: return .blue
        case .active: return .green
        case .disconnected: return .gray
        }
    }
}

// MARK: - 장치 정보 모델
struct DeviceInfo: Codable, Hashable, Identifiable {
    var id: String { ipAddress } // Identifiable 프로토콜 준수
    var name: String
    var ipAddress: String
    var type: String // DeviceType을 직접 저장할 수 없어 String으로 저장
    var lastSeen: Date
    var isEnabled: Bool = true
    var customName: String = "" // 사용자 지정 이름
    
    // 장치 타입 변환 헬퍼
    var deviceType: DeviceType {
        get {
            return DeviceType(rawValue: type) ?? .receiver
        }
        set {
            type = newValue.rawValue
        }
    }
    
    // 표시용 이름 (사용자 지정 이름이 있으면 사용)
    var displayName: String {
        return customName.isEmpty ? name : customName
    }
    
    // JSON 인코딩/디코딩을 위한 CodingKeys
    enum CodingKeys: String, CodingKey {
        case name, ipAddress, type, lastSeen, isEnabled, customName
    }
}
