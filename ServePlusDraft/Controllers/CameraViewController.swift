//
//  CameraViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 5/18/21.
//
//  View controller class for recording and uploading videos of
//  serve practices. Segues directly to the analysis controller,
//  where the pose detection AI gleans poses off of the entire
//  serve video.



import UIKit
import SwiftUI
import AVFoundation
import Vision
import Photos
import CoreGraphics
import MobileCoreServices


let imgWidth = 736        // constant for sending video frames to pose analysis


class CameraViewController: UIViewController {
        
    // Reference to the Common class, which has lots of helper functions
    let com = {
        Common(imgWidth,imgWidth)
    }()
    
    
    /* context helps this controller link to the app's data model to retrieve
       and update the user's practices. */
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

    
    // Reference to the base view of the controller
    @IBOutlet weak var HomeView: UIView!
    
    
    // Reference to the recording view - will display camera feed
    @IBOutlet weak var RecordingView: UIImageView!
    
    
    /* Reference to the replay view - will display frame-by-frame
       pose analysis */
    @IBOutlet weak var ReplayView: UIImageView!
    
    
    /* Reference to the message to "serve inside the box" - a box
       will be displayed on the recording screen, and the server
       will have to center themselves inside the box before recording. */
    @IBOutlet weak var messageLabel: UILabelStroked!
    
    
    // Reference to the analysis progress bar
    @IBOutlet weak var progressView: UIProgressView!
    
    
    // Reference to the analysis progress label (x% completed...)
    @IBOutlet weak var progressLabel: UILabelStroked!
    
    
    /* Reference to the box inside which the server must center
       themselves */
    @IBOutlet weak var playerBoxBorder: UIView!
    
    
    // Reference to the pulsating effect on the server box
    @IBOutlet weak var playerBoxBorderPulsating: UIView!
    
    
    /* Reference to the serve icon inside the server box - sort
       of a visual guid to let the user know they need to serve
       inside that box */
    @IBOutlet weak var serveIcon: UIImageView!

    
    // Reference to the video record button
    @IBOutlet weak var captureButton: UIButton!
    
    // If the video record button is clicked, start recording
    @IBAction func tappedCaptureButton(sender: UIButton) {
        shootVideo()
    }
    
    
    // Reference to the video upload button
    @IBOutlet weak var selectButton: UIButton!
    
    /* If the video upload button is clicked, prompt the user
       to select a video */
    @IBAction func tappedSelectButton(sender: UIButton) {
        selectVideo()
    }
    
    
    // Reference to the serve analysis button
    @IBOutlet weak var serveAnalysisButton: UIButton!
    
    /* If the serve analysis button is clicked, go to the
       serve analysis page */
    @IBAction func tappedAnalysisButton(sender: UIButton) {
        show(self.child!, sender: self)
    }
    
    
    // Initialize a container for the serve analysis page
    var child: ServeAnalysisViewController? = nil
    
    
    /* Initialize arrays to keep track of the y-positions of the
       left and right hands - used to split the reference video
       into individual serve videos */
    var lh_values: [Double] = []
    var rh_values: [Double] = []
    
    
    // Establish the target image size for pose analysis
    let targetImageSize = CGSize(width: imgWidth, height: imgWidth)
    
    
    // Initialize capture session to manage the camera feed
    var captureSession = AVCaptureSession()
    
    
    // Initialize capture device to manage the camera
    var captureDevice: AVCaptureDevice?
    
    
    // Initialize video device to manage the camera
    let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    
    
