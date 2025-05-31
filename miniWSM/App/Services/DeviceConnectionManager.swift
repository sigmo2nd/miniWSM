////
////  DeviceConnectionManager.swift
////  miniWSM
////
////  Created by Sieg on 4/27/25.
////
//
//import Foundation
//import Network
//import Combine
//
///// 연결 상태를 관리하고 자동 재연결 및 IP 변경 감지 기능을 제공하는 매니저
//class DeviceConnectionManager {
//    
//    // MARK: - 싱글톤 인스턴스
//    static let shared = DeviceConnectionManager()
//    
//    // MARK: - 타입 정의
//    
//    /// 연결 상태 열거형
//    enum ConnectionState {
//        case connected
//        case disconnected
//        case connecting
//        case failed(Error)
//    }
//    
//    /// 연결 관리 타입
//    struct DeviceConnection {
//        let deviceInfo: DeviceInfo
//        var client: SSCClient
//        var connectionState: ConnectionState = .disconnected
//        var lastConnectAttempt: Date = Date(timeIntervalSince1970: 0)
//        var connectAttempts: Int = 0
//        var serialNumber: String?
//        var macAddress: String?
//    }
//    
//    // MARK: - 속성
//    
//    /// 장치 연결 상태 발행자
//    private let connectionStateSubject = PassthroughSubject<(DeviceInfo, ConnectionState), Never>()
//    var connectionStatePublisher: AnyPublisher<(DeviceInfo, ConnectionState), Never> {
//        return connectionStateSubject.eraseToAnyPublisher()
//    }
//    
//    /// IP 주소 변경 감지 발행자
//    private let ipAddressChangedSubject = PassthroughSubject<(String, String, DeviceInfo), Never>()
//    var ipAddressChangedPublisher: AnyPublisher<(String, String, DeviceInfo), Never> {
//        return ipAddressChangedSubject.eraseToAnyPublisher()
//    }
//    
//    /// 활성 연결 관리
//    private var activeConnections: [String: DeviceConnection] = [:]
//    private let connectionsLock = NSLock()
//    
//    /// 장치 ID 매핑 (MAC 주소 또는 시리얼 번호 -> DeviceInfo)
//    private var deviceIdentifiers: [String: DeviceInfo] = [:]
//    
//    /// 재연결 타이머
//    private var reconnectTimer: Timer?
//    
//    /// 마지막 네트워크 스캔 시간
//    private var lastNetworkScan = Date(timeIntervalSince1970: 0)
//    
//    /// 스캐너 인스턴스
//    private let deviceScanner = DeviceScanner()
//    
//    // MARK: - 초기화 및 소멸
//    
//    private init() {
//        // 재연결 타이머 시작
//        startReconnectTimer()
//        
//        // 설정 변경 알림 구독
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleSettingsChanged),
//            name: NSNotification.Name("SettingsChanged"),
//            object: nil
//        )
//    }
//    
//    deinit {
//        stopReconnectTimer()
//        NotificationCenter.default.removeObserver(self)
//    }
//    
//    // MARK: - 공개 메서드
//    
//    /// 장치에 연결 시도
//    func connectToDevice(_ deviceInfo: DeviceInfo) -> SSCClient {
//        connectionsLock.lock()
//        defer { connectionsLock.unlock() }
//        
//        // 이미 존재하는 연결이 있는지 확인
//        if let existingConnection = activeConnections[deviceInfo.ipAddress] {
//            // 연결 상태 확인 및 필요시 재연결
//            if case .disconnected = existingConnection.connectionState {
//                SSCLogger.log("\(deviceInfo.name) 장치에 재연결 시도", category: .network)
//                initiateConnection(for: deviceInfo.ipAddress)
//            }
//            return existingConnection.client
//        }
//        
//        // 새 연결 생성
//        let client = SSCClient(deviceIP: deviceInfo.ipAddress)
//        
//        // 연결 정보 생성 및 저장
//        let connection = DeviceConnection(
//            deviceInfo: deviceInfo,
//            client: client,
//            connectionState: .disconnected
//        )
//        
//        activeConnections[deviceInfo.ipAddress] = connection
//        
//        // 연결 시작
//        initiateConnection(for: deviceInfo.ipAddress)
//        
//        // 장치 식별 정보 수집 예약
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//            self?.fetchDeviceIdentifiers(for: deviceInfo)
//        }
//        
//        return client
//    }
//    
//    /// 장치 연결 해제
//    func disconnectDevice(ipAddress: String) {
//        connectionsLock.lock()
//        defer { connectionsLock.unlock() }
//        
//        guard let connection = activeConnections[ipAddress] else { return }
//        
//        SSCLogger.log("\(connection.deviceInfo.name) 장치 연결 해제", category: .network)
//        connection.client.disconnect()
//        
//        // 상태 업데이트
//        var updatedConnection = connection
//        updatedConnection.connectionState = .disconnected
//        activeConnections[ipAddress] = updatedConnection
//        
//        // 연결 상태 발행
//        connectionStateSubject.send((connection.deviceInfo, .disconnected))
//    }
//    
//    /// 모든 연결 해제
//    func disconnectAllDevices() {
//        connectionsLock.lock()
//        let connections = activeConnections
//        connectionsLock.unlock()
//        
//        for (ipAddress, _) in connections {
//            disconnectDevice(ipAddress: ipAddress)
//        }
//        
//        // 타이머 중지
//        stopReconnectTimer()
//    }
//    
//    /// 장치 연결 상태 조회
//    func getConnectionState(for ipAddress: String) -> ConnectionState {
//        connectionsLock.lock()
//        defer { connectionsLock.unlock() }
//        
//        guard let connection = activeConnections[ipAddress] else {
//            return .disconnected
//        }
//        
//        return connection.connectionState
//    }
//    
//    /// 네트워크 스캔 수행하여 IP 변경 감지
//    func performNetworkScan() {
//        // 최근 스캔 후 충분한 시간이 지났는지 확인 (60초)
//        let now = Date()
//        guard now.timeIntervalSince(lastNetworkScan) > 60 else {
//            return
//        }
//        
//        lastNetworkScan = now
//        SSCLogger.log("네트워크 스캔 시작 (장치 자동 발견 및 IP 변경 감지)", category: .network)
//        
//        // 연결 문제가 있는 장치를 추적하기 위한 IP 목록 생성
//        var problematicDevices: [DeviceInfo] = []
//        
//        connectionsLock.lock()
//        for (_, connection) in activeConnections {
//            if case .disconnected = connection.connectionState, connection.connectAttempts > 3 {
//                problematicDevices.append(connection.deviceInfo)
//            }
//            
//            if case .failed = connection.connectionState {
//                problematicDevices.append(connection.deviceInfo)
//            }
//        }
//        connectionsLock.unlock()
//        
//        // 기존 장치의 MAC 주소와 시리얼 번호를 이용해 IP 변경 감지
//        deviceScanner.scanNetwork(baseIP: getCurrentNetworkBase()) { [weak self] devices in
//            guard let self = self else { return }
//            
//            // 발견된 장치 처리
//            for device in devices {
//                self.handleDiscoveredDevice(device)
//            }
//            
//            // 스캔 완료 로그
//            SSCLogger.log("네트워크 스캔 완료: 발견된 장치 \(devices.count)개", category: .network)
//        }
//    }
//    
//    // MARK: - 내부 메서드
//    
//    /// 설정 변경 처리
//    @objc private func handleSettingsChanged() {
//        // 활성 연결 업데이트
//        updateActiveConnections()
//    }
//    
//    /// 활성 연결 상태 업데이트
//    private func updateActiveConnections() {
//        // DeviceManager에서 현재 등록된 장치 가져오기
//        let registeredDevices = DeviceManager.shared.getRegisteredDevices()
//        
//        // 연결 목록 업데이트
//        connectionsLock.lock()
//        
//        // 1. 등록되지 않은 장치 제거
//        let registeredIPs = Set(registeredDevices.map { $0.ipAddress })
//        let currentIPs = Set(activeConnections.keys)
//        
//        for ip in currentIPs {
//            if !registeredIPs.contains(ip) {
//                if let connection = activeConnections[ip] {
//                    connection.client.disconnect()
//                    activeConnections.removeValue(forKey: ip)
//                    SSCLogger.log("\(connection.deviceInfo.name) 장치가 더 이상 등록되지 않아 연결 해제", category: .network)
//                }
//            }
//        }
//        
//        // 2. 새로 등록된 장치 추가
//        for device in registeredDevices {
//            if !activeConnections.keys.contains(device.ipAddress) {
//                let client = SSCClient(deviceIP: device.ipAddress)
//                let connection = DeviceConnection(
//                    deviceInfo: device,
//                    client: client,
//                    connectionState: .disconnected
//                )
//                activeConnections[device.ipAddress] = connection
//                SSCLogger.log("새로 등록된 장치 \(device.name) 추가됨", category: .network)
//            }
//        }
//        
//        // 3. 기존 장치 정보 업데이트
//        for device in registeredDevices {
//            if var connection = activeConnections[device.ipAddress] {
//                if connection.deviceInfo.name != device.name || connection.deviceInfo.isEnabled != device.isEnabled {
//                    // 정보 업데이트
//                    connection.deviceInfo = device
//                    activeConnections[device.ipAddress] = connection
//                    SSCLogger.log("\(device.name) 장치 정보 업데이트됨", category: .network, level: .debug)
//                }
//            }
//        }
//        
//        connectionsLock.unlock()
//    }
//    
//    /// 장치 연결 초기화
//    private func initiateConnection(for ipAddress: String) {
//        connectionsLock.lock()
//        guard var connection = activeConnections[ipAddress] else {
//            connectionsLock.unlock()
//            return
//        }
//        
//        // 연결 상태 및 시도 업데이트
//        connection.connectionState = .connecting
//        connection.lastConnectAttempt = Date()
//        connection.connectAttempts += 1
//        activeConnections[ipAddress] = connection
//        
//        // 상태 발행
//        let deviceInfo = connection.deviceInfo
//        connectionStateSubject.send((deviceInfo, .connecting))
//        
//        connectionsLock.unlock()
//        
//        // 클라이언트 연결 시작
//        connection.client.connect()
//        
//        // 연결 확인 타이머 (5초 후)
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
//            self?.verifyConnection(for: ipAddress)
//        }
//    }
//    
//    /// 연결 상태 확인
//    private func verifyConnection(for ipAddress: String) {
//        connectionsLock.lock()
//        guard var connection = activeConnections[ipAddress] else {
//            connectionsLock.unlock()
//            return
//        }
//        connectionsLock.unlock()
//        
//        // 기본 장치 정보 요청으로 연결 확인
//        let testMessage = """
//        {"device":{"name":null}}
//        """
//        
//        connection.client.sendRawMessage(testMessage) { [weak self] data, error in
//            guard let self = self else { return }
//            
//            self.connectionsLock.lock()
//            guard var updatedConnection = self.activeConnections[ipAddress] else {
//                self.connectionsLock.unlock()
//                return
//            }
//            
//            if let error = error {
//                // 연결 실패
//                updatedConnection.connectionState = .failed(error)
//                self.activeConnections[ipAddress] = updatedConnection
//                
//                // 상태 발행
//                self.connectionStateSubject.send((updatedConnection.deviceInfo, .failed(error)))
//                
//                SSCLogger.log("\(updatedConnection.deviceInfo.name) 장치 연결 실패: \(error.localizedDescription)", category: .error)
//            } else if let data = data {
//                // 연결 성공
//                updatedConnection.connectionState = .connected
//                updatedConnection.connectAttempts = 0
//                self.activeConnections[ipAddress] = updatedConnection
//                
//                // 상태 발행
//                self.connectionStateSubject.send((updatedConnection.deviceInfo, .connected))
//                
//                SSCLogger.log("\(updatedConnection.deviceInfo.name) 장치 연결 성공", category: .success)
//                
//                // 장치 식별자 정보 가져오기
//                self.connectionsLock.unlock()
//                self.fetchDeviceIdentifiers(for: updatedConnection.deviceInfo)
//                return
//            }
//            
//            self.connectionsLock.unlock()
//        }
//    }
//    
//    /// 장치 식별자 정보 가져오기 (MAC 주소, 시리얼 번호 등)
//    private func fetchDeviceIdentifiers(for deviceInfo: DeviceInfo) {
//        connectionsLock.lock()
//        guard let connection = activeConnections[deviceInfo.ipAddress] else {
//            connectionsLock.unlock()
//            return
//        }
//        connectionsLock.unlock()
//        
//        // 1. 시리얼 번호 요청
//        let serialRequest = """
//        {"device":{"identity":{"serial":null}}}
//        """
//        
//        connection.client.sendRawMessage(serialRequest) { [weak self] data, error in
//            guard let self = self, error == nil, let data = data else { return }
//            
//            // SSCResponse에서 시리얼 번호 추출
//            if let response = try? JSONDecoder().decode(SSCResponse.self, from: data),
//               let serial = response.device?.identity?.serial, !serial.isEmpty {
//                
//                self.connectionsLock.lock()
//                if var connection = self.activeConnections[deviceInfo.ipAddress] {
//                    connection.serialNumber = serial
//                    self.activeConnections[deviceInfo.ipAddress] = connection
//                    
//                    // 장치 식별자 매핑 업데이트
//                    self.deviceIdentifiers[serial] = deviceInfo
//                    SSCLogger.log("\(deviceInfo.name) 장치 시리얼 번호 확인: \(serial)", category: .device, level: .debug)
//                }
//                self.connectionsLock.unlock()
//            }
//        }
//        
//        // 2. MAC 주소 요청
//        let macRequest = """
//        {"device":{"network":{"ether":{"macs":null}}}}
//        """
//        
//        connection.client.sendRawMessage(macRequest) { [weak self] data, error in
//            guard let self = self, error == nil, let data = data else { return }
//            
//            // SSCResponse에서 MAC 주소 추출
//            if let response = try? JSONDecoder().decode(SSCResponse.self, from: data),
//               let macs = response.device?.network?.ether?.macs, !macs.isEmpty,
//               let primaryMac = macs.first, !primaryMac.isEmpty {
//                
//                self.connectionsLock.lock()
//                if var connection = self.activeConnections[deviceInfo.ipAddress] {
//                    connection.macAddress = primaryMac
//                    self.activeConnections[deviceInfo.ipAddress] = connection
//                    
//                    // 장치 식별자 매핑 업데이트
//                    self.deviceIdentifiers[primaryMac] = deviceInfo
//                    SSCLogger.log("\(deviceInfo.name) 장치 MAC 주소 확인: \(primaryMac)", category: .device, level: .debug)
//                }
//                self.connectionsLock.unlock()
//            }
//        }
//    }
//    
//    /// 발견된 장치 처리
//    private func handleDiscoveredDevice(_ device: DeviceInfo) {
//        // 1. 현재 등록된 장치 중 같은 IP를 가진 장치가 있는지 확인
//        let registeredDevices = DeviceManager.shared.getRegisteredDevices()
//        
//        if let existingDevice = registeredDevices.first(where: { $0.ipAddress == device.ipAddress }) {
//            // 이미 알고 있는 IP 주소의 장치 - 식별자 정보만 업데이트
//            fetchDeviceIdentifiers(for: existingDevice)
//            return
//        }
//        
//        // 2. 새 장치 정보로 식별자 가져오기 (비동기)
//        let client = SSCClient(deviceIP: device.ipAddress)
//        client.connect()
//        
//        // 2.1 시리얼 번호 요청
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            let serialRequest = """
//            {"device":{"identity":{"serial":null}}}
//            """
//            
//            client.sendRawMessage(serialRequest) { [weak self] data, error in
//                guard let self = self, error == nil, let data = data else { return }
//                
//                // 시리얼 번호 추출
//                if let response = try? JSONDecoder().decode(SSCResponse.self, from: data),
//                   let serial = response.device?.identity?.serial, !serial.isEmpty {
//                    
//                    // 3. 기존 장치 중 같은 시리얼 번호를 가진 장치가 있는지 확인
//                    self.checkForIPChange(identifier: serial, discoveredDevice: device, client: client)
//                }
//            }
//        }
//        
//        // 2.2 MAC 주소 요청
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//            let macRequest = """
//            {"device":{"network":{"ether":{"macs":null}}}}
//            """
//            
//            client.sendRawMessage(macRequest) { [weak self] data, error in
//                guard let self = self, error == nil, let data = data else { return }
//                
//                // MAC 주소 추출
//                if let response = try? JSONDecoder().decode(SSCResponse.self, from: data),
//                   let macs = response.device?.network?.ether?.macs, !macs.isEmpty,
//                   let primaryMac = macs.first, !primaryMac.isEmpty {
//                    
//                    // 3. 기존 장치 중 같은 MAC 주소를 가진 장치가 있는지 확인
//                    self.checkForIPChange(identifier: primaryMac, discoveredDevice: device, client: client)
//                }
//            }
//        }
//    }
//    
//    /// IP 변경 확인 및 처리
//    private func checkForIPChange(identifier: String, discoveredDevice: DeviceInfo, client: SSCClient) {
//        // 기존에 등록된 장치와 식별자 비교
//        guard let existingDevice = deviceIdentifiers[identifier],
//              existingDevice.ipAddress != discoveredDevice.ipAddress else {
//            return
//        }
//        
//        // IP 주소가 변경된 장치 발견
//        let oldIP = existingDevice.ipAddress
//        let newIP = discoveredDevice.ipAddress
//        
//        SSCLogger.log("장치 식별자 \(identifier)의 IP 주소가 변경됨: \(oldIP) → \(newIP)", category: .info)
//        
//        // IP 주소 변경 이벤트 발행
//        ipAddressChangedSubject.send((oldIP, newIP, existingDevice))
//        
//        // 장치 관리자에 IP 변경 알림
//        updateDeviceIP(deviceInfo: existingDevice, newIP: newIP)
//        
//        // 연결 관리 상태 업데이트
//        connectionsLock.lock()
//        
//        // 1. 기존 연결 정보 복사
//        if let oldConnection = activeConnections[oldIP] {
//            // 기존 클라이언트 연결 해제
//            oldConnection.client.disconnect()
//            
//            // 새 클라이언트 생성 또는 사용
//            var newConnection = oldConnection
//            newConnection.deviceInfo = DeviceInfo(
//                name: oldConnection.deviceInfo.name,
//                ipAddress: newIP,
//                type: oldConnection.deviceInfo.type,
//                lastSeen: Date(),
//                isEnabled: oldConnection.deviceInfo.isEnabled,
//                customName: oldConnection.deviceInfo.customName
//            )
//            newConnection.client = client
//            newConnection.connectionState = .connecting
//            newConnection.connectAttempts = 0
//            
//            // 연결 목록 업데이트
//            activeConnections.removeValue(forKey: oldIP)
//            activeConnections[newIP] = newConnection
//            
//            // 식별자 매핑 업데이트
//            deviceIdentifiers[identifier] = newConnection.deviceInfo
//        }
//        
//        connectionsLock.unlock()
//        
//        // 연결 상태 확인
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
//            self?.verifyConnection(for: newIP)
//        }
//    }
//    
//    /// 장치 IP 주소 업데이트
//    private func updateDeviceIP(deviceInfo: DeviceInfo, newIP: String) {
//        // 새 장치 정보 생성
//        var updatedDevice = deviceInfo
//        updatedDevice.ipAddress = newIP
//        updatedDevice.lastSeen = Date()
//        
//        // 장치 관리자 업데이트
//        DeviceManager.shared.unregisterDevice(ipAddress: deviceInfo.ipAddress)
//        DeviceManager.shared.registerDevice(device: updatedDevice)
//        
//        // 알림 표시
//        let notification = NSUserNotification()
//        notification.title = "장치 IP 주소 변경"
//        notification.informativeText = "\(deviceInfo.name)의 IP 주소가 변경되었습니다: \(deviceInfo.ipAddress) → \(newIP)"
//        NSUserNotificationCenter.default.deliver(notification)
//    }
//    
//    /// 재연결 타이머 시작
//    private func startReconnectTimer() {
//        reconnectTimer?.invalidate()
//        
//        reconnectTimer = Timer.scheduledTimer(
//            timeInterval: 30.0,  // 30초마다 재연결 시도
//            target: self,
//            selector: #selector(reconnectFailedDevices),
//            userInfo: nil,
//            repeats: true
//        )
//    }
//    
//    /// 재연결 타이머 중지
//    private func stopReconnectTimer() {
//        reconnectTimer?.invalidate()
//        reconnectTimer = nil
//    }
//    
//    /// 연결 실패한 장치들에 재연결 시도
//    @objc private func reconnectFailedDevices() {
//        connectionsLock.lock()
//        let connections = activeConnections
//        connectionsLock.unlock()
//        
//        var needsNetworkScan = false
//        
//        for (ipAddress, connection) in connections {
//            // 연결 상태 확인
//            switch connection.connectionState {
//            case .disconnected:
//                // 일정 시간이 지난 후에만 재연결 시도 (지수 백오프 적용)
//                let backoffInterval = min(pow(2.0, Double(connection.connectAttempts)), 300) // 최대 5분
//                let now = Date()
//                
//                if now.timeIntervalSince(connection.lastConnectAttempt) > backoffInterval {
//                    // 재연결 시도
//                    SSCLogger.log("\(connection.deviceInfo.name) 장치에 재연결 시도 (\(connection.connectAttempts+1)번째)", category: .network)
//                    initiateConnection(for: ipAddress)
//                }
//                
//                // 여러 번 실패하면 네트워크 스캔 필요
//                if connection.connectAttempts > 2 {
//                    needsNetworkScan = true
//                }
//                
//            case .failed:
//                // 실패한 연결은 disconnected로 변경하고 다음 사이클에서 재시도
//                connectionsLock.lock()
//                if var updatedConnection = activeConnections[ipAddress] {
//                    updatedConnection.connectionState = .disconnected
//                    activeConnections[ipAddress] = updatedConnection
//                }
//                connectionsLock.unlock()
//                
//                needsNetworkScan = true
//                
//            default:
//                break
//            }
//        }
//        
//        // 네트워크 스캔 필요시 실행
//        if needsNetworkScan {
//            performNetworkScan()
//        }
//    }
//    
//    /// 현재 네트워크 기본 주소 얻기
//    private func getCurrentNetworkBase() -> String {
//        // 기존 장치 IP를 기준으로 네트워크 주소 추정
//        let registeredDevices = DeviceManager.shared.getRegisteredDevices()
//        
//        // 첫 번째 방법: 등록된 장치의 IP 기반
//        if let device = registeredDevices.first, !device.ipAddress.isEmpty {
//            let components = device.ipAddress.split(separator: ".")
//            if components.count == 4 {
//                return "\(components[0]).\(components[1]).\(components[2]).x"
//            }
//        }
//        
//        // 두 번째 방법: 네트워크 인터페이스 기반으로 현재 IP 추정
//        if let interfaceInfo = getNetworkInterfaceInfo(),
//           let ipComponents = interfaceInfo.ipComponents,
//           ipComponents.count == 4 {
//            return "\(ipComponents[0]).\(ipComponents[1]).\(ipComponents[2]).x"
//        }
//        
//        // 기본값
//        return "192.168.0.x"
//    }
//    
//    /// 네트워크 인터페이스 정보 가져오기
//    private func getNetworkInterfaceInfo() -> (name: String, ip: String, ipComponents: [String]?)? {
//        var ifaddr: UnsafeMutablePointer<ifaddrs>?
//        
//        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
//            return nil
//        }
//        
//        defer {
//            freeifaddrs(ifaddr)
//        }
//        
//        var interfaceName: String?
//        var interfaceIP: String?
//        
//        // 우선순위: en0, en1, eth0, 그 외
//        let preferredInterfaces = ["en0", "en1", "eth0"]
//        var bestMatch: (name: String, ip: String, priority: Int) = ("", "", Int.max)
//        
//        // 인터페이스 순회
//        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
//            let interface = ifptr.pointee
//            let name = String(cString: interface.ifa_name)
//            
//            // IPv4 주소만 고려
//            let family = interface.ifa_addr.pointee.sa_family
//            if family == UInt8(AF_INET) {
//                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
//                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
//                            &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
//                let ip = String(cString: hostname)
//                
//                // 루프백 주소는 건너뛰기
//                if ip.hasPrefix("127.") {
//                    continue
//                }
//                
//                // 우선순위 계산
//                var priority = Int.max
//                if let index = preferredInterfaces.firstIndex(of: name) {
//                    priority = index
//                }
//                
//                // 더 높은 우선순위의 인터페이스 선택
//                if priority < bestMatch.priority {
//                    bestMatch = (name, ip, priority)
//                }
//            }
//        }
//        
//        // 결과 반환
//        if !bestMatch.name.isEmpty && !bestMatch.ip.isEmpty {
//            return (bestMatch.name, bestMatch.ip, bestMatch.ip.split(separator: ".").map { String($0) })
//        }
//        
//        return nil
//    }
//}
