//
//  DeviceManagerWindowController.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Cocoa
import SwiftUI

// MARK: - 장치 관리 윈도우 컨트롤러
class DeviceManagerWindowController: NSWindowController {
    // 싱글턴 인스턴스 추가
    static private var sharedInstance: DeviceManagerWindowController?
    
    private var deviceListViewController: DeviceListViewController?
    
    override var windowNibName: String? {
        return nil
    }
    
    // 싱글턴 메서드 추가 - 공유 인스턴스 반환
    static func shared() -> DeviceManagerWindowController {
        if sharedInstance == nil {
            sharedInstance = DeviceManagerWindowController()
        }
        return sharedInstance!
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EW-DX 장치 관리"
        window.center()
        window.minSize = NSSize(width: 600, height: 350) // 최소 창 크기 설정
        window.setFrameAutosaveName("DeviceManagerWindow") // 창 크기/위치 자동 저장
        
        self.init(window: window)
        
        let viewController = DeviceListViewController()
        window.contentViewController = viewController
        self.deviceListViewController = viewController
        
        // 창이 닫힐 때 싱글턴 인스턴스 제거를 위한 대리자 설정
        window.delegate = self
    }
    
    func loadDevices() {
        deviceListViewController?.loadDevices()
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
extension DeviceManagerWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 창이 닫힐 때 싱글턴 인스턴스 제거
        if let closingWindow = notification.object as? NSWindow,
           closingWindow == self.window {
            DeviceManagerWindowController.sharedInstance = nil
        }
    }
}
