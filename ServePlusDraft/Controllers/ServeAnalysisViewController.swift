//
//  ServeAnalysisViewController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/6/21.
//

import UIKit
import SwiftUI
import AVFoundation
import Vision
import Photos
import CoreGraphics


class ServeAnalysisViewController: UIViewController {

    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    @IBOutlet weak var ReplayView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabelStroked!
    
    var inputURL: URL?
    var serveVectorArray: [[Double]] = []
    var lh_values: [Double] = []
    var rh_values: [Double] = []
    var urlArray: [URL] = []
    var allServeMLArrays: [[[Double]]] = []
    var orientation: UIImage.Orientation?
    var editingImage: UIImage?
    let targetImageSize = CGSize(width: imgWidth, height: imgWidth)
    var completedDetection: Bool = false
    var timestamp_frames : [[Int]] = []

    var allVideoPoses: [[Double]] = []
    var total_points: [Int] = []
    
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
    //Feet Spacing
    
    //Left Arm Straight
    var leftHandAngles: [Double] = []
    var rightHandAngles: [Double] = []
    var newPractice: Practice?
    
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
    var continue_analyzing: Bool?
    
    var progressChange: ((Double) -> Void)?
    var noPosesDetected: (() -> Void)?


    
    lazy var poseDetectionRequest = [VNDetectHumanBodyPoseRequest(completionHandler: posesDetected)]
    
    let com = {
        Common(imgWidth,imgWidth)
    }()
    
    
    override func viewDidLoad() {

        if !continue_analyzing! {
            super.viewDidLoad()

            progressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
            analyzeServe(self.inputURL!)
        }
        else {
            DispatchQueue.main.async {
                self.progressLabel.isHidden = false
                self.progressView.isHidden = false
                self.ReplayView.isHidden = false
            }
        }
        
    }
    
    let ciContext = CIContext()
    var resultBuffer: CVPixelBuffer?
    
    func uiImageToPixelBuffer(_ uiImage: UIImage, targetSize: CGSize, orientation: UIImage.Orientation) -> CVPixelBuffer? {
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

        if resultBuffer == nil {
            let result = CVPixelBufferCreate(kCFAllocatorDefault, Int(targetSize.width), Int(targetSize.height), kCVPixelFormatType_32BGRA, nil, &resultBuffer)
            
            guard result == kCVReturnSuccess else {
                fatalError("Can't allocate pixel buffer.")
            }
        }
        
        ciContext.render(rotated, to: resultBuffer!)
        
        return resultBuffer
    }
    
    func addLine(context: inout CGContext, fromPoint start: CGPoint, toPoint end:CGPoint, color: UIColor) {
        context.setLineWidth(3.0)
        context.setStrokeColor(color.cgColor)
        
        context.move(to: start)
        context.addLine(to: end)
        
        context.closePath()
        context.strokePath()
    }
     
