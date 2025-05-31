//
//  Network.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Foundation
import Network

// MARK: - SSC 클라이언트
class SSCClient {
    private var _connection: NWConnection?
    public let deviceIP: String
    private let devicePort: UInt16
    private let queue = DispatchQueue(label: "com.ewdx.udpqueue")
    
    // Thread-safe properties
    private let propertyLock = NSLock()
    private var _detectedDeviceType: DeviceType?
    private var _isDetectingType = false
    
    private var connection: NWConnection? {
        get {
            propertyLock.lock()
            defer { propertyLock.unlock() }
            return _connection
        }
        set {
            propertyLock.lock()
            defer { propertyLock.unlock() }
            _connection = newValue
        }
    }
    
    public private(set) var detectedDeviceType: DeviceType? {
        get {
            propertyLock.lock()
            defer { propertyLock.unlock() }
            return _detectedDeviceType
        }
        set {
            propertyLock.lock()
            defer { propertyLock.unlock() }
            _detectedDeviceType = newValue
        }
    }
    
    private var isDetectingType: Bool {
        get {
            propertyLock.lock()
            defer { propertyLock.unlock() }
            return _isDetectingType
        }
        set {
            propertyLock.lock()
            defer { propertyLock.unlock() }
            _isDetectingType = newValue
        }
    }
    
    init(deviceIP: String, devicePort: UInt16 = 45) {
        self.deviceIP = deviceIP
        self.devicePort = devicePort
    }
    
