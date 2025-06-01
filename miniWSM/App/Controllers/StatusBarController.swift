//
//  StatusBarController.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Cocoa
import SwiftUI
import Combine

// MARK: - 상태바 컨트롤러
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var monitor: DeviceStatusMonitor
    var customView: StatusBarView?
    private var cancellables = Set<AnyCancellable>()
    
    // 테스트 메뉴 표시 여부
    private var showTestMenu = false
    
    // 배터리 시뮬레이션 관련 변수
    var batterySimulationActive = false // 접근자 추가
    private var simulationTimer: Timer?
    private var simulationLevel = 100
    private var simulationMicStatuses: [MicStatus] = []
    
    // 현재 시간을 문자열로 반환하는 함수
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    init(popover: NSPopover, monitor: DeviceStatusMonitor) {
        self.popover = popover
        self.monitor = monitor
        
        // 상태바 아이템 생성 - 가변 길이로 설정
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 커스텀 뷰 설정
        configureStatusBarView()
        
        // 테스트 메뉴 표시 상태 로드
        showTestMenu = UserDefaults.standard.bool(forKey: "showTestMenu")
        
        // 메뉴 설정
        configureMenu()
        
        // 상태 업데이트 구독
        setupBindings()
        
        // 초기 시뮬레이션 마이크 상태 설정
        setupSimulationMicStatuses()
        
        // 테스트 메뉴 토글 알림 구독
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTestMenuToggled(_:)),
            name: NSNotification.Name("TestMenuToggled"),
            object: nil
        )
    }
    
    deinit {
        // 알림 관찰자 제거
        NotificationCenter.default.removeObserver(self)
        simulationTimer?.invalidate()
        simulationTimer = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // 모니터 참조 업데이트 (설정 변경 시 사용)
    func updateMonitor(_ newMonitor: DeviceStatusMonitor) {
        // 기존 구독 취소
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // 새 모니터로 교체
        monitor = newMonitor
        
        // 바인딩 재설정
        setupBindings()
    }
    
    // 테스트 메뉴 토글 처리 메소드
    @objc func handleTestMenuToggled(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let showMenu = userInfo["showTestMenu"] as? Bool {
            // 테스트 메뉴 표시 상태 업데이트
            showTestMenu = showMenu
            
            // 메뉴만 재구성 (statusItem은 그대로 유지)
            DispatchQueue.main.async { [weak self] in
                self?.configureMenu()
            }
        }
    }
    
    private func setupBindings() {
        // 마이크 상태 변경 구독
        monitor.$micStatuses
            .receive(on: RunLoop.main)
            .sink { [weak self] micStatuses in
                guard let self = self, let customView = self.customView else { return }
                
                // 시뮬레이션 모드에서는 업데이트 무시
                if self.batterySimulationActive {
                    return
                }
                
                // 경고 상태 계산
                let hasWarning = micStatuses.contains { $0.warning }
                
                // 사이클 성공 여부 확인
                let hasError = !(self.monitor.lastCycleSuccessful)
                
                // 상태바 뷰 업데이트
                customView.update(with: micStatuses, warning: hasWarning, error: hasError)
            }
            .store(in: &cancellables)
    }
    
    private func configureStatusBarView() {
        guard let button = statusItem.button else { return }
        
        // 버튼의 기본 이미지 제거
        button.image = nil
        
        // 커스텀 뷰 생성
        let statusBarView = StatusBarView(frame: button.bounds)
        statusBarView.autoresizingMask = [.width, .height] // 자동 리사이징 설정
        
        // 버튼에 커스텀 뷰 추가
        button.subviews.forEach { $0.removeFromSuperview() } // 기존 서브뷰 제거
        button.frame.size.height = 20
        button.addSubview(statusBarView)
        
        // 버튼 설정 - 우클릭과 좌클릭 모두 처리
        button.action = #selector(handleButtonClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // 커스텀 뷰 참조 저장
        self.customView = statusBarView
    }
    
    private func configureMenu() {
        // 메뉴 생성
        let menu = NSMenu()
        
        // 장치 관리 메뉴 추가
        let deviceManagerItem = NSMenuItem(title: "장치 관리", action: #selector(openDeviceManager), keyEquivalent: "d")
        deviceManagerItem.target = self
        menu.addItem(deviceManagerItem)
        
        // 구분선 추가
        menu.addItem(NSMenuItem.separator())
        
        // 테스트 메뉴들 - showTestMenu가 true일 때만 표시
        if showTestMenu {
            // 배터리 시뮬레이션 토글
            let toggleSimulationItem = NSMenuItem(title: "배터리 시뮬레이션", action: #selector(toggleBatterySimulation), keyEquivalent: "b")
            toggleSimulationItem.target = self
            menu.addItem(toggleSimulationItem)
            
            // 충전 상태 토글
            let toggleChargingItem = NSMenuItem(title: "충전 상태 변경", action: #selector(toggleChargingState), keyEquivalent: "c")
            toggleChargingItem.target = self
            menu.addItem(toggleChargingItem)
            
            // 배터리 레벨 설정 하위메뉴
            let batteryLevelsMenu = NSMenu()
            let batteryLevelsItem = NSMenuItem(title: "배터리 레벨 설정", action: nil, keyEquivalent: "")
            batteryLevelsItem.submenu = batteryLevelsMenu
            
            // 각 배터리 레벨에 대한 메뉴 항목 추가
            for level in stride(from: 0, through: 100, by: 10) {
                let levelItem = NSMenuItem(title: "\(level)%", action: #selector(setBatteryLevelFromMenu(_:)), keyEquivalent: "")
                levelItem.tag = level
                levelItem.target = self
                batteryLevelsMenu.addItem(levelItem)
            }
            
            menu.addItem(batteryLevelsItem)
            
            // 구분선 추가
            menu.addItem(NSMenuItem.separator())
        }
        
        // 앱 종료 메뉴
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        // 상태바 아이템에 메뉴 할당
        statusItem.menu = menu
        
        SSCLogger.log("메뉴 설정 완료 (테스트 메뉴 \(showTestMenu ? "표시" : "숨김"))", category: .info, level: .debug)
    }
    
    @objc func handleButtonClick(_ sender: NSStatusBarButton) {
        // 현재 이벤트 가져오기
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // 우클릭은 메뉴 표시
            statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: sender)
        } else {
            // 좌클릭은 팝오버 표시/숨김
            togglePopover(sender)
        }
    }
    
    // MARK: - 배터리 시뮬레이션 관련 메서드
    
    // 시뮬레이션 마이크 상태 초기화
    private func setupSimulationMicStatuses() {
        // 마이크 1: 일반 상태
        let mic1 = MicStatus(
            id: 0,
            name: "마이크 1",
            batteryPercentage: 100,
            signalStrength: 85,
            batteryRuntime: 360, // 6시간
            warning: false,
            state: .active
        )
        
        // 마이크 2: 충전 중 상태
        let mic2 = MicStatus(
            id: 1,
            name: "마이크 2",
            batteryPercentage: 65,
            signalStrength: 0,
            batteryRuntime: 0,
            warning: false,
            state: .charging
        )
        
        simulationMicStatuses = [mic1, mic2]
    }
    
    // 배터리 시뮬레이션 토글
    @objc func toggleBatterySimulation() {
        SSCLogger.log("배터리 시뮬레이션 토글", category: .battery)
        batterySimulationActive = !batterySimulationActive
        
        if batterySimulationActive {
            // 시뮬레이션 시작
            startBatterySimulation()
        } else {
            // 시뮬레이션 중지
            stopBatterySimulation()
            
            // 일반 모니터링으로 복귀
            monitor.startMonitoring()
        }
    }
    
    // 배터리 시뮬레이션 시작
    private func startBatterySimulation() {
        SSCLogger.log("배터리 시뮬레이션 시작", category: .battery)
        
        // 일반 모니터링 중지
        monitor.stopMonitoring()
        
        // 시뮬레이션 초기화
        simulationLevel = 100
        setupSimulationMicStatuses()
        
        // 상태바 업데이트
        updateSimulationStatus()
        
        // 타이머 시작 (3초마다 배터리 5% 감소)
        simulationTimer = Timer.scheduledTimer(
            timeInterval: 3.0,
            target: self,
            selector: #selector(decreaseBatteryLevel),
            userInfo: nil,
            repeats: true
        )
    }
    
    // 배터리 시뮬레이션 중지
    func stopBatterySimulation() {
        SSCLogger.log("배터리 시뮬레이션 중지", category: .battery)
        
        // 타이머 중지 및 정리
        simulationTimer?.invalidate()
        simulationTimer = nil
        batterySimulationActive = false
        
        // 시뮬레이션 데이터 정리
        simulationMicStatuses.removeAll()
    }
    
    // 배터리 감소 처리
    @objc private func decreaseBatteryLevel() {
        // 배터리 레벨 감소 (5% 단위)
        simulationLevel = max(0, simulationLevel - 5)
        
        SSCLogger.log("시뮬레이션 배터리 감소: \(simulationLevel)%", category: .battery, level: .debug)
        
        // 상태 업데이트
        updateSimulationMicStatus()
        
        // 배터리가 0이 되면 타이머 중지
        if simulationLevel <= 0 {
            simulationTimer?.invalidate()
        }
    }
    
    // 시뮬레이션 마이크 상태 업데이트
    private func updateSimulationMicStatus() {
        // 마이크 1 (활성 상태) 업데이트
        if var mic1 = simulationMicStatuses.first(where: { $0.id == 0 }) {
            // 충전 중이 아닐 때만 배터리 레벨 업데이트
            if mic1.state != .charging {
                mic1.batteryPercentage = simulationLevel
                
                // 배터리 런타임 업데이트 (배터리 퍼센트에 비례)
                mic1.batteryRuntime = simulationLevel * 4 // 100%일 때 약 6.6시간 (400분)
                
                // 배터리 20% 이하일 때 경고 표시
                mic1.warning = simulationLevel <= 20
                
                // 배터리 0%일 때 연결 해제 상태로 변경
                if simulationLevel <= 0 {
                    mic1.state = .disconnected
                    mic1.batteryRuntime = 0
                    mic1.signalStrength = 0
                }
                
                // 업데이트된 상태 반영
                if let index = simulationMicStatuses.firstIndex(where: { $0.id == 0 }) {
                    simulationMicStatuses[index] = mic1
                }
            }
        }
        
        // 상태바 업데이트
        updateSimulationStatus()
    }
    
    // 시뮬레이션 상태 UI 업데이트
    private func updateSimulationStatus() {
        // 경고 상태 확인
        let hasWarning = simulationMicStatuses.contains { $0.warning }
        
        // 상태바 업데이트
        customView?.update(with: simulationMicStatuses, warning: hasWarning, error: false)
        
        // 모니터 객체도 업데이트 (팝오버 표시용)
        monitor.micStatuses = simulationMicStatuses
        monitor.objectWillChange.send()
    }
    
    // 메뉴에서 배터리 레벨 설정 - NSMenuItem용 메서드
    @objc func setBatteryLevelFromMenu(_ sender: NSMenuItem) {
        let level = sender.tag
        setBatteryLevel(level)
    }
    
    // 배터리 레벨 설정 (외부에서 호출 가능)
    func setBatteryLevel(_ level: Int) {
        simulationLevel = level
        
        SSCLogger.log("배터리 레벨 설정: \(level)%", category: .battery)
        
        // 시뮬레이션이 활성화되어 있지 않으면 활성화
        if !batterySimulationActive {
            toggleBatterySimulation()
        } else {
            // 이미 활성화되어 있으면 상태만 업데이트
            updateSimulationMicStatus()
        }
    }
    
    // 충전 상태 토글
    @objc func toggleChargingState() {
        SSCLogger.log("충전 상태 토글 시도", category: .battery)
        
        // 시뮬레이션이 활성화되어 있지 않으면 활성화
        if !batterySimulationActive {
            SSCLogger.log("배터리 시뮬레이션 먼저 활성화", category: .battery)
            toggleBatterySimulation()
        }
        
        // 마이크 1의 충전 상태 토글
        if var mic1 = simulationMicStatuses.first(where: { $0.id == 0 }) {
            // 상태 토글
            mic1.state = mic1.state == .charging ? .active : .charging
            
            // 충전 중이면 배터리 런타임 0으로 설정
            if mic1.state == .charging {
                mic1.batteryRuntime = 0
                mic1.signalStrength = 0
            } else {
                mic1.batteryRuntime = simulationLevel * 4
                mic1.signalStrength = 85
            }
            
            // 업데이트된 상태 반영
            if let index = simulationMicStatuses.firstIndex(where: { $0.id == 0 }) {
                simulationMicStatuses[index] = mic1
            }
            
            SSCLogger.log("충전 상태 토글 완료: \(mic1.state.description)", category: .battery)
            
            // 상태바 업데이트
            updateSimulationStatus()
        }
    }
    
    @objc func openDeviceManager() {
        let manager = DeviceManagerWindowController.shared()
        manager.window?.makeKeyAndOrderFront(nil) // 창이 확실히 앞으로 오도록 강제
        manager.showWindow(nil)
        manager.loadDevices()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    func closePopover() {
        popover.performClose(nil)
    }
}
