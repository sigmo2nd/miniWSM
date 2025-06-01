//
//  AppDelegate.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Cocoa
import SwiftUI
import Combine

// MARK: - 앱 델리게이트
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var popover: NSPopover?
    var deviceStatusMonitor: DeviceStatusMonitor?
    private var cancellables = Set<AnyCancellable>()
    
    // 현재 시간을 문자열로 반환하는 함수
    private func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        SSCLogger.log("앱 실행 시작", category: .info)
        
        // 디바이스 모니터링 시작
        deviceStatusMonitor = DeviceStatusMonitor()
        
        // 팝오버 생성
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 450)
        popover.behavior = .transient
        
        // SwiftUI 뷰 설정
        let contentView = PopoverView(monitor: deviceStatusMonitor!)
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // 상태바 컨트롤러 생성
        statusBarController = StatusBarController(popover: popover, monitor: deviceStatusMonitor!)
        
        // 테스트 메뉴 설정 불러오기
        let showTestMenu = UserDefaults.standard.bool(forKey: "showTestMenu")
        if !showTestMenu {
            // 기본값이 false면 저장
            UserDefaults.standard.set(false, forKey: "showTestMenu")
        }
        
        // 모니터링 시작
        deviceStatusMonitor?.startMonitoring()
        
        // 설정 변경 구독
        setupSettingsSubscriptions()
        
        // 처음 실행 시 최소한 하나 이상의 장치가 등록되어 있는지 확인
        let hasDevices = !DeviceManager.shared.getRegisteredDevices().isEmpty
        
        // 등록된 장치가 없는 경우에만 프롬프트 표시
        if !hasDevices {
            SSCLogger.log("초기 장치 설정 필요", category: .info)
            promptForDeviceRegistration()
        }
    }
    
    private var isHandlingSettingsChange = false
    
    private func setupSettingsSubscriptions() {
        // 장치 목록 변경 구독만 활성화
        DeviceManager.shared.deviceListPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                SSCLogger.log("장치 목록 변경 감지", category: .debug, level: .verbose)
                self?.handleSettingsChanged()
            }
            .store(in: &cancellables)
        
        // UserDefaults와 SettingsChanged 알림은 임시로 비활성화
        // 무한 루프를 일으킬 가능성이 있음
    }
    
    private func handleSettingsChanged() {
        // 이미 설정 변경을 처리 중이면 무시
        guard !isHandlingSettingsChange else {
            SSCLogger.log("설정 변경 처리 중 - 중복 호출 무시", category: .debug, level: .verbose)
            return
        }
        
        SSCLogger.log("설정 변경 감지", category: .info)
        
        // 배터리 시뮬레이션 중이면 설정 변경 무시
        if statusBarController?.batterySimulationActive ?? false {
            return
        }
        
        // 재진입 방지 플래그 설정
        isHandlingSettingsChange = true
        
        // 모니터링 재시작을 메인 큐에서 실행
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 모니터링 재시작
            self.deviceStatusMonitor?.stopMonitoring()
            self.deviceStatusMonitor = DeviceStatusMonitor()
            self.deviceStatusMonitor?.startMonitoring()
            
            // 팝오버 뷰 업데이트
            if let popover = self.popover, let monitor = self.deviceStatusMonitor {
                let contentView = PopoverView(monitor: monitor)
                popover.contentViewController = NSHostingController(rootView: contentView)
            }
            
            // 상태바 컨트롤러의 monitor 참조 업데이트
            if let statusBarController = self.statusBarController, let monitor = self.deviceStatusMonitor {
                statusBarController.updateMonitor(monitor)
            }
            
            // 처리 완료 후 플래그 해제
            self.isHandlingSettingsChange = false
        }
    }
    
    func promptForDeviceRegistration() {
        let alert = NSAlert()
        alert.messageText = "장치 설정"
        alert.informativeText = "EW-DX 장치를 등록하시겠습니까?"
        alert.addButton(withTitle: "네, 장치 등록")
        alert.addButton(withTitle: "나중에")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openDeviceManager()
        }
    }
    
    func openDeviceManager() {
        // 싱글톤 인스턴스를 사용하도록 수정
        let manager = DeviceManagerWindowController.shared()
        manager.window?.makeKeyAndOrderFront(nil) // 창이 확실히 앞으로 오도록 강제
        manager.showWindow(nil)
        manager.loadDevices()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        SSCLogger.log("앱 종료 중", category: .info)
        
        // 앱 종료 시 정리
        deviceStatusMonitor?.stopMonitoring()
        
        // 시뮬레이션 타이머 정리
        statusBarController?.stopBatterySimulation()
        
        // 구독 취소
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - 배터리 시뮬레이션 관련 메서드 - StatusBarController에 위임
    
    // 배터리 시뮬레이션 토글 - StatusBarController에 위임
    @objc public func toggleBatterySimulation() {
        statusBarController?.toggleBatterySimulation()
    }
    
    // 메뉴에서 배터리 레벨 설정 - StatusBarController에 위임
    @objc public func setBatteryLevelFromMenu(_ sender: NSMenuItem) {
        statusBarController?.setBatteryLevel(sender.tag)
    }
    
    // 충전 상태 토글 - StatusBarController에 위임
    @objc public func toggleChargingState() {
        statusBarController?.toggleChargingState()
    }
}
