import UIKit
import SwiftUI
import AVFoundation
import Vision
import Photos
import CoreGraphics
import MobileCoreServices


let imgWidth = 736        // constant for sending video frames to pose analysis


class CameraViewController: UIViewController {
        
        
    let com = {
        Common(imgWidth,imgWidth)
    }()
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    

    //"You can toggle which feedback points to inspect with the buttons above."
    //"Finish tutorial"
    
    @IBOutlet weak var HomeView: UIView!
    @IBOutlet weak var RecordingView: UIImageView!
    
    @IBOutlet weak var ReplayView: UIImageView!
    @IBOutlet weak var messageLabel: UILabelStroked!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabelStroked!
    
    @IBOutlet weak var playerBoxBorder: UIView!
    @IBOutlet weak var playerBoxBorderPulsating: UIView!
    @IBOutlet weak var serveIcon: UIImageView!

    
    @IBOutlet weak var captureButton: UIButton!
    @IBAction func tappedCaptureButton(sender: UIButton) {
        shootVideo()
    }
    
    @IBOutlet weak var selectButton: UIButton!
    @IBAction func tappedSelectButton(sender: UIButton) {
        selectVideo()
    }
    
    
    @IBOutlet weak var serveAnalysisButton: UIButton!
    @IBAction func tappedAnalysisButton(sender: UIButton) {
        show(self.child!, sender: self)
    }
    

