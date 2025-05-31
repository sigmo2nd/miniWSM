////
////  BatteryTestManager.swift
////  miniWSM
////
////  Created by Sieg on 4/27/25.
////
//
//import Cocoa
//import Combine
//
//// MARK: - 배터리 테스트 매니저
//class BatteryTestManager {
//    // 싱글톤 인스턴스
//    static let shared = BatteryTestManager()
//    
//    // 테스트 모드 활성화 여부
//    private(set) var isTestModeActive = false
//    
//    // 테스트 배터리 레벨 (0-100)
//    private var testBatteryLevel: Int = 95
//    
//    // 배터리 감소 타이머
//    private var batteryDecreaseTimer: Timer?
//    
//    // 타이머 간격 (초)
//    private let timerInterval: TimeInterval = 3.0
//    
//    // 배터리 감소량 (%)
//    private let decreaseAmount: Int = 5
//    
//    // 테스트 모드에서 사용할 마이크 상태
//    private var testMicStatuses: [MicStatus] = []
//    
//    // 구독 취소를 위한 저장소
//    private var cancellables = Set<AnyCancellable>()
//    
//    // 상태 변경 발행자
//    private let testStatusSubject = PassthroughSubject<[MicStatus], Never>()
//    var testStatusPublisher: AnyPublisher<[MicStatus], Never> {
//        return testStatusSubject.eraseToAnyPublisher()
//    }
//    
//    // 모드 변경 발행자
//    private let testModeSubject = PassthroughSubject<Bool, Never>()
//    var testModePublisher: AnyPublisher<Bool, Never> {
//        return testModeSubject.eraseToAnyPublisher()
//    }
//    
//    // 현재 시간을 문자열로 반환하는 함수
//    private func currentTimeString() -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "HH:mm:ss.SSS"
//        return formatter.string(from: Date())
//    }
//    
//    private init() {
//        // 초기 테스트 마이크 상태 설정
//        setupTestMicStatuses()
//    }
//    
//    deinit {
//        stopBatteryDecrease()
//        cancellables.forEach { $0.cancel() }
//    }
//    
//    // 초기 테스트 마이크 상태 설정
//    private func setupTestMicStatuses() {
//        // 마이크 1: 정상 상태, 95% 배터리
//        let mic1 = MicStatus(
//            id: 0,
//            name: "마이크 1",
//            batteryPercentage: testBatteryLevel,
//            signalStrength: 85,
//            batteryRuntime: 320,
//            warning: false,
//            state: .active
//        )
//        
//        // 마이크 2: 충전 중, 65% 배터리
//        let mic2 = MicStatus(
//            id: 1,
//            name: "마이크 2",
//            batteryPercentage: 65,
//            signalStrength: 0,
//            batteryRuntime: 0,
//            warning: false,
//            state: .charging
//        )
//        
//        testMicStatuses = [mic1, mic2]
//    }
//    
//    // 테스트 모드 토글
//    func toggleTestMode() {
//        isTestModeActive = !isTestModeActive
//        
//        print("\(currentTimeString()) 🧪 배터리 테스트 모드: \(isTestModeActive ? "활성화" : "비활성화")")
//        
//        if isTestModeActive {
//            startBatteryDecrease()
//        } else {
//            stopBatteryDecrease()
//            // 초기 상태로 리셋
//            testBatteryLevel = 95
//            setupTestMicStatuses()
//        }
//        
//        // 상태 변경 알림
//        testModeSubject.send(isTestModeActive)
//        testStatusSubject.send(testMicStatuses)
//    }
//    
//    // 충전 상태 토글
//    func toggleChargingState() {
//        guard isTestModeActive else { return }
//        
//        print("\(currentTimeString()) 🔌 충전 상태 토글")
//        
//        if var mic1 = testMicStatuses.first(where: { $0.id == 0 }) {
//            // 상태 토글
//            mic1.state = mic1.state == .charging ? .active : .charging
//            
//            // 충전 중이면 배터리 런타임 0으로 설정
//            if mic1.state == .charging {
//                mic1.batteryRuntime = 0
//                mic1.signalStrength = 0
//            } else {
//                mic1.batteryRuntime = testBatteryLevel * 4
//                mic1.signalStrength = 85
//            }
//            
//            // 업데이트된 상태 반영
//            if let index = testMicStatuses.firstIndex(where: { $0.id == 0 }) {
//                testMicStatuses[index] = mic1
//            }
//            
//            // 상태 변경 알림
//            testStatusSubject.send(testMicStatuses)
//        }
//    }
//    
//    // 배터리 감소 시작
//    private func startBatteryDecrease() {
//        // 기존 타이머 중지
//        stopBatteryDecrease()
//        
//        print("\(currentTimeString()) ⏱️ 배터리 감소 타이머 시작 (간격: \(timerInterval)초)")
//        
//        // 새 타이머 시작
//        batteryDecreaseTimer = Timer.scheduledTimer(
//            timeInterval: timerInterval,
//            target: self,
//            selector: #selector(decreaseBattery),
//            userInfo: nil,
//            repeats: true
//        )
//    }
//    
//    // 배터리 감소 중지
//    private func stopBatteryDecrease() {
//        if batteryDecreaseTimer != nil {
//            print("\(currentTimeString()) ⏱️ 배터리 감소 타이머 중지")
//        }
//        
//        batteryDecreaseTimer?.invalidate()
//        batteryDecreaseTimer = nil
//    }
//    
//    // 배터리 레벨 수동 설정
//    func setTestBatteryLevel(_ level: Int) {
//        let oldLevel = testBatteryLevel
//        testBatteryLevel = min(100, max(0, level))
//        
//        print("\(currentTimeString()) 🔋 배터리 레벨 설정: \(oldLevel)% → \(testBatteryLevel)%")
//        
//        updateTestMicStatus()
//    }
//    
//    // 배터리 감소 처리
//    @objc private func decreaseBattery() {
//        // 활성 상태인 마이크만 배터리 감소
//        let oldLevel = testBatteryLevel
//        testBatteryLevel = max(0, testBatteryLevel - decreaseAmount)
//        
//        print("\(currentTimeString()) 🔋 배터리 감소: \(oldLevel)% → \(testBatteryLevel)%")
//        
//        // 마이크 상태 업데이트
//        updateTestMicStatus()
//        
//        // 배터리가 0이 되면 타이머 중지
//        if testBatteryLevel <= 0 {
//            print("\(currentTimeString()) 🪫 배터리 방전됨, 타이머 중지")
//            stopBatteryDecrease()
//        }
//    }
//    
//    // 테스트 마이크 상태 업데이트
//    private func updateTestMicStatus() {
//        // 마이크 1 (활성 상태) 업데이트
//        if var mic1 = testMicStatuses.first(where: { $0.id == 0 }) {
//            mic1.batteryPercentage = testBatteryLevel
//            
//            // 충전 중이 아닐 때만 런타임과 신호 강도 업데이트
//            if mic1.state != .charging {
//                // 배터리 런타임 업데이트 (배터리 퍼센트에 비례)
//                mic1.batteryRuntime = testBatteryLevel * 4 // 100%일 때 약 6.6시간 (400분)
//                mic1.signalStrength = 85
//                
//                // 배터리 20% 이하일 때 경고 표시
//                mic1.warning = testBatteryLevel <= 20
//                
//                // 배터리 0%일 때 연결 해제 상태로 변경
//                if testBatteryLevel <= 0 {
//                    print("\(currentTimeString()) 🔌 마이크 연결 해제됨 (배터리 방전)")
//                    mic1.state = .disconnected
//                    mic1.batteryRuntime = 0
//                    mic1.signalStrength = 0
//                }
//            }
//            
//            // 업데이트된 상태 반영
//            if let index = testMicStatuses.firstIndex(where: { $0.id == 0 }) {
//                testMicStatuses[index] = mic1
//            }
//        }
//        
//        // 상태 변경 알림
//        testStatusSubject.send(testMicStatuses)
//    }
//    
//    // 테스트 마이크 상태 가져오기
//    func getTestMicStatuses() -> [MicStatus] {
//        return testMicStatuses
//    }
//}
//
//// MARK: - DeviceStatusMonitor 확장
//extension DeviceStatusMonitor {
//    // 테스트 데이터로 업데이트
//    func updateWithTestData(_ testMicStatuses: [MicStatus]) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            // 테스트 마이크 상태로 업데이트
//            self.micStatuses = testMicStatuses
//            
//            // 경고 상태 확인
//            let hasWarnings = testMicStatuses.contains { $0.warning }
//            
//            // UI 업데이트
//            self.objectWillChange.send()
//            
//            // 상태바 업데이트
//            if let controller = (NSApp.delegate as? AppDelegate)?.statusBarController {
//                controller.updateWithTestData(testMicStatuses, warning: hasWarnings)
//            }
//        }
//    }
//    
//    // 테스트 모드 구독 설정
//    func setupTestModeSubscription() {
//        let testManager = BatteryTestManager.shared
//        
//        // 테스트 상태 구독
//        testManager.testStatusPublisher
//            .sink { [weak self] micStatuses in
//                if testManager.isTestModeActive {
//                    self?.updateWithTestData(micStatuses)
//                }
//            }
//            .store(in: &cancellables)
//        
//        // 테스트 모드 변경 구독
//        testManager.testModePublisher
//            .sink { [weak self] isActive in
//                if isActive {
//                    // 테스트 모드 활성화
//                    self?.updateWithTestData(testManager.getTestMicStatuses())
//                } else {
//                    // 테스트 모드 비활성화 시 일반 모니터링 재개
//                    self?.startMonitoring()
//                }
//            }
//            .store(in: &cancellables)
//    }
//}
