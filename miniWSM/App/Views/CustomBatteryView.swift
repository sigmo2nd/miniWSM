//
//  CustomBatteryView.swift
//  miniWSM
//
//  Created by Sieg on 4/27/25.
//

import Cocoa

class CustomBatteryView: NSView {
    // 배터리 레벨 (0-100, 5% 단위로 반올림)
    var batteryLevel: Int = 100 {
        didSet {
            // 5% 단위로 레벨 반올림
            let roundedLevel = Int(round(Double(batteryLevel) / 5.0) * 5.0)
            // 0-100 범위로 제한
            let clampedLevel = min(100, max(0, roundedLevel))
            self.displayLevel = clampedLevel
            needsDisplay = true
        }
    }
    
    // 표시할 배터리 레벨 (5% 단위)
    private var displayLevel: Int = 100
    
    // 충전 중 여부
    var isCharging: Bool = false {
        didSet {
            needsDisplay = true
        }
    }
    
    // 배터리 색상
    var batteryColor: NSColor {
        switch displayLevel {
        case 65...100:
            return .systemGreen
        case 30...64:
            return .systemYellow
        case 0...29:
            return isCharging ? .systemBlue : .systemRed
        default:
            return .systemGray
        }
    }
    
    // SF 심볼 배터리 아이콘 (기본 / 충전)
    private var normalBatteryImage: NSImage?
    private var chargingBatteryImage: NSImage?
    
    // 내부 레벨 그리기 위한 크기 정보
    private struct BatteryMetrics {
        // 실제 배터리 내부 영역(게이지 표시) 위치 및 크기
        static let innerRect = NSRect(x: 2.71, y: 2.71, width: 20.5, height: 7.8)
        // 게이지 모서리 반경
        static let cornerRadius: CGFloat = 1.0
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupImages()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupImages()
    }
    
    private func setupImages() {
        // 일반 배터리 아이콘 (SF 심볼)
        normalBatteryImage = NSImage(systemSymbolName: "battery.0", accessibilityDescription: nil)
        
        // 충전 중 배터리 아이콘 (SF 심볼)
        chargingBatteryImage = NSImage(systemSymbolName: "battery.0.bolt", accessibilityDescription: nil)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 배경 지우기
        NSColor.clear.set()
        dirtyRect.fill()
        
        // 사용할 배터리 이미지 결정
        let baseImage = isCharging ? chargingBatteryImage : normalBatteryImage
        
        // 배터리 아이콘 그리기 (템플릿 이미지로 처리)
        if let baseImage = baseImage {
            // 이미지에 색상 적용 (템플릿 모드)
            baseImage.isTemplate = true
            
            // 이미지 그리기
            NSGraphicsContext.current?.imageInterpolation = .high
            baseImage.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
            
            // 만약 배터리 레벨이 0보다 크면 내부 게이지 그리기
            if displayLevel > 0 {
                drawBatteryLevel()
            }
        }
    }
    
    private func drawBatteryLevel() {
        // 배터리 내부 게이지 그리기
        let levelRect = calculateLevelRect()
        
        // 게이지 색상 설정
        batteryColor.setFill()
        
        // 게이지 그리기 (모서리 둥글게)
        let path = NSBezierPath(roundedRect: levelRect, xRadius: BatteryMetrics.cornerRadius, yRadius: BatteryMetrics.cornerRadius)
        path.fill()
    }
    
    private func calculateLevelRect() -> NSRect {
        let innerRect = BatteryMetrics.innerRect
        
        // 뷰 크기에 맞게 스케일링
        let scale = min(bounds.width / 29.0, bounds.height / 13.0)
        
        let scaledInnerRect = NSRect(
            x: innerRect.origin.x * scale,
            y: innerRect.origin.y * scale,
            width: innerRect.width * scale,
            height: innerRect.height * scale
        )
        
        // 배터리 레벨에 따라 너비 계산 (0-100%)
        let levelWidth = scaledInnerRect.width * CGFloat(displayLevel) / 100.0
        
        // 레벨 직사각형 반환 (왼쪽부터 채움)
        return NSRect(
            x: scaledInnerRect.origin.x,
            y: scaledInnerRect.origin.y,
            width: levelWidth,
            height: scaledInnerRect.height
        )
    }
}

// MARK: - StatusBarView 확장
extension StatusBarView {
    // 기존 getBatteryImage 대신 사용할 메서드
    func getCustomBatteryImage(for mic: MicStatus) -> NSImage? {
        // 커스텀 배터리 뷰 생성
        let batteryView = CustomBatteryView(frame: NSRect(x: 0, y: 0, width: 20, height: 10))
        
        // 배터리 속성 설정
        batteryView.batteryLevel = mic.batteryPercentage
        batteryView.isCharging = mic.state == .charging
        
        // 뷰를 이미지로 변환
        let image = NSImage(size: batteryView.bounds.size)
        image.lockFocus()
        
        // 뷰 그리기
        batteryView.draw(batteryView.bounds)
        
        image.unlockFocus()
        
        return image
    }
}
