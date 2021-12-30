//
//  ServeAnalysisViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/6/21.
//
//  View controller that displays the frame-by-frame pose detection
//  results on an input video. It also handles the scoring of serves,
//  and passes the scores onto the feedback controller

import UIKit
import SwiftUI
import AVFoundation
import Vision
import Photos
import CoreGraphics


class ServeAnalysisViewController: UIViewController {

    /* context helps this controller link to the app's data model to retrieve
       and update the user's practices. */
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    
    // Reference to the frame-by-frame replay vire
    @IBOutlet weak var ReplayView: UIImageView!
    
    
    // Reference to the progress bar
    @IBOutlet weak var progressView: UIProgressView!
    
    
    // Reference to the progress message ("x% completed...")
    @IBOutlet weak var progressLabel: UILabelStroked!
    
    
    // URL to analyze
    var inputURL: URL?
    
    
    // Array to keep track of individual serve scores
    var serveVectorArray: [[Double]] = []
    
    
    /* Arrays to keep track of hand positions (used to split a
       service practice into multiple videos */
    var lh_values: [Double] = []
    var rh_values: [Double] = []
    
    
    // Array to store the URLS of the individual serves
    /* DISCLAIMER: Each URL in this array will just be the
       original URL, and timestamps to split the videos
       will be gleaned and used separately. Originally, each
       URL would have referred to an individual video, but
       the memory suffered. */
    var urlArray: [URL] = []
    
    
    /* Array to keep track of the inputs to the ML models. Each serve
       will get its own array */
    var allServeMLArrays: [[[Double]]] = []
    
    
    // Variable to keep track of how to display the replay video
    var orientation: UIImage.Orientation?
    
    
    // Image to store the current analysis frame
    var poseImage: UIImage?
    
    
    // Variable to store the target image size
    let targetImageSize = CGSize(width: imgWidth, height: imgWidth)
    
    
    /* Array to keep track of the starts and ends of each detected
       serve */
    var timestamp_frames : [[Int]] = []

    
    /* Array to keep track of the detected poses. Each serve will
       get its own array */
    var allVideoPoses: [[Double]] = []
    
    
    /* Array to keep track of detected body points. If not enough
       key points are detected, the serve is invalidated */
    var total_points: [Int] = []
    
    
    // References to AI models - one for each category
    var BAModel = try? backArchXGBoost(configuration: MLModelConfiguration())
    var BLModel = try? backLegKickedBackXGBoost(configuration: MLModelConfiguration())
    var FSModel = try? feetSpacingXGBoost(configuration: MLModelConfiguration())
    var JHModel = try? jumpHeightXGBoost(configuration: MLModelConfiguration())
    var LAModel = try? leftArmStraightXGBoost(configuration: MLModelConfiguration())
    var LBModel = try? legsBentXGBoost(configuration: MLModelConfiguration())
    var STModel = try? shoulderTimingXGBoost(configuration: MLModelConfiguration())
    var THModel = try? tossHeightXGBoost(configuration: MLModelConfiguration())
        
    //Back Arched specific metrics
    var backAngles: [Double] = []
    

    //Back Leg Kicked Back specific metrics
    var pt10xs: [Double] = []
    var pt10ys: [Double] = []
    var pt13xs: [Double] = [] //also for Jump Height
    var pt13ys: [Double] = [] //also for Jump Height
    var leftLegAngles: [Double] = [] //also for legs bent and shoulder rotation
    var rightLegAngles: [Double] = [] // also for legs bent and shoulder rotation
    
    //Feet Spacing specific metrics
    
    //Left Arm Straight specific metrics
    var leftHandAngles: [Double] = []
    var rightHandAngles: [Double] = []
    var newPractice: Practice?
    
    //Shoulder Rotation specific metrics
    
    //Toss height specific metrics
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
    
    
    // Function to handle progress change
    var progressChange: ((Double) -> Void)?
    
    
    // Alert function if no serves are detected
    var noPosesDetected: (() -> Void)?


    // Initialize a pose detection request
    lazy var poseDetectionRequest = [VNDetectHumanBodyPoseRequest(completionHandler: posesDetected)]
    
    
    // Reference to the Common class, which has lots of helper functions
    let com = {
        Common(imgWidth,imgWidth)
    }()
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

