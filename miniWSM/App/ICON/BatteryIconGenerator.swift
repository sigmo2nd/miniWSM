//#!/usr/bin/env swift
//import AppKit
//
//// ────────── 배터리 아이콘 생성 설정 ──────────
//let basePointSize: CGFloat = 18       // 기본 아이콘 크기
//let weight = NSFont.Weight.regular    // 폰트 무게
//
//// 내보낼 해상도 배율 및 파일명 접미사
//let scales: [(factor: Int, suffix: String)] = [
//    (1, ""),      // @1x (접미사 없음)
//    (2, "@2x"),   // @2x
//    (3, "@3x")    // @3x
//]
//
//// 배터리 레벨 (0부터 100까지 10단위로)
//let levels = stride(from: 0, through: 100, by: 10)
//
//// 내보낼 디렉토리 설정
//let exportDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
//    .appendingPathComponent("BatteryIcons", isDirectory: true)
//
//// 디렉토리가 없으면 생성
//try? FileManager.default.createDirectory(at: exportDir,
//                                         withIntermediateDirectories: true)
//print("📁 배터리 아이콘 생성 시작")
//print("📂 저장 경로: \(exportDir.path)")
//
//// 각 해상도별로 반복
//for (factor, suffix) in scales {
//    // 해상도에 맞게 포인트 크기 조정
//    let ptSize = basePointSize * CGFloat(factor)
//    
//    // 해당 해상도 전용 폴더 생성
//    let scaleDir = exportDir.appendingPathComponent(suffix.isEmpty ? "1x" : String(suffix.dropFirst()), isDirectory: true)
//    try? FileManager.default.createDirectory(at: scaleDir,
//                                         withIntermediateDirectories: true)
//    
//    // 배터리 레벨별로 아이콘 생성
//    for level in levels {
//        // 일반 상태와 충전 상태 모두 처리
//        for chargingState in ["", ".bolt"] {
//            // 아이콘 이름 생성 (예: battery.50 또는 battery.50.bolt)
//            let iconName = "battery.\(level)\(chargingState)"
//            
//            // SF Symbol 이미지 가져오기
//            let symbolConfig = NSImage.SymbolConfiguration(pointSize: ptSize, weight: weight)
//            guard let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
//                    .withSymbolConfiguration(symbolConfig),
//                  let tiff = img.tiffRepresentation,
//                  let rep = NSBitmapImageRep(data: tiff),
//                  let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
//            else {
//                print("⚠️ 아이콘 생성 실패: \(iconName) \(suffix)")
//                continue
//            }
//            
//            // 파일명 설정
//            let filename = "\(iconName)\(suffix).png"
//            let outputPath = scaleDir.appendingPathComponent(filename)
//            
//            // 파일 저장
//            do {
//                try png.write(to: outputPath)
//                print("✅ 생성 완료: \(filename)")
//            } catch {
//                print("❌ 저장 실패: \(filename) - \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    print("✓ \(suffix.isEmpty ? "1x" : suffix) 해상도 처리 완료")
//}
//
//// 아래는 PDF 아이콘 생성 (벡터 기반 아이콘용)
//print("\n📄 PDF 아이콘 생성 시작")
//let pdfDir = exportDir.appendingPathComponent("PDF", isDirectory: true)
//try? FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)
//
//for level in levels {
//    for chargingState in ["", ".bolt"] {
//        let iconName = "battery.\(level)\(chargingState)"
//        let symbolConfig = NSImage.SymbolConfiguration(pointSize: basePointSize * 4, weight: weight)
//        
//        guard let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)?
//                .withSymbolConfiguration(symbolConfig) else {
//            print("⚠️ PDF 아이콘 생성 실패: \(iconName)")
//            continue
//        }
//        
//        // PDF 데이터로 변환
//        let filename = "\(iconName).pdf"
//        let outputPath = pdfDir.appendingPathComponent(filename)
//        
//        // PDF 생성을 위한 다른 방식으로 시도
//        let pdfData = NSMutableData()
//        var mediaBox = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
//        
//        if let consumer = CGDataConsumer(data: pdfData as CFMutableData),
//           let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) {
//            
//            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
//            NSGraphicsContext.saveGraphicsState()
//            NSGraphicsContext.current = nsContext
//            
//            // NSRect 사용하여 그리기
//            let rect = NSRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
//            img.draw(in: rect)
//            
//            NSGraphicsContext.restoreGraphicsState()
//            context.closePDF()
//            
//            do {
//                try pdfData.write(to: outputPath, options: .atomic)
//                print("✅ PDF 생성 완료: \(filename)")
//            } catch {
//                print("❌ PDF 저장 실패: \(filename) - \(error.localizedDescription)")
//            }
//        } else {
//            print("❌ PDF 컨텍스트 생성 실패: \(filename)")
//        }
//    }
//}
//
//print("\n✨ 모든 배터리 아이콘 생성이 완료되었습니다!")
//print("📂 아이콘 저장 경로: \(exportDir.path)")
//print("- PNG 파일: 1x, 2x, 3x 해상도")
//print("- PDF 파일: 벡터 기반 고해상도")