    func showAlert(title: String, message: String, btnText: String, completion: @escaping () -> Void = {}) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: btnText, style: .default, handler: nil))
        present(alert, animated: true, completion: completion)
    }
    

    
    func posesDetected(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedPointsObservation] else { return }

        var humans: [[CGPoint]] = []
        var center = (0.0, 0.0)
        observations.forEach {
            let ((imgWidth, imgHeight), imagePoints) = com.getImagePoints($0, self.orientation!)
            humans.append(imagePoints)
            center = (Double(imgWidth)/2.0, Double(imgHeight)/2.0)
        }
        var serverIndex = 0
        var currentDistanceFromCenter = 1000000.0
        
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
            completedDetection = true
            return
        }
        
        if humans.count > 1 {
            for human in 0...humans.count-1 {
                if com.distanceFromCenter(humans[human], center) < currentDistanceFromCenter {
                    currentDistanceFromCenter = com.distanceFromCenter(humans[human], center)
                    serverIndex = human
                }
            }
        }
        self.allVideoPoses.append([])
        for point in 0...humans[serverIndex].count-1 {
            let x_pos = Double(humans[serverIndex][point].x)
            let y_pos = Double(humans[serverIndex][point].y)
            self.allVideoPoses[self.allVideoPoses.count - 1].append(x_pos)
            self.allVideoPoses[self.allVideoPoses.count - 1].append(y_pos)
            if x_pos != 0.0 && y_pos != 0.0 {
                self.total_points[point] = 1
            }
        }
        //If less than half of the points are detected, it is not a serve
        
        
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
        
        self.lh_values.append(Double(humans[serverIndex][7].y))
        self.rh_values.append(Double(humans[serverIndex][4].y))
        
        let normalizedPose = com.normalizeServeFrame(humans[serverIndex])
        
        guard let mlMultiArray = try? MLMultiArray(shape:[1,36], dataType:MLMultiArrayDataType.double) else {
            fatalError("Unexpected runtime error. MLMultiArray")
        }
        for (index, element) in normalizedPose.enumerated() {
            mlMultiArray[index] = NSNumber(floatLiteral: element)
        }

        let connections = com.getConnections(humans[serverIndex])
        UIGraphicsBeginImageContext(targetImageSize)
        var context:CGContext = UIGraphicsGetCurrentContext()!

        for connection in connections {
            let (center1, center2, color) = connection
            addLine(context: &context, fromPoint: center1, toPoint: center2, color: color)
        }

        var serveImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        var mainImage: UIImage = editingImage!

        mainImage = com.resizeImage(image: mainImage, size: mainImage.size, useToMakeVideo: true)

        let serveImageCropped: UIImage = com.cropImage(image: serveImage, aspectX: mainImage.size.width, aspectY: mainImage.size.height)

        serveImage = com.resizeImage(image: serveImageCropped, size: mainImage.size)

        editingImage = com.superimposeImages(mainImage: mainImage, subImage: serveImage)
        completedDetection = true
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToFeedback" {
            if let destinationVC = segue.destination as? FeedbackController {
                destinationVC.practice = self.newPractice
            }
        }
    }
    
    func analyzeServe(_ inputURL: URL) {
        self.serveVectorArray = []
        self.urlArray = []
        self.total_points = [Int](repeating: 0, count: 18)

        let outputURL: URL = NSURL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("\(NSUUID().uuidString).mp4")!

        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov) else {
            print("ERROR: Failed to construct AVAssetWriter.")
            return
        }

        let avAsset = AVURLAsset(url: inputURL, options: nil)
        let composition = AVVideoComposition(asset: avAsset, applyingCIFiltersWithHandler: { request in })
        let track = avAsset.tracks(withMediaType: AVMediaType.video)

        guard let media = track[0] as AVAssetTrack? else {
            print("ERROR: There is no video track.")
            return
        }
        DispatchQueue.main.async {
            self.progressLabel.strokedText = "Analyzing poses...(0%)"
            self.progressLabel.isHidden = false
            self.progressView.setProgress(0.0, animated: false)
            self.progressChange!(0.0)
            self.progressView.isHidden = false
        }

        let naturalSize: CGSize = media.naturalSize
        let preferedTransform: CGAffineTransform = media.preferredTransform
        let size = naturalSize.applying(preferedTransform)
        let width = abs(size.width)
        let height = abs(size.height)

        let outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ] as [String: Any]

        let writerInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings as [String : AnyObject])
        videoWriter.add(writerInput)

        _ = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        writerInput.expectsMediaDataInRealTime = false

        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: CMTime.zero)

        let generator = AVAssetImageGenerator(asset: avAsset)

        generator.requestedTimeToleranceAfter = CMTime.zero
        generator.requestedTimeToleranceBefore = CMTime.zero

        var buffer: CVPixelBuffer? = nil
        var frameCount = 0
        let durationForEachImage = 1

        let length: Double = Double(CMTimeGetSeconds(avAsset.duration))
        let fps: Int = Int(1 / CMTimeGetSeconds(composition.frameDuration))
        DispatchQueue.global().async {

            for i in stride(from: 0, to: length, by: 1.0 / Double(fps)) {
                autoreleasepool {
                    let capturedImage : CGImage! = try? generator.copyCGImage(at: CMTime(seconds: i, preferredTimescale : 600), actualTime: nil)
                    if capturedImage != nil {
                        if preferedTransform.tx == naturalSize.width && preferedTransform.ty == naturalSize.height {
                            self.orientation = UIImage.Orientation.down
                        } else if preferedTransform.tx == 0 && preferedTransform.ty == 0 {
                            self.orientation = UIImage.Orientation.up
                        } else if preferedTransform.tx == 0 && preferedTransform.ty == naturalSize.width {
                            self.orientation = UIImage.Orientation.left
                        } else {
                            self.orientation = UIImage.Orientation.right
                        }

                        let tmpImageToEdit = UIImage(cgImage: capturedImage, scale: 1.0, orientation: self.orientation!)

                        self.editingImage = self.com.resizeImage(image: tmpImageToEdit, size: tmpImageToEdit.size, useToMakeVideo: true)

                        let tmpImageToDetect: UIImage = UIImage(cgImage: capturedImage)
                        let bufferToDetect = self.uiImageToPixelBuffer(tmpImageToDetect, targetSize: self.targetImageSize, orientation: self.orientation!)
                        do {
                            let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: bufferToDetect!, options: [:])
                            try classifierRequestHandler.perform(self.poseDetectionRequest)
                        } catch {
                            print("Error: Failed to detect serves.")
                            print(error)
                        }

                        while true {
                            if self.completedDetection {
                                buffer = self.com.getPixelBufferFromCGImage(cgImage: self.editingImage!.cgImage!)
                                self.completedDetection = false
                                break
                            }
                        }
                        let frameTime: CMTime = CMTimeMake(value: Int64(__int32_t(frameCount) * __int32_t(durationForEachImage)), timescale: __int32_t(fps))

                        frameCount += 1
                    }


                }

                let progressRate = i / length * 100

                DispatchQueue.main.async {
                    self.ReplayView.image = self.editingImage!
                    self.progressLabel.strokedText = "Analyzing poses...(" + String(Int(progressRate)) + "%)"
                    self.progressView.setProgress(Float(floor(progressRate) / 100), animated: true)
                    self.progressChange!(progressRate)
                }
            }
            DispatchQueue.main.async {
                self.ReplayView.image = nil
                self.progressChange!(100.0)
            }
            if self.total_points.reduce(0, +) < 14 {
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: false)
                    self.noPosesDetected!()

                }
            }
            else {
                DispatchQueue.main.async {
                    self.progressLabel.strokedText = "Detecting serves..."
                    self.progressView.setProgress(0.0, animated: false)
                }
                let before_frame_subtractor = 20
                let after_frame_adder = 100


                let pois = self.com.final_filter(self.lh_values, self.rh_values, 60, 10.0, 60, false)
                self.lh_values = []
                self.rh_values = []

                self.timestamp_frames = []

                for frame in pois {
                    let beginning = max(0, frame - before_frame_subtractor)
                    let end = min(frame + after_frame_adder, frameCount - 1)
                    self.timestamp_frames.append([beginning, end])
                }
                self.urlArray = Array(repeating: inputURL, count: self.timestamp_frames.count)

                var minX = 1000000.0
                var minY = 1000000.0
                var maxX = 0.0
                var maxY = 0.0

                DispatchQueue.main.async {
                    self.progressLabel.strokedText = "Gleaning keypoints..."
                    self.progressView.setProgress(0.0, animated: false)
                }
                for bookmark in self.timestamp_frames {
                    let poses_of_interest = Array(self.allVideoPoses[bookmark[0]...bookmark[1]-1])
                    var specificbackAngles = self.com.zero_pad(Array(self.backAngles[bookmark[0]...bookmark[1]-1]))
                    var specificpt10xs = self.com.zero_pad(Array(self.pt10xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt13xs = self.com.zero_pad(Array(self.pt13xs[bookmark[0]...bookmark[1]-1]))
                    var specificpt10ys = self.com.zero_pad(Array(self.pt10ys[bookmark[0]...bookmark[1]-1]))
                    var specificpt13ys = self.com.zero_pad(Array(self.pt13ys[bookmark[0]...bookmark[1]-1]))
                    var specificleftLegAngles = self.com.zero_pad(Array(self.leftLegAngles[bookmark[0]...bookmark[1]-1]))
                    var specificrightLegAngles = self.com.zero_pad(Array(self.rightLegAngles[bookmark[0]...bookmark[1]-1]))
                    var specificleftHandAngles = self.com.zero_pad(Array(self.leftHandAngles[bookmark[0]...bookmark[1]-1]))
                    var specificrightHandAngles = self.com.zero_pad(Array(self.rightHandAngles[bookmark[0]...bookmark[1]-1]))
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
                    if poses_of_interest.count > 0 {
                        for pose_idx in 0...poses_of_interest.count-1 {
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
                        //Feet Spacing


                    }
                    var specificfeetDistances: [Double] = []
                    for (index, coord) in specificpt10xs.enumerated() {
                        specificfeetDistances.append(self.com.distance(coord, specificpt10ys[index], specificpt13xs[index], specificpt13ys[index]))
                    }


                    //Shoulder Rotation

                    var specificshoulderDistances: [Double] = []
                    for (index, coord) in specificpt2xs.enumerated() {
                        specificshoulderDistances.append(self.com.distance(coord, specificpt2ys[index], specificpt5xs[index], specificpt5ys[index]))
                    }
                    self.allServeMLArrays.append([
                        specificbackAngles,


                        //Back Leg Kicked Back
                        specificpt10ys,//also for Jump Height
                        specificpt13ys, //also for Jump Height
                        specificleftLegAngles, //also for legs bent and shoulder rotation
                        specificrightLegAngles, // also for legs bent and shoulder rotation

                        //Feet Spacing
                        specificfeetDistances,

                        //Left Arm Straight
                        specificleftHandAngles,
                        specificrightHandAngles,

                        //Shoulder Rotation
                        specificshoulderDistances,

                        //Toss height
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
                    ])

                }
                let bounds = [
                    (0, 4),
                    (0, 4),
                    (0, 1),
                    (0, 4),
                    (0, 1),
                    (0, 4),
                    (9, 9),
                    (0, 4),
                    (0, 3)
                ]
                DispatchQueue.main.async {
                    self.progressLabel.strokedText = "Grading serves..."
                    self.progressView.setProgress(0.0, animated: false)
                }
                for MLArray in self.allServeMLArrays {
                    let backArchScore = self.com.getBAPrediction(self.BAModel!, MLArray[0])
                    let backLegScore = self.com.getBLPrediction(self.BLModel!, MLArray[1], MLArray[2], MLArray[3], MLArray[4])
                    let feetSpacingScore = self.com.getFSPrediction(self.FSModel!, MLArray[5])
                    let jumpHeightScore = self.com.getJHPrediction(self.JHModel!, MLArray[1], MLArray[2])
                    let leftArmScore = self.com.getLAPrediction(self.LAModel!, MLArray[6], MLArray[7])
                    let legsBentScore = self.com.getLBPrediction(self.LBModel!, MLArray[3], MLArray[4])
                    let shoulderScore = self.com.getSTPrediction(self.STModel!, MLArray[8], MLArray[3], MLArray[4])
                    let tossHeightScore = self.com.getTHPrediction(self.THModel!, MLArray[9], MLArray[10], MLArray[11], MLArray[12], MLArray[13], MLArray[14], MLArray[15], MLArray[16], MLArray[17], MLArray[18], MLArray[19], MLArray[20])
                    self.serveVectorArray.append([backArchScore, feetSpacingScore, backLegScore, jumpHeightScore, leftArmScore, legsBentScore, shoulderScore, tossHeightScore])

                }

                self.backAngles = []


                //Back Leg Kicked Back
                self.pt10xs = []
                self.pt10ys = []
                self.pt13xs = [] //also for Jump Height
                self.pt13ys = [] //also for Jump Height
                self.leftLegAngles = [] //also for legs bent and shoulder rotation
                self.rightLegAngles = [] // also for legs bent and shoulder rotation

                //Feet Spacing

                //Left Arm Straight
                self.leftHandAngles = []
                self.rightHandAngles = []

                //Shoulder Rotation

                //Toss height
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
                self.newPractice = Practice(context: self.context)
                self.newPractice!.date = NSDate() as Date
                self.newPractice!.urls = self.urlArray
                self.newPractice!.vectors = self.serveVectorArray
                self.newPractice!.timestamps = self.timestamp_frames
                
                do {
                    try self.context.save()
                } catch {
                    print("Couldn't save new practice")
                }

                DispatchQueue.main.async {
                    self.progressLabel.isHidden = true
                    self.progressView.isHidden = true
                    self.navigationController?.popViewController(animated: false)
                    self.performSegue(withIdentifier:"segueToFeedback", sender: self)
                }

            }
        }
    }
    

    /*
     MARK: - Navigation

     In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         Get the new view controller using segue.destination.
         Pass the selected object to the new view controller.
    }
    */

}


