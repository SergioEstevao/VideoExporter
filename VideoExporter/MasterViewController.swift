import UIKit
import MobileCoreServices
import Photos
import AVKit

class MasterViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var objects = [VideoExporter]()
    let exportQueue = DispatchQueue(label: "video export queue")
    var exportItems = [VideoExporter]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItem = addButton

        let shareButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share(_:)))
        navigationItem.leftBarButtonItem = shareButton
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func insertNewObject(_ sender: Any) {
        let mediaPicker = UIImagePickerController()
        mediaPicker.mediaTypes = [kUTTypeMovie as String]
        mediaPicker.videoQuality = .typeLow
        mediaPicker.delegate = self
        self.present(mediaPicker, animated: true, completion: nil)
    }

    func share(_ sender: Any) {
        let csvFileURL = saveExportResults()

        let activityViewController = UIActivityViewController(activityItems:[csvFileURL], applicationActivities:nil)
        activityViewController.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(activityViewController, animated:true, completion:nil);
    }

    func saveExportResults() -> URL {
        let fileURL = URL.URLForTemporaryFileWithFilename("IOS Video Transcoding Stats.csv")!
        var text = "Preset, Width (px), Height (px), Size (MB), Time (s)\n"

        for exporter in objects {
            guard exporter.exportSession?.status == .completed else {
                continue
            }
            text += "\(exporter.preset.replacingOccurrences(of: "AVAssetExportPreset", with: "")),\(exporter.exportURL.pixelSize.width),\(exporter.exportURL.pixelSize.height), \(exporter.exportURL.fileSize!.doubleValue / (1024.0*1024.0)), \(exporter.timeToExport)\n"
        }
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let object = objects[indexPath.row]
        var text = object.preset.replacingOccurrences(of: "AVAssetExportPreset", with: "")
        text += " " + object.status
        text += " \(percentFormatter.string(from:NSNumber(value: object.progress))!)"
        var detail: String = ""
        if (object.progress == 1) {
            if let fileSize = object.resultFileSize {
                detail += "size: \(ByteCountFormatter.string(fromByteCount: fileSize.int64Value, countStyle: ByteCountFormatter.CountStyle.file)) "
            }
            if let pixelSize = object.resultPixelSize {
                detail += "resolution: \(NSStringFromCGSize(pixelSize)) "
            }
            if object.timeToExport != 0 {
                detail += "time: \(timeIntervalFormatter.string(from: object.timeToExport)!)"
            }
        }
        cell.textLabel!.text = text
        cell.detailTextLabel!.text = detail
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            objects.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let exporter = objects[indexPath.row]
        if (exporter.status == "Completed") {
            let playerViewController = AVPlayerViewController()
            playerViewController.player = AVPlayer(url: exporter.exportURL)
            self.present(playerViewController, animated: true, completion: nil)
        }
    }

    func startExportOf(asset: PHAsset) {
        let presets = [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality, AVAssetExportPresetMediumQuality, AVAssetExportPresetLowQuality, AVAssetExportPreset1920x1080, AVAssetExportPreset1280x720, AVAssetExportPreset960x540]
        for preset in presets {
            guard let tempURL = URL.URLForTemporaryFileWithFilename(asset.originalFilename() ?? "Unknow") else {
                continue
            }
            let position = objects.count
            let videoExporter = VideoExporter(asset: asset, preset: preset, destinationURL: tempURL,
                                              successHandler: { () in
                self.nextItem()
            }, progressHandler: { (progress) in
                DispatchQueue.main.async {
                    self.tableView.reloadRows(at: [IndexPath(row:position, section:0)], with: .none)
                }
            }, errorHandler: { (error) in
                self.nextItem()
            })
            objects.append(videoExporter)
            exportItems.append(videoExporter)
        }
        nextItem()
        self.tableView.reloadData()
    }

    func nextItem() {
        self.exportQueue.async {
            if self.exportItems.isEmpty {
                return
            }
            let exporter = self.exportItems.removeFirst()
            exporter.export()
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    lazy var percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = NumberFormatter.Style.percent
        return formatter
    }()

    lazy var timeIntervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()
}


extension MasterViewController {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let originalURL = info[UIImagePickerControllerReferenceURL] as? URL,
              let asset = PHAsset.fetchAssets(withALAssetURLs: [originalURL], options: nil).firstObject
        else {
            return
        }
        print("\(asset)")
        self.dismiss(animated: true) { 
            self.startExportOf(asset: asset)
        }
    }
}