    var child: ServeAnalysisViewController? = nil

    
    var iconNames: [String] = [
                               "BendBackTransparent",
                               "FeetSpacingTransparent",
                               "LegKickBackTransparent",
                               "JumpTransparent",
                               "LeftArmTransparent",
                               "BendLegsTransparent",
                               "ShoulderTurnTransparent",
                               "BallTossTransparent",
                               ]
    var serveVectorArray: [[Double]] = []
    var lh_values: [Double] = []
    var rh_values: [Double] = []
    var urlArray: [URL] = []
    var allServeMLArrays: [[[Double]]] = []

    
    var feedbackCategories = ["Back arched", "Feet spacing", "Back leg follow through", "Jump height", "Left arm straight", "Legs bent", "Timing of shoulder rotation", "Toss height"]
    var FeedbackRankings = [
        ["Too little.", "Just a little lacking.", "Perfect!", "A little too much.", "Way too much."],
        ["Too close.", "A little too close.", "Perfect!", "A little too far.", "Too far apart."],
        ["Didn't kick back", "Perfect!"],
        ["Barely any jump.", "Just a little jump.", "Average jump.", "Fantastic jump!", "Perfect!"],
        ["Crooked left arm.", "Perfect!"],
        ["Barely any bending.", "Average amount of bend.", "Almost perfect!", "Perfect!", "A little too much bend."],
        ["Too early", "Just a little early", "Perfect!", "Just a little late", "Too late."],
        ["Too low", "Just a little too low", "Perfect!", "A little too high."]
    ]
    var feedbackColors = [
        [UIColor(red:0.0, green:0.0, blue:0.0, alpha: 0.0)],
        [UIColor(red:0.0, green:0.0, blue:0.0, alpha: 0.0)],
        [
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0)
        ],
        [UIColor(red:0.0, green:0.0, blue:0.0, alpha: 0.0)],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0)
        ],
        [
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:172/255, green:252/255, blue:131/255, alpha: 1.0),
            UIColor(red:252/255, green:131/255, blue:131/255, alpha: 1.0),
            UIColor(red:181/255, green:62/255, blue:62/255, alpha: 1.0)
        ]
    ]
    var currentCategory = 6
    
    
    
    
        
    let targetImageSize = CGSize(width: imgWidth, height: imgWidth)
    var captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    var cameraLayer: AVCaptureVideoPreviewLayer!
    
    let fileOutput = AVCaptureMovieFileOutput()
    var isRecording = false
    var selectedFileURL: URL?
    var editingImage: UIImage?
    var completedDetection: Bool = false
    
    var deviceType: UIUserInterfaceIdiom?
    var isIPhoneX: Bool = false
    
    var canUseCamera: Bool?
    var canUsePhotoLibrary: Bool?
    
    var allVideoPoses: [[Double]] = []
    var timestamp_frames : [[Int]] = []
    
    var BAModel = try? backArchXGBoost(configuration: MLModelConfiguration())
    var BLModel = try? backLegKickedBackXGBoost(configuration: MLModelConfiguration())
    var FSModel = try? feetSpacingXGBoost(configuration: MLModelConfiguration())
    var JHModel = try? jumpHeightXGBoost(configuration: MLModelConfiguration())
    var LAModel = try? leftArmStraightXGBoost(configuration: MLModelConfiguration())
    var LBModel = try? legsBentXGBoost(configuration: MLModelConfiguration())
    var STModel = try? shoulderTimingXGBoost(configuration: MLModelConfiguration())
    var THModel = try? tossHeightXGBoost(configuration: MLModelConfiguration())
        
    //Back Arched
    var backAngles: [Double] = []
    

    //Back Leg Kicked Back
    var pt10xs: [Double] = []
    var pt10ys: [Double] = []
    var pt13xs: [Double] = [] //also for Jump Height
    var pt13ys: [Double] = [] //also for Jump Height
    var leftLegAngles: [Double] = [] //also for legs bent and shoulder rotation
    var rightLegAngles: [Double] = [] // also for legs bent and shoulder rotation
    var inputURL: URL?
    //Feet Spacing
    
    //Left Arm Straight
    var leftHandAngles: [Double] = []
    var rightHandAngles: [Double] = []
    
    //Shoulder Rotation
    
    //Toss height
    var pt2xs: [Double] = []
    var pt3xs: [Double] = []
    var pt4xs: [Double] = []
    var pt5xs: [Double] = []
    var pt6xs: [Double] = []
    var pt7xs: [Double] = []
    var pt2ys: [Double] = []
    var pt3ys: [Double] = []
    var pt4ys: [Double] = []
    var pt5ys: [Double] = []
    var pt6ys: [Double] = []
    var pt7ys: [Double] = []
    
    
    var orientation: UIImage.Orientation = UIImage.Orientation.down
    let shapeLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController!.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationController!.navigationBar.isTranslucent = true
        
        title = "Record and Upload"
                
        
        if (self.child == nil) {
            self.serveAnalysisButton.isHidden = true
        }
        
        deviceType = UIDevice.current.userInterfaceIdiom
        guard deviceType == .phone || deviceType == .pad else {
            fatalError("ERROR: Invalid device.")
        }
        
        let deviceName = com.getDeviceName()
        if deviceType == .phone && deviceName.range(of: "iPhone10") != nil {
            isIPhoneX = true
        }
                
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        
        cameraLayer = AVCaptureVideoPreviewLayer(session: self.captureSession) as AVCaptureVideoPreviewLayer
        cameraLayer.frame = self.view.bounds
        cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        RecordingView.layer.addSublayer(cameraLayer)
        
        messageLabel.strokedText = "Start serving inside box"
        
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.layer.borderWidth = 3
        
        serveAnalysisButton.backgroundColor =  UIColor(red: 3/255, green: 57/255, blue: 248/255, alpha: 0.9)
        serveAnalysisButton.layer.cornerRadius = serveAnalysisButton.frame.height/2
        serveAnalysisButton.layer.shadowOpacity = 0.25
        serveAnalysisButton.layer.shadowRadius = 5
        serveAnalysisButton.layer.shadowOffset = CGSize(width: 0, height: 10)
        
        
        let center = serveAnalysisButton.center
        let circularPath = UIBezierPath(arcCenter: CGPoint(serveAnalysisButton.frame.width/2, serveAnalysisButton.frame.height/2), radius: (serveAnalysisButton.frame.height/2 + 5.0), startAngle: -CGFloat.pi/2, endAngle: 2*CGFloat.pi-CGFloat.pi/2, clockwise: true)
        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeEnd = 0
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        
        shapeLayer.strokeColor = CGColor(red: 3/255, green: 57/255, blue: 248/255, alpha: 0.3)
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 10
        
                
        serveAnalysisButton.layer.addSublayer(shapeLayer)
        serveAnalysisButton.setTitle("0%", for: .normal)
        
        serveIcon.alpha = 0.4
        
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if response {
                self.canUseCamera = true
                DispatchQueue.main.async {
                    self.captureButton.isHidden = false
                }
                self.setupCamera()
            } else {
                self.canUseCamera = false
            }
        }
        
        PHPhotoLibrary.requestAuthorization() { (status) -> Void in
            if status == .authorized {
                self.canUsePhotoLibrary = true
                self.updateSelectButton()
            } else {
                self.canUsePhotoLibrary = false
                DispatchQueue.main.async {
                    self.captureButton.isHidden = true
                }
            }
        }
    }
    
    func animatePulsatingLayer() {
        let anim = CABasicAnimation(keyPath: "transform.scale")
        
        anim.toValue = 1.2
        anim.duration = 0.4
        anim.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        anim.autoreverses = true
        anim.repeatCount = Float.infinity
        
        playerBoxBorderPulsating.layer.add(anim, forKey: "pulsing")
        
        
    }
    
    func handleProgressChange(_ newProgress: Double) {
        
        serveAnalysisButton.setTitle(String(Int(newProgress)) + "%", for: .normal)
        
        let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")
        
        basicAnimation.toValue = newProgress/100
        basicAnimation.duration = 1
        
        basicAnimation.fillMode = CAMediaTimingFillMode.forwards
        basicAnimation.isRemovedOnCompletion = false
        
        shapeLayer.add(basicAnimation, forKey: "urSoBasic")
        shapeLayer.strokeEnd = CGFloat(newProgress/100)
        
        if newProgress == 100.0 {
            self.child = nil
            DispatchQueue.main.async {
                self.serveAnalysisButton.isHidden = true
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playerBoxBorder.layer.borderColor = CGColor(red: 0.0, green: 34/255, blue: 238/255, alpha: 0.75)
        playerBoxBorder.layer.borderWidth = 10.0
        playerBoxBorder.layer.cornerRadius = 10.0
        
        playerBoxBorderPulsating.layer.borderColor = CGColor(red: 0.0, green: 44/255, blue: 248/255, alpha: 0.50)
        playerBoxBorderPulsating.layer.borderWidth = 10.0
        playerBoxBorderPulsating.layer.cornerRadius = 10.0
        
        animatePulsatingLayer()

        // Hide the navigation bar on the this view controller
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Show the navigation bar on other view controllers
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        guard let url: URL = selectedFileURL else {
            
            return
        }
//        
//        if ["MOV", "MP4", "M4V"].firstIndex(of: url.pathExtension.uppercased()) != nil {
//            //showAlert(title: "", message: "You can select only mov, mp4 or m4v video.", btnText: "OK")
//            
//        } else {
//            showAlert(title: "", message: "You can select only mov, mp4 or m4v video.", btnText: "OK")
//        }
//        
        selectedFileURL = nil
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraLayer.frame = self.view.bounds
        
        if isIPhoneX {
            RecordingView.frame = CGRect(x: 0, y: 0, width: RecordingView.frame.width, height: RecordingView.frame.height)
        }
    }
    
    
    

    
    func updateSelectButton() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        let last = fetchResult.lastObject
        
        if let lastAsset = last {
            let targetSize: CGSize = CGSize(width: 50, height: 50)
            let options: PHImageRequestOptions = PHImageRequestOptions()
            options.version = .current
            
            PHImageManager.default().requestImage(
                for: lastAsset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options,
                resultHandler: { image, _ in
                    if self.canUsePhotoLibrary! {
                        DispatchQueue.main.async {
                            self.selectButton.setImage(image, for: .normal)
                            self.selectButton.isHidden = false
                        }
                    }
                }
            )
        }
    }
    
    func setupCamera() {
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        
        if let device = deviceDiscovery.devices.last {
            captureDevice = device
            beginSession()
        }
    }
    
    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    func shootVideo() {
        self.selectButton.isHidden = true
        self.playerBoxBorder.alpha = 0.2
        self.playerBoxBorderPulsating.isHidden = true
        self.serveIcon.isHidden = true

        if !self.isRecording {
            messageLabel.isHidden = true
            
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0] as String
//            let title = randomString(50)
            let fileURL : NSURL = NSURL(fileURLWithPath: "\(documentsDirectory)/temp.mp4")
//            let fileURL : NSURL = NSURL(fileURLWithPath: "\(documentsDirectory)/" + title + ".mp4")

            fileOutput.startRecording(to: fileURL as URL, recordingDelegate: self)
            
            captureButton.layer.cornerRadius = 0
            isRecording = true
        } else {
            fileOutput.stopRecording()
            
            captureButton.layer.cornerRadius = captureButton.bounds.width / 2
            isRecording = false
        }
    }
    
    
    func beginSession() {
        let videoInput = try? AVCaptureDeviceInput(device: videoDevice!) as AVCaptureDeviceInput
        
        captureSession.addInput(videoInput!)
        captureSession.addOutput(fileOutput)

        if deviceType == .phone {
            captureSession.sessionPreset = .hd1920x1080
        } else {
            captureSession.sessionPreset = .vga640x480
        }
        
        captureSession.startRunning()
    }
    
    func noPosesDetected() {
        showAlert(title: "No Serves Detected", message: "Please check that you have selected the correct video", btnText: "OK")
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "segue" {
//            if let destinationVC = segue.destination as? FeedbackController {
//                destinationVC.urlArray = self.urlArray
//                destinationVC.timestamps = self.timestamp_frames
//                destinationVC.serveVectorArray = self.serveVectorArray
//            }
//        }
//        else if segue.identifier == "nonButtonAnalysisSegue" {
        if segue.identifier == "nonButtonAnalysisSegue" {
            if let destinationVC = segue.destination as? ServeAnalysisViewController {
                destinationVC.progressChange = self.handleProgressChange
                destinationVC.noPosesDetected = self.noPosesDetected
                destinationVC.inputURL = self.inputURL
                destinationVC.continue_analyzing = false
                self.child = destinationVC
            }
            
        }
    }
    func createAnalysisView(_ inputURL: URL) {
        self.inputURL = inputURL
        if self.child == nil {
            self.performSegue(withIdentifier:"nonButtonAnalysisSegue", sender: self)
            DispatchQueue.main.async {
                self.serveAnalysisButton.isHidden = false
                self.selectButton.isHidden = false
                self.playerBoxBorder.alpha = 1
                self.playerBoxBorderPulsating.isHidden = false
                self.messageLabel.isHidden = false
                self.serveIcon.isHidden = false

            }
        }
        else {
            showAlert(title: "Already analyzing your practice", message: "A previous practice is currently being analyzed. Concurrent analysis will be supported in a future update.", btnText: "OK")
            DispatchQueue.main.async {
                self.serveAnalysisButton.isHidden = false
                self.selectButton.isHidden = false
                self.playerBoxBorder.alpha = 1
                self.playerBoxBorderPulsating.isHidden = false
                self.messageLabel.isHidden = false
                self.serveIcon.isHidden = false

            }
        }
    }
    
    func addPractice(_ serveURLs: [URL], _ serveVectors: [[Double]], _ timestamps: [[Int]]) {
        let newPractice = Practice(context: self.context)
        newPractice.date = NSDate() as Date
        newPractice.urls = serveURLs
        newPractice.vectors = serveVectors
        newPractice.timestamps = timestamps
        do {
            try self.context.save()
        } catch {
            print("Couldn't save new practice")
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
    
    func updatePractice(_ practice: Practice, _ serveURLs: [URL], _ serveVectors: [[Double]], _ timestamps: [[Int]]) {
        practice.urls = serveURLs
        practice.vectors = serveVectors
        practice.timestamps = timestamps
        do {
            try self.context.save()
        } catch {
            print("Couldn't update practices")
        }
    }
    
    func showAlert(title: String, message: String, btnText: String, completion: @escaping () -> Void = {}) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: btnText, style: .default, handler: nil))
        present(alert, animated: true, completion: completion)
    }
    

    
    func moveVideoToPhotoLibrary(_ url: URL){
        var urlToReturn = url
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url as URL)

        }){ completed, error in
            if completed {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

                // After uploading we fetch the PHAsset for most recent video and then get its current location url

                let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions).lastObject
                PHImageManager().requestAVAsset(forVideo: fetchResult!, options: nil, resultHandler: { (avurlAsset, audioMix, dict) in
                    let newObj = avurlAsset as! AVURLAsset
                    // This is the URL we need now to access the video from gallery directly.
                    urlToReturn = newObj.url
                    DispatchQueue.main.async {
                        self.createAnalysisView(newObj.url)
                    }
                    })
            }
            else {
                print("ERROR: Failed to move a video file to Photo Library.")
            }
        }
    }
    
    

    
}

extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let newURL = moveVideoToPhotoLibrary(outputFileURL)
    }
}

extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func selectVideo() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
        print(UIImagePickerController.availableMediaTypes(for: .photoLibrary))
        imagePickerController.mediaTypes = ["public.movie"]
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        selectedFileURL = info["UIImagePickerControllerReferenceURL"] as? URL
        let asset = AVAsset(url: selectedFileURL!)

        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)

//        picker.dismiss(animated: true, completion: {self.analyzeServe(self.selectedFileURL!)})
        if durationTime > 0.0 {
            picker.dismiss(animated: true, completion: {self.createAnalysisView(self.selectedFileURL!)})
        }
        else {
            picker.dismiss(animated: true, completion: {self.showAlert(title: "", message: "You can select only mov, mp4 or m4v video.", btnText: "OK")})
            
        }
        

    }
}

extension UIColor {

    func rgb() -> (red:Int, green:Int, blue:Int, alpha:Int)? {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            let iRed = Int(fRed * 255.0)
            let iGreen = Int(fGreen * 255.0)
            let iBlue = Int(fBlue * 255.0)
            let iAlpha = Int(fAlpha * 255.0)

            return (red:iRed, green:iGreen, blue:iBlue, alpha:iAlpha)
        } else {
            // Could not extract RGBA components:
            return nil
        }
    }
}
