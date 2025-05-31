//
//  DeviceManager.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Foundation
import Combine

// MARK: - 장치 관리자
class DeviceManager {
    static let shared = DeviceManager()
    
    // 장치 목록 변경을 알리는 발행자
    private let deviceListSubject = PassthroughSubject<[DeviceInfo], Never>()
    var deviceListPublisher: AnyPublisher<[DeviceInfo], Never> {
        return deviceListSubject.eraseToAnyPublisher()
    }
    
    private var knownDevices: [String: DeviceInfo] = [:]
    
    private init() {
        // UserDefaults에서 저장된 장치 정보 로드
        loadDevices()
    }
    
    // 장치 등록
    func registerDevice(device: DeviceInfo) {
        knownDevices[device.ipAddress] = device
        saveDevices()
        
        // 장치 목록 변경 알림
        deviceListSubject.send(getRegisteredDevices())
    }
    
    // 장치 등록 취소
    func unregisterDevice(ipAddress: String) {
        knownDevices.removeValue(forKey: ipAddress)
        saveDevices()
        
        // 장치 목록 변경 알림
        deviceListSubject.send(getRegisteredDevices())
    }
    
    // 등록된 장치 목록 가져오기
    func getRegisteredDevices() -> [DeviceInfo] {
        return knownDevices.values.filter { $0.isEnabled }.sorted { $0.name < $1.name }
    }
    
    // 특정 유형의 장치만 가져오기
    func getDevicesByType(_ type: DeviceType) -> [DeviceInfo] {
        return getRegisteredDevices().filter { $0.deviceType == type }
    }
    
    // 장치 정보 저장 - Codable 활용
    private func saveDevices() {
        do {
            let data = try JSONEncoder().encode(knownDevices)
            UserDefaults.standard.set(data, forKey: "knownDevices")
        } catch {
            print("장치 정보 저장 실패: \(error.localizedDescription)")
        }
    }
    
    // 장치 정보 로드 - Codable 활용
    private func loadDevices() {
        if let savedData = UserDefaults.standard.data(forKey: "knownDevices") {
            do {
                let decoder = JSONDecoder()
                knownDevices = try decoder.decode([String: DeviceInfo].self, from: savedData)
                
                // 초기 장치 로드 시 알림
                deviceListSubject.send(getRegisteredDevices())
            } catch {
                print("장치 정보 로드 실패: \(error.localizedDescription)")
                // 오류 발생 시 빈 장치 목록으로 시작
                knownDevices = [:]
            }
        }
    }
}


// MARK: - DeviceManager 확장 구현
extension DeviceManager {
    
    /// 장치의 IP 주소 업데이트
    func updateDeviceIP(deviceId: String, newIP: String) {
        // deviceId가 시리얼 번호나 MAC 주소인 경우에 대한 처리
        var foundDevice: DeviceInfo?
        
        // 먼저 이름으로 검색
        for (_, device) in knownDevices {
            if device.name == deviceId {
                foundDevice = device
                break
            }
        }
        
        // 그 다음 IP로 검색
        if foundDevice == nil {
            foundDevice = knownDevices[deviceId]
        }
        
        guard var deviceInfo = foundDevice else {
            SSCLogger.log("장치 ID '\(deviceId)'를 찾을 수 없어 IP 업데이트 실패", category: .error)
            return
        }
        
        // 이전 IP 주소 백업
        let oldIP = deviceInfo.ipAddress
        
        // 새 IP 주소로 업데이트
        deviceInfo.ipAddress = newIP
        deviceInfo.lastSeen = Date()
        
        // 이전 IP 키 제거 및 새 IP로 등록
        knownDevices.removeValue(forKey: oldIP)
        knownDevices[newIP] = deviceInfo
        
        // 변경 저장
        saveDevices()
        
        // 알림 발송
        SSCLogger.log("장치 '\(deviceInfo.name)'의 IP 주소가 업데이트됨: \(oldIP) → \(newIP)", category: .success)
        deviceListSubject.send(getRegisteredDevices())
        
        // 설정 변경 알림 발송
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }
    
    /// 장치의 고유 식별자 부여 및 조회
    func associateDeviceIdentifier(ipAddress: String, identifier: String, type: String = "serial") {
        guard var deviceInfo = knownDevices[ipAddress] else {
            return
        }
        
        // 장치 정보에 식별자 저장 (UserDefaults에 저장된 customName 필드 활용)
        let identifierKey = "\(type):\(identifier)"
        deviceInfo.customName = identifierKey
        knownDevices[ipAddress] = deviceInfo
        
        // 변경 저장
        saveDevices()
    }
    
    /// 식별자로 장치 찾기
    func findDeviceByIdentifier(identifier: String) -> DeviceInfo? {
        // 시리얼이나 MAC 등록된 장치 찾기
        for (_, device) in knownDevices {
            // customName 필드에서 식별자 정보 추출
            if device.customName.contains(identifier) {
                return device
            }
        }
        return nil
    }
    
    /// 특정 IP 주소의 장치가 접속 불가능할 때 처리
    func markDeviceAsUnavailable(ipAddress: String) {
        guard var deviceInfo = knownDevices[ipAddress] else {
            return
        }
        
        // lastSeen 업데이트 없이 상태만 변경
        deviceInfo.isEnabled = false
        knownDevices[ipAddress] = deviceInfo
        
        // 변경 저장
        saveDevices()
        
        // 알림 발송
        SSCLogger.log("장치 '\(deviceInfo.name)'이 접속 불가능 상태로 표시됨", category: .warning)
        deviceListSubject.send(getRegisteredDevices())
    }
    
    /// 장치 재활성화
    func markDeviceAsAvailable(ipAddress: String) {
        guard var deviceInfo = knownDevices[ipAddress] else {
            return
        }
        
        // 재활성화
        deviceInfo.isEnabled = true
        deviceInfo.lastSeen = Date()
        knownDevices[ipAddress] = deviceInfo
        
        // 변경 저장
        saveDevices()
        
        // 알림 발송
        SSCLogger.log("장치 '\(deviceInfo.name)'이 다시 활성화됨", category: .success)
        deviceListSubject.send(getRegisteredDevices())
    }
    
    /// IP가 변경된 장치의 일괄 업데이트
    func updateDevices(changedDevices: [(oldIP: String, newIP: String, device: DeviceInfo)]) {
        var updated = false
        
        for change in changedDevices {
            // 이전 IP 키 제거 및 새 IP로 등록
            knownDevices.removeValue(forKey: change.oldIP)
            
            var updatedDevice = change.device
            updatedDevice.ipAddress = change.newIP
            updatedDevice.lastSeen = Date()
            
            knownDevices[change.newIP] = updatedDevice
            updated = true
            
            SSCLogger.log("장치 '\(updatedDevice.name)'의 IP 주소가 업데이트됨: \(change.oldIP) → \(change.newIP)", category: .success)
        }
        
        if updated {
            // 변경 저장
            saveDevices()
            
            // 알림 발송
            deviceListSubject.send(getRegisteredDevices())
            
            // 설정 변경 알림 발송
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
}
