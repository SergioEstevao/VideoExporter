import Foundation
import Photos

extension PHAsset {

    func originalUTI() -> String? {
        let resources = PHAssetResource.assetResources(for: self)
        var types: [PHAssetResourceType.RawValue] = []
        if (mediaType == PHAssetMediaType.image) {
            types = [PHAssetResourceType.photo.rawValue]
        } else if (mediaType == PHAssetMediaType.video) {
            types = [PHAssetResourceType.video.rawValue]
        }
        for resource in resources {
            if (types.contains(resource.type.rawValue) ) {
                return resource.uniformTypeIdentifier
            }
        }
        return nil
    }

    func originalFilename() -> String? {
        let resources = PHAssetResource.assetResources(for: self)
        var types: [PHAssetResourceType.RawValue] = []
        if (mediaType == PHAssetMediaType.image) {
            types = [PHAssetResourceType.photo.rawValue]
        } else if (mediaType == PHAssetMediaType.video) {
            types = [PHAssetResourceType.video.rawValue]
        }
        for resource in resources {
            if (types.contains(resource.type.rawValue) ) {
                return resource.originalFilename
            }
        }
        return nil
    }
}
