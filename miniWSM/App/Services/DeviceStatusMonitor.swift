//
//  DeviceStatusMonitor.swift
//  miniWSM
//
//  Created on 4/27/25.
//

import Foundation
import Combine

/// 디바이스 상태 모니터링
class DeviceStatusMonitor: ObservableObject {
    // 상태 발행자
    @Published var micStatuses: [MicStatus] = []
    @Published var chargingBayStatuses: [ChargingBayStatus] = []
    
    @Published private(set) var isUpdating = false
    @Published private(set) var cycleCount = 0
    @Published private(set) var lastCycleSuccessful = true
    
    // 구독 취소를 위한 저장소
    private var cancellables = Set<AnyCancellable>()
    
    // 장치 관리
    private var chargerClients: [DeviceClient] = []
    private var receiverClients: [DeviceClient] = []
    
    // 마이크 상태 캐시
    private var lastKnownMicStates: [MicStatus] = []
    
    // 중복 로그 방지용
    private var loggedBayIds = Set<Int>()
    private var loggedMicIds = Set<Int>()
    
    // 현재 사이클 ID 추적 (중복 완료 방지)
    private var currentCycleId = 0
    
    // MARK: - 초기화
    
    init() {
        SSCLogger.log("디바이스 상태 모니터 초기화", category: .info)
        loadRegisteredDevices()
    }
    
    // MARK: - 장치 관리
    
    /// 등록된 장치 로드
    private func loadRegisteredDevices() {
        // 기존 클라이언트 연결 해제
        for client in chargerClients {
            client.disconnect()
        }
        for client in receiverClients {
            client.disconnect()
        }
        
        // 클라이언트 배열 초기화
        chargerClients = []
        receiverClients = []
        
        // DeviceManager에서 등록된 장치 가져오기
        let chargers = DeviceManager.shared.getDevicesByType(.charger)
        let receivers = DeviceManager.shared.getDevicesByType(.receiver)
        
        // 충전기 클라이언트 생성
        for charger in chargers {
            let client = DeviceClient(deviceInfo: charger)
            chargerClients.append(client)
        }
        
        // 수신기 클라이언트 생성
        for receiver in receivers {
            let client = DeviceClient(deviceInfo: receiver)
            receiverClients.append(client)
        }
        
        SSCLogger.log("장치 로드 완료: 충전기 \(chargerClients.count)개, 수신기 \(receiverClients.count)개", category: .device)
    }
    
    // MARK: - 모니터링 제어
    
    /// 모니터링 시작
    func startMonitoring() {
        SSCLogger.log("디바이스 모니터링 시작", category: .info)
        
        // 모든 장치 연결 시작
        for client in chargerClients {
            client.connect()
        }
        for client in receiverClients {
            client.connect()
        }
        
        // 초기 상태 설정
        isUpdating = false
        cycleCount = 0
        
        // 초기 업데이트 시작 - 중복 호출 방지를 위해 수정
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            // startNewCycle만 호출 - checkChargingBays는 호출하지 않음
            self.startNewCycle()
        }
        
        // 주기적 업데이트 - Combine 타이머 사용
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        let actualInterval = interval > 0 ? interval : 5.0
        