    /* Initialize the layer on which the frame-by-frame pose
       analysis will take place */
    var cameraLayer: AVCaptureVideoPreviewLayer!
    
    
    /* Initialize the file output so the recorded video can be
       saved on camera */
    let fileOutput = AVCaptureMovieFileOutput()
    
    
    // Boolean to understand when the camera is recording
    var isRecording = false
    
    
    /* Initialize variable to keep track of which serve video
       the user wants to upload */
    var selectedFileURL: URL?
    
    
    // Boolean to understand when the pose detection has finished
    var completedDetection: Bool = false
    
    
    // Need to understand if the device is a compatible one
    var deviceType: UIUserInterfaceIdiom?
    
    
    // Boolean to understand if the phone is an IPhoneX or better
    var isIPhoneX: Bool = false
    
    
    /* Boolean to keep track of whether camera permissions have been
       allowed */
    var canUseCamera: Bool?
    
    
    /* Boolean to keep track of whether this app can access the
       user's photo library to upload videos */
    var canUsePhotoLibrary: Bool?
    

    /* Initialize variable to contain the URL for the video to
       analyze */
    var inputURL: URL?

    
    /* Initialize circular progress bar for the progress button,
       which keeps track of the analysis progress if you don't
       want to keep looking at the frame-by-frame analysis */
    let circularProgress = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Make sure the navigation bar jives with the view
        self.navigationController!.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationController!.navigationBar.isTranslucent = true
        
        
        // Set the title in the Tab Bar controlelr
        title = "Record and Upload"
                
        
        /* If serve analysis isn't currently happening, hide the serve
           analysis button */
        if (self.child == nil) {
            self.serveAnalysisButton.isHidden = true
        }
        
        
        // Ensure the device type is compatible
        deviceType = UIDevice.current.userInterfaceIdiom
        guard deviceType == .phone || deviceType == .pad else {
            fatalError("ERROR: Invalid device.")
        }
        
        
        // Determine if the phone model is greater than iPhone X
        let deviceName = com.getDeviceName()
        if deviceType == .phone && deviceName.range(of: "iPhone10") != nil {
            isIPhoneX = true
        }
                
        
        // Turn the progress bar into a thin rectagle
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        
        
        // Set the camera feed to be shown in cameraLayer
        cameraLayer = AVCaptureVideoPreviewLayer(session: self.captureSession) as AVCaptureVideoPreviewLayer
        cameraLayer.frame = self.view.bounds
        cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        RecordingView.layer.addSublayer(cameraLayer)
        
        
        // Set the message label
        messageLabel.strokedText = "Start serving inside box"
        
        
        // Set up the record button's style
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.layer.borderWidth = 3
        
        
        // Set up the serve analysis button's style
        serveAnalysisButton.backgroundColor =  UIColor(red: 3/255, green: 57/255, blue: 248/255, alpha: 0.9)
        serveAnalysisButton.layer.cornerRadius = serveAnalysisButton.frame.height/2
        serveAnalysisButton.layer.shadowOpacity = 0.25
        serveAnalysisButton.layer.shadowRadius = 5
        serveAnalysisButton.layer.shadowOffset = CGSize(width: 0, height: 10)
        
        
        // Set up a circular progress bar around the serve analysis button
        let circularPath = UIBezierPath(arcCenter: CGPoint(serveAnalysisButton.frame.width/2, serveAnalysisButton.frame.height/2), radius: (serveAnalysisButton.frame.height/2 + 5.0), startAngle: -CGFloat.pi/2, endAngle: 2*CGFloat.pi-CGFloat.pi/2, clockwise: true)
        circularProgress.path = circularPath.cgPath
        circularProgress.strokeEnd = 0
        circularProgress.lineCap = CAShapeLayerLineCap.round
        circularProgress.strokeColor = CGColor(red: 3/255, green: 57/255, blue: 248/255, alpha: 0.3)
        circularProgress.fillColor = UIColor.clear.cgColor
        circularProgress.lineWidth = 10
        
        
        // add circular progress bar to the analysis button
        serveAnalysisButton.layer.addSublayer(circularProgress)
        serveAnalysisButton.setTitle("0%", for: .normal)
        
        
        // make the serve icon guide (inside the serve box) transparent
        serveIcon.alpha = 0.4
        
        
        // Ask the user if the app can use the camera to record serves
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
        
        
        /* Ask the user if the app can access the photo library to upload
           serves */
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
    
