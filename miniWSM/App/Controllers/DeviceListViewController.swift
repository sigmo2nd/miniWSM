//
//  DeviceListViewController.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import Cocoa

// MARK: - 장치 목록 뷰 컨트롤러
class DeviceListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var addButton: NSButton!
    private var removeButton: NSButton!
    private var scanButton: NSButton!
    private var devices: [DeviceInfo] = []
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 650, height: 400)) // 창 크기 확대
        setupUI()
        loadDevices()
    }
    
    private func setupUI() {
        // 테이블 뷰 설정
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: view.frame.width - 40, height: view.frame.height - 100))
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
        
        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabledColumn"))
        enabledColumn.title = "활성"
        enabledColumn.width = 120
        enabledColumn.minWidth = 80 // 최소 너비 설정
        tableView.addTableColumn(enabledColumn)
        
        let lastSeenColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastSeenColumn"))
        lastSeenColumn.title = "마지막 연결"
        lastSeenColumn.width = 140
        lastSeenColumn.minWidth = 120 // 최소 너비 설정
        tableView.addTableColumn(lastSeenColumn)
        
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)
        
        // 버튼 설정
        scanButton = NSButton(frame: NSRect(x: 20, y: 20, width: 100, height: 24))
        scanButton.title = "장치 스캔"
        scanButton.bezelStyle = .rounded
        scanButton.target = self
        scanButton.action = #selector(scanDevices)
        view.addSubview(scanButton)
        
        addButton = NSButton(frame: NSRect(x: 130, y: 20, width: 100, height: 24))
        addButton.title = "수동 추가"
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addDevice)
        view.addSubview(addButton)
        
        removeButton = NSButton(frame: NSRect(x: 240, y: 20, width: 100, height: 24))
        removeButton.title = "삭제"
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removeDevice)
        view.addSubview(removeButton)
        
        // 테스트 메뉴 표시 토글 버튼 추가
        let toggleTestMenuButton = NSButton(frame: NSRect(x: 350, y: 20, width: 140, height: 24))
        toggleTestMenuButton.title = "테스트 메뉴 표시"
        toggleTestMenuButton.bezelStyle = .rounded
        toggleTestMenuButton.target = self
        toggleTestMenuButton.action = #selector(toggleTestMenu)
        view.addSubview(toggleTestMenuButton)
        
        let doneButton = NSButton(frame: NSRect(x: view.frame.width - 120, y: 20, width: 100, height: 24))
        doneButton.title = "완료"
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(doneButtonClicked)
        doneButton.autoresizingMask = .minXMargin // 창 크기가 변경될 때 오른쪽에 고정
        view.addSubview(doneButton)
        
        // 창 크기가 변경될 때 UI 요소 조정
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowResized),
            name: NSWindow.didResizeNotification,
            object: nil
        )
    }
    
    @objc func windowResized() {
        // 창 크기 변경 시 테이블 크기 자동 조정
        tableView.sizeToFit()
    }
    
    func loadDevices() {
        devices = DeviceManager.shared.getRegisteredDevices()
        tableView.reloadData()
    }
    
    @objc func scanDevices() {
        let scanner = DeviceScannerWindowController()
        scanner.showWindow(nil)
        scanner.startScan()
        
        // 스캔 윈도우가 닫힐 때 장치 목록 새로고침 - NSWindow.willCloseNotification 사용
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refreshDeviceList),
                                               name: NSWindow.willCloseNotification,
                                               object: scanner.window)
    }
    
    @objc func refreshDeviceList() {
        loadDevices()
    }
    
    // 테스트 메뉴 토글 메소드
    @objc func toggleTestMenu() {
        // UserDefaults에 테스트 메뉴 표시 상태 저장
        let currentState = UserDefaults.standard.bool(forKey: "showTestMenu")
        let newState = !currentState
        UserDefaults.standard.set(newState, forKey: "showTestMenu")
        
        // 테스트 메뉴 토글 알림 게시
        NotificationCenter.default.post(name: NSNotification.Name("TestMenuToggled"), object: nil, userInfo: ["showTestMenu": newState])
        
        // 알림 표시
        let alert = NSAlert()
        alert.messageText = "테스트 메뉴 " + (newState ? "표시" : "숨김")
        alert.informativeText = "상태 표시줄 메뉴에서 테스트 메뉴가 " + (newState ? "표시됩니다." : "숨겨집니다.")
        alert.runModal()
    }
    
    @objc func addDevice() {
        let alert = NSAlert()
        alert.messageText = "장치 수동 추가"
        alert.informativeText = "장치 정보를 입력하세요:"
        
        // 수직 스택을 위한 컨테이너
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        
        // 이름 필드
        let nameLabel = NSTextField(labelWithString: "장치 이름:")
        nameLabel.frame = NSRect(x: 0, y: 90, width: 100, height: 24)
        
        let nameField = NSTextField(frame: NSRect(x: 110, y: 90, width: 180, height: 24))
        nameField.placeholderString = "예: 충전기1"
        
        // IP 주소 필드
        let ipLabel = NSTextField(labelWithString: "IP 주소:")
        ipLabel.frame = NSRect(x: 0, y: 60, width: 100, height: 24)
        
        let ipField = NSTextField(frame: NSRect(x: 110, y: 60, width: 180, height: 24))
        ipField.placeholderString = "예: 192.168.0.150"
        
        // 장치 유형 선택
        let typeLabel = NSTextField(labelWithString: "장치 유형:")
        typeLabel.frame = NSRect(x: 0, y: 30, width: 100, height: 24)
        
        let typePopup = NSPopUpButton(frame: NSRect(x: 110, y: 30, width: 180, height: 24))
        typePopup.addItems(withTitles: ["충전기", "수신기"])
        
        // 활성화 체크박스
        let enabledCheck = NSButton(checkboxWithTitle: "활성화", target: nil, action: nil)
        enabledCheck.frame = NSRect(x: 110, y: 0, width: 180, height: 24)
        enabledCheck.state = .on
        
        // 컨테이너에 추가
        container.addSubview(nameLabel)
        container.addSubview(nameField)
        container.addSubview(ipLabel)
        container.addSubview(ipField)
        container.addSubview(typeLabel)
        container.addSubview(typePopup)
        container.addSubview(enabledCheck)
        
        alert.accessoryView = container
        alert.addButton(withTitle: "추가")
        alert.addButton(withTitle: "취소")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 입력 검증
            guard !nameField.stringValue.isEmpty, !ipField.stringValue.isEmpty else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "오류"
                errorAlert.informativeText = "모든 필드를 입력해주세요."
                errorAlert.runModal()
                return
            }
            
            // 장치 정보 생성
            let deviceType: DeviceType = typePopup.indexOfSelectedItem == 0 ? .charger : .receiver
            let deviceInfo = DeviceInfo(
                name: nameField.stringValue,
                ipAddress: ipField.stringValue,
                type: deviceType == .charger ? "charger" : "receiver",
                lastSeen: Date(),
                isEnabled: enabledCheck.state == .on
            )
            
            // 장치 등록
            DeviceManager.shared.registerDevice(device: deviceInfo)
            
            // 목록 새로고침
            loadDevices()
            
            // 설정 변경 알림
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
    
    @objc func removeDevice() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < devices.count else {
            let alert = NSAlert()
            alert.messageText = "오류"
            alert.informativeText = "삭제할 장치를 선택해주세요."
            alert.runModal()
            return
        }
        
        let device = devices[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "장치 삭제"
        alert.informativeText = "정말로 '\(device.name)' 장치를 삭제하시겠습니까?"
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 장치 삭제
            DeviceManager.shared.unregisterDevice(ipAddress: device.ipAddress)
            
            // 목록 새로고침
            loadDevices()
            
            // 설정 변경 알림
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
    
    @objc func doneButtonClicked() {
        self.view.window?.close()
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < devices.count else { return nil }
        
        let device = devices[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        let cellIdentifier = NSUserInterfaceItemIdentifier("\(identifier)Cell")
        
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            if identifier == "enabledColumn" {
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleDeviceEnabled(_:)))
                checkbox.tag = row
                checkbox.translatesAutoresizingMaskIntoConstraints = false
                
                cell?.addSubview(checkbox)
                
                NSLayoutConstraint.activate([
                    checkbox.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 10),
                    checkbox.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
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
        
        // 셀 내용 업데이트
        switch identifier {
        case "nameColumn":
            cell?.textField?.stringValue = device.name
            
        case "ipColumn":
            cell?.textField?.stringValue = device.ipAddress
            
        case "typeColumn":
            cell?.textField?.stringValue = device.deviceType.description
            
        case "enabledColumn":
            if let checkbox = cell?.subviews.first as? NSButton {
                checkbox.state = device.isEnabled ? .on : .off
                checkbox.tag = row
            }
            
        case "lastSeenColumn":
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            cell?.textField?.stringValue = formatter.string(from: device.lastSeen)
            
        default:
            cell?.textField?.stringValue = ""
        }
        
        return cell
    }
    
    @objc func toggleDeviceEnabled(_ sender: NSButton) {
        let row = sender.tag
        guard row < devices.count else { return }
        
        var device = devices[row]
        device.isEnabled = sender.state == .on
        
        // 장치 정보 업데이트
        DeviceManager.shared.registerDevice(device: device)
        
        // 목록 새로고침
        loadDevices()
        
        // 설정 변경 알림
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }
}