    func connect() {
        SSCLogger.log("UDP 연결 시도: \(deviceIP):\(devicePort)", category: .network)
        
        let host = NWEndpoint.Host(deviceIP)
        let port = NWEndpoint.Port(integerLiteral: devicePort)
        
        connection = NWConnection(host: host, port: port, using: .udp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                SSCLogger.log("UDP 연결 준비 완료: \(self?.deviceIP ?? "") (연결 성공)", category: .network)
                
                // 연결 확인 및 디바이스 타입 감지
                if !(self?.isDetectingType ?? true) {
                    self?.detectDeviceType()
                }
                
            case .setup:
                SSCLogger.log("UDP 연결 설정 중...", category: .network, level: .debug)
                
            case .preparing:
                SSCLogger.log("UDP 연결 준비 중...", category: .network, level: .debug)
                
            case .failed(let error):
                SSCLogger.log("UDP 연결 실패: \(error)", category: .error)
                self?.reconnect()
                
            case .waiting(let error):
                SSCLogger.log("UDP 연결 대기 중: \(error)", category: .warning)
                self?.reconnect()
                
            case .cancelled:
                SSCLogger.log("UDP 연결 취소됨", category: .network)
                
            default:
                SSCLogger.log("UDP 연결 상태 변경: \(state)", category: .network, level: .debug)
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func detectDeviceType() {
        // 장치 정보 요청으로 디바이스 타입 감지
        isDetectingType = true
        SSCLogger.log("디바이스 타입 감지: device/name 요청 중...", category: .device)
        
        let testMessage = """
        {"device":{"name":null}}
        """
        
        // 디바이스 이름으로 타입 확인
        self.sendRawMessage(testMessage) { [weak self] data, error in
            guard let self = self else { return }
            
            if let data = data, error == nil,
               let jsonString = String(data: data, encoding: .utf8) {
                SSCLogger.log("장치 응답 받음", category: .device, level: .debug)
                
                // 보다 포괄적인 장치 타입 감지
                if jsonString.contains("\"CHG") {
                    SSCLogger.log("충전기 디바이스 감지됨", category: .device)
                    self.detectedDeviceType = .charger
                } else if jsonString.contains("\"EW-DX EM") ||
                          jsonString.contains("\"EWDXEM") ||
                          (jsonString.contains("EW-DX") && jsonString.contains("EM")) {
                    SSCLogger.log("수신기 디바이스 감지됨", category: .device)
                    self.detectedDeviceType = .receiver
                } else {
                    // 추가 식별 시도
                    self.identifyBySecondaryCheck()
                }
            } else if let error = error {
                SSCLogger.log("디바이스 타입 감지 실패: \(error)", category: .error)
                self.isDetectingType = false
            }
        }
    }
    
    // 일차 감지 실패시 추가 식별 시도
    private func identifyBySecondaryCheck() {
        // 수신기 특성 확인 (rx1 또는 rx2가 있는지)
        let rxCheckMessage = """
        {"rx1":{"name":null}}
        """
        
        self.sendRawMessage(rxCheckMessage) { [weak self] data, error in
            guard let self = self else { return }
            
            if let data = data, error == nil,
               let jsonString = String(data: data, encoding: .utf8) {
                SSCLogger.log("수신기 특성 확인 응답", category: .device, level: .debug)
                
                if jsonString.contains("rx1") && !jsonString.contains("error") {
                    SSCLogger.log("수신기 디바이스 감지됨 (rx1 확인): \(self.deviceIP)", category: .device)
                    self.detectedDeviceType = .receiver
                } else {
                    // 충전기 특성 확인 (베이 정보가 있는지)
                    self.checkForChargerFeatures()
                }
            } else {
                self.checkForChargerFeatures()
            }
        }
    }
    
    // 충전기 특성 확인
    private func checkForChargerFeatures() {
        let baysCheckMessage = """
        {"bays":{"bat_gauge":null}}
        """
        
        self.sendRawMessage(baysCheckMessage) { [weak self] data, error in
            guard let self = self else { return }
            
            if let data = data, error == nil,
               let jsonString = String(data: data, encoding: .utf8) {
                SSCLogger.log("충전기 특성 확인 응답", category: .device, level: .debug)
                
                if jsonString.contains("bays") && !jsonString.contains("error") {
                    SSCLogger.log("충전기 디바이스 감지됨 (베이 확인): \(self.deviceIP)", category: .device)
                    self.detectedDeviceType = .charger
                } else {
                    SSCLogger.log("알 수 없는 디바이스 타입: \(self.deviceIP)", category: .warning)
                }
            } else {
                SSCLogger.log("장치 타입 감지 실패: \(self.deviceIP)", category: .error)
            }
            
            self.isDetectingType = false
        }
    }
    
    private func reconnect() {
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.connect()
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        isDetectingType = false
    }
    
    // 원시 메시지 직접 전송
    func sendRawMessage(_ message: String, completion: @escaping (Data?, Error?) -> Void) {
        guard let connection = connection else {
            completion(nil, NSError(domain: "SSCClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "연결이 없습니다"]))
            return
        }
        
        guard let messageData = message.data(using: .utf8) else {
            completion(nil, NSError(domain: "SSCClient", code: 4, userInfo: [NSLocalizedDescriptionKey: "메시지 인코딩 실패"]))
            return
        }
        
        // 메시지 고유 ID 생성
        let requestId = UUID().uuidString.prefix(8)
        SSCLogger.logNetworkRequest(deviceIP, message: message, requestId: String(requestId))
        
        // 메시지 전송
        connection.send(content: messageData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                SSCLogger.log("전송 오류: \(error)", category: .error)
                completion(nil, error)
                return
            }
            
            // 응답 대기
            self?.receiveResponse(connection: connection, requestId: String(requestId), completion: completion)
        })
    }
    
    private func receiveResponse(connection: NWConnection, requestId: String, completion: @escaping (Data?, Error?) -> Void) {
        // 응답 타임아웃을 위한 작업 생성
        let workItem = DispatchWorkItem {
            SSCLogger.log("응답 타임아웃 발생", category: .error)
            completion(nil, NSError(domain: "SSCClient", code: 5, userInfo: [NSLocalizedDescriptionKey: "응답 타임아웃"]))
        }
        
        // 타임아웃 설정 (1초 후 실행) - UDP 큐에서 실행
        queue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
        
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            // 타임아웃 작업 취소
            workItem.cancel()
            
            // 동일한 큐에서 completion 호출을 보장
            self?.queue.async {
                if let error = error {
                    SSCLogger.logNetworkResponse(requestId, response: "오류", error: error)
                    completion(nil, error)
                    return
                }
                
                if let data = data, !data.isEmpty {
                    // 응답 성공
                    let responseStr = String(data: data, encoding: .utf8) ?? "디코딩 실패"
                    SSCLogger.logNetworkResponse(requestId, response: responseStr)
                    completion(data, nil)
                } else if isComplete {
                    // 빈 응답도 성공으로 처리 (일부 명령은 응답이 없을 수 있음)
                    SSCLogger.logNetworkResponse(requestId, response: "빈 응답")
                    completion(nil, nil)
                } else {
                    SSCLogger.log("수신 실패: 알 수 없는 오류", category: .error)
                    completion(nil, NSError(domain: "SSCClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "알 수 없는 오류"]))
                }
            }
        }
    }
}

// MARK: - 장치 스캐너
class DeviceScanner {
    // 스캔 작업 상태 추적을 위한 클래스
    private class ScanOperation {
        let ip: String
        private let lock = NSLock()
        private var _isTimedOut = false
        private var _isCompleted = false
        
        var isTimedOut: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _isTimedOut
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _isTimedOut = newValue
            }
        }
        
        var isCompleted: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _isCompleted
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _isCompleted = newValue
            }
        }
        