    func showAlert(title: String, message: String, btnText: String, completion: @escaping () -> Void = {}) {
        
        /* Function to show a customizable alert to a user */
        
        // Initialize the object that will display the alert
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Add a button to the alert that will dismiss the alert
        alert.addAction(UIAlertAction(title: btnText, style: .default, handler: nil))
        
        
        // Present the notification
        present(alert, animated: true, completion: completion)
    }
    
    
    func animatePulsatingLayer() {
        
        /* Animate the pulsating layer around the border box*/
        
        // Define a shrink-grow type animation
        let anim = CABasicAnimation(keyPath: "transform.scale")
        
        
        // Grow to 120% of original size
        anim.toValue = 1.2
        
        
        // 0.8 second cycles (0.4 seconds up, 0.4 seconds down)
        anim.duration = 0.4
        
        
        // Smooth easeOut animation
        anim.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        
        
        // Not just growing, but also shrinking back
        anim.autoreverses = true
        
        
        // Repeat forever
        anim.repeatCount = Float.infinity
        
        
        // Add pulsating animation to the pulsating layer
        playerBoxBorderPulsating.layer.add(anim, forKey: "pulsing")
        
        
    }
    
    func handleProgressChange(_ newProgress: Double) {
        
        /* Manage when the serve analysis progress changes */
        
        // Change the label of the serve analysis button
        serveAnalysisButton.setTitle(String(Int(newProgress)) + "%", for: .normal)
        
        
        // Animate the serve analysis button's circular progress bar
        let basicAnimation = CABasicAnimation(keyPath: "strokeEnd")
        basicAnimation.toValue = newProgress/100
        basicAnimation.duration = 1
        basicAnimation.fillMode = CAMediaTimingFillMode.forwards
        basicAnimation.isRemovedOnCompletion = false
        
        
        // Add animation to the circular progress bar
        circularProgress.add(basicAnimation, forKey: "urSoBasic")
        circularProgress.strokeEnd = CGFloat(newProgress/100)
        
        
        /* If the analysis is complete, hide the button and remove the
           ability to segue to the analysis controller */
        if newProgress == 100.0 {
            self.child = nil
            DispatchQueue.main.async {
                self.serveAnalysisButton.isHidden = true
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Define the box where the server's body must start inside
        playerBoxBorder.layer.borderColor = CGColor(red: 0.0, green: 34/255, blue: 238/255, alpha: 0.75)
        playerBoxBorder.layer.borderWidth = 10.0
        playerBoxBorder.layer.cornerRadius = 10.0
        
        
        // Add the pulsating layer around the serve box guide
        playerBoxBorderPulsating.layer.borderColor = CGColor(red: 0.0, green: 44/255, blue: 248/255, alpha: 0.50)
        playerBoxBorderPulsating.layer.borderWidth = 10.0
        playerBoxBorderPulsating.layer.cornerRadius = 10.0
        
        
        // Animate the pulsating layer
        animatePulsatingLayer()

        
        // Hide the navigation bar on this view controller
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Show the navigation bar on other view controllers
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        // Set the current selected file to nil (because none is selected)
        selectedFileURL = nil
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Fit the camera feed into the bounds of the phone screen
        cameraLayer.frame = self.view.bounds
        
        
        /* Extend the camera feed beyond the notch if the phone is
           an iPhone X */
        if isIPhoneX {
            RecordingView.frame = CGRect(x: 0, y: 0, width: RecordingView.frame.width, height: RecordingView.frame.height)
        }
    }
    
    
    

    
    func updateSelectButton() {
        
        /* Manage the thumbnail of the select button */
        
        // Sort selectable videos by reverse chronological order
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        
        // Only fetch videos from the photo library
        let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        
        /* Set the select button thumbnail to the thumbnail of the
           latest video */
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
        
        /* Get the built-in camera ready to start recording */
        
        // Detect the built-in camera
        let deviceDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        
        
        // Use one of the devices to start recording
        if let device = deviceDiscovery.devices.last {
            captureDevice = device
            beginSession()
        }
    }
    
    func shootVideo() {
        
        /* Change the look of the Camera View when recording */
        
        // Hide the record button
        self.selectButton.isHidden = true
        
        
        // Keep the player box barely visible
        self.playerBoxBorder.alpha = 0.2
        
        
        // Remove the player box's pulsating effect
        self.playerBoxBorderPulsating.isHidden = true
        
        
        // Remove the serve icon guide
        self.serveIcon.isHidden = true
        
        
        // Hide the serve box message
        messageLabel.isHidden = true

        
        // When recording starts, write the camera feed to a video file
        if !self.isRecording {
            
            
            // Get path to documents directory to store the video
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0] as String
            
            
            // Create a temporary URL path to store the video
            let fileURL : NSURL = NSURL(fileURLWithPath: "\(documentsDirectory)/temp.mp4")

            
            // Start recording to the file output URL
            fileOutput.startRecording(to: fileURL as URL, recordingDelegate: self)
            
            
            // Change the capture button to look like a square
            captureButton.layer.cornerRadius = 0
            
            
            // Boolean to keep track of recording
            isRecording = true
            
        }
        /* When recording ends, stop the recording and reset the look of the
           camera view */
        else {
            
            // Stop writing to the output
            fileOutput.stopRecording()
            
            
            // Show the record button
            self.selectButton.isHidden = false
            
            
            // Make the player box fully visible
            self.playerBoxBorder.alpha = 1
            
            
            // Show the player box's pulsating effect
            self.playerBoxBorderPulsating.isHidden = false
            
            
            // Show the serve icon guide
            self.serveIcon.isHidden = false
            
            
            // Show the serve box message
            messageLabel.isHidden = false
            
            
            // Make the record button look like a circle again
            captureButton.layer.cornerRadius = captureButton.bounds.width / 2
            
            
            // Boolean to keep track of recording
            isRecording = false
        }
    }
    
    
    func beginSession() {
        
        /* Start the recording and manage the flow from camera feed
           to output video */
        
        // Get the video input data
        let videoInput = try? AVCaptureDeviceInput(device: videoDevice!) as AVCaptureDeviceInput
        
        
        // Input the video input data to the capture session's input
        captureSession.addInput(videoInput!)
        
        
        // Add the output video location to the capture session's output
        captureSession.addOutput(fileOutput)

        
        // iPhone vs iPad settings for video quality
        if deviceType == .phone {
            captureSession.sessionPreset = .hd1920x1080
        } else {
            captureSession.sessionPreset = .vga640x480
        }
        
        
        // Initialize the video caprue session
        captureSession.startRunning()
    }
    
    func noPosesDetected() {
        
        /* Show an alert if the video has no detectable serves */
        
        showAlert(title: "No Serves Detected", message: "Please check that you have selected the correct video", btnText: "OK")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Check if the segue destination is the serve analysis view controller
        if segue.identifier == "nonButtonAnalysisSegue" {
            
            // Set destinationVC to the destination view controller
            if let destinationVC = segue.destination as? ServeAnalysisViewController {
                
                
                /* Pass along the function to handle a change in analysis
                   progress, so when the analysis progress changes, so does
                   the progress circle around the analysis button on the
                   Camera View Controller */
                destinationVC.progressChange = self.handleProgressChange
                
                
                /* Pass along the function that shows an alert when the
                   video has no serves in it */
                destinationVC.noPosesDetected = self.noPosesDetected
                
                
                // Pass along the user's video to analyze
                destinationVC.inputURL = self.inputURL
                
                
                /* Keep track of the ServeAnalysisViewController so it can
                   be segued to later */
                self.child = destinationVC
            }
            
        }
    }
    func createAnalysisView(_ inputURL: URL) {
        
        /* Perform the segue to the analysis view only if there isn't already
           an analysis happening */
        self.inputURL = inputURL
        
        
        // If there is no analysis currently happening, segue to the analysis
        if self.child == nil {
            
            
            // Perform the segue to the analysis
            self.performSegue(withIdentifier:"nonButtonAnalysisSegue", sender: self)
            
            DispatchQueue.main.async {
                
                // Show everything that was hidden while recording
                self.serveAnalysisButton.isHidden = false
                self.selectButton.isHidden = false
                self.playerBoxBorder.alpha = 1
                self.playerBoxBorderPulsating.isHidden = false
                self.messageLabel.isHidden = false
                self.serveIcon.isHidden = false

            }
        }
        
        /* If analysis is currently happening, tell the user they can't
           analyze another of their serve practices */
        else {
            
            
            // Show the alert to the user
            showAlert(title: "Already analyzing your practice", message: "A previous practice is currently being analyzed. Concurrent analysis will be supported in a future update.", btnText: "OK")
            
            DispatchQueue.main.async {
                
                // Show everything that was hidden while recording
                self.serveAnalysisButton.isHidden = false
                self.selectButton.isHidden = false
                self.playerBoxBorder.alpha = 1
                self.playerBoxBorderPulsating.isHidden = false
                self.messageLabel.isHidden = false
                self.serveIcon.isHidden = false

            }
        }
    }
    
 

    
    func moveVideoToPhotoLibrary(_ url: URL){
        
        /* Move a recorded video to the user's photo library and segue to the
           serve analysis view */
        
        // Request the video to be added to the user's photo library
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url as URL)

        })
        { completed, error in
            
            /* If adding the video was successful, pass the video url along for
               pose detection in the serve analysis controller */
            if completed {
                
                /* Fetch the latest video from the Photo Library (this is the
                   video we just added */
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions).lastObject
                                
                
                /* Get the video as an AVURL asset so we can pass the location
                   of the video (the url) to the serve analysis controller */
                PHImageManager().requestAVAsset(forVideo: fetchResult!, options: nil, resultHandler: { (avurlAsset, audioMix, dict) in
                    
                    // Store the video contents in newObj
                    let newObj = avurlAsset as! AVURLAsset
                    
                    
                    // Pass the video URL to the serve analysis controller
                    DispatchQueue.main.async {
                        self.createAnalysisView(newObj.url)
                    }
                    })
            }
            
            // Print an error if moving the video to the photo library was unsuccessful
            else {
                print("ERROR: Failed to move a video file to Photo Library.")
            }
        }
    }
}