        // Make the progress bar a nice rectangle
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        
        
        // Analyze the input video
        analyzeServe(self.inputURL!)
    }
    
    
    // Initialize an evaluation context for rendering image processing results
    let ciContext = CIContext()
    
    
    // Initialize a buffer that stores pixels. Useful for frame analysis
    var resultBuffer: CVPixelBuffer?
    
    
    func uiImageToPixelBuffer(_ uiImage: UIImage, targetSize: CGSize, orientation: UIImage.Orientation) -> CVPixelBuffer? {
        
        
        /* Turn an image into a pixel buffer */
        
        
        // Determine what orientation to display the image
        var angle: CGFloat
            
        if orientation == UIImage.Orientation.down {
            angle = CGFloat.pi
        } else if orientation == UIImage.Orientation.up {
            angle = 0
        } else if orientation == UIImage.Orientation.left {
            angle = CGFloat.pi / 2.0
        } else {
            angle = -CGFloat.pi / 2.0
        }
        let rotateTransform: CGAffineTransform = CGAffineTransform(translationX: targetSize.width / 2.0, y: targetSize.height / 2.0).rotated(by: angle).translatedBy(x: -targetSize.height / 2.0, y: -targetSize.width / 2.0)
        let uiImageResized = com.resizeImage(image: uiImage, size: targetSize, keepAspectRatio: true)
        let ciImage = CIImage(image: uiImageResized)!
        let rotated = ciImage.transformed(by: rotateTransform)

        
        // Make sure the result buffer actually returns a buffer
        if resultBuffer == nil {
            let result = CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32BGRA, nil, &resultBuffer)
            
            guard result == kCVReturnSuccess else {
                fatalError("Can't allocate pixel buffer.")
            }
        }
        
        // Take the rotated image and make a pixel buffer out of it
        ciContext.render(rotated, to: resultBuffer!)
        
        return resultBuffer
    }
    
    func addLine(context: inout CGContext, fromPoint start: CGPoint, toPoint end:CGPoint, color: UIColor) {
        
        /* Draws a line on an image. Will help draw connections between keypoints
           of a server's pose when displaying frame-by-frame analysis */
        
        context.setLineWidth(3.0)
        context.setStrokeColor(color.cgColor)
        
        context.move(to: start)
        context.addLine(to: end)
        
        context.closePath()
        context.strokePath()
    }

    
    func posesDetected(request: VNRequest, error: Error?) {
        
        /* Takes a detected pose and does two things. One, preprocess the results
           in order to feed them into the ML models that score the serves. Two,
           draw nice-looking poses on the replay video. */
        
        // Get the observed poses for a single frame
        guard let observations = request.results as? [VNRecognizedPointsObservation] else { return }

        
        /* Initialize an array that tracks all the detected humans (pose detection
           can detect the poses of multiple humans, but we just want the main one) */
        var humans: [[CGPoint]] = []
        
        
        /* Initialize a variable that will help reference the center of the frame.
           We want the pose that is "closest" to the center of the frame */
        var center = (0.0, 0.0)
        
        // Loop through all of the detected human poses
        observations.forEach {
            
            // Get the image size and detected keypoints
            let ((imgWidth, imgHeight), imagePoints) = com.getImagePoints($0, self.orientation!)
            
            
            // Append the keypoints to the humans array
            humans.append(imagePoints)
            
            
            // Get the center of the image
            center = (Double(imgWidth)/2.0, Double(imgHeight)/2.0)
        }
        
        // Variable to keep track of the index of the "main" human (i.e the server)
        var serverIndex = 0
        
        
        /* Variable that keeps track of the current detected human's distance
           from the center */
        var currentDistanceFromCenter = 1000000.0
        
        
        /* If there are no detected humans, append nan's to the ML arrays that
           we will feed the ML Model. Then, end this frame's pose detection */
        if humans.count == 0 {
            self.allVideoPoses.append([Double](repeating: 0.0, count: 36))
            self.backAngles.append(Double.nan)
            

            //Back Leg Kicked Back
            self.pt10xs.append(Double.nan)
            self.pt10ys.append(Double.nan)
            self.pt13xs.append(Double.nan) //also for Jump Height
            self.pt13ys.append(Double.nan) //also for Jump Height
            self.leftLegAngles.append(Double.nan) //also for legs bent and shoulder rotation
            self.rightLegAngles.append(Double.nan) // also for legs bent and shoulder rotation
            
            //Feet Spacing
            
            //Left Arm Straight
            self.leftHandAngles.append(Double.nan)
            self.rightHandAngles.append(Double.nan)
            
            //Shoulder Rotation
            
            //Toss height
            self.pt2xs.append(Double.nan)
            self.pt3xs.append(Double.nan)
            self.pt4xs.append(Double.nan)
            self.pt5xs.append(Double.nan)
            self.pt6xs.append(Double.nan)
            self.pt7xs.append(Double.nan)
            self.pt2ys.append(Double.nan)
            self.pt3ys.append(Double.nan)
            self.pt4ys.append(Double.nan)
            self.pt5ys.append(Double.nan)
            self.pt6ys.append(Double.nan)
            self.pt7ys.append(Double.nan)
            return
        }
        
        
        /* If more than one human was detected, choose the human that is closest
           to the center */
        if humans.count > 1 {
            
            // Loop through all of the detected poses
            for human in 0...humans.count-1 {
                
                /* Get the distance of the current human from the image center.
                   If the distance is the smallest yet, this is the main human
                   for now */
                if com.distanceFromCenter(humans[human], center) < currentDistanceFromCenter {
                    currentDistanceFromCenter = com.distanceFromCenter(humans[human], center)
                    serverIndex = human
                }
            }
        }
        
        // Add the detected pose to our array of all the video's poses
        self.allVideoPoses.append([])
        for point in 0...humans[serverIndex].count-1 {
            
            let x_pos = Double(humans[serverIndex][point].x)
            let y_pos = Double(humans[serverIndex][point].y)
            self.allVideoPoses[self.allVideoPoses.count - 1].append(x_pos)
            self.allVideoPoses[self.allVideoPoses.count - 1].append(y_pos)
            
            // Check that the detected keypoint isn't just (0,0)
            if x_pos != 0.0 && y_pos != 0.0 {
                self.total_points[point] = 1
            }
        }
        
        // If less than half of the points are detected, it is not a serve
        // An alert will be shown later.
        
        
        /* Now, store the angles and distance of important keypoints into the
           arrays that the ML Models will use. */
        
        //Back Arched
        let (hipX, hipY) = com.midpoint(Double(humans[serverIndex][8].x), Double(humans[serverIndex][8].y), Double(humans[serverIndex][11].x), Double(humans[serverIndex][11].y))
        self.backAngles.append(com.two_point_angle(Double(humans[serverIndex][1].x), Double(humans[serverIndex][1].y), hipX, hipY))

        //Back Leg Kicked Back
        self.pt10xs.append(Double(humans[serverIndex][10].x))
        self.pt10ys.append(Double(humans[serverIndex][10].y))//also for Jump Height
        self.pt13xs.append(Double(humans[serverIndex][13].x))
        self.pt13ys.append(Double(humans[serverIndex][13].y)) //also for Jump Height
        self.leftLegAngles.append(com.three_point_angle(
                                    Double(humans[serverIndex][8].x),
                                    Double(humans[serverIndex][8].y),
                                    Double(humans[serverIndex][9].x),
                                    Double(humans[serverIndex][9].y),
                                    Double(humans[serverIndex][10].x),
                                    Double(humans[serverIndex][10].y))) //also for legs bent and shoulder rotation
        self.rightLegAngles.append(com.three_point_angle(
                                    Double(humans[serverIndex][11].x),
                                    Double(humans[serverIndex][11].y),
                                    Double(humans[serverIndex][12].x),
                                    Double(humans[serverIndex][12].y),
                                    Double(humans[serverIndex][13].x),
                                    Double(humans[serverIndex][13].y)))// also for legs bent and shoulder rotation
        
        //Feet Spacing

        //Left Arm Straight
        self.leftHandAngles.append(com.two_point_angle(Double(humans[serverIndex][2].x), Double(humans[serverIndex][2].y), Double(humans[serverIndex][4].x), Double(humans[serverIndex][4].y)))
        self.rightHandAngles.append(com.two_point_angle(Double(humans[serverIndex][5].x), Double(humans[serverIndex][5].y), Double(humans[serverIndex][7].x), Double(humans[serverIndex][7].y)))
        
        //Shoulder Rotation

        
        //Toss height
        self.pt2xs.append(Double(humans[serverIndex][2].x))
        self.pt3xs.append(Double(humans[serverIndex][3].x))
        self.pt4xs.append(Double(humans[serverIndex][4].x))
        self.pt5xs.append(Double(humans[serverIndex][5].x))
        self.pt6xs.append(Double(humans[serverIndex][6].x))
        self.pt7xs.append(Double(humans[serverIndex][7].x))
        self.pt2ys.append(Double(humans[serverIndex][2].y))
        self.pt3ys.append(Double(humans[serverIndex][3].y))
        self.pt4ys.append(Double(humans[serverIndex][4].y))
        self.pt5ys.append(Double(humans[serverIndex][5].y))
        self.pt6ys.append(Double(humans[serverIndex][6].y))
        self.pt7ys.append(Double(humans[serverIndex][7].y))
        
        
        /* Keep track of the hand positions to split the video into
           individual serves later */
        self.lh_values.append(Double(humans[serverIndex][7].y))
        self.rh_values.append(Double(humans[serverIndex][4].y))
        

        // Fetch the keypoint connections
        let connections = com.getConnections(humans[serverIndex])
        
        
        // Start the image context given the target size
        UIGraphicsBeginImageContext(targetImageSize)
        
        
        // Get a reference to the image context
        var context:CGContext = UIGraphicsGetCurrentContext()!

        
        // Draw a line for every keypoint connection
        for connection in connections {
            let (center1, center2, color) = connection
            addLine(context: &context, fromPoint: center1, toPoint: center2, color: color)
        }

        
        // Get a reference to the drawn connections
        var serveImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        
        // End the image context
        UIGraphicsEndImageContext()

        
        /* Get a reference to the image upon which the connections will be
           overlayed */
        var mainImage: UIImage = poseImage!

        
        // Resize the image to the target size
        mainImage = com.resizeImage(image: mainImage, size: mainImage.size)

        
        // Crop the drawn connections to match the size of the main image
        let serveImageCropped: UIImage = com.cropImage(image: serveImage, aspectX: mainImage.size.width, aspectY: mainImage.size.height)

        
        // Resize the serve image to the size of the main image
        serveImage = com.resizeImage(image: serveImageCropped, size: mainImage.size)

        
        // Draw the connection onto the main image
        poseImage = com.superimposeImages(mainImage: mainImage, subImage: serveImage)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        /* Prepare to segue to the Feedback Controller */
        
        if segue.identifier == "segueToFeedback" {
            if let destinationVC = segue.destination as? FeedbackController {
                
                /* Pass the current practice object so the Feedback Controller
                   can display a nice feedback UI */
                destinationVC.practice = self.newPractice
            }
        }
    }
    
    func analyzeServe(_ inputURL: URL) {
        
        /* Main function that analyzes the serve video. This function will
           display frame-by-frame analysis, store the detected poses, split
           the video into individual serves, and generate the scores for
           each serve. Finally, it will segue to the feedback controller. */
        
        
        /* Initialize array that will store the scores of all the detected
           serves */
        self.serveVectorArray = []
        
        
        // Array to store the URLs of all the individual serves
        self.urlArray = []
        
        
        // Array to keep track of the detected points througout the video
        self.total_points = [Int](repeating: 0, count: 18)

        
        // Generate an AVURLAsset form the input URL
        let avAsset = AVURLAsset(url: inputURL, options: nil)
        
        
        // Get an immutable video composition from the avAsset
        let composition = AVVideoComposition(asset: avAsset, applyingCIFiltersWithHandler: { request in })
        
        
        // Return the video track of the avAsset (as opposed to the audio track)
        let track = avAsset.tracks(withMediaType: AVMediaType.video)

        
        // Check to see if the video track exists
        guard let media = track[0] as AVAssetTrack? else {
            print("ERROR: There is no video track.")
            return
        }
        
        
        // Set the progress to 0 on the UI
        DispatchQueue.main.async {
            self.progressLabel.strokedText = "Analyzing poses...(0%)"
            self.progressLabel.isHidden = false
            self.progressView.setProgress(0.0, animated: false)
            self.progressChange!(0.0)
            self.progressView.isHidden = false
        }
        
        
        /* Get critical information about the natural dimensions of the
           input video */
        let naturalSize: CGSize = media.naturalSize
        let preferedTransform: CGAffineTransform = media.preferredTransform

        
        /* Initialize a generator that will generate frames from the
           video for frame-by-frame analysis */
        let generator = AVAssetImageGenerator(asset: avAsset)

        
        // Make sure the generator gives you a requested frame ASAP
        generator.requestedTimeToleranceAfter = CMTime.zero
        generator.requestedTimeToleranceBefore = CMTime.zero
        
        
        // Keep track of the number of frames and duration per frame
        var frameCount = 0

        
        // Calculate the FPS of the video
        let length: Double = Double(CMTimeGetSeconds(avAsset.duration))
        let fps: Int = Int(1 / CMTimeGetSeconds(composition.frameDuration))
        

        DispatchQueue.global().async {
            
            // Loop through every frame
            for i in stride(from: 0, to: length, by: 1.0 / Double(fps)) {
                autoreleasepool {
                    
                    // Glean the frame
                    let capturedImage : CGImage! = try? generator.copyCGImage(at: CMTime(seconds: i, preferredTimescale : 600), actualTime: nil)
                    
                    // Ensure the frame exists
                    if capturedImage != nil {
                        
                        // Set the orientation
                        if preferedTransform.tx == naturalSize.width && preferedTransform.ty == naturalSize.height {
                            self.orientation = UIImage.Orientation.down
                        } else if preferedTransform.tx == 0 && preferedTransform.ty == 0 {
                            self.orientation = UIImage.Orientation.up
                        } else if preferedTransform.tx == 0 && preferedTransform.ty == naturalSize.width {
                            self.orientation = UIImage.Orientation.left
                        } else {
                            self.orientation = UIImage.Orientation.right
                        }
                        

                        // Generate a temporary image to draw the poses on on
                        let tmpImageToEdit = UIImage(cgImage: capturedImage, scale: 1.0, orientation: self.orientation!)

                        
                        // Resize the image
                        self.poseImage = self.com.resizeImage(image: tmpImageToEdit, size: tmpImageToEdit.size)

                        
                        // Generate image to run pose detection on
                        let tmpImageToDetect: UIImage = UIImage(cgImage: capturedImage)
                        
                        
                        // Generate a pixel buffer from the image
                        let bufferToDetect = self.uiImageToPixelBuffer(tmpImageToDetect, targetSize: self.targetImageSize, orientation: self.orientation!)
                        
                        
                        // Detect poses from the frame
                        do {
                            let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: bufferToDetect!, options: [:])
                            try classifierRequestHandler.perform(self.poseDetectionRequest)
                        } catch {
                            print("Error: Failed to detect serves.")
                            print(error)
                        }
                        
                        // Increment the frame count
                        frameCount += 1
                    }
                }
                
                
                // Increment the progress rate
                let progressRate = i / length * 100

                DispatchQueue.main.async {
                    
                    // Update the Replay View's frame
                    self.ReplayView.image = self.poseImage!
                    
                    
                    // Update the progress-related UI
                    self.progressLabel.strokedText = "Analyzing poses...(" + String(Int(progressRate)) + "%)"
                    self.progressView.setProgress(Float(floor(progressRate) / 100), animated: true)
                    self.progressChange!(progressRate)
                }
            }
            
            /* After the whole video has been analyzed, split the video into
               individual serves and use ML to score each serve. */
            
            
            // Progress has reached 100%
            DispatchQueue.main.async {
                self.ReplayView.image = nil
                self.progressChange!(100.0)
            }
            
            /* There are 18 keypoints. If less that 14 were detected across
               the entire video, then tell the user no serves were detected. */
            if self.total_points.reduce(0, +) < 14 {
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: false)
                    self.noPosesDetected!()

                }
            }
            
            /* If enough points were detected, split the video into serves*/
            
            else {
                
                // Update the progress label
                DispatchQueue.main.async {
                    self.progressLabel.strokedText = "Detecting serves..."
                    
                    // Reset the progress bar
                    self.progressView.setProgress(0.0, animated: false)
                }
                
                /* Peaks in the standard deviation of the server's hand
                   positions are used to determine the location of
                   individual serves. These two metrics determine how
                   many frames before and after the peak to include in
                   the video of the individual serve */
                let before_frame_subtractor = 20
                let after_frame_adder = 100

                
                /* Get the peaks of interest, which are the peaks in the
                   standard deviations that match between the left and
                   hands */
                let pois = self.com.final_filter(self.lh_values, self.rh_values, 60, 10.0, 60, false)
                
                
                // Reset the left and right hand arrays
                self.lh_values = []
                self.rh_values = []
                
                
                /* Generate the starting and ending frames for each individual
                   serves */
                
                /* Initialize the array that will hold the starting and
                   ending frames for every individual serve */
                self.timestamp_frames = []
                
                /* If the entire video was only a single serve, there is no
                   need to have more than one starting and ending frame */
                if pois == [0] {
                    self.timestamp_frames = [[0, frameCount - 1]]
                }
                
                /* If there was more than one serve in the video, then
                   every serve needs a proper starting and ending frame*/
                else {
                    for frame in pois {
                        let beginning = max(0, frame - before_frame_subtractor)
                        let end = min(frame + after_frame_adder, frameCount - 1)
                        self.timestamp_frames.append([beginning, end])
                    }
                }
                
                /* Create a repeating array of the input array to save in
                   the practice. A single url would suffice, but updating the
                   app would inconvenience those who already have the app by
                   invalidating all of their previous practices */
                self.urlArray = Array(repeating: inputURL, count: self.timestamp_frames.count)

                
                /* Keep track of the minimum and maximum X and Y values
                   in order to normalize the poses later */
                var minX = 1000000.0
                var minY = 1000000.0
                var maxX = 0.0
                var maxY = 0.0

                
                /* Update the UI to let the user know we are storing keypoints
                   in the respective ML arrays */
                DispatchQueue.main.async {
                    self.progressLabel.strokedText = "Gleaning keypoints..."
                }
                
                // Loop through each timestamp (each individual serve)
                for bookmark in self.timestamp_frames {
                    
                    // Get a reference to all of the poses in this serve
                    let poses_of_interest = Array(self.allVideoPoses[bookmark[0]...bookmark[1]-1])
                    
                    
                    // Save all of the manipulated values in their own arrays
                    let specificbackAngles = self.com.zero_pad(Array(self.backAngles[bookmark[0]...bookmark[1]-1]))
                    let specificpt10xs = self.com.zero_pad(Array(self.pt10xs[bookmark[0]...bookmark[1]-1]))
                    let specificpt13xs = self.com.zero_pad(Array(self.pt13xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt10ys = self.com.zero_pad(Array(self.pt10ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt13ys = self.com.zero_pad(Array(self.pt13ys[bookmark[0]...bookmark[1]-1]))
                    let specificleftLegAngles = self.com.zero_pad(Array(self.leftLegAngles[bookmark[0]...bookmark[1]-1]))
                    let specificrightLegAngles = self.com.zero_pad(Array(self.rightLegAngles[bookmark[0]...bookmark[1]-1]))
                    let specificleftHandAngles = self.com.zero_pad(Array(self.leftHandAngles[bookmark[0]...bookmark[1]-1]))
                    let specificrightHandAngles = self.com.zero_pad(Array(self.rightHandAngles[bookmark[0]...bookmark[1]-1]))
                    var specificpt2xs = self.com.zero_pad(Array(self.pt2xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt2ys = self.com.zero_pad(Array(self.pt2ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt3xs = self.com.zero_pad(Array(self.pt3xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt3ys = self.com.zero_pad(Array(self.pt3ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt4xs = self.com.zero_pad(Array(self.pt4xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt4ys = self.com.zero_pad(Array(self.pt4ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt5xs = self.com.zero_pad(Array(self.pt5xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt5ys = self.com.zero_pad(Array(self.pt5ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt6xs = self.com.zero_pad(Array(self.pt6xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt6ys = self.com.zero_pad(Array(self.pt6ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt7xs = self.com.zero_pad(Array(self.pt7xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt7ys = self.com.zero_pad(Array(self.pt7ys[bookmark[0]...bookmark[1]-1]))
                    
                    
                    /* Check that there is more than one pose in this group of frames,
                       then calculate the minimum and maximum X and Y values to
                       normalize the entire serve as one group */
                    if poses_of_interest.count > 0 {
                        
                        // Loop through all of the pose indices
                        for pose_idx in 0...poses_of_interest.count-1 {
                            
                            // Loop through every coordinate in the pose
                            for value_idx in 0...poses_of_interest[pose_idx].count-1 {
                                let coordinate = poses_of_interest[pose_idx][value_idx]
                                if ((value_idx % 2) == 0) {
                                    if (coordinate > maxX) {
                                        maxX = coordinate
                                    }
                                    if (coordinate < minX) || (coordinate > 0.0) {
                                        minX = coordinate
                                    }
                                }
                                else {
                                    if (coordinate > maxY) {
                                        maxY = coordinate
                                    }
                                    if (coordinate < minY) || (coordinate > 0.0) {
                                        minY = coordinate
                                    }
                                }
                            }
                        }
                        
                        /* Normalize every element in every array that doesn't
                           contain distances or angles*/
                        
                        //Back Leg Kicked Back
                        specificpt10ys.enumerated().forEach { index, value in
                            specificpt10ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt13ys.enumerated().forEach { index, value in
                            specificpt13ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt2xs.enumerated().forEach { index, value in
                            specificpt2xs[index] = (value - maxX) * (1.0/(maxX-minX))
                          }
                        specificpt3xs.enumerated().forEach { index, value in
                            specificpt3xs[index] = (value - maxX) * (1.0/(maxX-minX))
                          }
                        specificpt4xs.enumerated().forEach { index, value in
                            specificpt4xs[index] = (value - maxX) * (1.0/(maxX-minX))
                          }
                        specificpt5xs.enumerated().forEach { index, value in
                            specificpt5xs[index] = (value - maxX) * (1.0/(maxX-minX))
                          }
                        specificpt6xs.enumerated().forEach { index, value in
                            specificpt6xs[index] = (value - maxX) * (1.0/(maxX-minX))
                          }
                        specificpt7xs.enumerated().forEach { index, value in
                            specificpt7xs[index] = (value - maxX) * (1.0/(maxX-minX))
                          }
                        specificpt2ys.enumerated().forEach { index, value in
                            specificpt2ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt3ys.enumerated().forEach { index, value in
                            specificpt3ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt4ys.enumerated().forEach { index, value in
                            specificpt4ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt5ys.enumerated().forEach { index, value in
                            specificpt5ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt6ys.enumerated().forEach { index, value in
                            specificpt6ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }
                        specificpt7ys.enumerated().forEach { index, value in
                            specificpt7ys[index] = (value - maxY) * (-1.0/(maxY-minY))
                          }


                    }
                    
                    //Feet Spacing - distances between the server's feet
                    var specificfeetDistances: [Double] = []
                    for (index, coord) in specificpt10xs.enumerated() {
                        specificfeetDistances.append(self.com.distance(coord, specificpt10ys[index], specificpt13xs[index], specificpt13ys[index]))
                    }


                    //Shoulder Rotation - distances between the shoulders
                    var specificshoulderDistances: [Double] = []
                    for (index, coord) in specificpt2xs.enumerated() {
                        specificshoulderDistances.append(self.com.distance(coord, specificpt2ys[index], specificpt5xs[index], specificpt5ys[index]))
                    }
                    
                    /* Construct histograms out of the lists of metrics.
                       These histograms will be fed to the AI serve grader
                       models. */
                    
                    // Group all the angle-related arrays together
                    let preHistogramAngleArrays = [
                        specificbackAngles,
                        specificleftLegAngles,
                        specificrightLegAngles,
                        specificleftHandAngles,
                        specificrightHandAngles
                    ]
                    
                    // Group all the distance-related arrays together
                    let preHistogramDistanceArrays = [
                        specificfeetDistances,
                        specificshoulderDistances
                    ]
                    
                    // Group all the coordinate-related arrays together
                    let preHistogramCoordArrays = [
                        specificpt10ys,
                        specificpt13ys,
                        specificpt2xs,
                        specificpt3xs,
                        specificpt4xs,
                        specificpt5xs,
                        specificpt6xs,
                        specificpt7xs,
                        specificpt2ys,
                        specificpt3ys,
                        specificpt4ys,
                        specificpt5ys,
                        specificpt6ys,
                        specificpt7ys
                    ]
                    
                    
                    // Initialize array to hold the final histograms
                    var postHistogramArrays: [[Double]] = []
                    
                    
                    // Construct histograms from the angle-related arrays
                    for array in preHistogramAngleArrays {
                        postHistogramArrays.append(self.com.histogram(array, 120, -2 * Double.pi, 2*Double.pi))
                    }
                    
                    // Construct histograms from the distance-related arrays
                    for array in preHistogramDistanceArrays {
                        postHistogramArrays.append(self.com.histogram(array, 120, 0.0, Double(imgWidth)))
                    }
                    
                    // Construct histograms from the coordinate-related arrays
                    for array in preHistogramCoordArrays {
                        postHistogramArrays.append(self.com.histogram(array, 120, 0.0, 1.0))
                    }
                    
                    
                    // Add all histograms to the collection of ML arrays
                    self.allServeMLArrays.append(postHistogramArrays)
                }

                // Update the UI to let users know their serves are being graded
                DispatchQueue.main.async {
                    self.progressLabel.strokedText = "Grading serves..."
                }
                
                
                // Get 8 category scores for every serve in allServeMLArrays
                for MLArray in self.allServeMLArrays {
                    
                    // Back Arch score
                    let backArchScore = self.com.getBAPrediction(self.BAModel!, MLArray[0])
                    
                    
                    // Back Leg Kicked Back score
                    let backLegScore = self.com.getBLPrediction(self.BLModel!, MLArray[7], MLArray[8], MLArray[1], MLArray[2])
                    
                    
                    // Feet Spacing score
                    let feetSpacingScore = self.com.getFSPrediction(self.FSModel!, MLArray[5])
                    
                    
                    // Jump Height score
                    let jumpHeightScore = self.com.getJHPrediction(self.JHModel!, MLArray[7], MLArray[8])
                    
                    
                    // Left Arm Straight Score
                    let leftArmScore = self.com.getLAPrediction(self.LAModel!, MLArray[3], MLArray[4])
                    
                    
                    // Legs Bent Score
                    let legsBentScore = self.com.getLBPrediction(self.LBModel!, MLArray[1], MLArray[2])
                    
                    
                    // Shoulder Rotation Timing Score
                    let shoulderScore = self.com.getSTPrediction(self.STModel!, MLArray[6], MLArray[1], MLArray[2])
                    
                    
                    // Toss Height Score
                    let tossHeightScore = self.com.getTHPrediction(self.THModel!, MLArray[9], MLArray[10], MLArray[11], MLArray[12], MLArray[13], MLArray[14], MLArray[15], MLArray[16], MLArray[17], MLArray[18], MLArray[19], MLArray[20])
                    
                    
                    // Add the final score "vector" to the collection of score vectors
                    self.serveVectorArray.append([backArchScore, feetSpacingScore, backLegScore, jumpHeightScore, leftArmScore, legsBentScore, shoulderScore, tossHeightScore])

                }
                
                /* Reset all of the ML Arrays */
                
                self.backAngles = []
                self.pt10xs = []
                self.pt10ys = []
                self.pt13xs = []
                self.pt13ys = []
                self.leftLegAngles = []
                self.rightLegAngles = []
                self.leftHandAngles = []
                self.rightHandAngles = []
                self.pt2xs = []
                self.pt3xs = []
                self.pt4xs = []
                self.pt5xs = []
                self.pt6xs = []
                self.pt7xs = []
                self.pt2ys = []
                self.pt3ys = []
                self.pt4ys = []
                self.pt5ys = []
                self.pt6ys = []
                self.pt7ys = []
                self.allServeMLArrays = []
                
                
                /* Create a new practice object from the existing serve video,
                   date, scores and timestams */
                self.newPractice = Practice(context: self.context)
                self.newPractice!.date = NSDate() as Date
                self.newPractice!.urls = self.urlArray
                self.newPractice!.vectors = self.serveVectorArray
                self.newPractice!.timestamps = self.timestamp_frames
                
                
                // Save the practice object
                do {
                    try self.context.save()
                } catch {
                    print("Couldn't save new practice")
                }

                
                // Segue to the feedback controller
                DispatchQueue.main.async {
                    self.progressLabel.isHidden = true
                    self.progressView.isHidden = true
                    self.navigationController?.popViewController(animated: false)
                    self.performSegue(withIdentifier:"segueToFeedback", sender: self)
                }

            }
        }
    }
}