        Timer.publish(every: actualInterval, on: .main, in: .common)
            .autoconnect()
            .filter { [weak self] _ in !(self?.isUpdating ?? true) }
            .sink { [weak self] _ in
                self?.startNewCycle()
            }
            .store(in: &cancellables)
    }
    
    /// 모니터링 중지
    func stopMonitoring() {
        SSCLogger.log("모니터링 중지", category: .info)
        
        // 업데이트 중단
        isUpdating = false
        
        // 구독 취소
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // 모든 장치 연결 해제
        for client in chargerClients {
            client.disconnect()
        }
        for client in receiverClients {
            client.disconnect()
        }
        
        // 클라이언트 목록 정리
        chargerClients.removeAll()
        receiverClients.removeAll()
        
        // 상태 데이터 정리
        chargingBayStatuses.removeAll()
        micStatuses.removeAll()
        loggedBayIds.removeAll()
        loggedMicIds.removeAll()
    }
    
    // MARK: - 업데이트 사이클
    
    /// 새 업데이트 사이클 시작
    private func startNewCycle() {
        guard !isUpdating else {
            SSCLogger.log("이미 업데이트 사이클이 진행 중입니다", category: .warning)
            return
        }
        
        isUpdating = true
        cycleCount += 1
        currentCycleId = cycleCount // 현재 사이클 ID 저장
        
        // 새 사이클 시작시 로그 추적 초기화
        loggedBayIds.removeAll()
        loggedMicIds.removeAll()
        
        SSCLogger.logCycleStart(cycleNumber: cycleCount)
        
        // 메모리 사용량 로그 (디버깅용)
        if cycleCount % 10 == 0 {  // 10 사이클마다 체크
            // 메모리 정보
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
            
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                             task_flavor_t(MACH_TASK_BASIC_INFO),
                             $0,
                             &count)
                }
            }
            
            if result == KERN_SUCCESS {
                let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
                SSCLogger.log("시스템 상태 (사이클 \(cycleCount)): 메모리 사용량 \(String(format: "%.1f", memoryUsageMB)) MB", category: .debug)
                
                // 메모리가 비정상적으로 많으면 경고
                if memoryUsageMB > 500 {
                    SSCLogger.log("⚠️ 메모리 사용량 경고: \(String(format: "%.1f", memoryUsageMB)) MB (정상: 50-200 MB)", category: .warning)
                }
            }
        }
        
        // 충전기 베이 상태 확인
        updateChargingBays()
    }
    
    /// 사이클 완료 - 중복 호출 방지 로직 추가
    private func finishCycle(_ success: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 중복 완료 방지를 위한 체크 추가
            // 현재 진행 중인 사이클이 아니면 무시
            guard self.isUpdating && self.currentCycleId == self.cycleCount else {
                return
            }
            
            // 성공 여부 저장
            self.lastCycleSuccessful = success
            
            // 완료 로그
            SSCLogger.logCycleComplete(cycleNumber: self.cycleCount, successful: success)
            
            // UI 업데이트
            self.objectWillChange.send()
            
            // 사이클 종료
            self.isUpdating = false
        }
    }
    
    // MARK: - 장치 상태 업데이트
    
    /// 충전기 베이 상태 업데이트
    private func updateChargingBays() {
        // 연결된 충전기가 없으면 바로 다음 단계로
        if chargerClients.isEmpty {
            updateMicStatuses()
            return
        }
        
        // 현재 사이클 ID를 로컬 변수에 저장 (클로저 캡처용)
        let cycleId = self.currentCycleId
        
        // 디스패치 그룹 생성
        let dispatchGroup = DispatchGroup()
        var allBayStatuses: [[ChargingBayStatus]] = []
        
        // 모든 충전기 확인
        for (index, client) in chargerClients.enumerated() {
            dispatchGroup.enter()
            
            // DeviceClient의 queryBayStatus 메서드 사용
            client.queryBayStatus { bayStatuses in
                allBayStatuses.append(bayStatuses)
                
                SSCLogger.log("충전기 \(index+1) 상태 확인 완료: \(bayStatuses.count)개의 베이",
                             category: .battery, level: .debug)
                             
                dispatchGroup.leave()
            }
        }
        
        // 모든 충전기 확인 완료 후 처리
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self, cycleId == self.currentCycleId else { return }
            
            // 베이 상태 업데이트
            if !allBayStatuses.isEmpty {
                // 모든 충전기의 베이 정보 병합
                var mergedBayStatuses: [ChargingBayStatus] = []
                for bayArray in allBayStatuses {
                    mergedBayStatuses.append(contentsOf: bayArray)
                }
                self.chargingBayStatuses = mergedBayStatuses
                
                // 중복되지 않은 베이만 로그 출력
                for (index, bay) in mergedBayStatuses.enumerated() {
                    if bay.hasDevice && !self.loggedBayIds.contains(index) {
                        SSCLogger.logBatteryStatus(
                            deviceName: "베이 \(index+1) (\(bay.deviceType))",
                            level: bay.batteryPercentage,
                            isCharging: true
                        )
                        // 로그 출력 추적
                        self.loggedBayIds.insert(index)
                    }
                }
            }
            
            // 수신기 확인 진행
            self.updateMicStatuses()
        }
    }
    
    /// 수신기 마이크 상태 확인
    private func updateMicStatuses() {
        // 연결된 수신기가 없으면 사이클 완료
        if receiverClients.isEmpty {
            finishCycle(true)
            return
        }
        
        // 현재 사이클 ID를 로컬 변수에 저장 (클로저 캡처용)
        let cycleId = self.currentCycleId
        
        // 디스패치 그룹 생성
        let dispatchGroup = DispatchGroup()
        var allMicStatuses: [[MicStatus]] = []
        
        // 모든 수신기 확인
        for (index, client) in receiverClients.enumerated() {
            dispatchGroup.enter()
            
            // 마이크 상태 배열
            var micStatuses: [MicStatus] = []
            
            // 마이크 1 (rx1) 확인
            let dispatchGroupMic = DispatchGroup()
            
            // 마이크 1 상태 확인 - DeviceClient의 queryMicStatus 메서드 사용
            dispatchGroupMic.enter()
            client.queryMicStatus(channel: 1) { status in
                if let status = status {
                    micStatuses.append(status)
                } else {
                    micStatuses.append(MicStatus.empty(id: 0))
                }
                dispatchGroupMic.leave()
            }
            
            // 마이크 2 (rx2) 확인 - DeviceClient의 queryMicStatus 메서드 사용
            dispatchGroupMic.enter()
            client.queryMicStatus(channel: 2) { status in
                if let status = status {
                    micStatuses.append(status)
                } else {
                    micStatuses.append(MicStatus.empty(id: 1))
                }
                dispatchGroupMic.leave()
            }
            
            // 모든 마이크 확인 완료
            dispatchGroupMic.notify(queue: .main) {
                // 결과 저장
                allMicStatuses.append(micStatuses)
                
                SSCLogger.log("수신기 \(index+1) 상태 확인 완료: \(micStatuses.count)개의 마이크",
                             category: .info, level: .debug)
                             
                dispatchGroup.leave()
            }
        }
        
        // 모든 수신기 확인 완료 후 처리
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self, cycleId == self.currentCycleId else { return }
            
            // 마이크 상태 처리
            var newMicStatuses: [MicStatus] = []
            
            // 모든 수신기의 모든 마이크 병합
            for micArray in allMicStatuses {
                newMicStatuses.append(contentsOf: micArray)
            }
            
            // 임시 배열 정리
            allMicStatuses.removeAll()
            
            // 최종 마이크 상태 처리
            let finalMicStatuses = self.processMicStatuses(newMicStatuses)
            // 마이크 이름 순으로 정렬
            self.micStatuses = finalMicStatuses.sorted { $0.name < $1.name }
            self.lastKnownMicStates = finalMicStatuses
            
            // 중복되지 않은 마이크만 로그 출력
            for mic in finalMicStatuses {
                if mic.batteryPercentage > 0 && !self.loggedMicIds.contains(mic.id) {
                    SSCLogger.logBatteryStatus(
                        deviceName: mic.name,
                        level: mic.batteryPercentage,
                        isCharging: mic.state == .charging
                    )
                    
                    // 로그 출력 추적
                    self.loggedMicIds.insert(mic.id)
                }
            }
            
            // 사이클 완료
            self.finishCycle(true)
        }
    }
    
    /// 마이크 상태 처리 - 충전기와 수신기 정보 병합
    private func processMicStatuses(_ newStatuses: [MicStatus]) -> [MicStatus] {
        // 현재 가지고 있는 마이크 상태들의 복사본 생성
        var finalStatuses = self.micStatuses
        
        // 마이크 ID 목록 생성 (기존 마이크 + 새로 수신된 마이크)
        var allMicIds = Set<Int>()
        
        // 기존 마이크 ID 추가
        for mic in finalStatuses {
            allMicIds.insert(mic.id)
        }
        
        // 새로 수신된 마이크 ID 추가
        for mic in newStatuses {
            allMicIds.insert(mic.id)
        }
        
        // 충전 베이 상태 가져오기
        let chargingBays = self.chargingBayStatuses
        
        // 각 마이크에 대해 상태 확인
        for micId in allMicIds {
            // 해당 ID의 마이크가 finalStatuses에 없으면 추가
            let micIndex = finalStatuses.firstIndex { $0.id == micId }
            if micIndex == nil {
                finalStatuses.append(MicStatus.empty(id: micId))
            }
            
            // 현재 마이크 인덱스 가져오기
            guard let currentMicIndex = finalStatuses.firstIndex(where: { $0.id == micId }) else {
                continue
            }
            
            // 1. 먼저 충전기에서 마이크 확인
            var foundInCharger = false
            
            // 충전 베이 확인
            for bay in chargingBays {
                if bay.hasDevice && bay.id == micId {
                    // 충전기에 마이크가 있으면 충전 중 상태로 설정
                    var micStatus = finalStatuses[currentMicIndex]
                    micStatus.state = .charging
                    micStatus.batteryPercentage = bay.batteryPercentage
                    micStatus.name = "마이크 \(micId+1)"
                    micStatus.sourceDevice = bay.sourceDevice
                    
                    // 마이크 상태 업데이트
                    finalStatuses[currentMicIndex] = micStatus
                    foundInCharger = true
                    break
                }
            }
            
            if foundInCharger {
                continue // 다음 마이크로
            }
            
            // 2. 수신기에서 마이크 확인
            let matchingMics = newStatuses.filter { $0.id == micId }
            if let activeMic = matchingMics.first, activeMic.batteryPercentage > 0 {
                // 수신기에서 마이크를 찾았고 배터리 정보가 있으면 활성 상태로 설정
                var micStatus = activeMic
                micStatus.state = .active
                
                // 배터리 런타임 검사: 유효하지 않은 값(0 또는 음수)이면 이전 저장값 사용
                if micStatus.batteryRuntime <= 0 {
                    // 이전 저장값이 있으면 사용
                    let previousMic = self.lastKnownMicStates.first { $0.id == micId }
                    if let previous = previousMic, previous.batteryRuntime > 0 {
                        micStatus.batteryRuntime = previous.batteryRuntime
                    }
                }
                
                finalStatuses[currentMicIndex] = micStatus
            } else {
                // 3. 어디에서도 마이크를 찾지 못한 경우
                // 이전에 알려진 상태가 있으면 배터리 정보 유지하며 disconnected 상태로 변경
                let previousMic = self.lastKnownMicStates.first { $0.id == micId }
                if let previous = previousMic, previous.batteryPercentage > 0 {
                    var micStatus = previous
                    micStatus.state = .disconnected
                    micStatus.signalStrength = 0
                    micStatus.batteryRuntime = 0
                    finalStatuses[currentMicIndex] = micStatus
                } else {
                    // 이전 상태도 없으면 완전히 빈 상태로 설정
                    finalStatuses[currentMicIndex] = MicStatus.empty(id: micId)
                }
            }
        }
        
        return finalStatuses
    }
    
    // MARK: - 공개 메소드
    
    /// 충전기 베이 상태 확인 (독립적으로 호출 가능)
    func checkChargingBays() {
        // 이미 사이클이 진행 중이면 무시
        guard !isUpdating else {
            return
        }
        
        // 임시 사이클 시작 - 실제 사이클 카운트는 증가시키지 않음
        isUpdating = true
        let tempCycleId = -999 // 임시 ID (실제 사이클과 구분)
        currentCycleId = tempCycleId
        
        // 로그 추적 초기화
        loggedBayIds.removeAll()
        loggedMicIds.removeAll()
        
        // 상태 업데이트 (완료 콜백에서 스스로 종료)
        updateChargingBays()
    }
    
    /// 충전기 목록 가져오기
    func getChargers() -> [DeviceInfo] {
        return chargerClients.map { $0.deviceInfo }
    }
    
    /// 수신기 목록 가져오기
    func getReceivers() -> [DeviceInfo] {
        return receiverClients.map { $0.deviceInfo }
    }
}

