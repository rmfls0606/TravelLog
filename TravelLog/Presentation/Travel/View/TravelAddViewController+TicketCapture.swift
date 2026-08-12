//
//  TravelAddViewController+TicketCapture.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//
//  티켓 사진 촬영/선택 → 리사이즈/압축 → ticketImageRelay 전달까지 담당하는,
//  TravelAddViewController와는 독립적으로 읽고 수정할 수 있는 캡처 전용 확장.
//

import UIKit
import PhotosUI
import RxCocoa
import Toast

extension TravelAddViewController {

    //MARK: - 촬영/앨범 선택 액션시트

    func presentTicketCaptureOptions() {
        let sheet = UIAlertController(title: "티켓 사진 추가", message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "사진 촬영", style: .default) { [weak self] _ in
                self?.presentTicketCamera()
            })
        }

        sheet.addAction(UIAlertAction(title: "앨범에서 선택", style: .default) { [weak self] _ in
            self?.presentTicketPhotoPicker()
        })

        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(sheet, animated: true)
    }

    private func presentTicketCamera() {
        let camera = TicketCameraViewController()
        camera.delegate = self
        // present(_:) 이후(viewDidLoad 시점)에 설정하면 이미 전환 스타일이
        // 확정된 뒤라 반영되지 않을 수 있어, 여기서 미리 지정한다.
        camera.modalPresentationStyle = .fullScreen
        present(camera, animated: true)
    }

    private func presentTicketPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    //MARK: - 선택된 이미지를 서버로 보낼 수 있는 형태로 가공

    /// 압축 후에도 이 값을 넘으면 base64 인코딩 시 서버의 5MB 제한을 넘길 수 있어 전송하지 않는다.
    private static let maxUploadByteSize = 3_670_016 // 3.5MB

    fileprivate func handlePickedTicketImage(_ image: UIImage?) {
        guard let image else {
            view.makeToast("이미지를 불러오지 못했어요. 다시 시도해주세요.", duration: 2.0, position: .top)
            return
        }

        guard let jpegData = Self.compressedTicketImageData(from: image) else {
            view.makeToast("이미지를 처리하지 못했어요. 다른 사진으로 시도해주세요.", duration: 2.0, position: .top)
            return
        }

        guard jpegData.count <= Self.maxUploadByteSize else {
            view.makeToast("이미지 용량이 너무 커요. 다른 사진으로 시도해주세요.", duration: 2.0, position: .top)
            return
        }

        ticketImageRelay.accept((imageData: jpegData, mimeType: "image/jpeg"))
    }

    /// 긴 변 기준 최대 해상도로 축소한 뒤, 목표 용량 이하가 될 때까지 JPEG 압축률을 낮춘다.
    fileprivate static func compressedTicketImageData(
        from image: UIImage,
        maxDimension: CGFloat = 2000,
        targetByteSize: Int = 3 * 1024 * 1024
    ) -> Data? {
        let resized = resized(image, maxDimension: maxDimension)

        var quality: CGFloat = 0.8
        var data = resized.jpegData(compressionQuality: quality)

        while let currentData = data, currentData.count > targetByteSize, quality > 0.3 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }

        return data
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

//MARK: - PHPickerViewControllerDelegate (앨범 선택)

extension TravelAddViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        // results가 비어 있으면 사용자가 취소한 것으로, 별도 안내 없이 조용히 종료한다.
        guard let provider = results.first?.itemProvider else { return }

        guard provider.canLoadObject(ofClass: UIImage.self) else {
            view.makeToast("지원하지 않는 이미지 형식이에요. 다른 사진으로 시도해주세요.", duration: 2.0, position: .top)
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                self?.handlePickedTicketImage(object as? UIImage)
            }
        }
    }
}

//MARK: - TicketCameraViewControllerDelegate (사각형 가이드로 잘라낸 촬영 결과)

extension TravelAddViewController: TicketCameraViewControllerDelegate {
    func ticketCamera(_ controller: TicketCameraViewController, didCapture image: UIImage) {
        controller.dismiss(animated: true) { [weak self] in
            self?.handlePickedTicketImage(image)
        }
    }

    func ticketCameraDidCancel(_ controller: TicketCameraViewController) {
        controller.dismiss(animated: true)
    }
}
