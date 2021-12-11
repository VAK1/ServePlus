//
//  MiddlePracticeViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/4/21.
//

import UIKit
import AVFoundation
import Foundation
import CoreGraphics

class MiddlePracticeViewController: UIViewController {

    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    let productionMode = true

    let defaults = UserDefaults.standard

    var practices:[Practice]?
    var dateLabels:[String]?
    var serveLabels:[String]?
    var durationLabels:[String]?
    var bestLabels:[String]?
    var worstLabels:[String]?
    var thumbnails:[UIImage]?
    let iconNames: [String] = [
                               "Back Arch",
                               "Feet Spacing",
                               "Back Leg Kicking Back",
                               "Jump Height",
                               "Straight Left Arm",
                               "Bending Legs",
                               "Timing of Shoulder Turn",
                               "Height of Ball Toss",
                               ]
    var urls: [URL]?
    var timestamps: [[Int]]?
    var vectors: [[Double]]?
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyTableMessage: UILabel!
    @IBOutlet weak var emptyTableView: UIView!
    @IBOutlet weak var emptyTableImage: UIImageView!
    
    var practiceToSegue: Practice?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Review"
        
        let bundleId = "VikramKhandelwal.ServePlus"
        let appUpdater = AppUpdateManager()
        let updateStatus = appUpdater.updateStatus(for: bundleId)

        if let alertController = UIAlertController(for: updateStatus) {
            self.present(alertController, animated: true)
        }
        
        if self.productionMode == false {
            defaults.set(false, forKey: "First Launch")
        }
        if !defaults.bool(forKey: "First Launch") == true {
            self.conductTutorial()
            defaults.set(true, forKey: "First Launch")
        }
        
        let bgImage = UIImage(named: "DefaultBackground")
        let imgWidth = bgImage!.size.width
        let imgHeight = bgImage!.size.height
        
        print(emptyTableView.frame.size)
        print(emptyTableImage.frame.size)
        
        let ratio = imgWidth/emptyTableImage.frame.width
        
        let realHeight = imgHeight/ratio
        
        emptyTableImage.frame.size = CGSize(width: emptyTableImage.frame.width, height: CGFloat(realHeight))
        
        print(emptyTableView.frame.size)
        print(emptyTableImage.frame.size)
        
        emptyTableImage.image = bgImage
        emptyTableImage.blurImage()

        let nib1 = UINib(nibName: "WideVideoCell", bundle: nil)
        tableView.register(nib1, forCellReuseIdentifier: "WideVideoCell")
        let nib2 = UINib(nibName: "TallVideoCell", bundle: nil)
        tableView.register(nib2, forCellReuseIdentifier: "TallVideoCell")
        tableView.delegate = self
        tableView.dataSource = self
        
