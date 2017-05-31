import Foundation
import Photos
import MobileCoreServices
import AVFoundation

typealias SuccessHandler = () -> ()
typealias ProgressHandler = (_ progress: Float) -> ()
typealias ErrorHandler = (_ error: NSError) -> ()


class VideoExporter: NSObject {

    let asset: PHAsset
    let preset: String
    let exportURL: URL
    let targetUTI: String

    var timeToRequestSession: TimeInterval = 0
    var timeToExport: TimeInterval = 0
    var exportSession: AVAssetExportSession?
    var startExport: Bool = false
    var successHandler: SuccessHandler
    var progressHandler: ProgressHandler?
    var errorHandler: ErrorHandler
    var timer: Timer?

    static private var progressObserverContext: String = "progressObserverContext"

    init(asset: PHAsset, preset: String, destinationURL: URL, targetUTI: String? = nil,
         successHandler: @escaping SuccessHandler,
         progressHandler: ProgressHandler?,
         errorHandler: @escaping ErrorHandler)
    {
        self.asset = asset
        self.preset = preset
        self.exportURL = destinationURL
        self.targetUTI = targetUTI ?? asset.originalUTI()!
        self.successHandler = successHandler
        self.progressHandler = progressHandler
        self.errorHandler = errorHandler
    }

    func export()
    {
        startExport = true
        var startDate = CACurrentMediaTime()
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestExportSession(forVideo: asset,
                                                      options: options,
                                                      exportPreset: preset) {
        (exportSession, info) -> Void in
            self.timeToRequestSession = CACurrentMediaTime() - startDate
            guard let exportSession = exportSession
                else {
                    if let error = info?[PHImageErrorKey] as? NSError {
                        self.errorHandler(error)
                    } else {
                        let failureReason = NSLocalizedString("Failed to create export session.",
                                                              comment: "Error reason to display when the export of a video from device library fails")
                        self.errorHandler(ErrorCode.failedToExport.errorWith(failureReason: failureReason))
                    }
                    return
            }
            self.exportSession = exportSession
            exportSession.outputFileType = self.targetUTI
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.outputURL = self.exportURL
            if self.progressHandler != nil {
                exportSession.addObserver(self, forKeyPath: #keyPath(AVAssetExportSession.status), options:[.new], context:&VideoExporter.progressObserverContext)
                DispatchQueue.main.async {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer) in
                        self.refreshProgress()
                    })
                }
            }
            startDate = CACurrentMediaTime()
            exportSession.exportAsynchronously(completionHandler: { () -> Void in
                self.timeToExport = CACurrentMediaTime() - startDate
                if self.progressHandler != nil {
                    exportSession.removeObserver(self, forKeyPath: #keyPath(AVAssetExportSession.status))
                }
                guard exportSession.status == .completed else {
                    if let error = exportSession.error {
                        self.errorHandler(error as NSError)
                    } else {
                        let failureReason = NSLocalizedString("Failed to export.",
                                                              comment: "Error reason to display when the export of a video from device library fails")
                        self.errorHandler(ErrorCode.failedToExport.errorWith(failureReason: failureReason))
                    }
                    return
                }
                self.successHandler()
            })
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard
            context == &VideoExporter.progressObserverContext,
            keyPath == #keyPath(AVAssetExportSession.status)
            else {
                super.observeValue(forKeyPath: keyPath,
                                   of: object,
                                   change: change,
                                   context: context)
                return
        }

        refreshProgress()
    }

    func refreshProgress() {
        if let exportSession = self.exportSession {
            switch exportSession.status {
            case .cancelled, .completed:
                self.timer?.invalidate()
                self.timer = nil
            default:
                break
            }
        }
        DispatchQueue.main.async {
            if let progress = self.exportSession?.progress {
                self.progressHandler?(progress)
            } else {
                self.progressHandler?(0)
            }
        }
    }

    var progress: Float {
        if let progress = self.exportSession?.progress {
            return progress
        } else {
            return 0
        }
    }

    var status: String {
        if !startExport {
            return NSLocalizedString("Waiting on Queue", comment:"")
        }

        guard let exportSession = self.exportSession else {
            return NSLocalizedString("Downloading asset data", comment:"")
        }
        switch exportSession.status {
        case .unknown:
            return NSLocalizedString("Unknow", comment:"")
        case .cancelled:
            return NSLocalizedString("Cancelled", comment:"")
        case .completed:
            return NSLocalizedString("Completed", comment:"")
        case .exporting:
            return NSLocalizedString("Exporting", comment:"")
        case .failed:
            return NSLocalizedString("Failed", comment:"")
        case .waiting:
            return NSLocalizedString("Waiting", comment:"")

        }
    }

    var resultPixelSize: CGSize? {
        if !self.exportURL.isVideo {
            return nil
        }
        return self.exportURL.pixelSize
    }

    var resultFileSize: NSNumber? {
        return self.exportURL.fileSize
    }

    enum ErrorCode: Int {
        case unsupportedAssetType = 1
        case failedToExport = 2

        func errorWith(failureReason: String) -> NSError {
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: "VideoExporter+ErrorCode", code: self.rawValue, userInfo: userInfo)

            return error
        }
    }

}
