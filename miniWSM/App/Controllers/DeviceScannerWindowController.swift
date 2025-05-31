//
//  DeviceScannerWindowController.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Cocoa

// MARK: - 장치 스캔 윈도우 컨트롤러
class DeviceScannerWindowController: NSWindowController {
    // 싱글턴 인스턴스 추가
    static private var sharedInstance: DeviceScannerWindowController?
    
    private var scanResults: [DeviceInfo] = []
    private var viewController: DeviceScannerViewController?
    private var isScanning: Bool = false
    
    override var windowNibName: String? {
        return nil
    }
    
    // 싱글턴 메서드 추가 - 공유 인스턴스 반환
    static func shared() -> DeviceScannerWindowController {
        if sharedInstance == nil {
            sharedInstance = DeviceScannerWindowController()
        }
        return sharedInstance!
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EW-DX 장치 스캔"
        window.center()
        window.minSize = NSSize(width: 600, height: 400) // 최소 창 크기 설정
        window.setFrameAutosaveName("DeviceScannerWindow") // 창 크기/위치 자동 저장
        
        self.init(window: window)
        
        let viewController = DeviceScannerViewController()
        window.contentViewController = viewController
        self.viewController = viewController
        
        // 창 닫을 때 스캔 중지를 위한 윈도우 대리자 설정
        window.delegate = self
    }
    
    func startScan() {
        isScanning = true
        viewController?.startScan()
    }
    
    func stopScan() {
        if isScanning {
            viewController?.stopScan()
            isScanning = false
        }
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // 창을 확실히 앞으로 표시하기 위해 세 가지 메서드 모두 호출
        window?.makeKeyAndOrderFront(sender)
        window?.orderFrontRegardless() // 앱이 비활성화된 상태에서도 항상 앞으로 오도록 함
        NSApp.activate(ignoringOtherApps: true) // 다른 앱이 활성화된 경우에도 우리 앱을 활성화
    }
}

// MARK: - NSWindowDelegate 확장
extension DeviceScannerWindowController: NSWindowDelegate {
    // 창이 닫히기 전에 호출
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow,
           closingWindow == self.window {
            print("스캔 창이 닫힙니다. 스캔 중지...")
            stopScan()
            
            // 싱글턴 인스턴스 제거
            DeviceScannerWindowController.sharedInstance = nil
        }
    }
}