        fetchPractices()
        tableView.refreshControl = UIRefreshControl()
        tableView.refreshControl?.addTarget(self,
                                            action: #selector(pullRefresh),
                                            for: .valueChanged)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        let currentCount = self.practices!.count
        DispatchQueue.main.async {
            self.fetchPractices()
            if self.practices!.count != currentCount {
                self.tableView.reloadData()
            }
        }



    }
    
    func conductTutorial() {
        print("hi")
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            self.performSegue(withIdentifier:"OnboardingSegue", sender: self)
        }
    }
    
    @objc private func pullRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            self.fetchPractices()
            self.tableView.reloadData()
            self.tableView.refreshControl?.endRefreshing()

        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "buttonSegueFeedback" {
            if let destinationVC = segue.destination as? FeedbackController {
                destinationVC.practice = self.practiceToSegue
            }
        }
        if segue.identifier == "OnboardingSegue" {
            if let destinationVC = segue.destination as? OnboardingController {
            }
        }
    }
    
    func doSegue(_ practiceIndex: Int) {
        self.practiceToSegue = self.practices![practiceIndex]
        self.performSegue(withIdentifier: "buttonSegueFeedback", sender: self)
    }
    
    func getThumbnailImage(url: URL) -> UIImage? {
        let asset = AVAsset(url: url) //2
        let avAssetImageGenerator = AVAssetImageGenerator(asset: asset) //3
        avAssetImageGenerator.appliesPreferredTrackTransform = true //4
        let thumnailTime = CMTimeMake(value: 2, timescale: 1) //5
        do {
            let cgThumbImage = try avAssetImageGenerator.copyCGImage(at: thumnailTime, actualTime: nil) //6
            let thumbNailImage = UIImage(cgImage: cgThumbImage).withRoundedCorners(radius: 30.0) //7
            return thumbNailImage
        } catch {
            print(error.localizedDescription) //10
            return nil
        }

    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let ratio = thumbnails![indexPath.row].size.width / thumbnails![indexPath.row].size.height
        if ratio > 1 {
            return (tableView.frame.width-40) / ratio + 120
        }
        else {
            return ((tableView.frame.width-40) * 0.6) / ratio + 30
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            self.thumbnails!.remove(at:indexPath.row)
            
            self.serveLabels!.remove(at:indexPath.row)
            self.dateLabels!.remove(at:indexPath.row)
            self.durationLabels!.remove(at:indexPath.row)
            
            self.deletePractice(self.practices![indexPath.row])
            self.practices!.remove(at: indexPath.row)

            
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            tableView.endUpdates()
        }
    }
    
    func fetchPractices() {
        do {
            self.practices = try self.context.fetch(Practice.fetchRequest())
            self.practices = self.practices!.reversed()
            
            var dateLabels:[String] = []
            var serveLabels:[String] = []
            var durationLabels:[String] = []
            var bestLabels:[String] = []
            var worstLabels:[String] = []
            var imgs:[UIImage] = []
            
            for practice in self.practices! {
                
                if let img = self.getThumbnailImage(url: practice.urls![0]) {
                    imgs.append(img)
                }
                
                let date = practice.date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, y | hh:mm"
                dateLabels.append(dateFormatter.string(from: date!))
                
                
                if (practice.vectors!.count) == 1 {
                    serveLabels.append("1 serve")
                }
                else {
                    serveLabels.append(String(practice.vectors!.count) + " serves")
                }
                
                let durationTime = Float64(CMTimeGetSeconds(AVAsset(url: practice.urls![0]).duration))

                if durationTime < 60.0 {
                    if Int(ceil(durationTime)) % 60 == 1 {
                        durationLabels.append("1 second")
                    }
                    else {
                        durationLabels.append(String(Int(ceil(durationTime)) % 60) + " seconds")
                    }
                }
                else if durationTime > 120.0 {
                    if (Int(durationTime) % 60) > 0 {
                        if Int(durationTime) % 60 == 1 {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minutes and 1 second")
                        }
                        else {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minutes and " + String(Int(durationTime) % 60) + " seconds")
                        }
                    }
                    else {
                        durationLabels.append(String(Int(floor(durationTime / 60))) + " minutes")
                    }
                }
                else {
                    if (Int(durationTime) % 60) > 0 {
                        if Int(durationTime) % 60 == 1 {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minute and 1 second")
                        }
                        else {
                            durationLabels.append(String(Int(floor(durationTime / 60))) + " minute and " + String(Int(durationTime) % 60) + " seconds")
                        }
                    }
                    else {
                        durationLabels.append(String(Int(floor(durationTime / 60))) + " minute")
                    }
                }
                
                let serveVectors = practice.vectors!
                let count = Double(serveVectors.count)
                var finals = [Double](repeating: 0.0, count: 8)
                for vector in serveVectors {
                    finals[0] += (2.0 - Double(abs(2-vector[0])))/(count*2.0)
                    finals[1] += (2.0 - Double(abs(2-vector[1])))/(count*2.0)
                    finals[2] += vector[2]/count
                    finals[3] += vector[3]/(count*4)
                    finals[4] += vector[4]/count
                    finals[5] += (3.0 - Double(abs(3-vector[5])))/(count*3.0)
                    finals[6] += (2.0 - Double(abs(2-vector[6])))/(count*2.0)
                    finals[7] += (2.0 - Double(abs(2-vector[7])))/(count*2.0)
                }
                let minIndex = zip(finals.indices, finals).min(by: { $0.1 < $1.1 })?.0
                let maxIndex = zip(finals.indices, finals).max(by: { $0.1 < $1.1 })?.0
                bestLabels.append("Best part: " + String(self.iconNames[maxIndex!]))
                worstLabels.append("Worst part: " + String(self.iconNames[minIndex!]))
            }
            self.dateLabels = dateLabels
            self.serveLabels = serveLabels
            self.durationLabels = durationLabels
            self.bestLabels = bestLabels
            self.worstLabels = worstLabels
            self.thumbnails = imgs
        } catch {
            
        }
    }
    
    
    
    func deletePractice(_ practice: Practice) {
        self.context.delete(practice)
        do {
            try self.context.save()
        } catch {
            print("Couldn't save practices after deleting")
        }
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
extension MiddlePracticeViewController: UITableViewDataSource{
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.practices!.count == 0 {
             self.tableView.setEmptyMessage(self.emptyTableView, label: self.emptyTableMessage)
        } else {
            self.tableView.restore(self.emptyTableView)
        }
        return self.practices!.count
    }
    
}
extension MiddlePracticeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        

        let vidUrl = self.practices![indexPath.row].urls![0]
        let img = self.thumbnails![indexPath.row]

