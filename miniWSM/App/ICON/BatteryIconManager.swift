////
////  BatteryIconManager.swift
////  miniWSM
////
////  Created by Sieg on 4/27/25.
////
//
//import Cocoa
//
//class BatteryIconManager {
//    // 싱글톤 인스턴스
//    static let shared = BatteryIconManager()
//    
//    // 일반 배터리 아이콘 캐시
//    private var normalBatteryIcons: [Int: NSImage] = [:]
//    
//    // 충전 중 배터리 아이콘 캐시
//    private var chargingBatteryIcons: [Int: NSImage] = [:]
//    
//    // 캐시 초기화 여부
//    private var isInitialized = false
//    
//    // 앱 번들 내 리소스 경로
//    private var resourcePath: String {
//        return Bundle.main.resourcePath ?? ""
//    }
//    
//    // 아이콘 캐시 초기화
//    func initialize() {
//        guard !isInitialized else { return }
//        
//        // 배터리 아이콘 로드
//        loadBatteryIcons()
//        
//        isInitialized = true
//    }
//    
//    // 배터리 아이콘 로드
//    private func loadBatteryIcons() {
//        // 0부터 100까지 10% 단위로 아이콘 로드
//        for level in stride(from: 0, through: 100, by: 10) {
//            // 일반 배터리 아이콘 로드
//            if let normalIcon = loadBatteryIcon(level: level, charging: false) {
//                normalBatteryIcons[level] = normalIcon
//            }
//            
//            // 충전 중 배터리 아이콘 로드
//            if let chargingIcon = loadBatteryIcon(level: level, charging: true) {
//                chargingBatteryIcons[level] = chargingIcon
//            }
//        }
//    }
//    
//    // 특정 레벨의 배터리 아이콘 로드
//    private func loadBatteryIcon(level: Int, charging: Bool) -> NSImage? {
//        let suffix = charging ? ".bolt" : ""
//        let iconName = "battery.\(level)\(suffix)"
//        
//        // 1. 앱 내 리소스에서 먼저 찾기
//        if let image = NSImage(named: iconName) {
//            return image
//        }
//        
//        // 2. 번들 내부에서 파일로 찾기
//        let resourceDirectories = ["", "1x", "2x", "3x", "PDF"]
//        
//        for directory in resourceDirectories {
//            let extensions = directory == "PDF" ? ["pdf"] : ["png"]
//            
//            for ext in extensions {
//                let directoryPath = directory.isEmpty ? resourcePath : "\(resourcePath)/\(directory)"
//                let filePath = "\(directoryPath)/\(iconName).\(ext)"
//                
//                if FileManager.default.fileExists(atPath: filePath) {
//                    return NSImage(contentsOfFile: filePath)
//                }
//                
//                // 해상도 표기가 있는 경우도 확인
//                for scale in ["", "@2x", "@3x"] {
//                    let scaleFilePath = "\(directoryPath)/\(iconName)\(scale).\(ext)"
//                    if FileManager.default.fileExists(atPath: scaleFilePath) {
//                        return NSImage(contentsOfFile: scaleFilePath)
//                    }
//                }
//            }
//        }
//        
//        // 3. SF Symbol 사용 (대체 방안)
//        return NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
//    }
//    
//    // 배터리 레벨에 맞는 아이콘 가져오기
//    func getBatteryIcon(level: Int, charging: Bool, tintColor: NSColor? = nil) -> NSImage? {
//        // 캐시 초기화 확인
//        if !isInitialized {
//            initialize()
//        }
//        
//        // 가장 가까운 10% 단위로 조정
//        let roundedLevel = Int(round(Double(level) / 10.0) * 10.0)
//        let clampedLevel = min(100, max(0, roundedLevel))
//        
//        // 캐시에서 아이콘 찾기
//        let icon = charging ? chargingBatteryIcons[clampedLevel] : normalBatteryIcons[clampedLevel]
//        
//        // 아이콘이 없는 경우 SF Symbol 사용
//        guard var finalIcon = icon else {
//            let symbolName = charging ? "battery.\(clampedLevel).bolt" : "battery.\(clampedLevel)"
//            return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
//        }
//        
//        // 색상 적용
//        if let color = tintColor {
//            finalIcon = tintImage(finalIcon, with: color)
//        }
//        
//        return finalIcon
//    }
//    
//    // 이미지에 색상 적용
//    private func tintImage(_ image: NSImage, with color: NSColor) -> NSImage {
//        let tintedImage = image.copy() as! NSImage
//        tintedImage.lockFocus()
//        
//        color.set()
//        NSRect(x: 0, y: 0, width: tintedImage.size.width, height: tintedImage.size.height).fill(using: .sourceAtop)
//        
//        tintedImage.unlockFocus()
//        return tintedImage
//    }
//}
//
//// MARK: - StatusBarView 확장
//extension StatusBarView {
//    // 배터리 아이콘 가져오기 - BatteryIconManager 이용
//    func getBatteryIcon(for mic: MicStatus) -> NSImage? {
//        // 배터리 레벨 및 충전 상태 가져오기
//        let level = mic.batteryPercentage
//        let charging = mic.state == .charging
//        
//        // 배터리 상태에 따른 색상 설정
//        let color: NSColor
//        if charging {
//            color = .systemBlue
//        } else if level > 60 {
//            color = .systemGreen
//        } else if level > 20 {
//            color = .systemOrange
//        } else {
//            color = .systemRed
//        }
//        
//        // BatteryIconManager에서 아이콘 가져오기
//        if let icon = BatteryIconManager.shared.getBatteryIcon(level: level, charging: charging, tintColor: color) {
//            return icon
//        }
//        
//        // 아이콘을 가져오지 못한 경우 기존 방식 사용
//        return getCustomBatteryImage(for: mic)
//    }
//}
