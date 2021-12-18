//
//  Common.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 3/8/21.
//
//  Class for the algorithmic, mathematical and AI components
//  that comprise the computational meat of ServePlus. The
//  functions that process human body keypoints, detect
//  individual serves from entire videos, and generate scores
//  for a players serve can be found here.

import CoreGraphics
import UIKit
import Foundation
import Vision
import AVFoundation
import MobileCoreServices


class Common {
        
    /* References to the dimensions of the frames of the input
       videos, so when keypoints are detected, I can project
       keypoints from the normalized coordinate space into
       image coordinates. */
    var imgWidth = 0
    var imgHeight = 0
    
    
    /* Pairs of body keypoints indices that are connected
       (e.g. the shoulder and the elbow, but not the left
       hip and the forehead) */
    let connection_indices = [
        (1, 2),   (1, 5),   (2, 3),  (3, 4),  (5, 6),
        (6, 7),   (1, 8),   (8, 9),  (9, 10), (1, 11),
        (11, 12), (12, 13), (1, 0),  (0, 14), (14, 16),
        (0, 15),  (15, 17), (2, 16), (5, 17)
    ]
    
    
    // Nice colors for the keypoint connections
    var connection_colors : [UIColor] = [UIColor.rgb(255, 0, 0),
                                  UIColor.rgb(255, 85, 0),
                                  UIColor.rgb(255, 170, 0),
                                  UIColor.rgb(255, 255, 0),
                                  UIColor.rgb(170, 255, 0),
                                  UIColor.rgb(85, 255, 0),
                                  UIColor.rgb(0, 255, 0),
                                  UIColor.rgb(0, 255, 85),
                                  UIColor.rgb(0, 255, 170),
                                  UIColor.rgb(0, 255, 255),
                                  UIColor.rgb(0, 170, 255),
                                  UIColor.rgb(0, 85, 255),
                                  UIColor.rgb(0, 0, 255),
                                  UIColor.rgb(85, 0, 255),
                                  UIColor.rgb(170, 0, 255),
                                  UIColor.rgb(255, 0, 255),
                                  UIColor.rgb(255, 0, 170),
                                  UIColor.rgb(255, 0, 85),
                                  UIColor.rgb(255, 0, 255)]
    
    
    /* This allows us to initialize an instance of the Common
       class so that the video dimensions can be used in all
       of these Common functions without having to specify
       the dimensions over and over again. */
    init(_ imageWidth: Int,_ imageHeight: Int){
        imgWidth = imageWidth
        imgHeight = imageHeight
    }
    
    func getImagePoints(_ observation: VNRecognizedPointsObservation, _ orientation: UIImage.Orientation) -> ((Int, Int), [CGPoint]) {

        /* Takes already detected keypoints and returns those same
           keypoints in the video's native coordinate space*/
        
        // Get the detected points from the ML Pose observation
        guard let recognizedPoints =
                try? observation.recognizedPoints(forGroupKey: .all) else {
            fatalError()
        }
        
//        
//        let jointsOfInterest: [VNRecognizedPointKey] = [
//            .bodyLandmarkKeyNose,
//            .bodyLandmarkKeyNeck,
//            .bodyLandmarkKeyRightShoulder,
//            .bodyLandmarkKeyRightElbow,
//            .bodyLandmarkKeyRightWrist,
//            .bodyLandmarkKeyLeftShoulder,
//            .bodyLandmarkKeyLeftElbow,
//            .bodyLandmarkKeyLeftWrist,
//            .bodyLandmarkKeyRightHip,
//            .bodyLandmarkKeyRightKnee,
//            .bodyLandmarkKeyRightAnkle,
//            .bodyLandmarkKeyLeftHip,
//            .bodyLandmarkKeyLeftKnee,
//            .bodyLandmarkKeyLeftAnkle,
//            .bodyLandmarkKeyRightEye,
//            .bodyLandmarkKeyLeftEye,
//            .bodyLandmarkKeyRightEar,
//            .bodyLandmarkKeyLeftEar,
//            ]
//        let imagePoints: [CGPoint] = jointsOfInterest.compactMap {
//            guard let point = recognizedPoints[$0], point.confidence > 0 else {
//                return CGPoint(0.0, 0.0) }
//            let x = point.x
//            let y = point.y
//            return VNImagePointForNormalizedPoint(CGPoint(CGFloat(x), CGFloat(1.0-y)),
//                                                  Int(imgWidth),
//                                                  Int(imgHeight))
//        }
        
        // Initialize an array to hold the frame-native points
        var trialPoints: [CGPoint] = []
        
        
        /* Bring every point into the frame's native coordinate
           space */
        for point in recognizedPoints {
            trialPoints.append(
                VNImagePointForNormalizedPoint(
                    CGPoint(CGFloat(point.value.x), CGFloat(1.0-point.value.y)),
                    Int(imgWidth),
                    Int(imgHeight)
                )
            )
        }
        
        // Return the points with the image dimensions
        return ((Int(imgWidth), Int(imgHeight)), trialPoints)
        
    }
    
    func distanceFromCenter(_ pose: [CGPoint], _ center: (Double, Double)) -> Double {
        
        /* Takes a pose and returns the average of each pose
           keypoint's distance from the frame's center. Used
           to determine the main person in a frame, since
           pose detection can detect multiple people. */
        
        // Initialize float to hold sum of keypoint distances
        var distanceSum = 0.0
        
        
        /* Initialize integer to keep track of how many detected
           keypoints are actually valid */
        var realPoints = pose.count
        
        
        // Loop through every keypoint
        for point in pose {
            
            /* Return the distance from the center if the detected
               point isn't a dud */
            if point != CGPoint(0.0, 0.0) {
                distanceSum += hypot(Double(point.x), Double(point.y))
            }
            
            /* Subtract from the total number of valid keypoints if
               the point is a dud */
            else {
                realPoints -= 1
            }
        }
        
        /* Average all the distances and return the result
           (ulpOfOne is a really small number to ensure we
           don't get a divideByZero error */
        return distanceSum/(Double(realPoints)+Double.ulpOfOne)
    }
    
    func getConnections(_ points: [CGPoint]) -> [(CGPoint, CGPoint, UIColor)] {
        
        /* Takes detected keypoints and returns a list of
           "connections". Each connection is a pair of points with
            a color that represents a line that will be drawn on
            the replay video.*/
        
        // Initialize array to hold all the connections
        var connections: [(CGPoint, CGPoint, UIColor)] = []
        
        
        /* Loop through all pairs of connected keypoint indices */
        for conn_idx in 0...connection_indices.count-1 {
            
            // Unpack the individual keypoint indices
            let (pointOneIndex, pointTwoIndex) = connection_indices[conn_idx]
            
            
            /* Only include a connection if both keypoints are
               valid */
            if points[pointOneIndex] != CGPoint(0.0,0.0) && points[pointTwoIndex] != CGPoint(0.0, 0.0) {
                
                // Add the connection to our array
                connections.append((points[pointOneIndex], points[pointTwoIndex], connection_colors[conn_idx]))
            }
        }
    
        // Return the connections
        return connections
    }
    
    func normalizeServeFrame(_ pose: [CGPoint]) -> [Double] {
        
        /* Normalizes a single pose such that all points fall
           between 0 and 1 on the x axis, and the proportions
           of the dimensions stay the same (i.e a taller person
           will still have a taller normalized pose than a
           shorter person) */
        
        /* Initialize array that will store the raw coords of
           the detected keypoints */
        var serve_frame: [Double] = []
        
        
        // Append each coordinate to the serve_frame array
        for point in pose {
            serve_frame.append(Double(point.x))
            serve_frame.append(Double(point.y))
        }
        
        /* Align the pose to the left side of the frame */
        
        var leftmostX = 99999999.0
        
        for index in stride(from:0, to: serve_frame.count, by: 2) {
            
            /* Ignore points already on the left side of the frame
               (they are probably duds) */
            if serve_frame[index] < leftmostX && serve_frame[index] != 0.0 {
                leftmostX = serve_frame[index]
            }
        }
        
        for index in stride(from:0, to: pose.count, by: 2) {
            
            /* Ignore points already on the left side of the frame
               (they are probably duds) */
            if serve_frame[index] != 0.0 {
                serve_frame[index] -= leftmostX
            }
        }
        
        /* Align the pose to the upper side of the frame*/
        
        var topmostY = 99999999.0
        
        for index in stride(from:1, to: serve_frame.count, by: 2) {
            
            /* Ignore points already on the upper side of the frame
               (they are probably duds) */
            if serve_frame[index] < topmostY && serve_frame[index] != 0.0 {
                topmostY = serve_frame[index]
            }
        }
        
        for index in stride(from:1, to: pose.count, by: 2) {
            
            /* Ignore points already on the upper side of the frame
               (they are probably duds) */
            if serve_frame[index] != 0.0 {
                serve_frame[index] -= topmostY
            }
        }
        
        /* Scale the pose until it has a unit width (a width of 1) */
        
        var bottommostY = 0.0
        
        for index in stride(from:1, to: serve_frame.count, by: 2) {
            if serve_frame[index] > bottommostY {
                bottommostY = serve_frame[index]
            }
        }
        for index in 0...serve_frame.count - 1 {
            serve_frame[index] /= bottommostY
        }
        
        
        // Return the coordinate list
        return serve_frame
        
    }
    
    func two_point_angle(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        return atan((x2-x1)/(y1-y2))
    }
    
