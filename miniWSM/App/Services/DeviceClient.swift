//
//  DeviceClient.swift
//  miniWSM
//
//  Created by Sieg on 4/27/25.
//

import Foundation

/// Client to communicate with a device via SSC
class DeviceClient {
    let deviceInfo: DeviceInfo
    let client: SSCClient
    private var isConnected = false
    
    init(deviceInfo: DeviceInfo) {
        self.deviceInfo = deviceInfo
        self.client = SSCClient(deviceIP: deviceInfo.ipAddress)
    }
    
    func connect() {
        client.connect()
        isConnected = true
    }
    
    func disconnect() {
        client.disconnect()
        isConnected = false
    }
    
    func sendRequest(_ request: String, completion: @escaping (Data?, Error?) -> Void) {
        if !isConnected {
            // Auto-connect if needed
            connect()
        }
        
        client.sendRawMessage(request, completion: completion)
    }
    
    // 편의 메서드 - 기존 sendRawMessage 호환
    func sendRawMessage(_ message: String, completion: @escaping (Data?, Error?) -> Void) {
        sendRequest(message, completion: completion)
    }
    
    // MARK: - 충전기 베이 상태 조회
    
    /// 충전기 베이 상태 조회 - 최적화된 버전
    func queryBayStatus(completion: @escaping ([ChargingBayStatus]) -> Void) {
        // 모든 베이 속성을 한 번의 요청으로 조회 시도
        let request = "{\"bays\":{\"device_type\":null,\"bat_gauge\":null,\"bat_health\":null,\"bat_timetofull\":null,\"bat_cycles\":null}}"
        
        sendRawMessage(request) { [weak self] data, error in
            guard let self = self else {
                SSCLogger.log("클라이언트 인스턴스가 해제됨", category: .error)
                completion([])
                return
            }
            
            if let data = data, error == nil,
               let bayStatuses = SSCResponseParser.parseChargingBayStatuses(from: data, sourceDevice: self.deviceInfo),
               !bayStatuses.isEmpty {
                
                SSCLogger.log("충전기 베이 상태 조회 성공: \(bayStatuses.count)개의 베이", category: .battery)
                completion(bayStatuses)
            } else {
                // 통합 요청 실패 시 개별 요청으로 폴백
                SSCLogger.log("충전기 베이 통합 조회 실패, 개별 요청으로 시도합니다", category: .warning)
                self.queryBayStatusFallback(completion: completion)
            }
        }
    }
    
    /// 개별 요청으로 폴백하는 메서드
    private func queryBayStatusFallback(completion: @escaping ([ChargingBayStatus]) -> Void) {
        // 디바이스 타입 요청
        sendRawMessage("{\"bays\":{\"device_type\":null}}") { [weak self] data, error in
            guard let self = self else {
                completion([])
                return
            }
            
            if let data = data, error == nil,
               let deviceTypes = SSCResponseParser.parseBaysDeviceTypes(from: data) {
                
                // 배터리 게이지 요청
                self.sendRawMessage("{\"bays\":{\"bat_gauge\":null}}") { data, error in
                    if let data = data, error == nil,
                       let batteryLevels = SSCResponseParser.parseBaysBatteryGauge(from: data) {
                        
                        // 베이 상태 객체 생성
                        var bayStatuses: [ChargingBayStatus] = []
                        for i in 0..<min(deviceTypes.count, batteryLevels.count) {
                            let bay = ChargingBayStatus(
                                id: i,
                                deviceType: deviceTypes[i],
                                batteryPercentage: batteryLevels[i],
                                batteryHealth: 99, // 기본값
                                timeToFull: 0,     // 기본값
                                batteryCycles: 0,  // 기본값
                                sourceDevice: self.deviceInfo
                            )
                            bayStatuses.append(bay)
                        }
                        
                        SSCLogger.log("충전기 베이 상태 개별 조회 성공: \(bayStatuses.count)개의 베이", category: .battery)
                        completion(bayStatuses)
                    } else {
                        // 배터리 정보를 가져오지 못한 경우
                        SSCLogger.log("충전기 베이 배터리 정보 조회 실패", category: .error)
                        completion([])
                    }
                }
            } else {
                // 디바이스 타입을 가져오지 못한 경우
                SSCLogger.log("충전기 베이 디바이스 타입 조회 실패", category: .error)
                completion([])
            }
        }
    }
    
    // MARK: - 마이크 상태 조회
    
    /// 마이크 상태 조회 - 간소화 버전 (배터리 정보만)
    func queryMicStatus(channel: Int, completion: @escaping (MicStatus?) -> Void) {
        // 연결 확인
        guard isConnected else {
            completion(nil)
            return
        }
        
        let txPath = channel == 1 ? "tx1" : "tx2"
        
        // 배터리 정보만 간단히 조회
        sendRawMessage("{\"mates\":{\"\(txPath)\":{\"battery\":{\"gauge\":null}}}}") { [weak self] data, error in
            guard let self = self else {
                completion(nil)
                return
            }
            
            var batteryPercentage = 0
            
            if let data = data, error == nil,
               let gauge = SSCResponseParser.parseTXBatteryGauge(from: data, channel: channel) {
                batteryPercentage = gauge
            }
            
            let status = MicStatus(
                id: channel - 1,
                name: "마이크 \(channel)",
                batteryPercentage: batteryPercentage,
                signalStrength: 0,
                batteryRuntime: 0,
                warning: false,
                state: batteryPercentage > 0 ? .charging : .disconnected,
                sourceDevice: self.deviceInfo
            )
            
            SSCLogger.log("마이크 \(channel) 상태: \(batteryPercentage)%", category: .battery, level: .debug)
            completion(status)
        }
    }
}