// Extension to pick a video from the photo library
extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func selectVideo() {
        
        /* Present a video picking interface to the user */
        
        /* Initialize the image picker controller (this will be narrowed down
           to videos later) */
        let imagePickerController = UIImagePickerController()
        
        
        // Make the picker controller look like the photo library
        imagePickerController.sourceType = .photoLibrary
        
        
        // Set the Camera View Controller as the delegate
        imagePickerController.delegate = self as UIImagePickerControllerDelegate & UINavigationControllerDelegate
        
        
        // Make sure only videos can be selected
        imagePickerController.mediaTypes = ["public.movie"]
        
        
        // Present the video picking interface
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        /* When the user selects a video, use that video in the serve
           analysis */
        
        // Get the selected video URL
        selectedFileURL = info["UIImagePickerControllerReferenceURL"] as? URL
        
        
        // Get the duration of the video to check if it is an actual video
        let asset = AVAsset(url: selectedFileURL!)
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)

        /* Segue to the analysis view only if the duration is longer than
           0 seconds */
        if durationTime > 0.0 {
            picker.dismiss(animated: true, completion: {self.createAnalysisView(self.selectedFileURL!)})
        }
        
        /* If the duration is 0 seconds, display an alert that lets the user
           know the video was incompatible */
        else {
            picker.dismiss(animated: true, completion: {self.showAlert(title: "", message: "You can select only mov, mp4 or m4v video.", btnText: "OK")})
            
        }
        

    }
}

// Extension to handle moving recorded video to the photo library
extension CameraViewController: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        
        /* Necessary function in AVCaptureFileOutputRecordingDelegate */
        
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        /* After recording is finished, move the recorded video to the
           photo library */
        moveVideoToPhotoLibrary(outputFileURL)
        
    }
}
