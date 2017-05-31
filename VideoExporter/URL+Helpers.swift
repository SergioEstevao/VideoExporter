import Foundation
import AVFoundation
import ImageIO
import MobileCoreServices

extension URL {

    public var fileSize: NSNumber? {
        guard isFileURL else { return nil }
        do {
            let data = try bookmarkData(options:.minimalBookmark, includingResourceValuesForKeys:[.fileSizeKey])
            guard let resourceValues = URL.resourceValues(forKeys:[.fileSizeKey], fromBookmarkData:data),
                let fileSize = resourceValues.fileSize else {
                    return nil
            }
            return fileSize as NSNumber
        } catch let error as NSError {
            print(error.debugDescription)
            return nil
        }
    }

    var pixelSize: CGSize {
        get {
            if isVideo {
                let asset = AVAsset(url: self as URL)
                if let track = asset.tracks(withMediaType: AVMediaTypeVideo).first {
                    let size = track.naturalSize.applying(track.preferredTransform)
                    return CGSize(width: abs(size.width), height: abs(size.height))
                }
            } else if isImage {
                let options: [NSString: NSObject] = [kCGImageSourceShouldCache: false as CFBoolean]
                if
                    let imageSource = CGImageSourceCreateWithURL(self as CFURL, nil),
                    let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options as CFDictionary?) as NSDictionary?,
                    let pixelWidth = imageProperties[kCGImagePropertyPixelWidth as NSString] as? Int,
                    let pixelHeight = imageProperties[kCGImagePropertyPixelHeight as NSString] as? Int
                {
                    return CGSize(width: pixelWidth, height: pixelHeight)
                }
            }
            return CGSize.zero
        }
    }

    var typeIdentifier: String? {
        guard isFileURL else { return nil }
        do {
            let data = try bookmarkData(options: NSURL.BookmarkCreationOptions.minimalBookmark, includingResourceValuesForKeys: [URLResourceKey.typeIdentifierKey], relativeTo: nil)
            guard
                let resourceValues = NSURL.resourceValues(forKeys: [URLResourceKey.typeIdentifierKey], fromBookmarkData: data),
                let typeIdentifier = resourceValues[URLResourceKey.typeIdentifierKey] as? String else {
                    return nil
            }
            return typeIdentifier
        } catch {
            return nil
        }
    }

    var mimeType: String {
        guard let uti = typeIdentifier,
            let mimeType = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType)?.takeUnretainedValue() as String?
            else {
                return "application/octet-stream"
        }

        return mimeType
    }

    var isVideo: Bool {
        guard let uti = typeIdentifier else {
            return false
        }

        return UTTypeConformsTo(uti as CFString, kUTTypeMovie)
    }

    var isImage: Bool {
        guard let uti = typeIdentifier else {
            return false
        }

        return UTTypeConformsTo(uti as CFString, kUTTypeImage)
    }

    public static func URLForTemporaryFileWithFileExtension(_ fileExtension: String) -> URL {
        assert(!fileExtension.isEmpty, "file Extension cannot be empty")
        let fileName = "\(ProcessInfo.processInfo.globallyUniqueString)_file.\(fileExtension)"
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        return fileURL
    }

    public static func URLForTemporaryFileWithFilename(_ filename: String) -> URL? {
        assert(!filename.isEmpty, "file name cannot be empty")
        let extraPath = "\(ProcessInfo.processInfo.globallyUniqueString)"
        let pathURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(extraPath)
        do {
            try FileManager.default.createDirectory(at: pathURL,
                                                    withIntermediateDirectories:true, attributes:nil)
        } catch {
            return nil
        }
        return pathURL.appendingPathComponent("/\(filename)")
    }

    public static func applicationDataDirectory() -> URL? {
        let sharedFM = FileManager.default
        let possibleURLs = sharedFM.urls(for:.applicationSupportDirectory,
                                         in:[.userDomainMask])
        guard
            let appSupportDir = possibleURLs.first,
            let appBundleID = Bundle.main.bundleIdentifier
            else {
                return nil
        }

        let appDirectory = appSupportDir.appendingPathComponent(appBundleID)
        do {
            try FileManager.default.createDirectory(at: appDirectory,
                                                    withIntermediateDirectories:true, attributes:nil)
        } catch {
            return nil
        }
        return appDirectory
    }

    public static func documentDirectory() -> URL? {
        let possibleURLs = FileManager.default.urls(for:.documentDirectory,
                                                    in:[.userDomainMask])
        guard let documentsDirectory = possibleURLs.first
            else {
                return nil
        }
        
        return documentsDirectory
    }
}
