//
//  LinkPreviewImageLoader.swift
//  TravelLog
//
//  Created by 이상민 on 7/5/26.
//

import LinkPresentation
import UIKit

enum LinkPreviewImageLoader {
    static func loadImage(from metadata: LPLinkMetadata, completion: @escaping (UIImage?) -> Void) {
        let providers = [
            metadata.imageProvider,
            metadata.iconProvider
        ].compactMap { $0 }

        loadImage(from: providers[...], completion: completion)
    }

    private static func loadImage(
        from providers: ArraySlice<NSItemProvider>,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard let provider = providers.first else {
            completion(nil)
            return
        }

        guard provider.canLoadObject(ofClass: UIImage.self) else {
            loadImage(from: providers.dropFirst(), completion: completion)
            return
        }

        provider.loadObject(ofClass: UIImage.self) { imageObject, _ in
            if let image = imageObject as? UIImage {
                completion(image)
            } else {
                loadImage(from: providers.dropFirst(), completion: completion)
            }
        }
    }
}
