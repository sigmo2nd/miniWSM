//
//  StatusBarView.swift
//  miniWSM
//
//  Created by Sieg on 4/27/25.
//

import Cocoa

// MARK: - 상태바 커스텀 뷰
class StatusBarView: NSView {
    let fontAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
        .foregroundColor: NSColor.headerTextColor
    ]
    
    var micStatuses: [MicStatus] = []
    var hasWarning = false
    var hasError = false
    
    // 마이크별 상태 추적
    private var lastStates: [Int: MicStateType] = [:]     // 마이크 ID -> 이전 상태
    private var stateChangeTimes: [Int: Date] = [:]      // 마이크 ID -> 상태 변경 시간
    
    // 객체 초기화
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // 배경 지우기
        NSColor.clear.set()
        dirtyRect.fill()
        
        // 마이크 상태가 있는지 확인 (최대 2개만 표시)
        let activeMics = micStatuses.prefix(2)
        
        // 필요한 너비 계산
        var requiredWidth: CGFloat = 0
        
        if activeMics.isEmpty {
            // 연결된 마이크가 없는 경우
            let noConnectionStr = hasError ? "연결 오류" : "연결 없음"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: hasError ? NSColor.systemRed : NSColor.headerTextColor
            ]
            
            let strSize = noConnectionStr.size(withAttributes: attrs)
            requiredWidth = strSize.width + 10 // 최소한의 패딩만 추가
            
            let xPos = (bounds.width - strSize.width) / 2
            let yPos = (bounds.height - strSize.height) / 2
            
            noConnectionStr.draw(at: NSPoint(x: xPos, y: yPos), withAttributes: attrs)
        } else {
            // 마이크 상태가 있는 경우
            // 행간
            let lineHeight: CGFloat = 11
            
            // 전체 콘텐츠 높이 계산
            let totalContentHeight = activeMics.count > 1 ? lineHeight * 2 + 1 : lineHeight
            // 콘텐츠가 상태바 중앙에 오도록 시작 y 위치 계산
            let startY = (bounds.height - totalContentHeight) / 2 + totalContentHeight - lineHeight
            
            // 각 마이크에 대해 필요한 너비 계산 및 상태 표시
            for (index, mic) in activeMics.enumerated() {
                // 현재 줄의 y 위치 (중앙 정렬 기준)
                let yPos = startY - CGFloat(index) * lineHeight
                
                // 이 마이크의 텍스트 색상 결정 (이 마이크가 경고 상태인 경우만 색상 변경)
                let textColor: NSColor
                if hasError {
                    textColor = NSColor.systemRed
                } else if mic.warning {
                    textColor = NSColor.systemOrange
                } else {
                    textColor = NSColor.headerTextColor
                }
                
                // 마이크 라벨 (M1, M2, ...)
                let micLabel = "M\(mic.id + 1)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: textColor
                ]
                
                // 텍스트 높이 계산 (수직 중앙 정렬용)
                let textHeight = "M1".size(withAttributes: attrs).height
                let labelWidth = micLabel.size(withAttributes: attrs).width
                
                // 배터리 아이콘 가져오기
                let batteryImage = getBatteryImage(for: mic)
                
                // 상태 텍스트 결정
                let statusText = getDisplayTextForMic(mic)
                
                // 배터리 이미지 여부 확인
                if let batteryImage = batteryImage {
                    // 배터리 이미지 높이와 너비
                    let batteryHeight = batteryImage.size.height
                    let batteryWidth = batteryImage.size.width
                    
                    // 수직 중앙 정렬 위치 계산
                    let lineCenter = yPos + textHeight/2
                    
                    // 텍스트 시작 위치
                    let textYPos = lineCenter - textHeight/2
                    
                    // 배터리 이미지 시작 위치
                    let batteryYPos = lineCenter - batteryHeight/2
                    
                    // 라벨 그리기
                    micLabel.draw(at: NSPoint(x: 4, y: textYPos), withAttributes: attrs)
                    
                    // 배터리 아이콘 그리기
                    let iconX = 4 + labelWidth + 2
                    batteryImage.draw(at: NSPoint(x: iconX, y: batteryYPos), from: .zero, operation: .sourceOver, fraction: 1.0)
                    
                    // 상태 텍스트 위치
                    let textX = iconX + batteryWidth + 2
                    statusText.draw(at: NSPoint(x: textX, y: textYPos), withAttributes: attrs)
                    
                    // 이 마이크에 필요한 총 너비 계산
                    let micWidth = textX + statusText.size(withAttributes: attrs).width + 4
                    
                    // 전체 필요 너비 업데이트
                    requiredWidth = max(requiredWidth, micWidth)
                } else {
                    // 배터리 이미지가 없을 경우 대체 표시
                    let textYPos = yPos
                    
                    // 라벨 그리기
                    micLabel.draw(at: NSPoint(x: 4, y: textYPos), withAttributes: attrs)
                    
                    // 대체 배터리 아이콘
                    let iconX = 4 + labelWidth + 2
                    let batteryText = mic.state == .charging ? "⚡" : "🔋"
                    batteryText.draw(at: NSPoint(x: iconX, y: textYPos), withAttributes: attrs)
                    
                    // 배터리 텍스트 너비
                    let batteryTextWidth = batteryText.size(withAttributes: attrs).width
                    
                    // 상태 텍스트 위치
                    let textX = iconX + batteryTextWidth + 2
                    statusText.draw(at: NSPoint(x: textX, y: textYPos), withAttributes: attrs)
                    
                    // 이 마이크에 필요한 총 너비 계산
                    let micWidth = textX + statusText.size(withAttributes: attrs).width + 4
                    
                    // 전체 필요 너비 업데이트
                    requiredWidth = max(requiredWidth, micWidth)
                }
            }
        }
        
        // 상태바 버튼 크기 업데이트
        if let button = self.superview as? NSStatusBarButton {
            let currentFrame = button.frame
            let newFrame = NSRect(x: currentFrame.origin.x,
                                 y: currentFrame.origin.y,
                                 width: requiredWidth,
                                 height: currentFrame.height)
            
            if abs(currentFrame.width - requiredWidth) > 1 { // 작은 변화는 무시
                button.frame = newFrame
            }
        }
    }
    
    // 마이크별 표시 텍스트 결정
    private func getDisplayTextForMic(_ mic: MicStatus) -> String {
        // 상태에 따라 텍스트 결정
        switch mic.state {
        case .charging:
            // 충전 중일 때는 배터리 퍼센트만 표시
            return "\(mic.batteryPercentage)%"
            
        case .active:
            // 활성 상태일 때 런타임 값 확인
            if mic.batteryRuntime > 0 {
                // 유효한 런타임 값이 있으면 시간:분 형식으로 표시
                return formatBatteryTime(mic.batteryRuntime)
            } else {
                // 런타임 값이 없으면 "계산 중" 표시
                return "계산 중"
            }
            
        case .disconnected:
            return "연결안됨"
        }
    }
    
    // 배터리 아이콘 가져오기 (새로운 방식)
    private func getBatteryImage(for mic: MicStatus) -> NSImage? {
        // 배터리 레벨에 따른 이미지 이름 결정
        let level = mic.batteryPercentage
        let charging = mic.state == .charging
        
        // 배터리 표시용 이미지 이름
        let imageName: String
        if charging {
            // 충전 중일 때는 단일 아이콘 (충전 중인 아이콘이 한 가지뿐이라고 가정)
            imageName = "battery.100.bolt"
        } else {
            // 사용 중일 때는 5단계 (0, 25, 50, 75, 100)
            if level <= 10 {
                imageName = "battery.0"
            } else if level <= 30 {
                imageName = "battery.25"
            } else if level <= 60 {
                imageName = "battery.50"
            } else if level <= 85 {
                imageName = "battery.75"
            } else {
                imageName = "battery.100"
            }
        }
        
        // SF Symbol 이미지 가져오기
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil) ??
                    NSImage(systemSymbolName: "battery.50", accessibilityDescription: nil)
        
        // 이미지가 없으면 기본값 반환
        guard let image = image else {
            return nil
        }
        
        // 배터리 색상 설정
        let tintedImage = image.copy() as! NSImage
        tintedImage.isTemplate = true
        
        // 10% 단위로 세밀한 색상 구분
        let color = getBatteryColorForLevel(level)
        
        // 이미지에 색상 적용
        tintedImage.lockFocus()
        color.set()
        NSRect(x: 0, y: 0, width: tintedImage.size.width, height: tintedImage.size.height).fill(using: .sourceAtop)
        tintedImage.unlockFocus()
        
        // 크기 조정
        let aspectRatio = tintedImage.size.height / tintedImage.size.width
        let calculatedHeight = 21 * aspectRatio
        tintedImage.size = NSSize(width: 20, height: calculatedHeight)
        
        return tintedImage
    }
    
    // 10% 단위로 배터리 색상 결정하는 함수
    private func getBatteryColorForLevel(_ level: Int) -> NSColor {
        // 10% 단위로 색상 결정
        switch level {
        case 0...10:
            return NSColor(calibratedRed: 0.95, green: 0.10, blue: 0.10, alpha: 1.0) // 빨간색 (더 강한)
        case 11...20:
            return NSColor(calibratedRed: 0.95, green: 0.25, blue: 0.10, alpha: 1.0) // 빨간색
        case 21...30:
            return NSColor(calibratedRed: 0.95, green: 0.40, blue: 0.10, alpha: 1.0) // 주황빨강
        case 31...40:
            return NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.10, alpha: 1.0) // 주황색
        case 41...50:
            return NSColor(calibratedRed: 0.95, green: 0.70, blue: 0.10, alpha: 1.0) // 황주황
        case 51...60:
            return NSColor(calibratedRed: 0.90, green: 0.85, blue: 0.10, alpha: 1.0) // 황색
        case 61...70:
            return NSColor(calibratedRed: 0.65, green: 0.85, blue: 0.10, alpha: 1.0) // 연두색
        case 71...80:
            return NSColor(calibratedRed: 0.45, green: 0.85, blue: 0.10, alpha: 1.0) // 밝은 녹색
        case 81...90:
            return NSColor(calibratedRed: 0.25, green: 0.85, blue: 0.10, alpha: 1.0) // 녹색
        case 91...100:
            return NSColor(calibratedRed: 0.10, green: 0.85, blue: 0.10, alpha: 1.0) // 진한 녹색
        default:
            return NSColor.systemGreen
        }
    }
    
    // 상태 업데이트
    func update(with mics: [MicStatus], warning: Bool, error: Bool = false) {
        // 마이크 상태 업데이트
        self.micStatuses = mics
        self.hasWarning = warning
        self.hasError = error
        
        // 상태 추적
        for mic in mics {
            let prevState = lastStates[mic.id]
            
            // 상태 변경 감지
            if prevState != mic.state {
                // 상태 변경 시간 저장
                stateChangeTimes[mic.id] = Date()
                // 상태 업데이트
                lastStates[mic.id] = mic.state
            }
        }
        
        // 화면 갱신
        DispatchQueue.main.async {
            self.setNeedsDisplay(self.bounds)
        }
    }
    
    // 배터리 시간 포맷팅
    private func formatBatteryTime(_ minutes: Int) -> String {
        if minutes <= 0 {
            return "0:00"
        }
        
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return String(format: "%d:%02d", hours, mins)
        } else {
            return String(format: "0:%02d", mins)
        }
    }
}

// MARK: - StatusBarController 확장
extension StatusBarController {
    // 테스트 데이터로 업데이트
    func updateWithTestData(_ testMicStatuses: [MicStatus], warning: Bool) {
        print("StatusBarController.updateWithTestData 호출됨, 마이크 수: \(testMicStatuses.count)")
        if customView == nil {
            print("⚠️ 경고: customView가 nil 입니다!")
        } else {
            print("customView 발견, 업데이트 진행")
            customView?.update(with: testMicStatuses, warning: warning, error: false)
        }
    }
}