    func midpoint(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> (Double, Double) {
        return ((x1+x2)/2, (y1+y2)/2)
    }
    
    func three_point_angle(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x3: Double, _ y3: Double) -> Double {
        let x1x2s = pow((x1 - x2),2)
        let x1x3s = pow((x1 - x3),2)
        let x2x3s = pow((x3 - x3),2)
         
        let y1y2s = pow((y1 - y2),2)
        let y1y3s = pow((y1 - y3),2)
        let y2y3s = pow((y2 - y3),2)
        
        return acos((x1x2s + y1y2s + x2x3s + y2y3s - x1x3s - y1y3s)/(2*sqrt(x1x2s + y1y2s)*sqrt(x2x3s + y2y3s)))
    }
    
    func distance(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        return sqrt(pow((x1-x2), 2) + pow((y1-y2), 2))
    }
    
   
    func interpolateZeroes(_ arr: [Double]) -> [Double] {
        let firstNonZero = arr.first(where: { $0 != 0 })
        if firstNonZero == nil {
            return arr
        }
        var lastNonZero = firstNonZero

        var new_arr:[Double] = []
        var found_nonzero = false
        for element in arr {
            if (element == 0.0 && !found_nonzero) {
                new_arr.append(firstNonZero!)
            }
            else if (element == 0.0) {
                new_arr.append(lastNonZero!)
            }
            if (element != 0.0) {
                lastNonZero = element
                new_arr.append(element)
                found_nonzero = true
            }
        }
        return new_arr
    }

    func scale_array(_ arr: [Double]) -> [Double] {
        let range = arr.max()!-arr.min()!
        return arr.map({ ($0 - arr.min()!) * (100.0/range) })
    }

    func stdev(arr : [Double]) -> Double
    {
        let length = Double(arr.count)
        let avg = arr.reduce(0, {$0 + $1}) / length
        let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
        return sqrt(sumOfSquaredAvgDiff / length)
    }

    func RollingSampleVariance(_ data: [Double], _ sampleSize: Int) -> [Double]
    {
        var variances:[Double] = []

        for n in stride(from: 0, to: data.count - 1 - sampleSize, by: 1) {
            let arr = Array(data[n...n+sampleSize])
            variances.append(stdev(arr: arr))
        }
        return variances
    }

    func detect_peaks(_ arr: [Double], _ window_size: Int = 60, _ subtraction_threshold: Double = 10.0) -> [Int] {
        var peaks:[Int] = []
        if (arr.count <= window_size) {
            return [-1]
        }
        let dummy_zeroes = [Double](repeating: 0.0, count: window_size)
        let arr = dummy_zeroes + arr + dummy_zeroes
        var life_of_max = 0
        var current_max = 0.0
        var current_window = Array(arr[...(window_size-1)])
        var current_max_index = 0
        
        for x in stride(from: 0, to: arr.count - window_size, by: 1) {
            let window_max = current_window.max()
            if ((window_max! > current_max) || !(current_window.contains(current_max))) {
                current_max = window_max!
                life_of_max = 0
                current_max_index = x + current_window.firstIndex(of: current_max)!
            }
            life_of_max += 1
            current_window = Array(current_window[1...])
            current_window.append(arr[x+window_size])
            if life_of_max == window_size - 1 {
                peaks.append(current_max_index - window_size)
            }
        }
        
        var max_values:[Double] = []
        for index in peaks {
            max_values.append(arr[index + window_size])
        }
        let combined = zip(max_values, peaks).sorted {$0.0 < $1.0}
        let sorted_values = combined.map {$0.0}
        let sorted_indices = combined.map {$0.1}

        
        var subtractions:[Double] = []
        
        if (sorted_indices.count < 2) {
            return sorted_indices
        }

        for index in stride(from: 0, to: sorted_values.count - 1, by: 1) {
            let larger = sorted_values[index+1]
            let smaller = sorted_values[index]
            subtractions.append(larger - smaller)
        }

        let biggest_diff = subtractions.max()

        if biggest_diff! < subtraction_threshold {
            return sorted_indices.sorted()
        }
        let thresh_index = subtractions.firstIndex(of: biggest_diff!)! + 1
        let final_peaks = Array(sorted_indices[thresh_index...])
        return final_peaks.sorted()
    }

    func final_filter(_ lh_values: [Double], _ rh_values: [Double], _ window_size: Int, _ sub_thresh: Double, _ index_difference: Int, _ left_handed: Bool) -> [Int] {
        
        if (lh_values == [] || rh_values == []) {
            return [0]
        }
        var LH_Values = interpolateZeroes(lh_values)
        LH_Values = scale_array(LH_Values)
        
        var RH_Values = interpolateZeroes(lh_values)
        RH_Values = scale_array(RH_Values)
        
        let LH_Variances = RollingSampleVariance(LH_Values, 50)
        let RH_Variances = RollingSampleVariance(RH_Values, 50)

        var lh_indices = detect_peaks(LH_Variances, window_size, sub_thresh)
        var rh_indices = detect_peaks(RH_Variances, window_size, sub_thresh)

        if (lh_indices == [-1] || rh_indices == [-1]) {
            return [0]
        }
        var lh_check = 0
        var rh_check = 0

        while lh_check < lh_indices.count && rh_check < rh_indices.count {
            let diff = lh_indices[lh_check] - rh_indices[rh_check]
            if abs(diff) < index_difference {
                lh_check += 1
                rh_check += 1
            }
            else if diff > 0 {
                rh_indices.remove(at: rh_check)
            }
            else {
                lh_indices.remove(at: lh_check)
            }
        }

        if lh_check < lh_indices.count {
            while lh_indices.count > lh_check {
                lh_indices.remove(at: lh_check)
            }
        }

        if rh_check < rh_indices.count {
            while rh_indices.count > rh_check {
                rh_indices.remove(at: rh_check)
            }
        }

        if left_handed {
            return rh_indices
        }
        else {
            return lh_indices
        }
    }
    
    func cropVideo(sourceURL1: URL, startTime:Float, endTime:Float) -> URL {
        let manager = FileManager.default

        guard let documentDirectory = try? manager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {return sourceURL1}
        let mediaType = "mp4"
        if mediaType == kUTTypeMovie as String || mediaType == "mp4" as String {
            let asset = AVAsset(url: sourceURL1 as URL)

            let start = startTime
            let end = endTime

            var outputURL = documentDirectory.appendingPathComponent("output")
            do {
                try manager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
                outputURL = outputURL.appendingPathComponent("\(UUID().uuidString).\(mediaType)")
            }catch let error {
                print(error)
            }

            //Remove existing file
            _ = try? manager.removeItem(at: outputURL)


            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {return sourceURL1}
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4

            let startTime = CMTime(seconds: Double(start ), preferredTimescale: 1000)
            let endTime = CMTime(seconds: Double(end ), preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startTime, end: endTime)

            exportSession.timeRange = timeRange
            var exported = false
            var error = false
            exportSession.exportAsynchronously{
                switch exportSession.status {
                case .completed:
                    print("exported at \(outputURL)")
                    exported = true
                case .failed:
                    print("failed \(String(describing: exportSession.error))")
                    error = true

                case .cancelled:
                    print("cancelled \(String(describing: exportSession.error))")
                    error = true

                default: break
                }
            }
            while !exported {
                if error {
                    return sourceURL1
                }
            }
            return outputURL
        }
        return sourceURL1
    }
    
    func getDeviceName() -> String {
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        
        return String(cString:machine)
    }
    
    func superimposeImages(mainImage: UIImage, subImage: UIImage) -> UIImage {
        UIGraphicsBeginImageContext(mainImage.size)
        mainImage.draw(in: CGRect(x: 0, y: 0, width: mainImage.size.width, height: mainImage.size.height))
        subImage.draw(in: CGRect(x: 0, y: 0, width: subImage.size.width, height: subImage.size.height))
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func resizeImage(image: UIImage, size: CGSize, keepAspectRatio: Bool = false) -> UIImage {
        
        var targetSize: CGSize = size
        
        var newSize: CGSize = targetSize
        var newPoint: CGPoint = CGPoint(x: 0, y: 0)
        
        if keepAspectRatio {
            if targetSize.width / image.size.width <= targetSize.height / image.size.height {
                newSize = CGSize(width: targetSize.width, height: image.size.height * targetSize.width / image.size.width)
                newPoint.y = (targetSize.height - newSize.height) / 2
            } else {
                newSize = CGSize(width: image.size.width * targetSize.height / image.size.height, height: targetSize.height)
                newPoint.x = (targetSize.width - newSize.width) / 2
            }
        }
        
        UIGraphicsBeginImageContext(targetSize)
        image.draw(in: CGRect(x: newPoint.x, y: newPoint.y, width: newSize.width, height: newSize.height))
        let resizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    func cropImage(image: UIImage, aspectX: CGFloat, aspectY: CGFloat) -> UIImage {
        var newPoint: CGPoint
        var newSize: CGSize
        
        if aspectX >= aspectY {
            newSize = CGSize(width: image.size.width, height: image.size.width * aspectY / aspectX)
            newPoint = CGPoint(x: 0, y: (image.size.height - newSize.height) / 2)
        } else {
            newSize = CGSize(width: image.size.height * aspectX / aspectY, height: image.size.height)
            newPoint = CGPoint(x: (image.size.width - newSize.width) / 2, y: 0)
        }
        
        let cropRect = CGRect.init(x: newPoint.x, y: newPoint.y, width: newSize.width, height: newSize.height)
        let cropRef = image.cgImage!.cropping(to: cropRect)
        let croppedImage = UIImage(cgImage: cropRef!)
        
        return croppedImage
    }
    
    func getPixelBufferFromCGImage(cgImage: CGImage) -> CVPixelBuffer {
        let width = cgImage.width
        let height = cgImage.height
        
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pxBuffer: CVPixelBuffer? = nil
        
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxBuffer)
        CVPixelBufferLockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pxdata = CVPixelBufferGetBaseAddress(pxBuffer!)
        let bitsPerComponent: size_t = 8
        let bytesPerRow: size_t = 4 * width
        let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(
            data: pxdata,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x:0, y:0, width:CGFloat(width),height:CGFloat(height)))
        
        CVPixelBufferUnlockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pxBuffer!
    }
    
    func getBAPrediction(_ model: backArchXGBoost, _ backAngles: [Double]) -> Double  {
        guard let backArchScore = try? model.prediction(input: backArchXGBoostInput(
            f0: backAngles[0],
            f1: backAngles[1],
            f2: backAngles[2],
            f3: backAngles[3],
            f4: backAngles[4],
            f5: backAngles[5],
            f6: backAngles[6],
            f7: backAngles[7],
            f8: backAngles[8],
            f9: backAngles[9],
            f10: backAngles[10],
            f11: backAngles[11],
            f12: backAngles[12],
            f13: backAngles[13],
            f14: backAngles[14],
            f15: backAngles[15],
            f16: backAngles[16],
            f17: backAngles[17],
            f18: backAngles[18],
            f19: backAngles[19],
            f20: backAngles[20],
            f21: backAngles[21],
            f22: backAngles[22],
            f23: backAngles[23],
            f24: backAngles[24],
            f25: backAngles[25],
            f26: backAngles[26],
            f27: backAngles[27],
            f28: backAngles[28],
            f29: backAngles[29],
            f30: backAngles[30],
            f31: backAngles[31],
            f32: backAngles[32],
            f33: backAngles[33],
            f34: backAngles[34],
            f35: backAngles[35],
            f36: backAngles[36],
            f37: backAngles[37],
            f38: backAngles[38],
            f39: backAngles[39],
            f40: backAngles[40],
            f41: backAngles[41],
            f42: backAngles[42],
            f43: backAngles[43],
            f44: backAngles[44],
            f45: backAngles[45],
            f46: backAngles[46],
            f47: backAngles[47],
            f48: backAngles[48],
            f49: backAngles[49],
            f50: backAngles[50],
            f51: backAngles[51],
            f52: backAngles[52],
            f53: backAngles[53],
            f54: backAngles[54],
            f55: backAngles[55],
            f56: backAngles[56],
            f57: backAngles[57],
            f58: backAngles[58],
            f59: backAngles[59],
            f60: backAngles[60],
            f61: backAngles[61],
            f62: backAngles[62],
            f63: backAngles[63],
            f64: backAngles[64],
            f65: backAngles[65],
            f66: backAngles[66],
            f67: backAngles[67],
            f68: backAngles[68],
            f69: backAngles[69],
            f70: backAngles[70],
            f71: backAngles[71],
            f72: backAngles[72],
            f73: backAngles[73],
            f74: backAngles[74],
            f75: backAngles[75],
            f76: backAngles[76],
            f77: backAngles[77],
            f78: backAngles[78],
            f79: backAngles[79],
            f80: backAngles[80],
            f81: backAngles[81],
            f82: backAngles[82],
            f83: backAngles[83],
            f84: backAngles[84],
            f85: backAngles[85],
            f86: backAngles[86],
            f87: backAngles[87],
            f88: backAngles[88],
            f89: backAngles[89],
            f90: backAngles[90],
            f91: backAngles[91],
            f92: backAngles[92],
            f93: backAngles[93],
            f94: backAngles[94],
            f95: backAngles[95],
            f96: backAngles[96],
            f97: backAngles[97],
            f98: backAngles[98],
            f99: backAngles[99],
            f100: backAngles[100],
            f101: backAngles[101],
            f102: backAngles[102],
            f103: backAngles[103],
            f104: backAngles[104],
            f105: backAngles[105],
            f106: backAngles[106],
            f107: backAngles[107],
            f108: backAngles[108],
            f109: backAngles[109],
            f110: backAngles[110],
            f111: backAngles[111],
            f112: backAngles[112],
            f113: backAngles[113],
            f114: backAngles[114],
            f115: backAngles[115],
            f116: backAngles[116],
            f117: backAngles[117],
            f118: backAngles[118],
            f119: backAngles[119])) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = backArchScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    
    func zero_pad(_ array: [Double]) -> [Double] {
        if array.count == 120 {
            return array
        }
        let added = Array(repeating: 0.0, count: 120-array.count)
        return array+added
    }
    
    func getBLPrediction(_ model: backLegKickedBackXGBoost, _ pt10ys: [Double], _ pt13ys: [Double], _ leftLegAngles: [Double], _ rightLegAngles: [Double]) -> Double  {
        guard let backLegScore = try? model.prediction(input: backLegKickedBackXGBoostInput(
            f0: pt10ys[0],
            f1: pt10ys[1],
            f2: pt10ys[2],
            f3: pt10ys[3],
            f4: pt10ys[4],
            f5: pt10ys[5],
            f6: pt10ys[6],
            f7: pt10ys[7],
            f8: pt10ys[8],
            f9: pt10ys[9],
            f10: pt10ys[10],
            f11: pt10ys[11],
            f12: pt10ys[12],
            f13: pt10ys[13],
            f14: pt10ys[14],
            f15: pt10ys[15],
            f16: pt10ys[16],
            f17: pt10ys[17],
            f18: pt10ys[18],
            f19: pt10ys[19],
            f20: pt10ys[20],
            f21: pt10ys[21],
            f22: pt10ys[22],
            f23: pt10ys[23],
            f24: pt10ys[24],
            f25: pt10ys[25],
            f26: pt10ys[26],
            f27: pt10ys[27],
            f28: pt10ys[28],
            f29: pt10ys[29],
            f30: pt10ys[30],
            f31: pt10ys[31],
            f32: pt10ys[32],
            f33: pt10ys[33],
            f34: pt10ys[34],
            f35: pt10ys[35],
            f36: pt10ys[36],
            f37: pt10ys[37],
            f38: pt10ys[38],
            f39: pt10ys[39],
            f40: pt10ys[40],
            f41: pt10ys[41],
            f42: pt10ys[42],
            f43: pt10ys[43],
            f44: pt10ys[44],
            f45: pt10ys[45],
            f46: pt10ys[46],
            f47: pt10ys[47],
            f48: pt10ys[48],
            f49: pt10ys[49],
            f50: pt10ys[50],
            f51: pt10ys[51],
            f52: pt10ys[52],
            f53: pt10ys[53],
            f54: pt10ys[54],
            f55: pt10ys[55],
            f56: pt10ys[56],
            f57: pt10ys[57],
            f58: pt10ys[58],
            f59: pt10ys[59],
            f60: pt10ys[60],
            f61: pt10ys[61],
            f62: pt10ys[62],
            f63: pt10ys[63],
            f64: pt10ys[64],
            f65: pt10ys[65],
            f66: pt10ys[66],
            f67: pt10ys[67],
            f68: pt10ys[68],
            f69: pt10ys[69],
            f70: pt10ys[70],
            f71: pt10ys[71],
            f72: pt10ys[72],
            f73: pt10ys[73],
            f74: pt10ys[74],
            f75: pt10ys[75],
            f76: pt10ys[76],
            f77: pt10ys[77],
            f78: pt10ys[78],
            f79: pt10ys[79],
            f80: pt10ys[80],
            f81: pt10ys[81],
            f82: pt10ys[82],
            f83: pt10ys[83],
            f84: pt10ys[84],
            f85: pt10ys[85],
            f86: pt10ys[86],
            f87: pt10ys[87],
            f88: pt10ys[88],
            f89: pt10ys[89],
            f90: pt10ys[90],
            f91: pt10ys[91],
            f92: pt10ys[92],
            f93: pt10ys[93],
            f94: pt10ys[94],
            f95: pt10ys[95],
            f96: pt10ys[96],
            f97: pt10ys[97],
            f98: pt10ys[98],
            f99: pt10ys[99],
            f100: pt10ys[100],
            f101: pt10ys[101],
            f102: pt10ys[102],
            f103: pt10ys[103],
            f104: pt10ys[104],
            f105: pt10ys[105],
            f106: pt10ys[106],
            f107: pt10ys[107],
            f108: pt10ys[108],
            f109: pt10ys[109],
            f110: pt10ys[110],
            f111: pt10ys[111],
            f112: pt10ys[112],
            f113: pt10ys[113],
            f114: pt10ys[114],
            f115: pt10ys[115],
            f116: pt10ys[116],
            f117: pt10ys[117],
            f118: pt10ys[118],
            f119: pt10ys[119],
            f120: pt13ys[0],
            f121: pt13ys[1],
            f122: pt13ys[2],
            f123: pt13ys[3],
            f124: pt13ys[4],
            f125: pt13ys[5],
            f126: pt13ys[6],
            f127: pt13ys[7],
            f128: pt13ys[8],
            f129: pt13ys[9],
            f130: pt13ys[10],
            f131: pt13ys[11],
            f132: pt13ys[12],
            f133: pt13ys[13],
            f134: pt13ys[14],
            f135: pt13ys[15],
            f136: pt13ys[16],
            f137: pt13ys[17],
            f138: pt13ys[18],
            f139: pt13ys[19],
            f140: pt13ys[20],
            f141: pt13ys[21],
            f142: pt13ys[22],
            f143: pt13ys[23],
            f144: pt13ys[24],
            f145: pt13ys[25],
            f146: pt13ys[26],
            f147: pt13ys[27],
            f148: pt13ys[28],
            f149: pt13ys[29],
            f150: pt13ys[30],
            f151: pt13ys[31],
            f152: pt13ys[32],
            f153: pt13ys[33],
            f154: pt13ys[34],
            f155: pt13ys[35],
            f156: pt13ys[36],
            f157: pt13ys[37],
            f158: pt13ys[38],
            f159: pt13ys[39],
            f160: pt13ys[40],
            f161: pt13ys[41],
            f162: pt13ys[42],
            f163: pt13ys[43],
            f164: pt13ys[44],
            f165: pt13ys[45],
            f166: pt13ys[46],
            f167: pt13ys[47],
            f168: pt13ys[48],
            f169: pt13ys[49],
            f170: pt13ys[50],
            f171: pt13ys[51],
            f172: pt13ys[52],
            f173: pt13ys[53],
            f174: pt13ys[54],
            f175: pt13ys[55],
            f176: pt13ys[56],
            f177: pt13ys[57],
            f178: pt13ys[58],
            f179: pt13ys[59],
            f180: pt13ys[60],
            f181: pt13ys[61],
            f182: pt13ys[62],
            f183: pt13ys[63],
            f184: pt13ys[64],
            f185: pt13ys[65],
            f186: pt13ys[66],
            f187: pt13ys[67],
            f188: pt13ys[68],
            f189: pt13ys[69],
            f190: pt13ys[70],
            f191: pt13ys[71],
            f192: pt13ys[72],
            f193: pt13ys[73],
            f194: pt13ys[74],
            f195: pt13ys[75],
            f196: pt13ys[76],
            f197: pt13ys[77],
            f198: pt13ys[78],
            f199: pt13ys[79],
            f200: pt13ys[80],
            f201: pt13ys[81],
            f202: pt13ys[82],
            f203: pt13ys[83],
            f204: pt13ys[84],
            f205: pt13ys[85],
            f206: pt13ys[86],
            f207: pt13ys[87],
            f208: pt13ys[88],
            f209: pt13ys[89],
            f210: pt13ys[90],
            f211: pt13ys[91],
            f212: pt13ys[92],
            f213: pt13ys[93],
            f214: pt13ys[94],
            f215: pt13ys[95],
            f216: pt13ys[96],
            f217: pt13ys[97],
            f218: pt13ys[98],
            f219: pt13ys[99],
            f220: pt13ys[100],
            f221: pt13ys[101],
            f222: pt13ys[102],
            f223: pt13ys[103],
            f224: pt13ys[104],
            f225: pt13ys[105],
            f226: pt13ys[106],
            f227: pt13ys[107],
            f228: pt13ys[108],
            f229: pt13ys[109],
            f230: pt13ys[110],
            f231: pt13ys[111],
            f232: pt13ys[112],
            f233: pt13ys[113],
            f234: pt13ys[114],
            f235: pt13ys[115],
            f236: pt13ys[116],
            f237: pt13ys[117],
            f238: pt13ys[118],
            f239: pt13ys[119],
            f240: leftLegAngles[0],
            f241: leftLegAngles[1],
            f242: leftLegAngles[2],
            f243: leftLegAngles[3],
            f244: leftLegAngles[4],
            f245: leftLegAngles[5],
            f246: leftLegAngles[6],
            f247: leftLegAngles[7],
            f248: leftLegAngles[8],
            f249: leftLegAngles[9],
            f250: leftLegAngles[10],
            f251: leftLegAngles[11],
            f252: leftLegAngles[12],
            f253: leftLegAngles[13],
            f254: leftLegAngles[14],
            f255: leftLegAngles[15],
            f256: leftLegAngles[16],
            f257: leftLegAngles[17],
            f258: leftLegAngles[18],
            f259: leftLegAngles[19],
            f260: leftLegAngles[20],
            f261: leftLegAngles[21],
            f262: leftLegAngles[22],
            f263: leftLegAngles[23],
            f264: leftLegAngles[24],
            f265: leftLegAngles[25],
            f266: leftLegAngles[26],
            f267: leftLegAngles[27],
            f268: leftLegAngles[28],
            f269: leftLegAngles[29],
            f270: leftLegAngles[30],
            f271: leftLegAngles[31],
            f272: leftLegAngles[32],
            f273: leftLegAngles[33],
            f274: leftLegAngles[34],
            f275: leftLegAngles[35],
            f276: leftLegAngles[36],
            f277: leftLegAngles[37],
            f278: leftLegAngles[38],
            f279: leftLegAngles[39],
            f280: leftLegAngles[40],
            f281: leftLegAngles[41],
            f282: leftLegAngles[42],
            f283: leftLegAngles[43],
            f284: leftLegAngles[44],
            f285: leftLegAngles[45],
            f286: leftLegAngles[46],
            f287: leftLegAngles[47],
            f288: leftLegAngles[48],
            f289: leftLegAngles[49],
            f290: leftLegAngles[50],
            f291: leftLegAngles[51],
            f292: leftLegAngles[52],
            f293: leftLegAngles[53],
            f294: leftLegAngles[54],
            f295: leftLegAngles[55],
            f296: leftLegAngles[56],
            f297: leftLegAngles[57],
            f298: leftLegAngles[58],
            f299: leftLegAngles[59],
            f300: leftLegAngles[60],
            f301: leftLegAngles[61],
            f302: leftLegAngles[62],
            f303: leftLegAngles[63],
            f304: leftLegAngles[64],
            f305: leftLegAngles[65],
            f306: leftLegAngles[66],
            f307: leftLegAngles[67],
            f308: leftLegAngles[68],
            f309: leftLegAngles[69],
            f310: leftLegAngles[70],
            f311: leftLegAngles[71],
            f312: leftLegAngles[72],
            f313: leftLegAngles[73],
            f314: leftLegAngles[74],
            f315: leftLegAngles[75],
            f316: leftLegAngles[76],
            f317: leftLegAngles[77],
            f318: leftLegAngles[78],
            f319: leftLegAngles[79],
            f320: leftLegAngles[80],
            f321: leftLegAngles[81],
            f322: leftLegAngles[82],
            f323: leftLegAngles[83],
            f324: leftLegAngles[84],
            f325: leftLegAngles[85],
            f326: leftLegAngles[86],
            f327: leftLegAngles[87],
            f328: leftLegAngles[88],
            f329: leftLegAngles[89],
            f330: leftLegAngles[90],
            f331: leftLegAngles[91],
            f332: leftLegAngles[92],
            f333: leftLegAngles[93],
            f334: leftLegAngles[94],
            f335: leftLegAngles[95],
            f336: leftLegAngles[96],
            f337: leftLegAngles[97],
            f338: leftLegAngles[98],
            f339: leftLegAngles[99],
            f340: leftLegAngles[100],
            f341: leftLegAngles[101],
            f342: leftLegAngles[102],
            f343: leftLegAngles[103],
            f344: leftLegAngles[104],
            f345: leftLegAngles[105],
            f346: leftLegAngles[106],
            f347: leftLegAngles[107],
            f348: leftLegAngles[108],
            f349: leftLegAngles[109],
            f350: leftLegAngles[110],
            f351: leftLegAngles[111],
            f352: leftLegAngles[112],
            f353: leftLegAngles[113],
            f354: leftLegAngles[114],
            f355: leftLegAngles[115],
            f356: leftLegAngles[116],
            f357: leftLegAngles[117],
            f358: leftLegAngles[118],
            f359: leftLegAngles[119],
            f360: rightLegAngles[0],
            f361: rightLegAngles[1],
            f362: rightLegAngles[2],
            f363: rightLegAngles[3],
            f364: rightLegAngles[4],
            f365: rightLegAngles[5],
            f366: rightLegAngles[6],
            f367: rightLegAngles[7],
            f368: rightLegAngles[8],
            f369: rightLegAngles[9],
            f370: rightLegAngles[10],
            f371: rightLegAngles[11],
            f372: rightLegAngles[12],
            f373: rightLegAngles[13],
            f374: rightLegAngles[14],
            f375: rightLegAngles[15],
            f376: rightLegAngles[16],
            f377: rightLegAngles[17],
            f378: rightLegAngles[18],
            f379: rightLegAngles[19],
            f380: rightLegAngles[20],
            f381: rightLegAngles[21],
            f382: rightLegAngles[22],
            f383: rightLegAngles[23],
            f384: rightLegAngles[24],
            f385: rightLegAngles[25],
            f386: rightLegAngles[26],
            f387: rightLegAngles[27],
            f388: rightLegAngles[28],
            f389: rightLegAngles[29],
            f390: rightLegAngles[30],
            f391: rightLegAngles[31],
            f392: rightLegAngles[32],
            f393: rightLegAngles[33],
            f394: rightLegAngles[34],
            f395: rightLegAngles[35],
            f396: rightLegAngles[36],
            f397: rightLegAngles[37],
            f398: rightLegAngles[38],
            f399: rightLegAngles[39],
            f400: rightLegAngles[40],
            f401: rightLegAngles[41],
            f402: rightLegAngles[42],
            f403: rightLegAngles[43],
            f404: rightLegAngles[44],
            f405: rightLegAngles[45],
            f406: rightLegAngles[46],
            f407: rightLegAngles[47],
            f408: rightLegAngles[48],
            f409: rightLegAngles[49],
            f410: rightLegAngles[50],
            f411: rightLegAngles[51],
            f412: rightLegAngles[52],
            f413: rightLegAngles[53],
            f414: rightLegAngles[54],
            f415: rightLegAngles[55],
            f416: rightLegAngles[56],
            f417: rightLegAngles[57],
            f418: rightLegAngles[58],
            f419: rightLegAngles[59],
            f420: rightLegAngles[60],
            f421: rightLegAngles[61],
            f422: rightLegAngles[62],
            f423: rightLegAngles[63],
            f424: rightLegAngles[64],
            f425: rightLegAngles[65],
            f426: rightLegAngles[66],
            f427: rightLegAngles[67],
            f428: rightLegAngles[68],
            f429: rightLegAngles[69],
            f430: rightLegAngles[70],
            f431: rightLegAngles[71],
            f432: rightLegAngles[72],
            f433: rightLegAngles[73],
            f434: rightLegAngles[74],
            f435: rightLegAngles[75],
            f436: rightLegAngles[76],
            f437: rightLegAngles[77],
            f438: rightLegAngles[78],
            f439: rightLegAngles[79],
            f440: rightLegAngles[80],
            f441: rightLegAngles[81],
            f442: rightLegAngles[82],
            f443: rightLegAngles[83],
            f444: rightLegAngles[84],
            f445: rightLegAngles[85],
            f446: rightLegAngles[86],
            f447: rightLegAngles[87],
            f448: rightLegAngles[88],
            f449: rightLegAngles[89],
            f450: rightLegAngles[90],
            f451: rightLegAngles[91],
            f452: rightLegAngles[92],
            f453: rightLegAngles[93],
            f454: rightLegAngles[94],
            f455: rightLegAngles[95],
            f456: rightLegAngles[96],
            f457: rightLegAngles[97],
            f458: rightLegAngles[98],
            f459: rightLegAngles[99],
            f460: rightLegAngles[100],
            f461: rightLegAngles[101],
            f462: rightLegAngles[102],
            f463: rightLegAngles[103],
            f464: rightLegAngles[104],
            f465: rightLegAngles[105],
            f466: rightLegAngles[106],
            f467: rightLegAngles[107],
            f468: rightLegAngles[108],
            f469: rightLegAngles[109],
            f470: rightLegAngles[110],
            f471: rightLegAngles[111],
            f472: rightLegAngles[112],
            f473: rightLegAngles[113],
            f474: rightLegAngles[114],
            f475: rightLegAngles[115],
            f476: rightLegAngles[116],
            f477: rightLegAngles[117],
            f478: rightLegAngles[118],
            f479: rightLegAngles[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = backLegScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    
    func getFSPrediction(_ model: feetSpacingXGBoost, _ feetDistances: [Double]) -> Double  {
        guard let feetSpacingScore = try? model.prediction(input: feetSpacingXGBoostInput(
            f0: feetDistances[0],
            f1: feetDistances[1],
            f2: feetDistances[2],
            f3: feetDistances[3],
            f4: feetDistances[4],
            f5: feetDistances[5],
            f6: feetDistances[6],
            f7: feetDistances[7],
            f8: feetDistances[8],
            f9: feetDistances[9],
            f10: feetDistances[10],
            f11: feetDistances[11],
            f12: feetDistances[12],
            f13: feetDistances[13],
            f14: feetDistances[14],
            f15: feetDistances[15],
            f16: feetDistances[16],
            f17: feetDistances[17],
            f18: feetDistances[18],
            f19: feetDistances[19],
            f20: feetDistances[20],
            f21: feetDistances[21],
            f22: feetDistances[22],
            f23: feetDistances[23],
            f24: feetDistances[24],
            f25: feetDistances[25],
            f26: feetDistances[26],
            f27: feetDistances[27],
            f28: feetDistances[28],
            f29: feetDistances[29],
            f30: feetDistances[30],
            f31: feetDistances[31],
            f32: feetDistances[32],
            f33: feetDistances[33],
            f34: feetDistances[34],
            f35: feetDistances[35],
            f36: feetDistances[36],
            f37: feetDistances[37],
            f38: feetDistances[38],
            f39: feetDistances[39],
            f40: feetDistances[40],
            f41: feetDistances[41],
            f42: feetDistances[42],
            f43: feetDistances[43],
            f44: feetDistances[44],
            f45: feetDistances[45],
            f46: feetDistances[46],
            f47: feetDistances[47],
            f48: feetDistances[48],
            f49: feetDistances[49],
            f50: feetDistances[50],
            f51: feetDistances[51],
            f52: feetDistances[52],
            f53: feetDistances[53],
            f54: feetDistances[54],
            f55: feetDistances[55],
            f56: feetDistances[56],
            f57: feetDistances[57],
            f58: feetDistances[58],
            f59: feetDistances[59],
            f60: feetDistances[60],
            f61: feetDistances[61],
            f62: feetDistances[62],
            f63: feetDistances[63],
            f64: feetDistances[64],
            f65: feetDistances[65],
            f66: feetDistances[66],
            f67: feetDistances[67],
            f68: feetDistances[68],
            f69: feetDistances[69],
            f70: feetDistances[70],
            f71: feetDistances[71],
            f72: feetDistances[72],
            f73: feetDistances[73],
            f74: feetDistances[74],
            f75: feetDistances[75],
            f76: feetDistances[76],
            f77: feetDistances[77],
            f78: feetDistances[78],
            f79: feetDistances[79],
            f80: feetDistances[80],
            f81: feetDistances[81],
            f82: feetDistances[82],
            f83: feetDistances[83],
            f84: feetDistances[84],
            f85: feetDistances[85],
            f86: feetDistances[86],
            f87: feetDistances[87],
            f88: feetDistances[88],
            f89: feetDistances[89],
            f90: feetDistances[90],
            f91: feetDistances[91],
            f92: feetDistances[92],
            f93: feetDistances[93],
            f94: feetDistances[94],
            f95: feetDistances[95],
            f96: feetDistances[96],
            f97: feetDistances[97],
            f98: feetDistances[98],
            f99: feetDistances[99],
            f100: feetDistances[100],
            f101: feetDistances[101],
            f102: feetDistances[102],
            f103: feetDistances[103],
            f104: feetDistances[104],
            f105: feetDistances[105],
            f106: feetDistances[106],
            f107: feetDistances[107],
            f108: feetDistances[108],
            f109: feetDistances[109],
            f110: feetDistances[110],
            f111: feetDistances[111],
            f112: feetDistances[112],
            f113: feetDistances[113],
            f114: feetDistances[114],
            f115: feetDistances[115],
            f116: feetDistances[116],
            f117: feetDistances[117],
            f118: feetDistances[118],
            f119: feetDistances[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = feetSpacingScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    
    func getJHPrediction(_ model: jumpHeightXGBoost, _ pt10ys: [Double], _ pt13ys: [Double]) -> Double  {
        guard let jumpHeightScore = try? model.prediction(input: jumpHeightXGBoostInput(
            f0: (pt10ys[0] + pt13ys[0]),
            f1: (pt10ys[1] + pt13ys[1]),
            f2: (pt10ys[2] + pt13ys[2]),
            f3: (pt10ys[3] + pt13ys[3]),
            f4: (pt10ys[4] + pt13ys[4]),
            f5: (pt10ys[5] + pt13ys[5]),
            f6: (pt10ys[6] + pt13ys[6]),
            f7: (pt10ys[7] + pt13ys[7]),
            f8: (pt10ys[8] + pt13ys[8]),
            f9: (pt10ys[9] + pt13ys[9]),
            f10: (pt10ys[10] + pt13ys[10]),
            f11: (pt10ys[11] + pt13ys[11]),
            f12: (pt10ys[12] + pt13ys[12]),
            f13: (pt10ys[13] + pt13ys[13]),
            f14: (pt10ys[14] + pt13ys[14]),
            f15: (pt10ys[15] + pt13ys[15]),
            f16: (pt10ys[16] + pt13ys[16]),
            f17: (pt10ys[17] + pt13ys[17]),
            f18: (pt10ys[18] + pt13ys[18]),
            f19: (pt10ys[19] + pt13ys[19]),
            f20: (pt10ys[20] + pt13ys[20]),
            f21: (pt10ys[21] + pt13ys[21]),
            f22: (pt10ys[22] + pt13ys[22]),
            f23: (pt10ys[23] + pt13ys[23]),
            f24: (pt10ys[24] + pt13ys[24]),
            f25: (pt10ys[25] + pt13ys[25]),
            f26: (pt10ys[26] + pt13ys[26]),
            f27: (pt10ys[27] + pt13ys[27]),
            f28: (pt10ys[28] + pt13ys[28]),
            f29: (pt10ys[29] + pt13ys[29]),
            f30: (pt10ys[30] + pt13ys[30]),
            f31: (pt10ys[31] + pt13ys[31]),
            f32: (pt10ys[32] + pt13ys[32]),
            f33: (pt10ys[33] + pt13ys[33]),
            f34: (pt10ys[34] + pt13ys[34]),
            f35: (pt10ys[35] + pt13ys[35]),
            f36: (pt10ys[36] + pt13ys[36]),
            f37: (pt10ys[37] + pt13ys[37]),
            f38: (pt10ys[38] + pt13ys[38]),
            f39: (pt10ys[39] + pt13ys[39]),
            f40: (pt10ys[40] + pt13ys[40]),
            f41: (pt10ys[41] + pt13ys[41]),
            f42: (pt10ys[42] + pt13ys[42]),
            f43: (pt10ys[43] + pt13ys[43]),
            f44: (pt10ys[44] + pt13ys[44]),
            f45: (pt10ys[45] + pt13ys[45]),
            f46: (pt10ys[46] + pt13ys[46]),
            f47: (pt10ys[47] + pt13ys[47]),
            f48: (pt10ys[48] + pt13ys[48]),
            f49: (pt10ys[49] + pt13ys[49]),
            f50: (pt10ys[50] + pt13ys[50]),
            f51: (pt10ys[51] + pt13ys[51]),
            f52: (pt10ys[52] + pt13ys[52]),
            f53: (pt10ys[53] + pt13ys[53]),
            f54: (pt10ys[54] + pt13ys[54]),
            f55: (pt10ys[55] + pt13ys[55]),
            f56: (pt10ys[56] + pt13ys[56]),
            f57: (pt10ys[57] + pt13ys[57]),
            f58: (pt10ys[58] + pt13ys[58]),
            f59: (pt10ys[59] + pt13ys[59]),
            f60: (pt10ys[60] + pt13ys[60]),
            f61: (pt10ys[61] + pt13ys[61]),
            f62: (pt10ys[62] + pt13ys[62]),
            f63: (pt10ys[63] + pt13ys[63]),
            f64: (pt10ys[64] + pt13ys[64]),
            f65: (pt10ys[65] + pt13ys[65]),
            f66: (pt10ys[66] + pt13ys[66]),
            f67: (pt10ys[67] + pt13ys[67]),
            f68: (pt10ys[68] + pt13ys[68]),
            f69: (pt10ys[69] + pt13ys[69]),
            f70: (pt10ys[70] + pt13ys[70]),
            f71: (pt10ys[71] + pt13ys[71]),
            f72: (pt10ys[72] + pt13ys[72]),
            f73: (pt10ys[73] + pt13ys[73]),
            f74: (pt10ys[74] + pt13ys[74]),
            f75: (pt10ys[75] + pt13ys[75]),
            f76: (pt10ys[76] + pt13ys[76]),
            f77: (pt10ys[77] + pt13ys[77]),
            f78: (pt10ys[78] + pt13ys[78]),
            f79: (pt10ys[79] + pt13ys[79]),
            f80: (pt10ys[80] + pt13ys[80]),
            f81: (pt10ys[81] + pt13ys[81]),
            f82: (pt10ys[82] + pt13ys[82]),
            f83: (pt10ys[83] + pt13ys[83]),
            f84: (pt10ys[84] + pt13ys[84]),
            f85: (pt10ys[85] + pt13ys[85]),
            f86: (pt10ys[86] + pt13ys[86]),
            f87: (pt10ys[87] + pt13ys[87]),
            f88: (pt10ys[88] + pt13ys[88]),
            f89: (pt10ys[89] + pt13ys[89]),
            f90: (pt10ys[90] + pt13ys[90]),
            f91: (pt10ys[91] + pt13ys[91]),
            f92: (pt10ys[92] + pt13ys[92]),
            f93: (pt10ys[93] + pt13ys[93]),
            f94: (pt10ys[94] + pt13ys[94]),
            f95: (pt10ys[95] + pt13ys[95]),
            f96: (pt10ys[96] + pt13ys[96]),
            f97: (pt10ys[97] + pt13ys[97]),
            f98: (pt10ys[98] + pt13ys[98]),
            f99: (pt10ys[99] + pt13ys[99]),
            f100: (pt10ys[100] + pt13ys[100]),
            f101: (pt10ys[101] + pt13ys[101]),
            f102: (pt10ys[102] + pt13ys[102]),
            f103: (pt10ys[103] + pt13ys[103]),
            f104: (pt10ys[104] + pt13ys[104]),
            f105: (pt10ys[105] + pt13ys[105]),
            f106: (pt10ys[106] + pt13ys[106]),
            f107: (pt10ys[107] + pt13ys[107]),
            f108: (pt10ys[108] + pt13ys[108]),
            f109: (pt10ys[109] + pt13ys[109]),
            f110: (pt10ys[110] + pt13ys[110]),
            f111: (pt10ys[111] + pt13ys[111]),
            f112: (pt10ys[112] + pt13ys[112]),
            f113: (pt10ys[113] + pt13ys[113]),
            f114: (pt10ys[114] + pt13ys[114]),
            f115: (pt10ys[115] + pt13ys[115]),
            f116: (pt10ys[116] + pt13ys[116]),
            f117: (pt10ys[117] + pt13ys[117]),
            f118: (pt10ys[118] + pt13ys[118]),
            f119: (pt10ys[119] + pt13ys[119])
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = jumpHeightScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getLAPrediction(_ model: leftArmStraightXGBoost, _ leftArmAngles: [Double], _ rightArmAngles: [Double]) -> Double  {
        guard let leftArmScore = try? model.prediction(input: leftArmStraightXGBoostInput(
            f0: leftArmAngles[0],
            f1: leftArmAngles[1],
            f2: leftArmAngles[2],
            f3: leftArmAngles[3],
            f4: leftArmAngles[4],
            f5: leftArmAngles[5],
            f6: leftArmAngles[6],
            f7: leftArmAngles[7],
            f8: leftArmAngles[8],
            f9: leftArmAngles[9],
            f10: leftArmAngles[10],
            f11: leftArmAngles[11],
            f12: leftArmAngles[12],
            f13: leftArmAngles[13],
            f14: leftArmAngles[14],
            f15: leftArmAngles[15],
            f16: leftArmAngles[16],
            f17: leftArmAngles[17],
            f18: leftArmAngles[18],
            f19: leftArmAngles[19],
            f20: leftArmAngles[20],
            f21: leftArmAngles[21],
            f22: leftArmAngles[22],
            f23: leftArmAngles[23],
            f24: leftArmAngles[24],
            f25: leftArmAngles[25],
            f26: leftArmAngles[26],
            f27: leftArmAngles[27],
            f28: leftArmAngles[28],
            f29: leftArmAngles[29],
            f30: leftArmAngles[30],
            f31: leftArmAngles[31],
            f32: leftArmAngles[32],
            f33: leftArmAngles[33],
            f34: leftArmAngles[34],
            f35: leftArmAngles[35],
            f36: leftArmAngles[36],
            f37: leftArmAngles[37],
            f38: leftArmAngles[38],
            f39: leftArmAngles[39],
            f40: leftArmAngles[40],
            f41: leftArmAngles[41],
            f42: leftArmAngles[42],
            f43: leftArmAngles[43],
            f44: leftArmAngles[44],
            f45: leftArmAngles[45],
            f46: leftArmAngles[46],
            f47: leftArmAngles[47],
            f48: leftArmAngles[48],
            f49: leftArmAngles[49],
            f50: leftArmAngles[50],
            f51: leftArmAngles[51],
            f52: leftArmAngles[52],
            f53: leftArmAngles[53],
            f54: leftArmAngles[54],
            f55: leftArmAngles[55],
            f56: leftArmAngles[56],
            f57: leftArmAngles[57],
            f58: leftArmAngles[58],
            f59: leftArmAngles[59],
            f60: leftArmAngles[60],
            f61: leftArmAngles[61],
            f62: leftArmAngles[62],
            f63: leftArmAngles[63],
            f64: leftArmAngles[64],
            f65: leftArmAngles[65],
            f66: leftArmAngles[66],
            f67: leftArmAngles[67],
            f68: leftArmAngles[68],
            f69: leftArmAngles[69],
            f70: leftArmAngles[70],
            f71: leftArmAngles[71],
            f72: leftArmAngles[72],
            f73: leftArmAngles[73],
            f74: leftArmAngles[74],
            f75: leftArmAngles[75],
            f76: leftArmAngles[76],
            f77: leftArmAngles[77],
            f78: leftArmAngles[78],
            f79: leftArmAngles[79],
            f80: leftArmAngles[80],
            f81: leftArmAngles[81],
            f82: leftArmAngles[82],
            f83: leftArmAngles[83],
            f84: leftArmAngles[84],
            f85: leftArmAngles[85],
            f86: leftArmAngles[86],
            f87: leftArmAngles[87],
            f88: leftArmAngles[88],
            f89: leftArmAngles[89],
            f90: leftArmAngles[90],
            f91: leftArmAngles[91],
            f92: leftArmAngles[92],
            f93: leftArmAngles[93],
            f94: leftArmAngles[94],
            f95: leftArmAngles[95],
            f96: leftArmAngles[96],
            f97: leftArmAngles[97],
            f98: leftArmAngles[98],
            f99: leftArmAngles[99],
            f100: leftArmAngles[100],
            f101: leftArmAngles[101],
            f102: leftArmAngles[102],
            f103: leftArmAngles[103],
            f104: leftArmAngles[104],
            f105: leftArmAngles[105],
            f106: leftArmAngles[106],
            f107: leftArmAngles[107],
            f108: leftArmAngles[108],
            f109: leftArmAngles[109],
            f110: leftArmAngles[110],
            f111: leftArmAngles[111],
            f112: leftArmAngles[112],
            f113: leftArmAngles[113],
            f114: leftArmAngles[114],
            f115: leftArmAngles[115],
            f116: leftArmAngles[116],
            f117: leftArmAngles[117],
            f118: leftArmAngles[118],
            f119: leftArmAngles[119],
            f120: rightArmAngles[0],
            f121: rightArmAngles[1],
            f122: rightArmAngles[2],
            f123: rightArmAngles[3],
            f124: rightArmAngles[4],
            f125: rightArmAngles[5],
            f126: rightArmAngles[6],
            f127: rightArmAngles[7],
            f128: rightArmAngles[8],
            f129: rightArmAngles[9],
            f130: rightArmAngles[10],
            f131: rightArmAngles[11],
            f132: rightArmAngles[12],
            f133: rightArmAngles[13],
            f134: rightArmAngles[14],
            f135: rightArmAngles[15],
            f136: rightArmAngles[16],
            f137: rightArmAngles[17],
            f138: rightArmAngles[18],
            f139: rightArmAngles[19],
            f140: rightArmAngles[20],
            f141: rightArmAngles[21],
            f142: rightArmAngles[22],
            f143: rightArmAngles[23],
            f144: rightArmAngles[24],
            f145: rightArmAngles[25],
            f146: rightArmAngles[26],
            f147: rightArmAngles[27],
            f148: rightArmAngles[28],
            f149: rightArmAngles[29],
            f150: rightArmAngles[30],
            f151: rightArmAngles[31],
            f152: rightArmAngles[32],
            f153: rightArmAngles[33],
            f154: rightArmAngles[34],
            f155: rightArmAngles[35],
            f156: rightArmAngles[36],
            f157: rightArmAngles[37],
            f158: rightArmAngles[38],
            f159: rightArmAngles[39],
            f160: rightArmAngles[40],
            f161: rightArmAngles[41],
            f162: rightArmAngles[42],
            f163: rightArmAngles[43],
            f164: rightArmAngles[44],
            f165: rightArmAngles[45],
            f166: rightArmAngles[46],
            f167: rightArmAngles[47],
            f168: rightArmAngles[48],
            f169: rightArmAngles[49],
            f170: rightArmAngles[50],
            f171: rightArmAngles[51],
            f172: rightArmAngles[52],
            f173: rightArmAngles[53],
            f174: rightArmAngles[54],
            f175: rightArmAngles[55],
            f176: rightArmAngles[56],
            f177: rightArmAngles[57],
            f178: rightArmAngles[58],
            f179: rightArmAngles[59],
            f180: rightArmAngles[60],
            f181: rightArmAngles[61],
            f182: rightArmAngles[62],
            f183: rightArmAngles[63],
            f184: rightArmAngles[64],
            f185: rightArmAngles[65],
            f186: rightArmAngles[66],
            f187: rightArmAngles[67],
            f188: rightArmAngles[68],
            f189: rightArmAngles[69],
            f190: rightArmAngles[70],
            f191: rightArmAngles[71],
            f192: rightArmAngles[72],
            f193: rightArmAngles[73],
            f194: rightArmAngles[74],
            f195: rightArmAngles[75],
            f196: rightArmAngles[76],
            f197: rightArmAngles[77],
            f198: rightArmAngles[78],
            f199: rightArmAngles[79],
            f200: rightArmAngles[80],
            f201: rightArmAngles[81],
            f202: rightArmAngles[82],
            f203: rightArmAngles[83],
            f204: rightArmAngles[84],
            f205: rightArmAngles[85],
            f206: rightArmAngles[86],
            f207: rightArmAngles[87],
            f208: rightArmAngles[88],
            f209: rightArmAngles[89],
            f210: rightArmAngles[90],
            f211: rightArmAngles[91],
            f212: rightArmAngles[92],
            f213: rightArmAngles[93],
            f214: rightArmAngles[94],
            f215: rightArmAngles[95],
            f216: rightArmAngles[96],
            f217: rightArmAngles[97],
            f218: rightArmAngles[98],
            f219: rightArmAngles[99],
            f220: rightArmAngles[100],
            f221: rightArmAngles[101],
            f222: rightArmAngles[102],
            f223: rightArmAngles[103],
            f224: rightArmAngles[104],
            f225: rightArmAngles[105],
            f226: rightArmAngles[106],
            f227: rightArmAngles[107],
            f228: rightArmAngles[108],
            f229: rightArmAngles[109],
            f230: rightArmAngles[110],
            f231: rightArmAngles[111],
            f232: rightArmAngles[112],
            f233: rightArmAngles[113],
            f234: rightArmAngles[114],
            f235: rightArmAngles[115],
            f236: rightArmAngles[116],
            f237: rightArmAngles[117],
            f238: rightArmAngles[118],
            f239: rightArmAngles[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = leftArmScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getLBPrediction(_ model: legsBentXGBoost, _ leftLegAngles: [Double], _ rightLegAngles: [Double]) -> Double  {
        guard let legsBendScore = try? model.prediction(input: legsBentXGBoostInput(
            f0: leftLegAngles[0],
            f1: leftLegAngles[1],
            f2: leftLegAngles[2],
            f3: leftLegAngles[3],
            f4: leftLegAngles[4],
            f5: leftLegAngles[5],
            f6: leftLegAngles[6],
            f7: leftLegAngles[7],
            f8: leftLegAngles[8],
            f9: leftLegAngles[9],
            f10: leftLegAngles[10],
            f11: leftLegAngles[11],
            f12: leftLegAngles[12],
            f13: leftLegAngles[13],
            f14: leftLegAngles[14],
            f15: leftLegAngles[15],
            f16: leftLegAngles[16],
            f17: leftLegAngles[17],
            f18: leftLegAngles[18],
            f19: leftLegAngles[19],
            f20: leftLegAngles[20],
            f21: leftLegAngles[21],
            f22: leftLegAngles[22],
            f23: leftLegAngles[23],
            f24: leftLegAngles[24],
            f25: leftLegAngles[25],
            f26: leftLegAngles[26],
            f27: leftLegAngles[27],
            f28: leftLegAngles[28],
            f29: leftLegAngles[29],
            f30: leftLegAngles[30],
            f31: leftLegAngles[31],
            f32: leftLegAngles[32],
            f33: leftLegAngles[33],
            f34: leftLegAngles[34],
            f35: leftLegAngles[35],
            f36: leftLegAngles[36],
            f37: leftLegAngles[37],
            f38: leftLegAngles[38],
            f39: leftLegAngles[39],
            f40: leftLegAngles[40],
            f41: leftLegAngles[41],
            f42: leftLegAngles[42],
            f43: leftLegAngles[43],
            f44: leftLegAngles[44],
            f45: leftLegAngles[45],
            f46: leftLegAngles[46],
            f47: leftLegAngles[47],
            f48: leftLegAngles[48],
            f49: leftLegAngles[49],
            f50: leftLegAngles[50],
            f51: leftLegAngles[51],
            f52: leftLegAngles[52],
            f53: leftLegAngles[53],
            f54: leftLegAngles[54],
            f55: leftLegAngles[55],
            f56: leftLegAngles[56],
            f57: leftLegAngles[57],
            f58: leftLegAngles[58],
            f59: leftLegAngles[59],
            f60: leftLegAngles[60],
            f61: leftLegAngles[61],
            f62: leftLegAngles[62],
            f63: leftLegAngles[63],
            f64: leftLegAngles[64],
            f65: leftLegAngles[65],
            f66: leftLegAngles[66],
            f67: leftLegAngles[67],
            f68: leftLegAngles[68],
            f69: leftLegAngles[69],
            f70: leftLegAngles[70],
            f71: leftLegAngles[71],
            f72: leftLegAngles[72],
            f73: leftLegAngles[73],
            f74: leftLegAngles[74],
            f75: leftLegAngles[75],
            f76: leftLegAngles[76],
            f77: leftLegAngles[77],
            f78: leftLegAngles[78],
            f79: leftLegAngles[79],
            f80: leftLegAngles[80],
            f81: leftLegAngles[81],
            f82: leftLegAngles[82],
            f83: leftLegAngles[83],
            f84: leftLegAngles[84],
            f85: leftLegAngles[85],
            f86: leftLegAngles[86],
            f87: leftLegAngles[87],
            f88: leftLegAngles[88],
            f89: leftLegAngles[89],
            f90: leftLegAngles[90],
            f91: leftLegAngles[91],
            f92: leftLegAngles[92],
            f93: leftLegAngles[93],
            f94: leftLegAngles[94],
            f95: leftLegAngles[95],
            f96: leftLegAngles[96],
            f97: leftLegAngles[97],
            f98: leftLegAngles[98],
            f99: leftLegAngles[99],
            f100: leftLegAngles[100],
            f101: leftLegAngles[101],
            f102: leftLegAngles[102],
            f103: leftLegAngles[103],
            f104: leftLegAngles[104],
            f105: leftLegAngles[105],
            f106: leftLegAngles[106],
            f107: leftLegAngles[107],
            f108: leftLegAngles[108],
            f109: leftLegAngles[109],
            f110: leftLegAngles[110],
            f111: leftLegAngles[111],
            f112: leftLegAngles[112],
            f113: leftLegAngles[113],
            f114: leftLegAngles[114],
            f115: leftLegAngles[115],
            f116: leftLegAngles[116],
            f117: leftLegAngles[117],
            f118: leftLegAngles[118],
            f119: leftLegAngles[119],
            f120: rightLegAngles[0],
            f121: rightLegAngles[1],
            f122: rightLegAngles[2],
            f123: rightLegAngles[3],
            f124: rightLegAngles[4],
            f125: rightLegAngles[5],
            f126: rightLegAngles[6],
            f127: rightLegAngles[7],
            f128: rightLegAngles[8],
            f129: rightLegAngles[9],
            f130: rightLegAngles[10],
            f131: rightLegAngles[11],
            f132: rightLegAngles[12],
            f133: rightLegAngles[13],
            f134: rightLegAngles[14],
            f135: rightLegAngles[15],
            f136: rightLegAngles[16],
            f137: rightLegAngles[17],
            f138: rightLegAngles[18],
            f139: rightLegAngles[19],
            f140: rightLegAngles[20],
            f141: rightLegAngles[21],
            f142: rightLegAngles[22],
            f143: rightLegAngles[23],
            f144: rightLegAngles[24],
            f145: rightLegAngles[25],
            f146: rightLegAngles[26],
            f147: rightLegAngles[27],
            f148: rightLegAngles[28],
            f149: rightLegAngles[29],
            f150: rightLegAngles[30],
            f151: rightLegAngles[31],
            f152: rightLegAngles[32],
            f153: rightLegAngles[33],
            f154: rightLegAngles[34],
            f155: rightLegAngles[35],
            f156: rightLegAngles[36],
            f157: rightLegAngles[37],
            f158: rightLegAngles[38],
            f159: rightLegAngles[39],
            f160: rightLegAngles[40],
            f161: rightLegAngles[41],
            f162: rightLegAngles[42],
            f163: rightLegAngles[43],
            f164: rightLegAngles[44],
            f165: rightLegAngles[45],
            f166: rightLegAngles[46],
            f167: rightLegAngles[47],
            f168: rightLegAngles[48],
            f169: rightLegAngles[49],
            f170: rightLegAngles[50],
            f171: rightLegAngles[51],
            f172: rightLegAngles[52],
            f173: rightLegAngles[53],
            f174: rightLegAngles[54],
            f175: rightLegAngles[55],
            f176: rightLegAngles[56],
            f177: rightLegAngles[57],
            f178: rightLegAngles[58],
            f179: rightLegAngles[59],
            f180: rightLegAngles[60],
            f181: rightLegAngles[61],
            f182: rightLegAngles[62],
            f183: rightLegAngles[63],
            f184: rightLegAngles[64],
            f185: rightLegAngles[65],
            f186: rightLegAngles[66],
            f187: rightLegAngles[67],
            f188: rightLegAngles[68],
            f189: rightLegAngles[69],
            f190: rightLegAngles[70],
            f191: rightLegAngles[71],
            f192: rightLegAngles[72],
            f193: rightLegAngles[73],
            f194: rightLegAngles[74],
            f195: rightLegAngles[75],
            f196: rightLegAngles[76],
            f197: rightLegAngles[77],
            f198: rightLegAngles[78],
            f199: rightLegAngles[79],
            f200: rightLegAngles[80],
            f201: rightLegAngles[81],
            f202: rightLegAngles[82],
            f203: rightLegAngles[83],
            f204: rightLegAngles[84],
            f205: rightLegAngles[85],
            f206: rightLegAngles[86],
            f207: rightLegAngles[87],
            f208: rightLegAngles[88],
            f209: rightLegAngles[89],
            f210: rightLegAngles[90],
            f211: rightLegAngles[91],
            f212: rightLegAngles[92],
            f213: rightLegAngles[93],
            f214: rightLegAngles[94],
            f215: rightLegAngles[95],
            f216: rightLegAngles[96],
            f217: rightLegAngles[97],
            f218: rightLegAngles[98],
            f219: rightLegAngles[99],
            f220: rightLegAngles[100],
            f221: rightLegAngles[101],
            f222: rightLegAngles[102],
            f223: rightLegAngles[103],
            f224: rightLegAngles[104],
            f225: rightLegAngles[105],
            f226: rightLegAngles[106],
            f227: rightLegAngles[107],
            f228: rightLegAngles[108],
            f229: rightLegAngles[109],
            f230: rightLegAngles[110],
            f231: rightLegAngles[111],
            f232: rightLegAngles[112],
            f233: rightLegAngles[113],
            f234: rightLegAngles[114],
            f235: rightLegAngles[115],
            f236: rightLegAngles[116],
            f237: rightLegAngles[117],
            f238: rightLegAngles[118],
            f239: rightLegAngles[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = legsBendScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getSTPrediction(_ model: shoulderTimingXGBoost, _ shoulderDistances: [Double], _ leftLegAngles: [Double], _ rightLegAngles: [Double]) -> Double  {
        guard let shoulderTimingScore = try? model.prediction(input: shoulderTimingXGBoostInput(
            f0: leftLegAngles[0],
            f1: leftLegAngles[1],
            f2: leftLegAngles[2],
            f3: leftLegAngles[3],
            f4: leftLegAngles[4],
            f5: leftLegAngles[5],
            f6: leftLegAngles[6],
            f7: leftLegAngles[7],
            f8: leftLegAngles[8],
            f9: leftLegAngles[9],
            f10: leftLegAngles[10],
            f11: leftLegAngles[11],
            f12: leftLegAngles[12],
            f13: leftLegAngles[13],
            f14: leftLegAngles[14],
            f15: leftLegAngles[15],
            f16: leftLegAngles[16],
            f17: leftLegAngles[17],
            f18: leftLegAngles[18],
            f19: leftLegAngles[19],
            f20: leftLegAngles[20],
            f21: leftLegAngles[21],
            f22: leftLegAngles[22],
            f23: leftLegAngles[23],
            f24: leftLegAngles[24],
            f25: leftLegAngles[25],
            f26: leftLegAngles[26],
            f27: leftLegAngles[27],
            f28: leftLegAngles[28],
            f29: leftLegAngles[29],
            f30: leftLegAngles[30],
            f31: leftLegAngles[31],
            f32: leftLegAngles[32],
            f33: leftLegAngles[33],
            f34: leftLegAngles[34],
            f35: leftLegAngles[35],
            f36: leftLegAngles[36],
            f37: leftLegAngles[37],
            f38: leftLegAngles[38],
            f39: leftLegAngles[39],
            f40: leftLegAngles[40],
            f41: leftLegAngles[41],
            f42: leftLegAngles[42],
            f43: leftLegAngles[43],
            f44: leftLegAngles[44],
            f45: leftLegAngles[45],
            f46: leftLegAngles[46],
            f47: leftLegAngles[47],
            f48: leftLegAngles[48],
            f49: leftLegAngles[49],
            f50: leftLegAngles[50],
            f51: leftLegAngles[51],
            f52: leftLegAngles[52],
            f53: leftLegAngles[53],
            f54: leftLegAngles[54],
            f55: leftLegAngles[55],
            f56: leftLegAngles[56],
            f57: leftLegAngles[57],
            f58: leftLegAngles[58],
            f59: leftLegAngles[59],
            f60: leftLegAngles[60],
            f61: leftLegAngles[61],
            f62: leftLegAngles[62],
            f63: leftLegAngles[63],
            f64: leftLegAngles[64],
            f65: leftLegAngles[65],
            f66: leftLegAngles[66],
            f67: leftLegAngles[67],
            f68: leftLegAngles[68],
            f69: leftLegAngles[69],
            f70: leftLegAngles[70],
            f71: leftLegAngles[71],
            f72: leftLegAngles[72],
            f73: leftLegAngles[73],
            f74: leftLegAngles[74],
            f75: leftLegAngles[75],
            f76: leftLegAngles[76],
            f77: leftLegAngles[77],
            f78: leftLegAngles[78],
            f79: leftLegAngles[79],
            f80: leftLegAngles[80],
            f81: leftLegAngles[81],
            f82: leftLegAngles[82],
            f83: leftLegAngles[83],
            f84: leftLegAngles[84],
            f85: leftLegAngles[85],
            f86: leftLegAngles[86],
            f87: leftLegAngles[87],
            f88: leftLegAngles[88],
            f89: leftLegAngles[89],
            f90: leftLegAngles[90],
            f91: leftLegAngles[91],
            f92: leftLegAngles[92],
            f93: leftLegAngles[93],
            f94: leftLegAngles[94],
            f95: leftLegAngles[95],
            f96: leftLegAngles[96],
            f97: leftLegAngles[97],
            f98: leftLegAngles[98],
            f99: leftLegAngles[99],
            f100: leftLegAngles[100],
            f101: leftLegAngles[101],
            f102: leftLegAngles[102],
            f103: leftLegAngles[103],
            f104: leftLegAngles[104],
            f105: leftLegAngles[105],
            f106: leftLegAngles[106],
            f107: leftLegAngles[107],
            f108: leftLegAngles[108],
            f109: leftLegAngles[109],
            f110: leftLegAngles[110],
            f111: leftLegAngles[111],
            f112: leftLegAngles[112],
            f113: leftLegAngles[113],
            f114: leftLegAngles[114],
            f115: leftLegAngles[115],
            f116: leftLegAngles[116],
            f117: leftLegAngles[117],
            f118: leftLegAngles[118],
            f119: leftLegAngles[119],
            f120: rightLegAngles[0],
            f121: rightLegAngles[1],
            f122: rightLegAngles[2],
            f123: rightLegAngles[3],
            f124: rightLegAngles[4],
            f125: rightLegAngles[5],
            f126: rightLegAngles[6],
            f127: rightLegAngles[7],
            f128: rightLegAngles[8],
            f129: rightLegAngles[9],
            f130: rightLegAngles[10],
            f131: rightLegAngles[11],
            f132: rightLegAngles[12],
            f133: rightLegAngles[13],
            f134: rightLegAngles[14],
            f135: rightLegAngles[15],
            f136: rightLegAngles[16],
            f137: rightLegAngles[17],
            f138: rightLegAngles[18],
            f139: rightLegAngles[19],
            f140: rightLegAngles[20],
            f141: rightLegAngles[21],
            f142: rightLegAngles[22],
            f143: rightLegAngles[23],
            f144: rightLegAngles[24],
            f145: rightLegAngles[25],
            f146: rightLegAngles[26],
            f147: rightLegAngles[27],
            f148: rightLegAngles[28],
            f149: rightLegAngles[29],
            f150: rightLegAngles[30],
            f151: rightLegAngles[31],
            f152: rightLegAngles[32],
            f153: rightLegAngles[33],
            f154: rightLegAngles[34],
            f155: rightLegAngles[35],
            f156: rightLegAngles[36],
            f157: rightLegAngles[37],
            f158: rightLegAngles[38],
            f159: rightLegAngles[39],
            f160: rightLegAngles[40],
            f161: rightLegAngles[41],
            f162: rightLegAngles[42],
            f163: rightLegAngles[43],
            f164: rightLegAngles[44],
            f165: rightLegAngles[45],
            f166: rightLegAngles[46],
            f167: rightLegAngles[47],
            f168: rightLegAngles[48],
            f169: rightLegAngles[49],
            f170: rightLegAngles[50],
            f171: rightLegAngles[51],
            f172: rightLegAngles[52],
            f173: rightLegAngles[53],
            f174: rightLegAngles[54],
            f175: rightLegAngles[55],
            f176: rightLegAngles[56],
            f177: rightLegAngles[57],
            f178: rightLegAngles[58],
            f179: rightLegAngles[59],
            f180: rightLegAngles[60],
            f181: rightLegAngles[61],
            f182: rightLegAngles[62],
            f183: rightLegAngles[63],
            f184: rightLegAngles[64],
            f185: rightLegAngles[65],
            f186: rightLegAngles[66],
            f187: rightLegAngles[67],
            f188: rightLegAngles[68],
            f189: rightLegAngles[69],
            f190: rightLegAngles[70],
            f191: rightLegAngles[71],
            f192: rightLegAngles[72],
            f193: rightLegAngles[73],
            f194: rightLegAngles[74],
            f195: rightLegAngles[75],
            f196: rightLegAngles[76],
            f197: rightLegAngles[77],
            f198: rightLegAngles[78],
            f199: rightLegAngles[79],
            f200: rightLegAngles[80],
            f201: rightLegAngles[81],
            f202: rightLegAngles[82],
            f203: rightLegAngles[83],
            f204: rightLegAngles[84],
            f205: rightLegAngles[85],
            f206: rightLegAngles[86],
            f207: rightLegAngles[87],
            f208: rightLegAngles[88],
            f209: rightLegAngles[89],
            f210: rightLegAngles[90],
            f211: rightLegAngles[91],
            f212: rightLegAngles[92],
            f213: rightLegAngles[93],
            f214: rightLegAngles[94],
            f215: rightLegAngles[95],
            f216: rightLegAngles[96],
            f217: rightLegAngles[97],
            f218: rightLegAngles[98],
            f219: rightLegAngles[99],
            f220: rightLegAngles[100],
            f221: rightLegAngles[101],
            f222: rightLegAngles[102],
            f223: rightLegAngles[103],
            f224: rightLegAngles[104],
            f225: rightLegAngles[105],
            f226: rightLegAngles[106],
            f227: rightLegAngles[107],
            f228: rightLegAngles[108],
            f229: rightLegAngles[109],
            f230: rightLegAngles[110],
            f231: rightLegAngles[111],
            f232: rightLegAngles[112],
            f233: rightLegAngles[113],
            f234: rightLegAngles[114],
            f235: rightLegAngles[115],
            f236: rightLegAngles[116],
            f237: rightLegAngles[117],
            f238: rightLegAngles[118],
            f239: rightLegAngles[119],
            f240: shoulderDistances[0],
            f241: shoulderDistances[1],
            f242: shoulderDistances[2],
            f243: shoulderDistances[3],
            f244: shoulderDistances[4],
            f245: shoulderDistances[5],
            f246: shoulderDistances[6],
            f247: shoulderDistances[7],
            f248: shoulderDistances[8],
            f249: shoulderDistances[9],
            f250: shoulderDistances[10],
            f251: shoulderDistances[11],
            f252: shoulderDistances[12],
            f253: shoulderDistances[13],
            f254: shoulderDistances[14],
            f255: shoulderDistances[15],
            f256: shoulderDistances[16],
            f257: shoulderDistances[17],
            f258: shoulderDistances[18],
            f259: shoulderDistances[19],
            f260: shoulderDistances[20],
            f261: shoulderDistances[21],
            f262: shoulderDistances[22],
            f263: shoulderDistances[23],
            f264: shoulderDistances[24],
            f265: shoulderDistances[25],
            f266: shoulderDistances[26],
            f267: shoulderDistances[27],
            f268: shoulderDistances[28],
            f269: shoulderDistances[29],
            f270: shoulderDistances[30],
            f271: shoulderDistances[31],
            f272: shoulderDistances[32],
            f273: shoulderDistances[33],
            f274: shoulderDistances[34],
            f275: shoulderDistances[35],
            f276: shoulderDistances[36],
            f277: shoulderDistances[37],
            f278: shoulderDistances[38],
            f279: shoulderDistances[39],
            f280: shoulderDistances[40],
            f281: shoulderDistances[41],
            f282: shoulderDistances[42],
            f283: shoulderDistances[43],
            f284: shoulderDistances[44],
            f285: shoulderDistances[45],
            f286: shoulderDistances[46],
            f287: shoulderDistances[47],
            f288: shoulderDistances[48],
            f289: shoulderDistances[49],
            f290: shoulderDistances[50],
            f291: shoulderDistances[51],
            f292: shoulderDistances[52],
            f293: shoulderDistances[53],
            f294: shoulderDistances[54],
            f295: shoulderDistances[55],
            f296: shoulderDistances[56],
            f297: shoulderDistances[57],
            f298: shoulderDistances[58],
            f299: shoulderDistances[59],
            f300: shoulderDistances[60],
            f301: shoulderDistances[61],
            f302: shoulderDistances[62],
            f303: shoulderDistances[63],
            f304: shoulderDistances[64],
            f305: shoulderDistances[65],
            f306: shoulderDistances[66],
            f307: shoulderDistances[67],
            f308: shoulderDistances[68],
            f309: shoulderDistances[69],
            f310: shoulderDistances[70],
            f311: shoulderDistances[71],
            f312: shoulderDistances[72],
            f313: shoulderDistances[73],
            f314: shoulderDistances[74],
            f315: shoulderDistances[75],
            f316: shoulderDistances[76],
            f317: shoulderDistances[77],
            f318: shoulderDistances[78],
            f319: shoulderDistances[79],
            f320: shoulderDistances[80],
            f321: shoulderDistances[81],
            f322: shoulderDistances[82],
            f323: shoulderDistances[83],
            f324: shoulderDistances[84],
            f325: shoulderDistances[85],
            f326: shoulderDistances[86],
            f327: shoulderDistances[87],
            f328: shoulderDistances[88],
            f329: shoulderDistances[89],
            f330: shoulderDistances[90],
            f331: shoulderDistances[91],
            f332: shoulderDistances[92],
            f333: shoulderDistances[93],
            f334: shoulderDistances[94],
            f335: shoulderDistances[95],
            f336: shoulderDistances[96],
            f337: shoulderDistances[97],
            f338: shoulderDistances[98],
            f339: shoulderDistances[99],
            f340: shoulderDistances[100],
            f341: shoulderDistances[101],
            f342: shoulderDistances[102],
            f343: shoulderDistances[103],
            f344: shoulderDistances[104],
            f345: shoulderDistances[105],
            f346: shoulderDistances[106],
            f347: shoulderDistances[107],
            f348: shoulderDistances[108],
            f349: shoulderDistances[109],
            f350: shoulderDistances[110],
            f351: shoulderDistances[111],
            f352: shoulderDistances[112],
            f353: shoulderDistances[113],
            f354: shoulderDistances[114],
            f355: shoulderDistances[115],
            f356: shoulderDistances[116],
            f357: shoulderDistances[117],
            f358: shoulderDistances[118],
            f359: shoulderDistances[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = shoulderTimingScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getTHPrediction(_ model: tossHeightXGBoost, _ pt2xs: [Double], _ pt3xs: [Double], _ pt4xs: [Double], _ pt5xs: [Double], _ pt6xs: [Double], _ pt7xs: [Double], _ pt2ys: [Double], _ pt3ys: [Double], _ pt4ys: [Double], _ pt5ys: [Double], _ pt6ys: [Double], _ pt7ys: [Double]) -> Double  {
        guard let tossHeightScore = try? model.prediction(input: tossHeightXGBoostInput(
            f0: pt2xs[0],
            f1: pt2xs[1],
            f2: pt2xs[2],
            f3: pt2xs[3],
            f4: pt2xs[4],
            f5: pt2xs[5],
            f6: pt2xs[6],
            f7: pt2xs[7],
            f8: pt2xs[8],
            f9: pt2xs[9],
            f10: pt2xs[10],
            f11: pt2xs[11],
            f12: pt2xs[12],
            f13: pt2xs[13],
            f14: pt2xs[14],
            f15: pt2xs[15],
            f16: pt2xs[16],
            f17: pt2xs[17],
            f18: pt2xs[18],
            f19: pt2xs[19],
            f20: pt2xs[20],
            f21: pt2xs[21],
            f22: pt2xs[22],
            f23: pt2xs[23],
            f24: pt2xs[24],
            f25: pt2xs[25],
            f26: pt2xs[26],
            f27: pt2xs[27],
            f28: pt2xs[28],
            f29: pt2xs[29],
            f30: pt2xs[30],
            f31: pt2xs[31],
            f32: pt2xs[32],
            f33: pt2xs[33],
            f34: pt2xs[34],
            f35: pt2xs[35],
            f36: pt2xs[36],
            f37: pt2xs[37],
            f38: pt2xs[38],
            f39: pt2xs[39],
            f40: pt2xs[40],
            f41: pt2xs[41],
            f42: pt2xs[42],
            f43: pt2xs[43],
            f44: pt2xs[44],
            f45: pt2xs[45],
            f46: pt2xs[46],
            f47: pt2xs[47],
            f48: pt2xs[48],
            f49: pt2xs[49],
            f50: pt2xs[50],
            f51: pt2xs[51],
            f52: pt2xs[52],
            f53: pt2xs[53],
            f54: pt2xs[54],
            f55: pt2xs[55],
            f56: pt2xs[56],
            f57: pt2xs[57],
            f58: pt2xs[58],
            f59: pt2xs[59],
            f60: pt2xs[60],
            f61: pt2xs[61],
            f62: pt2xs[62],
            f63: pt2xs[63],
            f64: pt2xs[64],
            f65: pt2xs[65],
            f66: pt2xs[66],
            f67: pt2xs[67],
            f68: pt2xs[68],
            f69: pt2xs[69],
            f70: pt2xs[70],
            f71: pt2xs[71],
            f72: pt2xs[72],
            f73: pt2xs[73],
            f74: pt2xs[74],
            f75: pt2xs[75],
            f76: pt2xs[76],
            f77: pt2xs[77],
            f78: pt2xs[78],
            f79: pt2xs[79],
            f80: pt2xs[80],
            f81: pt2xs[81],
            f82: pt2xs[82],
            f83: pt2xs[83],
            f84: pt2xs[84],
            f85: pt2xs[85],
            f86: pt2xs[86],
            f87: pt2xs[87],
            f88: pt2xs[88],
            f89: pt2xs[89],
            f90: pt2xs[90],
            f91: pt2xs[91],
            f92: pt2xs[92],
            f93: pt2xs[93],
            f94: pt2xs[94],
            f95: pt2xs[95],
            f96: pt2xs[96],
            f97: pt2xs[97],
            f98: pt2xs[98],
            f99: pt2xs[99],
            f100: pt2xs[100],
            f101: pt2xs[101],
            f102: pt2xs[102],
            f103: pt2xs[103],
            f104: pt2xs[104],
            f105: pt2xs[105],
            f106: pt2xs[106],
            f107: pt2xs[107],
            f108: pt2xs[108],
            f109: pt2xs[109],
            f110: pt2xs[110],
            f111: pt2xs[111],
            f112: pt2xs[112],
            f113: pt2xs[113],
            f114: pt2xs[114],
            f115: pt2xs[115],
            f116: pt2xs[116],
            f117: pt2xs[117],
            f118: pt2xs[118],
            f119: pt2xs[119],
            f120: pt2ys[0],
            f121: pt2ys[1],
            f122: pt2ys[2],
            f123: pt2ys[3],
            f124: pt2ys[4],
            f125: pt2ys[5],
            f126: pt2ys[6],
            f127: pt2ys[7],
            f128: pt2ys[8],
            f129: pt2ys[9],
            f130: pt2ys[10],
            f131: pt2ys[11],
            f132: pt2ys[12],
            f133: pt2ys[13],
            f134: pt2ys[14],
            f135: pt2ys[15],
            f136: pt2ys[16],
            f137: pt2ys[17],
            f138: pt2ys[18],
            f139: pt2ys[19],
            f140: pt2ys[20],
            f141: pt2ys[21],
            f142: pt2ys[22],
            f143: pt2ys[23],
            f144: pt2ys[24],
            f145: pt2ys[25],
            f146: pt2ys[26],
            f147: pt2ys[27],
            f148: pt2ys[28],
            f149: pt2ys[29],
            f150: pt2ys[30],
            f151: pt2ys[31],
            f152: pt2ys[32],
            f153: pt2ys[33],
            f154: pt2ys[34],
            f155: pt2ys[35],
            f156: pt2ys[36],
            f157: pt2ys[37],
            f158: pt2ys[38],
            f159: pt2ys[39],
            f160: pt2ys[40],
            f161: pt2ys[41],
            f162: pt2ys[42],
            f163: pt2ys[43],
            f164: pt2ys[44],
            f165: pt2ys[45],
            f166: pt2ys[46],
            f167: pt2ys[47],
            f168: pt2ys[48],
            f169: pt2ys[49],
            f170: pt2ys[50],
            f171: pt2ys[51],
            f172: pt2ys[52],
            f173: pt2ys[53],
            f174: pt2ys[54],
            f175: pt2ys[55],
            f176: pt2ys[56],
            f177: pt2ys[57],
            f178: pt2ys[58],
            f179: pt2ys[59],
            f180: pt2ys[60],
            f181: pt2ys[61],
            f182: pt2ys[62],
            f183: pt2ys[63],
            f184: pt2ys[64],
            f185: pt2ys[65],
            f186: pt2ys[66],
            f187: pt2ys[67],
            f188: pt2ys[68],
            f189: pt2ys[69],
            f190: pt2ys[70],
            f191: pt2ys[71],
            f192: pt2ys[72],
            f193: pt2ys[73],
            f194: pt2ys[74],
            f195: pt2ys[75],
            f196: pt2ys[76],
            f197: pt2ys[77],
            f198: pt2ys[78],
            f199: pt2ys[79],
            f200: pt2ys[80],
            f201: pt2ys[81],
            f202: pt2ys[82],
            f203: pt2ys[83],
            f204: pt2ys[84],
            f205: pt2ys[85],
            f206: pt2ys[86],
            f207: pt2ys[87],
            f208: pt2ys[88],
            f209: pt2ys[89],
            f210: pt2ys[90],
            f211: pt2ys[91],
            f212: pt2ys[92],
            f213: pt2ys[93],
            f214: pt2ys[94],
            f215: pt2ys[95],
            f216: pt2ys[96],
            f217: pt2ys[97],
            f218: pt2ys[98],
            f219: pt2ys[99],
            f220: pt2ys[100],
            f221: pt2ys[101],
            f222: pt2ys[102],
            f223: pt2ys[103],
            f224: pt2ys[104],
            f225: pt2ys[105],
            f226: pt2ys[106],
            f227: pt2ys[107],
            f228: pt2ys[108],
            f229: pt2ys[109],
            f230: pt2ys[110],
            f231: pt2ys[111],
            f232: pt2ys[112],
            f233: pt2ys[113],
            f234: pt2ys[114],
            f235: pt2ys[115],
            f236: pt2ys[116],
            f237: pt2ys[117],
            f238: pt2ys[118],
            f239: pt2ys[119],
            f240: pt3xs[0],
            f241: pt3xs[1],
            f242: pt3xs[2],
            f243: pt3xs[3],
            f244: pt3xs[4],
            f245: pt3xs[5],
            f246: pt3xs[6],
            f247: pt3xs[7],
            f248: pt3xs[8],
            f249: pt3xs[9],
            f250: pt3xs[10],
            f251: pt3xs[11],
            f252: pt3xs[12],
            f253: pt3xs[13],
            f254: pt3xs[14],
            f255: pt3xs[15],
            f256: pt3xs[16],
            f257: pt3xs[17],
            f258: pt3xs[18],
            f259: pt3xs[19],
            f260: pt3xs[20],
            f261: pt3xs[21],
            f262: pt3xs[22],
            f263: pt3xs[23],
            f264: pt3xs[24],
            f265: pt3xs[25],
            f266: pt3xs[26],
            f267: pt3xs[27],
            f268: pt3xs[28],
            f269: pt3xs[29],
            f270: pt3xs[30],
            f271: pt3xs[31],
            f272: pt3xs[32],
            f273: pt3xs[33],
            f274: pt3xs[34],
            f275: pt3xs[35],
            f276: pt3xs[36],
            f277: pt3xs[37],
            f278: pt3xs[38],
            f279: pt3xs[39],
            f280: pt3xs[40],
            f281: pt3xs[41],
            f282: pt3xs[42],
            f283: pt3xs[43],
            f284: pt3xs[44],
            f285: pt3xs[45],
            f286: pt3xs[46],
            f287: pt3xs[47],
            f288: pt3xs[48],
            f289: pt3xs[49],
            f290: pt3xs[50],
            f291: pt3xs[51],
            f292: pt3xs[52],
            f293: pt3xs[53],
            f294: pt3xs[54],
            f295: pt3xs[55],
            f296: pt3xs[56],
            f297: pt3xs[57],
            f298: pt3xs[58],
            f299: pt3xs[59],
            f300: pt3xs[60],
            f301: pt3xs[61],
            f302: pt3xs[62],
            f303: pt3xs[63],
            f304: pt3xs[64],
            f305: pt3xs[65],
            f306: pt3xs[66],
            f307: pt3xs[67],
            f308: pt3xs[68],
            f309: pt3xs[69],
            f310: pt3xs[70],
            f311: pt3xs[71],
            f312: pt3xs[72],
            f313: pt3xs[73],
            f314: pt3xs[74],
            f315: pt3xs[75],
            f316: pt3xs[76],
            f317: pt3xs[77],
            f318: pt3xs[78],
            f319: pt3xs[79],
            f320: pt3xs[80],
            f321: pt3xs[81],
            f322: pt3xs[82],
            f323: pt3xs[83],
            f324: pt3xs[84],
            f325: pt3xs[85],
            f326: pt3xs[86],
            f327: pt3xs[87],
            f328: pt3xs[88],
            f329: pt3xs[89],
            f330: pt3xs[90],
            f331: pt3xs[91],
            f332: pt3xs[92],
            f333: pt3xs[93],
            f334: pt3xs[94],
            f335: pt3xs[95],
            f336: pt3xs[96],
            f337: pt3xs[97],
            f338: pt3xs[98],
            f339: pt3xs[99],
            f340: pt3xs[100],
            f341: pt3xs[101],
            f342: pt3xs[102],
            f343: pt3xs[103],
            f344: pt3xs[104],
            f345: pt3xs[105],
            f346: pt3xs[106],
            f347: pt3xs[107],
            f348: pt3xs[108],
            f349: pt3xs[109],
            f350: pt3xs[110],
            f351: pt3xs[111],
            f352: pt3xs[112],
            f353: pt3xs[113],
            f354: pt3xs[114],
            f355: pt3xs[115],
            f356: pt3xs[116],
            f357: pt3xs[117],
            f358: pt3xs[118],
            f359: pt3xs[119],
            f360: pt3ys[0],
            f361: pt3ys[1],
            f362: pt3ys[2],
            f363: pt3ys[3],
            f364: pt3ys[4],
            f365: pt3ys[5],
            f366: pt3ys[6],
            f367: pt3ys[7],
            f368: pt3ys[8],
            f369: pt3ys[9],
            f370: pt3ys[10],
            f371: pt3ys[11],
            f372: pt3ys[12],
            f373: pt3ys[13],
            f374: pt3ys[14],
            f375: pt3ys[15],
            f376: pt3ys[16],
            f377: pt3ys[17],
            f378: pt3ys[18],
            f379: pt3ys[19],
            f380: pt3ys[20],
            f381: pt3ys[21],
            f382: pt3ys[22],
            f383: pt3ys[23],
            f384: pt3ys[24],
            f385: pt3ys[25],
            f386: pt3ys[26],
            f387: pt3ys[27],
            f388: pt3ys[28],
            f389: pt3ys[29],
            f390: pt3ys[30],
            f391: pt3ys[31],
            f392: pt3ys[32],
            f393: pt3ys[33],
            f394: pt3ys[34],
            f395: pt3ys[35],
            f396: pt3ys[36],
            f397: pt3ys[37],
            f398: pt3ys[38],
            f399: pt3ys[39],
            f400: pt3ys[40],
            f401: pt3ys[41],
            f402: pt3ys[42],
            f403: pt3ys[43],
            f404: pt3ys[44],
            f405: pt3ys[45],
            f406: pt3ys[46],
            f407: pt3ys[47],
            f408: pt3ys[48],
            f409: pt3ys[49],
            f410: pt3ys[50],
            f411: pt3ys[51],
            f412: pt3ys[52],
            f413: pt3ys[53],
            f414: pt3ys[54],
            f415: pt3ys[55],
            f416: pt3ys[56],
            f417: pt3ys[57],
            f418: pt3ys[58],
            f419: pt3ys[59],
            f420: pt3ys[60],
            f421: pt3ys[61],
            f422: pt3ys[62],
            f423: pt3ys[63],
            f424: pt3ys[64],
            f425: pt3ys[65],
            f426: pt3ys[66],
            f427: pt3ys[67],
            f428: pt3ys[68],
            f429: pt3ys[69],
            f430: pt3ys[70],
            f431: pt3ys[71],
            f432: pt3ys[72],
            f433: pt3ys[73],
            f434: pt3ys[74],
            f435: pt3ys[75],
            f436: pt3ys[76],
            f437: pt3ys[77],
            f438: pt3ys[78],
            f439: pt3ys[79],
            f440: pt3ys[80],
            f441: pt3ys[81],
            f442: pt3ys[82],
            f443: pt3ys[83],
            f444: pt3ys[84],
            f445: pt3ys[85],
            f446: pt3ys[86],
            f447: pt3ys[87],
            f448: pt3ys[88],
            f449: pt3ys[89],
            f450: pt3ys[90],
            f451: pt3ys[91],
            f452: pt3ys[92],
            f453: pt3ys[93],
            f454: pt3ys[94],
            f455: pt3ys[95],
            f456: pt3ys[96],
            f457: pt3ys[97],
            f458: pt3ys[98],
            f459: pt3ys[99],
            f460: pt3ys[100],
            f461: pt3ys[101],
            f462: pt3ys[102],
            f463: pt3ys[103],
            f464: pt3ys[104],
            f465: pt3ys[105],
            f466: pt3ys[106],
            f467: pt3ys[107],
            f468: pt3ys[108],
            f469: pt3ys[109],
            f470: pt3ys[110],
            f471: pt3ys[111],
            f472: pt3ys[112],
            f473: pt3ys[113],
            f474: pt3ys[114],
            f475: pt3ys[115],
            f476: pt3ys[116],
            f477: pt3ys[117],
            f478: pt3ys[118],
            f479: pt3ys[119],
            f480: pt4xs[0],
            f481: pt4xs[1],
            f482: pt4xs[2],
            f483: pt4xs[3],
            f484: pt4xs[4],
            f485: pt4xs[5],
            f486: pt4xs[6],
            f487: pt4xs[7],
            f488: pt4xs[8],
            f489: pt4xs[9],
            f490: pt4xs[10],
            f491: pt4xs[11],
            f492: pt4xs[12],
            f493: pt4xs[13],
            f494: pt4xs[14],
            f495: pt4xs[15],
            f496: pt4xs[16],
            f497: pt4xs[17],
            f498: pt4xs[18],
            f499: pt4xs[19],
            f500: pt4xs[20],
            f501: pt4xs[21],
            f502: pt4xs[22],
            f503: pt4xs[23],
            f504: pt4xs[24],
            f505: pt4xs[25],
            f506: pt4xs[26],
            f507: pt4xs[27],
            f508: pt4xs[28],
            f509: pt4xs[29],
            f510: pt4xs[30],
            f511: pt4xs[31],
            f512: pt4xs[32],
            f513: pt4xs[33],
            f514: pt4xs[34],
            f515: pt4xs[35],
            f516: pt4xs[36],
            f517: pt4xs[37],
            f518: pt4xs[38],
            f519: pt4xs[39],
            f520: pt4xs[40],
            f521: pt4xs[41],
            f522: pt4xs[42],
            f523: pt4xs[43],
            f524: pt4xs[44],
            f525: pt4xs[45],
            f526: pt4xs[46],
            f527: pt4xs[47],
            f528: pt4xs[48],
            f529: pt4xs[49],
            f530: pt4xs[50],
            f531: pt4xs[51],
            f532: pt4xs[52],
            f533: pt4xs[53],
            f534: pt4xs[54],
            f535: pt4xs[55],
            f536: pt4xs[56],
            f537: pt4xs[57],
            f538: pt4xs[58],
            f539: pt4xs[59],
            f540: pt4xs[60],
            f541: pt4xs[61],
            f542: pt4xs[62],
            f543: pt4xs[63],
            f544: pt4xs[64],
            f545: pt4xs[65],
            f546: pt4xs[66],
            f547: pt4xs[67],
            f548: pt4xs[68],
            f549: pt4xs[69],
            f550: pt4xs[70],
            f551: pt4xs[71],
            f552: pt4xs[72],
            f553: pt4xs[73],
            f554: pt4xs[74],
            f555: pt4xs[75],
            f556: pt4xs[76],
            f557: pt4xs[77],
            f558: pt4xs[78],
            f559: pt4xs[79],
            f560: pt4xs[80],
            f561: pt4xs[81],
            f562: pt4xs[82],
            f563: pt4xs[83],
            f564: pt4xs[84],
            f565: pt4xs[85],
            f566: pt4xs[86],
            f567: pt4xs[87],
            f568: pt4xs[88],
            f569: pt4xs[89],
            f570: pt4xs[90],
            f571: pt4xs[91],
            f572: pt4xs[92],
            f573: pt4xs[93],
            f574: pt4xs[94],
            f575: pt4xs[95],
            f576: pt4xs[96],
            f577: pt4xs[97],
            f578: pt4xs[98],
            f579: pt4xs[99],
            f580: pt4xs[100],
            f581: pt4xs[101],
            f582: pt4xs[102],
            f583: pt4xs[103],
            f584: pt4xs[104],
            f585: pt4xs[105],
            f586: pt4xs[106],
            f587: pt4xs[107],
            f588: pt4xs[108],
            f589: pt4xs[109],
            f590: pt4xs[110],
            f591: pt4xs[111],
            f592: pt4xs[112],
            f593: pt4xs[113],
            f594: pt4xs[114],
            f595: pt4xs[115],
            f596: pt4xs[116],
            f597: pt4xs[117],
            f598: pt4xs[118],
            f599: pt4xs[119],
            f600: pt4ys[0],
            f601: pt4ys[1],
            f602: pt4ys[2],
            f603: pt4ys[3],
            f604: pt4ys[4],
            f605: pt4ys[5],
            f606: pt4ys[6],
            f607: pt4ys[7],
            f608: pt4ys[8],
            f609: pt4ys[9],
            f610: pt4ys[10],
            f611: pt4ys[11],
            f612: pt4ys[12],
            f613: pt4ys[13],
            f614: pt4ys[14],
            f615: pt4ys[15],
            f616: pt4ys[16],
            f617: pt4ys[17],
            f618: pt4ys[18],
            f619: pt4ys[19],
            f620: pt4ys[20],
            f621: pt4ys[21],
            f622: pt4ys[22],
            f623: pt4ys[23],
            f624: pt4ys[24],
            f625: pt4ys[25],
            f626: pt4ys[26],
            f627: pt4ys[27],
            f628: pt4ys[28],
            f629: pt4ys[29],
            f630: pt4ys[30],
            f631: pt4ys[31],
            f632: pt4ys[32],
            f633: pt4ys[33],
            f634: pt4ys[34],
            f635: pt4ys[35],
            f636: pt4ys[36],
            f637: pt4ys[37],
            f638: pt4ys[38],
            f639: pt4ys[39],
            f640: pt4ys[40],
            f641: pt4ys[41],
            f642: pt4ys[42],
            f643: pt4ys[43],
            f644: pt4ys[44],
            f645: pt4ys[45],
            f646: pt4ys[46],
            f647: pt4ys[47],
            f648: pt4ys[48],
            f649: pt4ys[49],
            f650: pt4ys[50],
            f651: pt4ys[51],
            f652: pt4ys[52],
            f653: pt4ys[53],
            f654: pt4ys[54],
            f655: pt4ys[55],
            f656: pt4ys[56],
            f657: pt4ys[57],
            f658: pt4ys[58],
            f659: pt4ys[59],
            f660: pt4ys[60],
            f661: pt4ys[61],
            f662: pt4ys[62],
            f663: pt4ys[63],
            f664: pt4ys[64],
            f665: pt4ys[65],
            f666: pt4ys[66],
            f667: pt4ys[67],
            f668: pt4ys[68],
            f669: pt4ys[69],
            f670: pt4ys[70],
            f671: pt4ys[71],
            f672: pt4ys[72],
            f673: pt4ys[73],
            f674: pt4ys[74],
            f675: pt4ys[75],
            f676: pt4ys[76],
            f677: pt4ys[77],
            f678: pt4ys[78],
            f679: pt4ys[79],
            f680: pt4ys[80],
            f681: pt4ys[81],
            f682: pt4ys[82],
            f683: pt4ys[83],
            f684: pt4ys[84],
            f685: pt4ys[85],
            f686: pt4ys[86],
            f687: pt4ys[87],
            f688: pt4ys[88],
            f689: pt4ys[89],
            f690: pt4ys[90],
            f691: pt4ys[91],
            f692: pt4ys[92],
            f693: pt4ys[93],
            f694: pt4ys[94],
            f695: pt4ys[95],
            f696: pt4ys[96],
            f697: pt4ys[97],
            f698: pt4ys[98],
            f699: pt4ys[99],
            f700: pt4ys[100],
            f701: pt4ys[101],
            f702: pt4ys[102],
            f703: pt4ys[103],
            f704: pt4ys[104],
            f705: pt4ys[105],
            f706: pt4ys[106],
            f707: pt4ys[107],
            f708: pt4ys[108],
            f709: pt4ys[109],
            f710: pt4ys[110],
            f711: pt4ys[111],
            f712: pt4ys[112],
            f713: pt4ys[113],
            f714: pt4ys[114],
            f715: pt4ys[115],
            f716: pt4ys[116],
            f717: pt4ys[117],
            f718: pt4ys[118],
            f719: pt4ys[119],
            f720: pt5xs[0],
            f721: pt5xs[1],
            f722: pt5xs[2],
            f723: pt5xs[3],
            f724: pt5xs[4],
            f725: pt5xs[5],
            f726: pt5xs[6],
            f727: pt5xs[7],
            f728: pt5xs[8],
            f729: pt5xs[9],
            f730: pt5xs[10],
            f731: pt5xs[11],
            f732: pt5xs[12],
            f733: pt5xs[13],
            f734: pt5xs[14],
            f735: pt5xs[15],
            f736: pt5xs[16],
            f737: pt5xs[17],
            f738: pt5xs[18],
            f739: pt5xs[19],
            f740: pt5xs[20],
            f741: pt5xs[21],
            f742: pt5xs[22],
            f743: pt5xs[23],
            f744: pt5xs[24],
            f745: pt5xs[25],
            f746: pt5xs[26],
            f747: pt5xs[27],
            f748: pt5xs[28],
            f749: pt5xs[29],
            f750: pt5xs[30],
            f751: pt5xs[31],
            f752: pt5xs[32],
            f753: pt5xs[33],
            f754: pt5xs[34],
            f755: pt5xs[35],
            f756: pt5xs[36],
            f757: pt5xs[37],
            f758: pt5xs[38],
            f759: pt5xs[39],
            f760: pt5xs[40],
            f761: pt5xs[41],
            f762: pt5xs[42],
            f763: pt5xs[43],
            f764: pt5xs[44],
            f765: pt5xs[45],
            f766: pt5xs[46],
            f767: pt5xs[47],
            f768: pt5xs[48],
            f769: pt5xs[49],
            f770: pt5xs[50],
            f771: pt5xs[51],
            f772: pt5xs[52],
            f773: pt5xs[53],
            f774: pt5xs[54],
            f775: pt5xs[55],
            f776: pt5xs[56],
            f777: pt5xs[57],
            f778: pt5xs[58],
            f779: pt5xs[59],
            f780: pt5xs[60],
            f781: pt5xs[61],
            f782: pt5xs[62],
            f783: pt5xs[63],
            f784: pt5xs[64],
            f785: pt5xs[65],
            f786: pt5xs[66],
            f787: pt5xs[67],
            f788: pt5xs[68],
            f789: pt5xs[69],
            f790: pt5xs[70],
            f791: pt5xs[71],
            f792: pt5xs[72],
            f793: pt5xs[73],
            f794: pt5xs[74],
            f795: pt5xs[75],
            f796: pt5xs[76],
            f797: pt5xs[77],
            f798: pt5xs[78],
            f799: pt5xs[79],
            f800: pt5xs[80],
            f801: pt5xs[81],
            f802: pt5xs[82],
            f803: pt5xs[83],
            f804: pt5xs[84],
            f805: pt5xs[85],
            f806: pt5xs[86],
            f807: pt5xs[87],
            f808: pt5xs[88],
            f809: pt5xs[89],
            f810: pt5xs[90],
            f811: pt5xs[91],
            f812: pt5xs[92],
            f813: pt5xs[93],
            f814: pt5xs[94],
            f815: pt5xs[95],
            f816: pt5xs[96],
            f817: pt5xs[97],
            f818: pt5xs[98],
            f819: pt5xs[99],
            f820: pt5xs[100],
            f821: pt5xs[101],
            f822: pt5xs[102],
            f823: pt5xs[103],
            f824: pt5xs[104],
            f825: pt5xs[105],
            f826: pt5xs[106],
            f827: pt5xs[107],
            f828: pt5xs[108],
            f829: pt5xs[109],
            f830: pt5xs[110],
            f831: pt5xs[111],
            f832: pt5xs[112],
            f833: pt5xs[113],
            f834: pt5xs[114],
            f835: pt5xs[115],
            f836: pt5xs[116],
            f837: pt5xs[117],
            f838: pt5xs[118],
            f839: pt5xs[119],
            f840: pt5ys[0],
            f841: pt5ys[1],
            f842: pt5ys[2],
            f843: pt5ys[3],
            f844: pt5ys[4],
            f845: pt5ys[5],
            f846: pt5ys[6],
            f847: pt5ys[7],
            f848: pt5ys[8],
            f849: pt5ys[9],
            f850: pt5ys[10],
            f851: pt5ys[11],
            f852: pt5ys[12],
            f853: pt5ys[13],
            f854: pt5ys[14],
            f855: pt5ys[15],
            f856: pt5ys[16],
            f857: pt5ys[17],
            f858: pt5ys[18],
            f859: pt5ys[19],
            f860: pt5ys[20],
            f861: pt5ys[21],
            f862: pt5ys[22],
            f863: pt5ys[23],
            f864: pt5ys[24],
            f865: pt5ys[25],
            f866: pt5ys[26],
            f867: pt5ys[27],
            f868: pt5ys[28],
            f869: pt5ys[29],
            f870: pt5ys[30],
            f871: pt5ys[31],
            f872: pt5ys[32],
            f873: pt5ys[33],
            f874: pt5ys[34],
            f875: pt5ys[35],
            f876: pt5ys[36],
            f877: pt5ys[37],
            f878: pt5ys[38],
            f879: pt5ys[39],
            f880: pt5ys[40],
            f881: pt5ys[41],
            f882: pt5ys[42],
            f883: pt5ys[43],
            f884: pt5ys[44],
            f885: pt5ys[45],
            f886: pt5ys[46],
            f887: pt5ys[47],
            f888: pt5ys[48],
            f889: pt5ys[49],
            f890: pt5ys[50],
            f891: pt5ys[51],
            f892: pt5ys[52],
            f893: pt5ys[53],
            f894: pt5ys[54],
            f895: pt5ys[55],
            f896: pt5ys[56],
            f897: pt5ys[57],
            f898: pt5ys[58],
            f899: pt5ys[59],
            f900: pt5ys[60],
            f901: pt5ys[61],
            f902: pt5ys[62],
            f903: pt5ys[63],
            f904: pt5ys[64],
            f905: pt5ys[65],
            f906: pt5ys[66],
            f907: pt5ys[67],
            f908: pt5ys[68],
            f909: pt5ys[69],
            f910: pt5ys[70],
            f911: pt5ys[71],
            f912: pt5ys[72],
            f913: pt5ys[73],
            f914: pt5ys[74],
            f915: pt5ys[75],
            f916: pt5ys[76],
            f917: pt5ys[77],
            f918: pt5ys[78],
            f919: pt5ys[79],
            f920: pt5ys[80],
            f921: pt5ys[81],
            f922: pt5ys[82],
            f923: pt5ys[83],
            f924: pt5ys[84],
            f925: pt5ys[85],
            f926: pt5ys[86],
            f927: pt5ys[87],
            f928: pt5ys[88],
            f929: pt5ys[89],
            f930: pt5ys[90],
            f931: pt5ys[91],
            f932: pt5ys[92],
            f933: pt5ys[93],
            f934: pt5ys[94],
            f935: pt5ys[95],
            f936: pt5ys[96],
            f937: pt5ys[97],
            f938: pt5ys[98],
            f939: pt5ys[99],
            f940: pt5ys[100],
            f941: pt5ys[101],
            f942: pt5ys[102],
            f943: pt5ys[103],
            f944: pt5ys[104],
            f945: pt5ys[105],
            f946: pt5ys[106],
            f947: pt5ys[107],
            f948: pt5ys[108],
            f949: pt5ys[109],
            f950: pt5ys[110],
            f951: pt5ys[111],
            f952: pt5ys[112],
            f953: pt5ys[113],
            f954: pt5ys[114],
            f955: pt5ys[115],
            f956: pt5ys[116],
            f957: pt5ys[117],
            f958: pt5ys[118],
            f959: pt5ys[119],
            f960: pt6xs[0],
            f961: pt6xs[1],
            f962: pt6xs[2],
            f963: pt6xs[3],
            f964: pt6xs[4],
            f965: pt6xs[5],
            f966: pt6xs[6],
            f967: pt6xs[7],
            f968: pt6xs[8],
            f969: pt6xs[9],
            f970: pt6xs[10],
            f971: pt6xs[11],
            f972: pt6xs[12],
            f973: pt6xs[13],
            f974: pt6xs[14],
            f975: pt6xs[15],
            f976: pt6xs[16],
            f977: pt6xs[17],
            f978: pt6xs[18],
            f979: pt6xs[19],
            f980: pt6xs[20],
            f981: pt6xs[21],
            f982: pt6xs[22],
            f983: pt6xs[23],
            f984: pt6xs[24],
            f985: pt6xs[25],
            f986: pt6xs[26],
            f987: pt6xs[27],
            f988: pt6xs[28],
            f989: pt6xs[29],
            f990: pt6xs[30],
            f991: pt6xs[31],
            f992: pt6xs[32],
            f993: pt6xs[33],
            f994: pt6xs[34],
            f995: pt6xs[35],
            f996: pt6xs[36],
            f997: pt6xs[37],
            f998: pt6xs[38],
            f999: pt6xs[39],
            f1000: pt6xs[40],
            f1001: pt6xs[41],
            f1002: pt6xs[42],
            f1003: pt6xs[43],
            f1004: pt6xs[44],
            f1005: pt6xs[45],
            f1006: pt6xs[46],
            f1007: pt6xs[47],
            f1008: pt6xs[48],
            f1009: pt6xs[49],
            f1010: pt6xs[50],
            f1011: pt6xs[51],
            f1012: pt6xs[52],
            f1013: pt6xs[53],
            f1014: pt6xs[54],
            f1015: pt6xs[55],
            f1016: pt6xs[56],
            f1017: pt6xs[57],
            f1018: pt6xs[58],
            f1019: pt6xs[59],
            f1020: pt6xs[60],
            f1021: pt6xs[61],
            f1022: pt6xs[62],
            f1023: pt6xs[63],
            f1024: pt6xs[64],
            f1025: pt6xs[65],
            f1026: pt6xs[66],
            f1027: pt6xs[67],
            f1028: pt6xs[68],
            f1029: pt6xs[69],
            f1030: pt6xs[70],
            f1031: pt6xs[71],
            f1032: pt6xs[72],
            f1033: pt6xs[73],
            f1034: pt6xs[74],
            f1035: pt6xs[75],
            f1036: pt6xs[76],
            f1037: pt6xs[77],
            f1038: pt6xs[78],
            f1039: pt6xs[79],
            f1040: pt6xs[80],
            f1041: pt6xs[81],
            f1042: pt6xs[82],
            f1043: pt6xs[83],
            f1044: pt6xs[84],
            f1045: pt6xs[85],
            f1046: pt6xs[86],
            f1047: pt6xs[87],
            f1048: pt6xs[88],
            f1049: pt6xs[89],
            f1050: pt6xs[90],
            f1051: pt6xs[91],
            f1052: pt6xs[92],
            f1053: pt6xs[93],
            f1054: pt6xs[94],
            f1055: pt6xs[95],
            f1056: pt6xs[96],
            f1057: pt6xs[97],
            f1058: pt6xs[98],
            f1059: pt6xs[99],
            f1060: pt6xs[100],
            f1061: pt6xs[101],
            f1062: pt6xs[102],
            f1063: pt6xs[103],
            f1064: pt6xs[104],
            f1065: pt6xs[105],
            f1066: pt6xs[106],
            f1067: pt6xs[107],
            f1068: pt6xs[108],
            f1069: pt6xs[109],
            f1070: pt6xs[110],
            f1071: pt6xs[111],
            f1072: pt6xs[112],
            f1073: pt6xs[113],
            f1074: pt6xs[114],
            f1075: pt6xs[115],
            f1076: pt6xs[116],
            f1077: pt6xs[117],
            f1078: pt6xs[118],
            f1079: pt6xs[119],
            f1080: pt6ys[0],
            f1081: pt6ys[1],
            f1082: pt6ys[2],
            f1083: pt6ys[3],
            f1084: pt6ys[4],
            f1085: pt6ys[5],
            f1086: pt6ys[6],
            f1087: pt6ys[7],
            f1088: pt6ys[8],
            f1089: pt6ys[9],
            f1090: pt6ys[10],
            f1091: pt6ys[11],
            f1092: pt6ys[12],
            f1093: pt6ys[13],
            f1094: pt6ys[14],
            f1095: pt6ys[15],
            f1096: pt6ys[16],
            f1097: pt6ys[17],
            f1098: pt6ys[18],
            f1099: pt6ys[19],
            f1100: pt6ys[20],
            f1101: pt6ys[21],
            f1102: pt6ys[22],
            f1103: pt6ys[23],
            f1104: pt6ys[24],
            f1105: pt6ys[25],
            f1106: pt6ys[26],
            f1107: pt6ys[27],
            f1108: pt6ys[28],
            f1109: pt6ys[29],
            f1110: pt6ys[30],
            f1111: pt6ys[31],
            f1112: pt6ys[32],
            f1113: pt6ys[33],
            f1114: pt6ys[34],
            f1115: pt6ys[35],
            f1116: pt6ys[36],
            f1117: pt6ys[37],
            f1118: pt6ys[38],
            f1119: pt6ys[39],
            f1120: pt6ys[40],
            f1121: pt6ys[41],
            f1122: pt6ys[42],
            f1123: pt6ys[43],
            f1124: pt6ys[44],
            f1125: pt6ys[45],
            f1126: pt6ys[46],
            f1127: pt6ys[47],
            f1128: pt6ys[48],
            f1129: pt6ys[49],
            f1130: pt6ys[50],
            f1131: pt6ys[51],
            f1132: pt6ys[52],
            f1133: pt6ys[53],
            f1134: pt6ys[54],
            f1135: pt6ys[55],
            f1136: pt6ys[56],
            f1137: pt6ys[57],
            f1138: pt6ys[58],
            f1139: pt6ys[59],
            f1140: pt6ys[60],
            f1141: pt6ys[61],
            f1142: pt6ys[62],
            f1143: pt6ys[63],
            f1144: pt6ys[64],
            f1145: pt6ys[65],
            f1146: pt6ys[66],
            f1147: pt6ys[67],
            f1148: pt6ys[68],
            f1149: pt6ys[69],
            f1150: pt6ys[70],
            f1151: pt6ys[71],
            f1152: pt6ys[72],
            f1153: pt6ys[73],
            f1154: pt6ys[74],
            f1155: pt6ys[75],
            f1156: pt6ys[76],
            f1157: pt6ys[77],
            f1158: pt6ys[78],
            f1159: pt6ys[79],
            f1160: pt6ys[80],
            f1161: pt6ys[81],
            f1162: pt6ys[82],
            f1163: pt6ys[83],
            f1164: pt6ys[84],
            f1165: pt6ys[85],
            f1166: pt6ys[86],
            f1167: pt6ys[87],
            f1168: pt6ys[88],
            f1169: pt6ys[89],
            f1170: pt6ys[90],
            f1171: pt6ys[91],
            f1172: pt6ys[92],
            f1173: pt6ys[93],
            f1174: pt6ys[94],
            f1175: pt6ys[95],
            f1176: pt6ys[96],
            f1177: pt6ys[97],
            f1178: pt6ys[98],
            f1179: pt6ys[99],
            f1180: pt6ys[100],
            f1181: pt6ys[101],
            f1182: pt6ys[102],
            f1183: pt6ys[103],
            f1184: pt6ys[104],
            f1185: pt6ys[105],
            f1186: pt6ys[106],
            f1187: pt6ys[107],
            f1188: pt6ys[108],
            f1189: pt6ys[109],
            f1190: pt6ys[110],
            f1191: pt6ys[111],
            f1192: pt6ys[112],
            f1193: pt6ys[113],
            f1194: pt6ys[114],
            f1195: pt6ys[115],
            f1196: pt6ys[116],
            f1197: pt6ys[117],
            f1198: pt6ys[118],
            f1199: pt6ys[119],
            f1200: pt7xs[0],
            f1201: pt7xs[1],
            f1202: pt7xs[2],
            f1203: pt7xs[3],
            f1204: pt7xs[4],
            f1205: pt7xs[5],
            f1206: pt7xs[6],
            f1207: pt7xs[7],
            f1208: pt7xs[8],
            f1209: pt7xs[9],
            f1210: pt7xs[10],
            f1211: pt7xs[11],
            f1212: pt7xs[12],
            f1213: pt7xs[13],
            f1214: pt7xs[14],
            f1215: pt7xs[15],
            f1216: pt7xs[16],
            f1217: pt7xs[17],
            f1218: pt7xs[18],
            f1219: pt7xs[19],
            f1220: pt7xs[20],
            f1221: pt7xs[21],
            f1222: pt7xs[22],
            f1223: pt7xs[23],
            f1224: pt7xs[24],
            f1225: pt7xs[25],
            f1226: pt7xs[26],
            f1227: pt7xs[27],
            f1228: pt7xs[28],
            f1229: pt7xs[29],
            f1230: pt7xs[30],
            f1231: pt7xs[31],
            f1232: pt7xs[32],
            f1233: pt7xs[33],
            f1234: pt7xs[34],
            f1235: pt7xs[35],
            f1236: pt7xs[36],
            f1237: pt7xs[37],
            f1238: pt7xs[38],
            f1239: pt7xs[39],
            f1240: pt7xs[40],
            f1241: pt7xs[41],
            f1242: pt7xs[42],
            f1243: pt7xs[43],
            f1244: pt7xs[44],
            f1245: pt7xs[45],
            f1246: pt7xs[46],
            f1247: pt7xs[47],
            f1248: pt7xs[48],
            f1249: pt7xs[49],
            f1250: pt7xs[50],
            f1251: pt7xs[51],
            f1252: pt7xs[52],
            f1253: pt7xs[53],
            f1254: pt7xs[54],
            f1255: pt7xs[55],
            f1256: pt7xs[56],
            f1257: pt7xs[57],
            f1258: pt7xs[58],
            f1259: pt7xs[59],
            f1260: pt7xs[60],
            f1261: pt7xs[61],
            f1262: pt7xs[62],
            f1263: pt7xs[63],
            f1264: pt7xs[64],
            f1265: pt7xs[65],
            f1266: pt7xs[66],
            f1267: pt7xs[67],
            f1268: pt7xs[68],
            f1269: pt7xs[69],
            f1270: pt7xs[70],
            f1271: pt7xs[71],
            f1272: pt7xs[72],
            f1273: pt7xs[73],
            f1274: pt7xs[74],
            f1275: pt7xs[75],
            f1276: pt7xs[76],
            f1277: pt7xs[77],
            f1278: pt7xs[78],
            f1279: pt7xs[79],
            f1280: pt7xs[80],
            f1281: pt7xs[81],
            f1282: pt7xs[82],
            f1283: pt7xs[83],
            f1284: pt7xs[84],
            f1285: pt7xs[85],
            f1286: pt7xs[86],
            f1287: pt7xs[87],
            f1288: pt7xs[88],
            f1289: pt7xs[89],
            f1290: pt7xs[90],
            f1291: pt7xs[91],
            f1292: pt7xs[92],
            f1293: pt7xs[93],
            f1294: pt7xs[94],
            f1295: pt7xs[95],
            f1296: pt7xs[96],
            f1297: pt7xs[97],
            f1298: pt7xs[98],
            f1299: pt7xs[99],
            f1300: pt7xs[100],
            f1301: pt7xs[101],
            f1302: pt7xs[102],
            f1303: pt7xs[103],
            f1304: pt7xs[104],
            f1305: pt7xs[105],
            f1306: pt7xs[106],
            f1307: pt7xs[107],
            f1308: pt7xs[108],
            f1309: pt7xs[109],
            f1310: pt7xs[110],
            f1311: pt7xs[111],
            f1312: pt7xs[112],
            f1313: pt7xs[113],
            f1314: pt7xs[114],
            f1315: pt7xs[115],
            f1316: pt7xs[116],
            f1317: pt7xs[117],
            f1318: pt7xs[118],
            f1319: pt7xs[119],
            f1320: pt7ys[0],
            f1321: pt7ys[1],
            f1322: pt7ys[2],
            f1323: pt7ys[3],
            f1324: pt7ys[4],
            f1325: pt7ys[5],
            f1326: pt7ys[6],
            f1327: pt7ys[7],
            f1328: pt7ys[8],
            f1329: pt7ys[9],
            f1330: pt7ys[10],
            f1331: pt7ys[11],
            f1332: pt7ys[12],
            f1333: pt7ys[13],
            f1334: pt7ys[14],
            f1335: pt7ys[15],
            f1336: pt7ys[16],
            f1337: pt7ys[17],
            f1338: pt7ys[18],
            f1339: pt7ys[19],
            f1340: pt7ys[20],
            f1341: pt7ys[21],
            f1342: pt7ys[22],
            f1343: pt7ys[23],
            f1344: pt7ys[24],
            f1345: pt7ys[25],
            f1346: pt7ys[26],
            f1347: pt7ys[27],
            f1348: pt7ys[28],
            f1349: pt7ys[29],
            f1350: pt7ys[30],
            f1351: pt7ys[31],
            f1352: pt7ys[32],
            f1353: pt7ys[33],
            f1354: pt7ys[34],
            f1355: pt7ys[35],
            f1356: pt7ys[36],
            f1357: pt7ys[37],
            f1358: pt7ys[38],
            f1359: pt7ys[39],
            f1360: pt7ys[40],
            f1361: pt7ys[41],
            f1362: pt7ys[42],
            f1363: pt7ys[43],
            f1364: pt7ys[44],
            f1365: pt7ys[45],
            f1366: pt7ys[46],
            f1367: pt7ys[47],
            f1368: pt7ys[48],
            f1369: pt7ys[49],
            f1370: pt7ys[50],
            f1371: pt7ys[51],
            f1372: pt7ys[52],
            f1373: pt7ys[53],
            f1374: pt7ys[54],
            f1375: pt7ys[55],
            f1376: pt7ys[56],
            f1377: pt7ys[57],
            f1378: pt7ys[58],
            f1379: pt7ys[59],
            f1380: pt7ys[60],
            f1381: pt7ys[61],
            f1382: pt7ys[62],
            f1383: pt7ys[63],
            f1384: pt7ys[64],
            f1385: pt7ys[65],
            f1386: pt7ys[66],
            f1387: pt7ys[67],
            f1388: pt7ys[68],
            f1389: pt7ys[69],
            f1390: pt7ys[70],
            f1391: pt7ys[71],
            f1392: pt7ys[72],
            f1393: pt7ys[73],
            f1394: pt7ys[74],
            f1395: pt7ys[75],
            f1396: pt7ys[76],
            f1397: pt7ys[77],
            f1398: pt7ys[78],
            f1399: pt7ys[79],
            f1400: pt7ys[80],
            f1401: pt7ys[81],
            f1402: pt7ys[82],
            f1403: pt7ys[83],
            f1404: pt7ys[84],
            f1405: pt7ys[85],
            f1406: pt7ys[86],
            f1407: pt7ys[87],
            f1408: pt7ys[88],
            f1409: pt7ys[89],
            f1410: pt7ys[90],
            f1411: pt7ys[91],
            f1412: pt7ys[92],
            f1413: pt7ys[93],
            f1414: pt7ys[94],
            f1415: pt7ys[95],
            f1416: pt7ys[96],
            f1417: pt7ys[97],
            f1418: pt7ys[98],
            f1419: pt7ys[99],
            f1420: pt7ys[100],
            f1421: pt7ys[101],
            f1422: pt7ys[102],
            f1423: pt7ys[103],
            f1424: pt7ys[104],
            f1425: pt7ys[105],
            f1426: pt7ys[106],
            f1427: pt7ys[107],
            f1428: pt7ys[108],
            f1429: pt7ys[109],
            f1430: pt7ys[110],
            f1431: pt7ys[111],
            f1432: pt7ys[112],
            f1433: pt7ys[113],
            f1434: pt7ys[114],
            f1435: pt7ys[115],
            f1436: pt7ys[116],
            f1437: pt7ys[117],
            f1438: pt7ys[118],
            f1439: pt7ys[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = tossHeightScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
}


public struct Permutations<S: Sequence>: IteratorProtocol, Sequence {

    private let values: [S.Iterator.Element]
    private let permutationLength: Int
    private let repeatingElements: Bool
    private var indicesIterator: CartesianProduct<CountableRange<Int>>

    init(sequence: S, length: Int?, repeatingElements: Bool) {
        self.values = Array(sequence)

        if let length = length {
            self.permutationLength = length
        } else {
            self.permutationLength = values.count
        }

        self.repeatingElements = repeatingElements
        self.indicesIterator = product(values.indices, repeated: permutationLength)
    }

    public mutating func next() -> [S.Iterator.Element]? {
        guard let indices = indicesIterator.next() else {
            return nil
        }

        if !repeatingElements {
            guard Set(indices).count == permutationLength else {
                return next()
            }
        }

        let permutation = indices.map { values[$0] }
        return permutation.isEmpty ? nil : permutation
    }
}

public struct CartesianProduct<S: Sequence>: IteratorProtocol, Sequence {

    private let sequences: [S]
    private var iterators: [S.Iterator]
    private var currentValues: [S.Iterator.Element] = []

    fileprivate init(_ sequences: [S]) {
        self.sequences = sequences
        self.iterators = sequences.map { $0.makeIterator() }
    }

    public mutating func next() -> [S.Iterator.Element]? {
        guard !currentValues.isEmpty else {
            var firstValues: [S.Iterator.Element] = []
            for index in iterators.indices {
                guard let value = iterators[index].next() else {
                    return nil
                }
                firstValues.append(value)
            }
            currentValues = firstValues
            return firstValues
        }

        for index in currentValues.indices.reversed() {
            if let value = iterators[index].next() {
                currentValues[index] = value
                return currentValues
            }

            guard index != 0 else {
                return nil
            }

            iterators[index] = sequences[index].makeIterator()
            currentValues[index] = iterators[index].next()!
        }

        return currentValues
    }
}
public func product<S: Sequence>(_ sequences: S...) -> CartesianProduct<S> {
    return CartesianProduct(sequences)
}
public func product<S: Sequence>(_ sequence: S, repeated: Int) -> CartesianProduct<S> {
    let sequences = Array(repeating: sequence, count: repeated)
    return CartesianProduct(sequences)
}

public extension Sequence {

    
    func combinations(length: Int, repeatingElements: Bool) -> [[Iterator.Element]] {
        return Array(Combinations(sequence: self, length: length, repeatingElements: repeatingElements))
    }
}


public extension LazySequenceProtocol {

    func combinations(length: Int, repeatingElements: Bool) -> Combinations<Self> {
        return Combinations(sequence: self, length: length, repeatingElements: repeatingElements)
    }
}



public struct Combinations<S: Sequence>: IteratorProtocol, Sequence {

    private let values: [S.Iterator.Element]
    private let combinationLength: Int
    private let repeatingElements: Bool
    private var indicesIterator: AnyIterator<Array<Int>>

    fileprivate init(sequence: S, length: Int, repeatingElements: Bool) {
        self.values = Array(sequence)
        self.combinationLength = length
        self.repeatingElements = repeatingElements
        if repeatingElements {
            self.indicesIterator = AnyIterator(product(values.indices, repeated: length))
        } else {
            self.indicesIterator = AnyIterator(Permutations(sequence: values.indices, length: length, repeatingElements: false))
        }
    }

    public mutating func next() -> [S.Iterator.Element]? {
        guard let indices = indicesIterator.next() else {
            return nil
        }

        guard indices.sorted() == indices else {
            return next()
        }

        let combination = indices.map { values[$0] }
        return combination.isEmpty ? nil : combination
    }
}
extension CGPoint {
    init(_ x: CGFloat, _ y: CGFloat) {
        self.init()
        self.x = x
        self.y = y
    }
}
extension UIColor {
    class func rgb(_ r: Int,_ g: Int,_ b: Int) -> UIColor{
        return UIColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1)
    }
}
