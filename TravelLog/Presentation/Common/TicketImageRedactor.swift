//
//  TicketImageRedactor.swift
//  TravelLog
//
//  Created by Claude on 8/16/26.
//

import UIKit
import Vision

/// Claude Vision으로 사진을 보내기 전, 온디바이스 Vision으로 바코드/QR과
/// 개인정보로 보이는 텍스트 영역을 찾아 검게 칠한 이미지를 만든다.
///
/// 목적은 티켓을 완벽히 판독하는 게 아니라(그건 여전히 Claude가 함), 전송 전에
/// 민감정보 후보를 최대한 가리는 1차 방어선을 두는 것이다. 실패하거나 아무것도
/// 못 찾아도 원본을 그대로 반환하며, 최종 확인은 사용자가 미리보기 화면에서 한다.
enum TicketImageRedactor {
    static func redact(_ image: UIImage, completion: @escaping (UIImage) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(image)
            return
        }

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = false
        // Vision이 지원하는 인식 언어 전체. 티켓 발행국 언어를 예측할 수 없어, 커버리지를
        // 최대한 넓혀 마스킹 후보를 더 많이 잡아내는 쪽을 택한다(그래도 Vision이 지원하지
        // 않는 언어는 있어, 최종 확인은 사용자가 미리보기에서 직접 한다).
        textRequest.recognitionLanguages = [
            "en-US", "ko-KR", "ja-JP", "zh-Hans", "zh-Hant", "yue-Hans", "yue-Hant",
            "ar-SA", "ars-SA", "cs-CZ", "da-DK", "de-DE", "es-ES", "fr-FR", "id-ID",
            "it-IT", "ms-MY", "nb-NO", "nl-NL", "nn-NO", "no-NO", "pl-PL", "pt-BR",
            "ro-RO", "ru-RU", "sv-SE", "th-TH", "tr-TR", "uk-UA", "vi-VT",
        ]

        let barcodeRequest = VNDetectBarcodesRequest()

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgImagePropertyOrientation(from: image.imageOrientation)
        )

        DispatchQueue.global(qos: .userInitiated).async {
            var maskRects: [CGRect] = []

            do {
                try handler.perform([textRequest, barcodeRequest])

                let textRegions: [TicketTextRegion] = (textRequest.results ?? []).compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return TicketTextRegion(text: candidate.string, boundingBox: observation.boundingBox)
                }
                maskRects.append(contentsOf: TicketPIIClassifier.regionsToMask(in: textRegions))

                let barcodeRects = (barcodeRequest.results ?? []).map(\.boundingBox)
                maskRects.append(contentsOf: barcodeRects)
            } catch {
                // Vision이 실패해도 원본을 그대로 보내지 않는다. 빈 마스크로 진행해,
                // 사용자가 미리보기 화면에서 직접 보고 필요하면 다시 촬영하게 한다.
            }

            let masked = drawVisionMasks(maskRects, on: image)
            DispatchQueue.main.async {
                completion(masked)
            }
        }
    }

    /// 미리보기 화면에서 사용자가 손가락으로 직접 문질러 지정한 영역(이미지 픽셀 좌표계,
    /// 원점 좌상단)을 검게 칠한다. 자동 마스킹이 놓친 부분을 사용자가 보완할 때 쓴다.
    static func applyManualMasks(_ pixelRects: [CGRect], to image: UIImage) -> UIImage {
        fill(pixelRects, on: image)
    }

    private static func drawVisionMasks(_ normalizedRects: [CGRect], on image: UIImage) -> UIImage {
        guard !normalizedRects.isEmpty else { return image }

        let width = image.size.width
        let height = image.size.height
        let padding: CGFloat = 4

        let pixelRects = normalizedRects.map { rect -> CGRect in
            // Vision 좌표계(원점 좌하단, 0...1 정규화) → UIKit 좌표계(원점 좌상단, 픽셀)
            let x = rect.origin.x * width
            let y = (1 - rect.origin.y - rect.height) * height
            return CGRect(
                x: x - padding,
                y: y - padding,
                width: rect.width * width + padding * 2,
                height: rect.height * height + padding * 2
            )
        }

        return fill(pixelRects, on: image)
    }

    private static func fill(_ pixelRects: [CGRect], on image: UIImage) -> UIImage {
        guard !pixelRects.isEmpty else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            image.draw(at: .zero)
            context.cgContext.setFillColor(UIColor.black.cgColor)
            for rect in pixelRects {
                context.cgContext.fill(rect)
            }
        }
    }

    private static func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