//        let avPlayer = AVQueuePlayer(url: vidUrl)
//        avPlayer.isMuted = true
//
//        let playerItem = AVPlayerItem(url: vidUrl)
//        let duration = Float64(CMTimeGetSeconds(AVAsset(url: vidUrl).duration))
//        let avAsset = AVURLAsset(url: vidUrl, options: nil)
//        var findHeight = true
        let size = img.size
        let width = abs(Int(size.width))
        let height = abs(Int(size.height))
        
//
//        let composition = AVVideoComposition(asset: avAsset, applyingCIFiltersWithHandler: { request in })
//        let startTime = 0.0
//        let endTime = duration
//
//        let playerLooper = AVPlayerLooper(player: avPlayer as! AVQueuePlayer, templateItem: playerItem,
//                                                       timeRange: CMTimeRange(start: CMTimeMakeWithSeconds(startTime, preferredTimescale: 1000), end: CMTimeMakeWithSeconds(endTime, preferredTimescale: 1000)) )
//
//
        
        if (width > height) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "WideVideoCell", for: indexPath)  as! WideVideoCell
            cell.pSegue = self.doSegue
            cell.index = indexPath.row
            cell.VideoPlayer?.image = self.thumbnails![indexPath.row]
            
            cell.serveCountLabel?.text = self.serveLabels![indexPath.row]
            cell.vidDurationLabel?.text = self.dateLabels![indexPath.row]
            cell.timeLabel?.text = self.durationLabels![indexPath.row]


            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TallVideoCell", for: indexPath) as! TallVideoCell
            cell.index = indexPath.row
            cell.pSegue = self.doSegue
            cell.VideoPlayer?.image = self.thumbnails![indexPath.row]


            cell.serveCountLabel?.text = self.serveLabels![indexPath.row]
            cell.vidDurationLabel?.text = self.dateLabels![indexPath.row]
            cell.timeLabel?.text = self.durationLabels![indexPath.row]


            return cell
        }
        
    }
    
   
    


}
extension UIImage {
        // image with rounded corners
        public func withRoundedCorners(radius: CGFloat? = nil) -> UIImage? {
            let maxRadius = min(size.width, size.height) / 2
            let cornerRadius: CGFloat
            if let radius = radius, radius > 0 && radius <= maxRadius {
                cornerRadius = radius
            } else {
                cornerRadius = maxRadius
            }
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()
            draw(in: rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image
        }
    }
extension UITableView {
    

    func setEmptyMessage(_ view: UIView, label: UILabel) {

        view.backgroundColor = UIColor.systemBlue
        label.text = "Welcome to ServePlus!\n\nStart improving your serve immediately by heading over to the 'Record and Upload' tab on the left.\n\nAfter recording a serve, you can come back here to review areas of improvement."
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20)
        
        label.sizeToFit()
        view.isHidden = false
        self.isHidden = true
    }

    func restore(_ view: UIView) {
        self.isHidden = false
        view.isHidden = true
    }
}

extension UIImageView{
    func blurImage()
    {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.bounds

        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight] // for supporting device rotation
        self.addSubview(blurEffectView)
    }
}
