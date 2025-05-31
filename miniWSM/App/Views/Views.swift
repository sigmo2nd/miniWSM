//
//  Views.swift
//  miniWSM
//
//  Created by Sieg on 4/26/25.
//

import SwiftUI
import Combine

// MARK: - 팝업 뷰
struct PopoverView: View {
    @ObservedObject var monitor: DeviceStatusMonitor
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            HStack {
                Text("EW-DX 모니터링")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        // 장치 관리 창 표시
                        openDeviceManager()
                    }) {
                        Label("관리", systemImage: "gear")
                            .font(.caption)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("장치 관리")
                    
                    Button(action: {
                        // 장치 스캔 창 표시
                        openDeviceScanner()
                    }) {
                        Label("스캔", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("네트워크에서 장치 스캔")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            
            // 탭 선택기
            Picker("보기 모드", selection: $selectedTab) {
                Text("마이크").tag(0)
                Text("장치").tag(1)
                Text("설정").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 4)
            
            // 선택된 탭의 내용
            if selectedTab == 0 {
                // 마이크 상태 뷰
                MicTabView(monitor: monitor)
            } else if selectedTab == 1 {
                // 장치 상태 뷰
                DeviceTabView(monitor: monitor)
            } else {
                // 설정 뷰
                SettingsView()
            }
            
            Spacer()
            
            // 상태 표시줄 (연결된 장치 수 표시)
            DeviceConnectionStatusBarView(monitor: monitor)
                .frame(height: 30)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
        }
        .frame(width: 320, height: 450)
    }
    
    func openDeviceScanner() {
        let scanner = DeviceScannerWindowController.shared()
        scanner.showWindow(nil)
        scanner.startScan()
    }

    func openDeviceManager() {
        let manager = DeviceManagerWindowController.shared()
        manager.showWindow(nil)
        manager.loadDevices()
    }
}

