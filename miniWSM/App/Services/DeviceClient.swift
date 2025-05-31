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
    
    /// 마이크 상태 조회
    func queryMicStatus(channel: Int, completion: @escaping (MicStatus?) -> Void) {
        let rxPath = channel == 1 ? "rx1" : "rx2"
        let txPath = channel == 1 ? "tx1" : "tx2"
        
        // 데이터 저장 변수
        var name = "마이크 \(channel)"
        var batteryPercentage = 0
        var signalStrength = 0
        var batteryRuntime = 0
        var hasWarning = false
        var errorDetected = false
        
        // 디스패치 그룹 생성
        let dispatchGroup = DispatchGroup()
        
        // 1. 이름 조회
        dispatchGroup.enter()
        sendRawMessage("{\"\(rxPath)\":{\"name\":null}}") { data, error in
            defer { dispatchGroup.leave() }
            
            if let data = data, error == nil,
               let micName = SSCResponseParser.parseRXName(from: data, channel: channel) {
                name = micName
                SSCLogger.log("마이크 \(channel) 이름: \(micName)", category: .info, level: .debug)
            } else {
                errorDetected = true
                SSCLogger.log("마이크 \(channel) 이름 조회 실패", category: .warning)
            }
        }
        
        // 2. 배터리 레벨 조회
        dispatchGroup.enter()
        sendRawMessage("{\"mates\":{\"\(txPath)\":{\"battery\":{\"gauge\":null}}}}") { data, error in
            defer { dispatchGroup.leave() }
            
            if let data = data, error == nil,
               let gauge = SSCResponseParser.parseTXBatteryGauge(from: data, channel: channel) {
                batteryPercentage = gauge
                SSCLogger.log("마이크 \(channel) 배터리: \(gauge)%", category: .battery, level: .debug)
            } else {
                errorDetected = true
                SSCLogger.log("마이크 \(channel) 배터리 조회 실패", category: .warning)
            }
        }
        
        // 3. 신호 강도 조회
        dispatchGroup.enter()
        sendRawMessage("{\"m\":{\"\(rxPath)\":{\"rsqi\":null}}}") { data, error in
            defer { dispatchGroup.leave() }
            
            if let data = data, error == nil,
               let strength = SSCResponseParser.parseSignalStrength(from: data, channel: channel) {
                signalStrength = strength
                SSCLogger.log("마이크 \(channel) 신호 강도: \(strength)", category: .info, level: .debug)
            } else {
                errorDetected = true
                SSCLogger.log("마이크 \(channel) 신호 강도 조회 실패", category: .warning)
            }
        }
        
        // 4. 배터리 수명 조회
        dispatchGroup.enter()
        sendRawMessage("{\"mates\":{\"\(txPath)\":{\"battery\":{\"lifetime\":null}}}}") { data, error in
            defer { dispatchGroup.leave() }
            
            if let data = data, error == nil,
               let lifetime = SSCResponseParser.parseTXBatteryLifetime(from: data, channel: channel) {
                batteryRuntime = lifetime
                SSCLogger.log("마이크 \(channel) 배터리 런타임: \(lifetime)분", category: .battery, level: .debug)
            } else {
                SSCLogger.log("마이크 \(channel) 배터리 런타임 조회 실패", category: .warning, level: .debug)
            }
        }
        
        // 5. 경고 조회
        dispatchGroup.enter()
        sendRawMessage("{\"mates\":{\"\(txPath)\":{\"warnings\":null}}}") { data, error in
            defer { dispatchGroup.leave() }
            
            if let data = data, error == nil,
               let warnings = SSCResponseParser.parseTXWarnings(from: data, channel: channel) {
                hasWarning = !warnings.isEmpty
                if !warnings.isEmpty {
                    SSCLogger.log("마이크 \(channel) 경고 발견: \(warnings)", category: .warning)
                }
            } else {
                SSCLogger.log("마이크 \(channel) 경고 조회 실패", category: .warning, level: .debug)
            }
        }
        
        // 모든 조회 완료 후 마이크 상태 생성
        dispatchGroup.notify(queue: .global()) {
            let micState: MicStateType
            
            if errorDetected || batteryPercentage <= 0 {
                micState = .disconnected
            } else if signalStrength > 0 {
                micState = .active
            } else {
                micState = .charging
            }
            
            let status = MicStatus(
                id: channel - 1, // 채널 1은 ID 0
                name: name,
                batteryPercentage: batteryPercentage,
                signalStrength: signalStrength,
                batteryRuntime: batteryRuntime,
                warning: hasWarning,
                state: micState,
                sourceDevice: self.deviceInfo
            )
            
            SSCLogger.log("마이크 \(channel) 상태 조회 완료: \(status.state.description)", category: .info)
            completion(status)
        }
    }
}