        init(ip: String) {
            self.ip = ip
        }
    }
    
    // 스캔 취소 관련 변수 추가
    private let cancelLock = NSLock()
    private var _isCancelled = false
    private var isCancelled: Bool {
        get {
            cancelLock.lock()
            defer { cancelLock.unlock() }
            return _isCancelled
        }
        set {
            cancelLock.lock()
            defer { cancelLock.unlock() }
            _isCancelled = newValue
        }
    }
    private var activeClients = [SSCClient]()
    private let clientsLock = NSLock()
    
    // 스캔 취소 메서드 추가
    func cancelScan() {
        SSCLogger.log("네트워크 스캔 취소 요청됨", category: .network)
        isCancelled = true
        
        // 활성 클라이언트 모두 연결 해제
        clientsLock.lock()
        let clients = activeClients
        activeClients.removeAll()
        clientsLock.unlock()
        
        for client in clients {
            client.disconnect()
        }
        
        SSCLogger.log("모든 스캔 클라이언트 연결 해제됨", category: .network)
    }
    
    // 네트워크 범위에서 장치 스캔
    func scanNetwork(baseIP: String, completion: @escaping ([DeviceInfo]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var foundDevices: [DeviceInfo] = []
        let lock = NSLock() // 여러 스레드에서 동시에 foundDevices 배열 수정 방지
        
        // 상태 초기화
        isCancelled = false
        activeClients.removeAll()
        
        SSCLogger.log("네트워크 스캔 시작: IP 범위 \(baseIP)", category: .network)
        
        // 간단한 예: IP 범위 스캔 (실제로는 보다 효율적인 방법 사용 필요)
        for i in 1...254 {
            // 취소 확인
            if isCancelled {
                SSCLogger.log("스캔이 취소되어 더 이상 진행하지 않습니다.", category: .warning)
                break
            }
            
            let ip = baseIP.replacingOccurrences(of: "x", with: "\(i)")
            
            dispatchGroup.enter()
            
            // 각 IP 주소에 SSC 장치가 있는지 검사
            let client = SSCClient(deviceIP: ip)
            
            // 활성 클라이언트 추적
            clientsLock.lock()
            activeClients.append(client)
            clientsLock.unlock()
            
            // 작업 상태 관리용 객체
            let operation = ScanOperation(ip: ip)
            
            // 타임아웃 설정 - 메인 스레드에서만 Timer 생성
            DispatchQueue.main.async {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    
                    if !operation.isCompleted {
                        operation.isTimedOut = true
                        
                        // 취소된 경우 로그 출력 안함
                        if !self.isCancelled {
                            SSCLogger.log("타임아웃: \(ip)", category: .warning, level: .debug)
                        }
                        
                        // 클라이언트 목록에서 제거
                        self.clientsLock.lock()
                        if let index = self.activeClients.firstIndex(where: { $0.deviceIP == ip }) {
                            self.activeClients.remove(at: index)
                        }
                        self.clientsLock.unlock()
                        
                        client.disconnect()
                        dispatchGroup.leave()
                    }
                }
            }
            
            // 장치 확인 요청 전송
            let testMessage = """
            {"device":{"name":null}}
            """
            
            client.connect()
            
            // 0.2초 후 장치 조회 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                // 이미 타임아웃 되었거나 취소된 경우
                if operation.isTimedOut || (self?.isCancelled ?? false) {
                    // 클라이언트 목록에서 제거
                    self?.clientsLock.lock()
                    if let index = self?.activeClients.firstIndex(where: { $0.deviceIP == ip }) {
                        self?.activeClients.remove(at: index)
                    }
                    self?.clientsLock.unlock()
                    
                    client.disconnect()
                    
                    // 이미 타임아웃으로 dispatchGroup.leave()가 호출되었을 수 있으므로 체크
                    if !operation.isTimedOut {
                        dispatchGroup.leave()
                    }
                    return
                }
                
                client.sendRawMessage(testMessage) { [weak self] data, error in
                    guard let self = self else {
                        client.disconnect()
                        
                        // 이미 타임아웃으로 dispatchGroup.leave()가 호출되었을 수 있으므로 체크
                        if !operation.isTimedOut {
                            dispatchGroup.leave()
                        }
                        return
                    }
                    
                    // 취소 확인
                    if self.isCancelled {
                        // 클라이언트 목록에서 제거
                        self.clientsLock.lock()
                        if let index = self.activeClients.firstIndex(where: { $0.deviceIP == ip }) {
                            self.activeClients.remove(at: index)
                        }
                        self.clientsLock.unlock()
                        
                        client.disconnect()
                        
                        // 이미 타임아웃으로 dispatchGroup.leave()가 호출되었을 수 있으므로 체크
                        if !operation.isTimedOut {
                            dispatchGroup.leave()
                        }
                        return
                    }
                    
                    // 응답 처리
                    if let data = data, error == nil {
                        // JSON 파싱하여 장치 정보 추출
                        if let deviceName = SSCResponseParser.parseDeviceName(from: data) {
                            // 장치 타입 결정 - 보다 많은 패턴 추가
                            var deviceType: DeviceType = .receiver
                            
                            if deviceName.contains("CHG") {
                                deviceType = .charger
                                SSCLogger.log("충전기 발견: \(deviceName) at \(ip)", category: .device)
                            } else if deviceName.contains("EW-DX") ||
                                     deviceName.contains("EWDX") ||
                                     deviceName.contains("EM") {
                                deviceType = .receiver
                                SSCLogger.log("수신기 발견: \(deviceName) at \(ip)", category: .device)
                            } else {
                                SSCLogger.log("알 수 없는 장치 발견: \(deviceName) at \(ip)", category: .device)
                            }
                            
                            // 취소 안된 경우에만 장치 추가
                            if !self.isCancelled {
                                // 발견된 장치 추가 (스레드 안전하게)
                                let deviceInfo = DeviceInfo(
                                    name: deviceName,
                                    ipAddress: ip,
                                    type: deviceType.rawValue,
                                    lastSeen: Date()
                                )
                                
                                lock.lock()
                                foundDevices.append(deviceInfo)
                                lock.unlock()
                                
                                SSCLogger.log("장치 발견: \(deviceName) (\(ip)) - 타입: \(deviceType.description)", category: .success)
                            }
                        }
                    }
                    
                    // 클라이언트 목록에서 제거
                    self.clientsLock.lock()
                    if let index = self.activeClients.firstIndex(where: { $0.deviceIP == ip }) {
                        self.activeClients.remove(at: index)
                    }
                    self.clientsLock.unlock()
                    
                    // 처리 완료
                    operation.isCompleted = true
                    client.disconnect()
                    
                    // 이미 타임아웃으로 dispatchGroup.leave()가 호출되었을 수 있으므로 체크
                    if !operation.isTimedOut {
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // 모든 스캔 완료 후 결과 반환
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // 취소된 경우 빈 배열 반환
            if self.isCancelled {
                SSCLogger.log("스캔이 취소되어 빈 결과를 반환합니다.", category: .warning)
                completion([])
                return
            }
            
            SSCLogger.log("스캔 완료. 발견된 장치: \(foundDevices.count)개", category: .success)
            completion(foundDevices)
        }
    }
}