// MARK: - 마이크 탭 뷰
struct MicTabView: View {
    @ObservedObject var monitor: DeviceStatusMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(monitor.micStatuses, id: \.id) { status in
                    MicStatusView(status: status)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - 장치 탭 뷰
struct DeviceTabView: View {
    @ObservedObject var monitor: DeviceStatusMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 충전기 섹션
                if !monitor.getChargers().isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("충전기")
                            .font(.subheadline.bold())
                            .padding(.horizontal)
                        
                        ForEach(monitor.getChargers(), id: \.id) { device in
                            ChargerDeviceView(device: device)
                                .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                }
                
                // 수신기 섹션
                if !monitor.getReceivers().isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("수신기")
                            .font(.subheadline.bold())
                            .padding(.horizontal)
                        
                        ForEach(monitor.getReceivers(), id: \.id) { device in
                            ReceiverStatusView(device: device)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // 장치가 없는 경우
                if monitor.getChargers().isEmpty && monitor.getReceivers().isEmpty {
                    VStack {
                        Spacer()
                        Text("등록된 장치가 없습니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("우측 상단의 '관리' 또는 '스캔' 버튼을 사용하여 장치를 등록하세요")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - 충전기 장치 뷰
struct ChargerDeviceView: View {
    let device: DeviceInfo
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 장치 헤더
            HStack {
                Image(systemName: "battery.100.bolt")
                    .foregroundColor(.blue)
                
                Text(device.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(device.ipAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            // 확장된 내용 (충전 베이 정보)
            if isExpanded {
                VStack(spacing: 8) {
                    // 충전 베이 정보 표시
                    ForEach(0..<2) { index in
                        ChargingBayStatusView(status: ChargingBayStatus.empty(id: index))
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 수신기 상태 뷰
struct ReceiverStatusView: View {
    let device: DeviceInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                
                Text(device.ipAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 10))
            
            Text("연결됨")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 설정 뷰
struct SettingsView: View {
    @State private var showAutoRefresh = UserDefaults.standard.bool(forKey: "autoRefresh")
    @State private var refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
    @State private var showDeviceList = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 장치 관리 섹션
                VStack(alignment: .leading, spacing: 8) {
                    Text("장치 관리")
                        .font(.headline)
                    
                    Button("장치 관리 창 열기") {
                        openDeviceManager()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 8)
                
                // 새로고침 설정 섹션
                VStack(alignment: .leading, spacing: 8) {
                    Text("새로고침 설정")
                        .font(.headline)
                    
                    Toggle("자동 새로고침", isOn: $showAutoRefresh)
                    
                    Text("새로고침 간격: \(Int(refreshInterval))초")
                        .font(.caption)
                    
                    Slider(value: $refreshInterval, in: 1...30, step: 1)
                        .disabled(!showAutoRefresh)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 8)
                
                // 저장 버튼 섹션
                HStack {
                    Spacer()
                    
                    Button("적용") {
                        // 설정 저장
                        saveSettings()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            loadSettings()
        }
    }
    
    func loadSettings() {
        showAutoRefresh = UserDefaults.standard.bool(forKey: "autoRefresh")
        refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        if refreshInterval == 0 {
            refreshInterval = 10
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(showAutoRefresh, forKey: "autoRefresh")
        UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
    }
    
    func openDeviceManager() {
        let manager = DeviceManagerWindowController.shared()
        manager.showWindow(nil)
        manager.loadDevices()
    }
}

// MARK: - 장치 연결 상태 표시 바
struct DeviceConnectionStatusBarView: View {
    @ObservedObject var monitor: DeviceStatusMonitor
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 사이클 상태
                if monitor.isUpdating {
                    StatusIndicator(
                        isActive: true,
                        deviceName: "업데이트 중...",
                        color: .blue
                    )
                }
                
                // 충전기 상태들
                ForEach(monitor.getChargers(), id: \.id) { device in
                    StatusIndicator(
                        isActive: true,
                        deviceName: "\(device.displayName)",
                        color: .green
                    )
                }
                
                // 수신기 상태들
                ForEach(monitor.getReceivers(), id: \.id) { device in
                    StatusIndicator(
                        isActive: true,
                        deviceName: "\(device.displayName)",
                        color: .green
                    )
                }
                
                // 연결된 장치가 없을 경우
                if monitor.getChargers().isEmpty && monitor.getReceivers().isEmpty {
                    StatusIndicator(
                        isActive: false,
                        deviceName: "연결된 장치 없음",
                        color: .red
                    )
                }
                
                // 마지막 사이클 성공 여부
                if !monitor.lastCycleSuccessful {
                    StatusIndicator(
                        isActive: false,
                        deviceName: "통신 오류",
                        color: .red
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - 상태 표시 인디케이터
struct StatusIndicator: View {
    let isActive: Bool
    let deviceName: String
    let color: Color
    
    init(isActive: Bool, deviceName: String, color: Color? = nil) {
        self.isActive = isActive
        self.deviceName = deviceName
        self.color = color ?? (isActive ? .green : .red)
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(deviceName)
                .font(.system(size: 9))
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
}

// MARK: - 마이크 상태 뷰
struct MicStatusView: View {
    let status: MicStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(status.name)
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                if status.warning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 10))
                }
                
                // 소스 장치 표시 (어떤 장치에서 이 마이크 정보가 왔는지)
                if let sourceDevice = status.sourceDevice {
                    Text(sourceDevice.displayName)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                // 마이크 상태 아이콘
                Image(systemName: status.state.icon)
                    .foregroundColor(status.state.color)
                    .font(.system(size: 10))
                
                Text(status.state.description)
                    .foregroundColor(status.state.color)
                    .font(.system(size: 10))
                
                Spacer()
                
                // 배터리 퍼센트
                Text("\(status.batteryPercentage)%")
                    .font(.system(size: 10))
                    .foregroundColor(batteryColor)
            }
            
            if status.state == .active {
                HStack {
                    // 신호 강도
                    Label {
                        Text("\(status.signalStrength)%")
                            .font(.system(size: 9))
                    } icon: {
                        Image(systemName: status.signalImage)
                            .foregroundColor(signalColor)
                            .font(.system(size: 9))
                    }
                    
                    Spacer()
                    
                    // 남은 시간
                    Text("남은 시간: \(formatBatteryTime(status.batteryRuntime))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // 배터리 색상
    var batteryColor: Color {
        if status.batteryPercentage > 70 {
            return .green
        } else if status.batteryPercentage > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // 신호 색상
    var signalColor: Color {
        if status.signalStrength > 70 {
            return .green
        } else if status.signalStrength > 30 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - 충전 베이 상태 뷰
struct ChargingBayStatusView: View {
    let status: ChargingBayStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("베이 \(status.id + 1)")
                    .font(.system(size: 12, weight: .bold))
                
                Spacer()
                
                Text(status.deviceTypeDisplay)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                // 소스 장치 표시 (어떤 충전기에서 이 베이 정보가 왔는지)
                if let sourceDevice = status.sourceDevice {
                    Text(sourceDevice.displayName)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            
            if status.hasDevice {
                HStack {
                    // 배터리 충전량
                    Label {
                        Text("\(status.batteryPercentage)%")
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "battery.100")
                            .foregroundColor(batteryColor)
                            .font(.system(size: 10))
                    }
                    
                    Spacer()
                    
                    // 배터리 건강 상태
                    Label {
                        Text("건강: \(status.batteryHealth)%")
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundColor(healthColor)
                            .font(.system(size: 10))
                    }
                }
                
                // 충전 완료까지 남은 시간과 사이클 수
                HStack {
                    Text("완충 시간: \(formatTimeToFull(status.timeToFull))")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("사이클: \(status.batteryCycles)회")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("장치가 없습니다")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // 배터리 색상
    var batteryColor: Color {
        if status.batteryPercentage > 70 {
            return .green
        } else if status.batteryPercentage > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // 건강 상태 색상
    var healthColor: Color {
        if status.batteryHealth > 80 {
            return .green
        } else if status.batteryHealth > 60 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // 충전 완료 시간 포맷팅
    func formatTimeToFull(_ minutes: Int) -> String {
        if minutes == 0 {
            return "완료됨"
        }
        
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)시간 \(mins)분"
        } else {
            return "\(mins)분"
        }
    }
}

// 배터리 시간 포맷팅을 위한 유틸리티 함수
func formatBatteryTime(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    
    if hours > 0 {
        return "\(hours)시간 \(mins)분"
    } else {
        return "\(mins)분"
    }
}
