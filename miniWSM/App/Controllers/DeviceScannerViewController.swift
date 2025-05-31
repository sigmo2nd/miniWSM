//
//  DeviceScannerViewController.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Cocoa

// MARK: - 장치 스캔 뷰 컨트롤러
class DeviceScannerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var scanButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
    private var scanResults: [DeviceInfo] = []
    private var deviceScanner = DeviceScanner()
    private var selectedDevices: Set<Int> = [] // 선택된 장치 인덱스 추적
    private var isScanning: Bool = false
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 450)) // 창 크기 확대
        setupUI()
    }
    
    private func setupUI() {
        // 스캔 버튼
        scanButton = NSButton(frame: NSRect(x: 20, y: 360, width: 100, height: 24))
        scanButton.title = "스캔 시작"
        scanButton.bezelStyle = .rounded
        scanButton.target = self
        scanButton.action = #selector(startScan)
        view.addSubview(scanButton)
        
        // 진행 표시기
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 130, y: 362, width: 16, height: 16))
        progressIndicator.style = .spinning
        progressIndicator.isDisplayedWhenStopped = false
        view.addSubview(progressIndicator)
        
        // 테이블 뷰 설정
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: view.frame.width - 40, height: 280))
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.autoresizingMask = [.width, .height]
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle // 컬럼 자동 크기 조절
        
        // 컬럼 설정
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("nameColumn"))
        nameColumn.title = "장치 이름"
        nameColumn.width = 180
        nameColumn.minWidth = 120 // 최소 너비 설정
        tableView.addTableColumn(nameColumn)
        
        let ipColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ipColumn"))
        ipColumn.title = "IP 주소"
        ipColumn.width = 140
        ipColumn.minWidth = 100 // 최소 너비 설정
        tableView.addTableColumn(ipColumn)
        
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("typeColumn"))
        typeColumn.title = "유형"
        typeColumn.width = 100
        typeColumn.minWidth = 80 // 최소 너비 설정
        tableView.addTableColumn(typeColumn)
        
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actionColumn"))
        actionColumn.title = "선택"
        actionColumn.width = 120
        actionColumn.minWidth = 100 // 최소 너비 설정
        tableView.addTableColumn(actionColumn)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)
        
        // 등록 버튼
        let registerButton = NSButton(frame: NSRect(x: view.frame.width - 160, y: 20, width: 120, height: 24))
        registerButton.title = "선택 항목 등록"
        registerButton.bezelStyle = .rounded
        registerButton.target = self
        registerButton.action = #selector(registerSelected)
        registerButton.autoresizingMask = .minXMargin
        view.addSubview(registerButton)
        
        // 창 크기가 변경될 때 UI 요소 조정
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowResized),
            name: NSWindow.didResizeNotification,
            object: nil
        )
    }
    
    deinit {
        // 관찰자 제거
        NotificationCenter.default.removeObserver(self)
        // 스캔 중인 경우 중지
        stopScan()
    }
    
    @objc func windowResized() {
        // 창 크기 변경 시 테이블 크기 자동 조정
        tableView.sizeToFit()
    }
    
    @objc func startScan() {
        // 이미 스캔 중이면 중지
        if isScanning {
            stopScan()
            scanButton.title = "스캔 시작"
            progressIndicator.stopAnimation(nil)
            scanButton.isEnabled = true
            return
        }
        
        // 스캔 시작
        isScanning = true
        scanButton.title = "스캔 중지"
        scanButton.isEnabled = true
        progressIndicator.startAnimation(nil)
        selectedDevices.removeAll() // 선택 초기화
        
        // 현재 네트워크 구성에 기반한 IP 범위 결정
        let baseIP = getCurrentBaseIP()
        
        deviceScanner.scanNetwork(baseIP: baseIP) { [weak self] devices in
            DispatchQueue.main.async {
                guard let self = self, self.isScanning else { return }
                
                // 이미 등록된 장치는 별도 표시
                let registeredDevices = DeviceManager.shared.getRegisteredDevices()
                self.scanResults = devices
                
                // 기본적으로 등록되지 않은 장치만 체크
                for (index, device) in self.scanResults.enumerated() {
                    let isAlreadyRegistered = registeredDevices.contains { $0.ipAddress == device.ipAddress }
                    if !isAlreadyRegistered {
                        self.selectedDevices.insert(index)
                    }
                }
                
                self.tableView.reloadData()
                self.scanButton.title = "스캔 시작"
                self.progressIndicator.stopAnimation(nil)
                self.isScanning = false
            }
        }
    }
    
    // 스캔 중지 메서드 추가
    func stopScan() {
        if isScanning {
            deviceScanner.cancelScan()
            isScanning = false
            
            DispatchQueue.main.async {
                self.scanButton.title = "스캔 시작"
                self.progressIndicator.stopAnimation(nil)
                self.scanButton.isEnabled = true
            }
        }
    }
    
    // 현재 네트워크 구성에 기반한 IP 범위 결정
    private func getCurrentBaseIP() -> String {
        // 등록된 장치의 IP를 기준으로 네트워크 범위 추정
        let devices = DeviceManager.shared.getRegisteredDevices()
        if let device = devices.first, !device.ipAddress.isEmpty {
            // IP 주소에서 마지막 숫자를 'x'로 대체
            let components = device.ipAddress.split(separator: ".")
            if components.count == 4 {
                return "\(components[0]).\(components[1]).\(components[2]).x"
            }
        }
        
        // 기본 IP 범위
        return "192.168.0.x"
    }
    
    @objc func registerSelected() {
        // 선택된 장치 등록
        var registeredCount = 0
        var newRegisteredDevices: [DeviceInfo] = []
        
        // 선택된 인덱스 기반으로 장치 등록
        for index in selectedDevices {
            guard index < scanResults.count else { continue }
            
            var device = scanResults[index]
            device.lastSeen = Date() // 현재 시간으로 마지막 연결 시간 업데이트
            DeviceManager.shared.registerDevice(device: device)
            newRegisteredDevices.append(device)
            registeredCount += 1
        }
        
        // 디버그 로그
        for device in newRegisteredDevices {
            print("등록된 장치: \(device.name) (\(device.ipAddress)), 타입: \(device.deviceType.description)")
        }
        
        // 등록 확인 알림
        let alert = NSAlert()
        alert.messageText = "장치 등록 완료"
        alert.informativeText = "\(registeredCount)개의 장치가 등록되었습니다."
        alert.addButton(withTitle: "확인")
        alert.runModal()
        
        // 앱 델리게이트에 설정 변경 알림
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        
        // 창 닫기
        self.view.window?.close()
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return scanResults.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = scanResults[row]
        
        let identifier = tableColumn?.identifier.rawValue ?? ""
        let cellIdentifier = NSUserInterfaceItemIdentifier("\(identifier)Cell")
        
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            if identifier == "actionColumn" {
                let checkBox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleDeviceSelection(_:)))
                checkBox.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
                checkBox.translatesAutoresizingMaskIntoConstraints = false
                
                cell?.addSubview(checkBox)
                
                NSLayoutConstraint.activate([
                    checkBox.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                    checkBox.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            } else {
                let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 100, height: 17))
                textField.isEditable = false
                textField.isBordered = false
                textField.drawsBackground = false
                textField.translatesAutoresizingMaskIntoConstraints = false
                
                cell?.addSubview(textField)
                cell?.textField = textField
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor),
                    textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor),
                    textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
                ])
            }
        }
        
        switch identifier {
        case "nameColumn":
            cell?.textField?.stringValue = device.name
        case "ipColumn":
            cell?.textField?.stringValue = device.ipAddress
        case "typeColumn":
            cell?.textField?.stringValue = device.deviceType.description
        case "actionColumn":
            // 이미 등록된 장치인지 확인
            let isRegistered = DeviceManager.shared.getRegisteredDevices().contains { $0.ipAddress == device.ipAddress }
            
            if let checkBox = cell?.subviews.first as? NSButton {
                // 체크박스 태그 설정 (행 번호 저장)
                checkBox.tag = row
                
                // 현재 선택 상태에 따라 체크박스 상태 설정
                checkBox.state = selectedDevices.contains(row) ? .on : .off
                
                // 이미 등록된 장치는 비활성화하고 제목 설정
                if isRegistered {
                    checkBox.isEnabled = false
                    checkBox.title = " (등록됨)"
                } else {
                    checkBox.isEnabled = true
                    checkBox.title = ""
                }
            }
        default:
            cell?.textField?.stringValue = ""
        }
        
        return cell
    }
    
    // 체크박스 토글 처리
    @objc func toggleDeviceSelection(_ sender: NSButton) {
        let row = sender.tag
        
        if sender.state == .on {
            selectedDevices.insert(row)
        } else {
            selectedDevices.remove(row)
        }
        
        // 디버그 로그
        print("장치 선택 변경: 행=\(row), 선택됨=\(sender.state == .on), IP=\(scanResults[row].ipAddress)")
    }
}
