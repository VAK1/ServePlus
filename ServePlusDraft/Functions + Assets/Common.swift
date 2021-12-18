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
    
    func zero_pad(_ array: [Double]) -> [Double] {
        
        /* Makes sure the input array has 120 points to match the
           requirements of the AI serve grading models */
        
        if array.count == 120 {
            return array
        }
        let added = Array(repeating: 0.0, count: 120-array.count)
        return array+added
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
        
        /* Returns the angle between two points and the horizon */
        
        return atan((x2-x1)/(y1-y2))
    }
    
    func midpoint(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> (Double, Double) {
        
        /* Returns the midpoint between two points */
        
        return ((x1+x2)/2, (y1+y2)/2)
    }
    
    func three_point_angle(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x3: Double, _ y3: Double) -> Double {
        
        /* Returns the angle between three points */
        
        let x1x2s = pow((x1 - x2),2)
        let x1x3s = pow((x1 - x3),2)
        let x2x3s = pow((x3 - x3),2)
         
        let y1y2s = pow((y1 - y2),2)
        let y1y3s = pow((y1 - y3),2)
        let y2y3s = pow((y2 - y3),2)
        
        return acos((x1x2s + y1y2s + x2x3s + y2y3s - x1x3s - y1y3s)/(2*sqrt(x1x2s + y1y2s)*sqrt(x2x3s + y2y3s)))
    }
    
    func distance(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        
        /* Returns the distance between two points */
        
        return sqrt(pow((x1-x2), 2) + pow((y1-y2), 2))
    }
    
   
    func interpolateZeroes(_ arr: [Double]) -> [Double] {
        
        /* Interpolates zeroes in an array. Useful when
           certain coordinates of poses aren't detected for
           some reason, and we want to use non-zero numbers
           for maximum benefit. Basic interpolation function
           that fills in zeroes with the last nonzero number. */
    
        // Get the first non-zero number
        let firstNonZero = arr.first(where: { $0 != 0 })
        
        
        // If the entire array is zeroes, return it
        if firstNonZero == nil {
            return arr
        }
        
        /* Initialize an integer to keep track of the last
           nonzero number */
        var latestNonZero = firstNonZero

        
        /* Initialize an array that will become the interpolated
           array */
        var interpolated:[Double] = []
        
        
        /* Boolean to keep track of if the first nonzero number
           has been iterated through yet */
        var found_nonzero = false
        
        
        // Loop through the elements in the original array
        for element in arr {
            
            /* Case 1: Element is 0, and the first nonzero
               number hasn't been iterated through yet */
            if (element == 0.0 && !found_nonzero) {
                
                /* Append the first nonzero number we
                   calculated earlier */
                interpolated.append(firstNonZero!)
            }
            
            /* Case 2: Element is 0, and the first nonzero
               number has been iterated through already */
            else if (element == 0.0) {
                
                /* Append the last nonzero number that was
                   discovered */
                interpolated.append(latestNonZero!)
            }
            
            /* Case 3: Element is nonzero */
            if (element != 0.0) {
                
                /* Set the latest nonzero element to the
                   current element */
                latestNonZero = element
                
                
                // Append that element to the final array
                interpolated.append(element)
                
                    
                /* We must have found the first nonzero
                   number */
                found_nonzero = true
            }
        }
        
        // Return the interpolated array
        return interpolated
    }

    func normalize_array(_ arr: [Double]) -> [Double] {
        
        /* Normalizes all values of an array to numbers
           between 0 and 100 */
        
        let range = arr.max()!-arr.min()!
        return arr.map({ ($0 - arr.min()!) * (100.0/range) })
    }

    func stdev(arr : [Double]) -> Double {
        
        /* Calculates the standard deviation of a
           list of numbers */
        
        // Store the length of the input array
        let length = Double(arr.count)
        
        
        // Get the average of the elements in the array
        let avg = arr.reduce(0, {$0 + $1}) / length
        
        
        /* Get the sum of the squared differences between
           each element in the array and the average value */
        let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
        
        
        // Calculate and return the standard deviation
        return sqrt(sumOfSquaredAvgDiff / length)
    }

    func RollingSampleStandardDeviations(_ data: [Double], _ sampleSize: Int) -> [Double] {
        
        /* Calculates the standard deviations of an array
           over the length of the array. The sampleSize
           dictates how many elements are assigned to a
           "window" when calculating individual standard
           deviations. */
        
        /* Initialize an array to store the final rolling
           sample standard deviations */
        var standardDeviations:[Double] = []

        
        /* Loop through all the subarrays in the input
           array with a length of sampleLength */
        for n in stride(from: 0, to: data.count - 1 - sampleSize, by: 1) {
            
            // Store the subarray, or window
            let arr = Array(data[n...n+sampleSize])
            
            
            /* Calculate the standard deviation of that
               window and append it to the final list
               of standard deviations */
            standardDeviations.append(stdev(arr: arr))
        }
        
        // Return the rolling standard deviations
        return standardDeviations
    }

    func detect_peaks(_ arr: [Double], _ window_size: Int = 60, _ subtraction_threshold: Double = 10.0) -> [Int] {
        
        /* Returns the local peaks in an array using standard
           deviations. The hyperparameters of this function
           were determined through countless sessions of trial
           and error, because this function will be used to
           detect the serves in an input video. */
        
        /* Initialize an array to store the incides of the input
           array's peaks */
        var peak_indices:[Int] = []
        
        
        /* Initialize an array to store the values of the input
           array's peaks */
        var peak_values:[Double] = []

        
        /* If the array is smaller than the window size, return
           an array with -1. This lets the program calling this
           function know that the input video should only have
           a single serve. */
        if (arr.count <= window_size) {
            return [-1]
        }
        
        
        /* Append some zeroes at the beginning and end of the input
           array so the rolling sample standard deviation includes
           every element of the original array the same number of
           times. */
        let dummy_zeroes = [Double](repeating: 0.0, count: window_size)
        let arr = dummy_zeroes + arr + dummy_zeroes
        
        
        /* Initialize the integer that keeps track of for how many
           windows the current peak has been the maximum. */
        var life_of_max = 0
        
        
        // Initialize the double that stores the current peak
        var current_max = 0.0
        
        
        // Initialize the current window
        var current_window = Array(arr[...(window_size-1)])
        
        
        /* Initialize the integer that will store the index of the
           current peak. */
        var current_max_index = 0
        
        
        // Loop through every window in the input array
        for x in stride(from: 0, to: arr.count - window_size, by: 1) {
            
            // Get the maximum value of the current window
            let window_max = current_window.max()
            
            
            /* If the window max is larger than the maximum from the
               previous window, or the current window doesn't contain
               the maximum from the previous window anymore, then the
               window max becomes the new maximum */
            if ((window_max! > current_max) || !(current_window.contains(current_max))) {
                current_max = window_max!
                life_of_max = 0
                current_max_index = x + current_window.firstIndex(of: current_max)!
            }
            
            /* Increment the number of windows for which the current
               maximum has remained the maximum */
            life_of_max += 1
            
            
            // Shift the window one element to the right
            current_window = Array(current_window[1...])
            current_window.append(arr[x+window_size])
            
            
            /* If the current maximum has been the maximum for all
               the windows it has been a part of, then it's index
               will be indicted into the list of peaks. */
            if life_of_max == window_size - 1 {
                peak_indices.append(current_max_index - window_size)
                peak_values.append(current_max)
            }
        }
        
        
        /* Zip the peak indices and values into one array, where each
           element in the array is a tuple of a peak's value and it's
           corresponding index. The array is sorted from the maximum
           peak value to the minimum peak value. */
        let combined = zip(peak_values, peak_indices).sorted {$0.0 < $1.0}
        
        
        /* Get references to the sorted values and their respective
           indices */
        let sorted_values = combined.map {$0.0}
        let sorted_indices = combined.map {$0.1}

        
        /* Initialize an array to keep track of the differences
           between consecutive maximum values */
        var subtractions:[Double] = []
        
        
        // If there were only two peaks, return both of them
        if (sorted_indices.count < 2) {
            return sorted_indices
        }

        
        /* Generate the differences between consecutive maximum
           values */
        for index in stride(from: 0, to: sorted_values.count - 1, by: 1) {
            let larger = sorted_values[index+1]
            let smaller = sorted_values[index]
            subtractions.append(larger - smaller)
        }

        // Get a reference to the biggest difference
        let biggest_diff = subtractions.max()

        
        /* If the biggest difference is smaller than the threshold
           that represents when maximums don't belong to individual
           tennis serves, then return all the detected maximums'
           indices. */
        if biggest_diff! < subtraction_threshold {
            return sorted_indices.sorted()
        }
        
        /* Otherwise, return only the indices of the maximums that
           occur before the biggest difference, the idea being that
           the ones after are related to variations that don't have
           to do with service motions. */
        let thresh_index = subtractions.firstIndex(of: biggest_diff!)! + 1
        
        let final_peaks = Array(sorted_indices[thresh_index...])
        
        return final_peaks.sorted()
    }
    

    func final_filter(_ lh_values: [Double], _ rh_values: [Double], _ window_size: Int, _ sub_thresh: Double, _ index_difference: Int, _ right_handed: Bool) -> [Int] {
        
        /* This function takes the y values of the player's hands, and
           returns the frames where individual serves are most likely
           to be happening. */
        
        /* If no y values were tracked for either hand, let the
           program know to use the entire video as a single serve
           by returning [0]. */
        if (lh_values == [] || rh_values == []) {
            return [0]
        }
        
        
        // Fill in zeroes for the lists of y values for both hands.
        var LH_Values = interpolateZeroes(lh_values)
        var RH_Values = interpolateZeroes(lh_values)
        
        
        // Normalize both lists to the range of 0 to 100
        LH_Values = normalize_array(LH_Values)
        RH_Values = normalize_array(RH_Values)
        
        
        /* Calculate the rolling sample standard deviations for both
           lists with a window size of 50 */
        let LH_Variances = RollingSampleStandardDeviations(LH_Values, 50)
        let RH_Variances = RollingSampleStandardDeviations(RH_Values, 50)

        
        // Detect the peaks in the standard deviations of both hands
        var lh_indices = detect_peaks(LH_Variances, window_size, sub_thresh)
        var rh_indices = detect_peaks(RH_Variances, window_size, sub_thresh)

        /* If there weren't enough y values for the statistical
           analysis to be executed, let the program know to use
           the entire video as a single serve by returning [0]. */
        if (lh_indices == [-1] || rh_indices == [-1]) {
            return [0]
        }
        
        /* The following portion removes frame indices where individual
           serves might be initiated based on when the peaks for the
           left and right hands don't line up. There is some forgiveness
           in the form of the parameter "index_difference", but if the
           differences in the positions of corresponding peaks between
           the two hands is greater than index_difference, then the
           possibility of a serve happening in those frames is limited. */
        
        
        /* Initialize two integers that keep track of the current
           indices being compared. */
        var lh_check = 0
        var rh_check = 0

        
        // Loop through both lists of indices simultaneously
        while lh_check < lh_indices.count && rh_check < rh_indices.count {
            
            /* Calculate the difference between the positions that
               the two hands are arguing where the serve starts */
            let diff = lh_indices[lh_check] - rh_indices[rh_check]
        
            
            /* If there is general agreement, then move on to the
               next pair of positions */
            if abs(diff) < index_difference {
                lh_check += 1
                rh_check += 1
            }
            
            /* If the right hand is significantly behind, then remove
               the right hand's position and move on in hopes that the
               next position is closer to the left hand's argument */
            else if diff > 0 {
                rh_indices.remove(at: rh_check)
            }
            /* If the left hand is significantly behind, then remove
               the left hand's position and move on in hopes that the
               next position is closer to the right hand's argument */
            else {
                lh_indices.remove(at: lh_check)
            }
        }

        /* Remove the leftover indices that didn't get iterated through
           because the other hand ran out of indices */
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

        /* Return the final list of indices where the individual serves
           start based on the player's dominant hand. */
        if right_handed {
            return rh_indices
        }
        else {
            return lh_indices
        }
    }
    
    func histogram(_ arr: [Double], _ bins: Int, _ start: Double, _ end: Double) -> [Double] {
        
        /* Generates a histogram from an input array based on an
           indicated number of bins, a starting bin vaule and an
           ending bin value */
        
        return arr
    }
    
    func getDeviceName() -> String {
        
        /* Gets the name of the user's device. Used to understand if
           their device can support this app. */
        
        var size: Int = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        
        return String(cString:machine)
    }
    
    func superimposeImages(mainImage: UIImage, subImage: UIImage) -> UIImage {
        
        /* Draws one image on top of the other. Used for drawing
           detected poses on top of an input video */
        
        UIGraphicsBeginImageContext(mainImage.size)
        mainImage.draw(in: CGRect(x: 0, y: 0, width: mainImage.size.width, height: mainImage.size.height))
        subImage.draw(in: CGRect(x: 0, y: 0, width: subImage.size.width, height: subImage.size.height))
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func resizeImage(image: UIImage, size: CGSize, keepAspectRatio: Bool = false) -> UIImage {
        
        /* Resizes an image to a target size. Used for drawing images
           with respect to the aspect ratio of the user's device. */
        
        let targetSize: CGSize = size
        
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
        
        /* Crops an image. Used to crop the image with the detected
           poses so it matches the input video frame. */
        
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
        
        /* Generates a pixel buffer from a CG Image. */
        
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
    
    
    
    /* The following functions generate predictions for the scores of
       individual serves. */
    
    
    
    func getBAPrediction(_ model: backArchXGBoost, _ backAngleHistogramVals: [Double]) -> Double  {
        
        /* Generates a back arching score based on a probability histogram
           of back angles */
        
        guard let backArchScore = try? model.prediction(input: backArchXGBoostInput(
            f0: backAngleHistogramVals[0],
            f1: backAngleHistogramVals[1],
            f2: backAngleHistogramVals[2],
            f3: backAngleHistogramVals[3],
            f4: backAngleHistogramVals[4],
            f5: backAngleHistogramVals[5],
            f6: backAngleHistogramVals[6],
            f7: backAngleHistogramVals[7],
            f8: backAngleHistogramVals[8],
            f9: backAngleHistogramVals[9],
            f10: backAngleHistogramVals[10],
            f11: backAngleHistogramVals[11],
            f12: backAngleHistogramVals[12],
            f13: backAngleHistogramVals[13],
            f14: backAngleHistogramVals[14],
            f15: backAngleHistogramVals[15],
            f16: backAngleHistogramVals[16],
            f17: backAngleHistogramVals[17],
            f18: backAngleHistogramVals[18],
            f19: backAngleHistogramVals[19],
            f20: backAngleHistogramVals[20],
            f21: backAngleHistogramVals[21],
            f22: backAngleHistogramVals[22],
            f23: backAngleHistogramVals[23],
            f24: backAngleHistogramVals[24],
            f25: backAngleHistogramVals[25],
            f26: backAngleHistogramVals[26],
            f27: backAngleHistogramVals[27],
            f28: backAngleHistogramVals[28],
            f29: backAngleHistogramVals[29],
            f30: backAngleHistogramVals[30],
            f31: backAngleHistogramVals[31],
            f32: backAngleHistogramVals[32],
            f33: backAngleHistogramVals[33],
            f34: backAngleHistogramVals[34],
            f35: backAngleHistogramVals[35],
            f36: backAngleHistogramVals[36],
            f37: backAngleHistogramVals[37],
            f38: backAngleHistogramVals[38],
            f39: backAngleHistogramVals[39],
            f40: backAngleHistogramVals[40],
            f41: backAngleHistogramVals[41],
            f42: backAngleHistogramVals[42],
            f43: backAngleHistogramVals[43],
            f44: backAngleHistogramVals[44],
            f45: backAngleHistogramVals[45],
            f46: backAngleHistogramVals[46],
            f47: backAngleHistogramVals[47],
            f48: backAngleHistogramVals[48],
            f49: backAngleHistogramVals[49],
            f50: backAngleHistogramVals[50],
            f51: backAngleHistogramVals[51],
            f52: backAngleHistogramVals[52],
            f53: backAngleHistogramVals[53],
            f54: backAngleHistogramVals[54],
            f55: backAngleHistogramVals[55],
            f56: backAngleHistogramVals[56],
            f57: backAngleHistogramVals[57],
            f58: backAngleHistogramVals[58],
            f59: backAngleHistogramVals[59],
            f60: backAngleHistogramVals[60],
            f61: backAngleHistogramVals[61],
            f62: backAngleHistogramVals[62],
            f63: backAngleHistogramVals[63],
            f64: backAngleHistogramVals[64],
            f65: backAngleHistogramVals[65],
            f66: backAngleHistogramVals[66],
            f67: backAngleHistogramVals[67],
            f68: backAngleHistogramVals[68],
            f69: backAngleHistogramVals[69],
            f70: backAngleHistogramVals[70],
            f71: backAngleHistogramVals[71],
            f72: backAngleHistogramVals[72],
            f73: backAngleHistogramVals[73],
            f74: backAngleHistogramVals[74],
            f75: backAngleHistogramVals[75],
            f76: backAngleHistogramVals[76],
            f77: backAngleHistogramVals[77],
            f78: backAngleHistogramVals[78],
            f79: backAngleHistogramVals[79],
            f80: backAngleHistogramVals[80],
            f81: backAngleHistogramVals[81],
            f82: backAngleHistogramVals[82],
            f83: backAngleHistogramVals[83],
            f84: backAngleHistogramVals[84],
            f85: backAngleHistogramVals[85],
            f86: backAngleHistogramVals[86],
            f87: backAngleHistogramVals[87],
            f88: backAngleHistogramVals[88],
            f89: backAngleHistogramVals[89],
            f90: backAngleHistogramVals[90],
            f91: backAngleHistogramVals[91],
            f92: backAngleHistogramVals[92],
            f93: backAngleHistogramVals[93],
            f94: backAngleHistogramVals[94],
            f95: backAngleHistogramVals[95],
            f96: backAngleHistogramVals[96],
            f97: backAngleHistogramVals[97],
            f98: backAngleHistogramVals[98],
            f99: backAngleHistogramVals[99],
            f100: backAngleHistogramVals[100],
            f101: backAngleHistogramVals[101],
            f102: backAngleHistogramVals[102],
            f103: backAngleHistogramVals[103],
            f104: backAngleHistogramVals[104],
            f105: backAngleHistogramVals[105],
            f106: backAngleHistogramVals[106],
            f107: backAngleHistogramVals[107],
            f108: backAngleHistogramVals[108],
            f109: backAngleHistogramVals[109],
            f110: backAngleHistogramVals[110],
            f111: backAngleHistogramVals[111],
            f112: backAngleHistogramVals[112],
            f113: backAngleHistogramVals[113],
            f114: backAngleHistogramVals[114],
            f115: backAngleHistogramVals[115],
            f116: backAngleHistogramVals[116],
            f117: backAngleHistogramVals[117],
            f118: backAngleHistogramVals[118],
            f119: backAngleHistogramVals[119])) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = backArchScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    
    func getBLPrediction(_ model: backLegKickedBackXGBoost, _ pt10ysHistogramVals: [Double], _ pt13ysHistogramVals: [Double], _ leftLegAngleHistogramVals: [Double], _ rightLegAngleHistogramVals: [Double]) -> Double  {
        
        /* Generates a back leg kick back score based on probability
           histograms of feet positions and leg angles. */
        
        guard let backLegScore = try? model.prediction(input: backLegKickedBackXGBoostInput(
            f0: pt10ysHistogramVals[0],
            f1: pt10ysHistogramVals[1],
            f2: pt10ysHistogramVals[2],
            f3: pt10ysHistogramVals[3],
            f4: pt10ysHistogramVals[4],
            f5: pt10ysHistogramVals[5],
            f6: pt10ysHistogramVals[6],
            f7: pt10ysHistogramVals[7],
            f8: pt10ysHistogramVals[8],
            f9: pt10ysHistogramVals[9],
            f10: pt10ysHistogramVals[10],
            f11: pt10ysHistogramVals[11],
            f12: pt10ysHistogramVals[12],
            f13: pt10ysHistogramVals[13],
            f14: pt10ysHistogramVals[14],
            f15: pt10ysHistogramVals[15],
            f16: pt10ysHistogramVals[16],
            f17: pt10ysHistogramVals[17],
            f18: pt10ysHistogramVals[18],
            f19: pt10ysHistogramVals[19],
            f20: pt10ysHistogramVals[20],
            f21: pt10ysHistogramVals[21],
            f22: pt10ysHistogramVals[22],
            f23: pt10ysHistogramVals[23],
            f24: pt10ysHistogramVals[24],
            f25: pt10ysHistogramVals[25],
            f26: pt10ysHistogramVals[26],
            f27: pt10ysHistogramVals[27],
            f28: pt10ysHistogramVals[28],
            f29: pt10ysHistogramVals[29],
            f30: pt10ysHistogramVals[30],
            f31: pt10ysHistogramVals[31],
            f32: pt10ysHistogramVals[32],
            f33: pt10ysHistogramVals[33],
            f34: pt10ysHistogramVals[34],
            f35: pt10ysHistogramVals[35],
            f36: pt10ysHistogramVals[36],
            f37: pt10ysHistogramVals[37],
            f38: pt10ysHistogramVals[38],
            f39: pt10ysHistogramVals[39],
            f40: pt10ysHistogramVals[40],
            f41: pt10ysHistogramVals[41],
            f42: pt10ysHistogramVals[42],
            f43: pt10ysHistogramVals[43],
            f44: pt10ysHistogramVals[44],
            f45: pt10ysHistogramVals[45],
            f46: pt10ysHistogramVals[46],
            f47: pt10ysHistogramVals[47],
            f48: pt10ysHistogramVals[48],
            f49: pt10ysHistogramVals[49],
            f50: pt10ysHistogramVals[50],
            f51: pt10ysHistogramVals[51],
            f52: pt10ysHistogramVals[52],
            f53: pt10ysHistogramVals[53],
            f54: pt10ysHistogramVals[54],
            f55: pt10ysHistogramVals[55],
            f56: pt10ysHistogramVals[56],
            f57: pt10ysHistogramVals[57],
            f58: pt10ysHistogramVals[58],
            f59: pt10ysHistogramVals[59],
            f60: pt10ysHistogramVals[60],
            f61: pt10ysHistogramVals[61],
            f62: pt10ysHistogramVals[62],
            f63: pt10ysHistogramVals[63],
            f64: pt10ysHistogramVals[64],
            f65: pt10ysHistogramVals[65],
            f66: pt10ysHistogramVals[66],
            f67: pt10ysHistogramVals[67],
            f68: pt10ysHistogramVals[68],
            f69: pt10ysHistogramVals[69],
            f70: pt10ysHistogramVals[70],
            f71: pt10ysHistogramVals[71],
            f72: pt10ysHistogramVals[72],
            f73: pt10ysHistogramVals[73],
            f74: pt10ysHistogramVals[74],
            f75: pt10ysHistogramVals[75],
            f76: pt10ysHistogramVals[76],
            f77: pt10ysHistogramVals[77],
            f78: pt10ysHistogramVals[78],
            f79: pt10ysHistogramVals[79],
            f80: pt10ysHistogramVals[80],
            f81: pt10ysHistogramVals[81],
            f82: pt10ysHistogramVals[82],
            f83: pt10ysHistogramVals[83],
            f84: pt10ysHistogramVals[84],
            f85: pt10ysHistogramVals[85],
            f86: pt10ysHistogramVals[86],
            f87: pt10ysHistogramVals[87],
            f88: pt10ysHistogramVals[88],
            f89: pt10ysHistogramVals[89],
            f90: pt10ysHistogramVals[90],
            f91: pt10ysHistogramVals[91],
            f92: pt10ysHistogramVals[92],
            f93: pt10ysHistogramVals[93],
            f94: pt10ysHistogramVals[94],
            f95: pt10ysHistogramVals[95],
            f96: pt10ysHistogramVals[96],
            f97: pt10ysHistogramVals[97],
            f98: pt10ysHistogramVals[98],
            f99: pt10ysHistogramVals[99],
            f100: pt10ysHistogramVals[100],
            f101: pt10ysHistogramVals[101],
            f102: pt10ysHistogramVals[102],
            f103: pt10ysHistogramVals[103],
            f104: pt10ysHistogramVals[104],
            f105: pt10ysHistogramVals[105],
            f106: pt10ysHistogramVals[106],
            f107: pt10ysHistogramVals[107],
            f108: pt10ysHistogramVals[108],
            f109: pt10ysHistogramVals[109],
            f110: pt10ysHistogramVals[110],
            f111: pt10ysHistogramVals[111],
            f112: pt10ysHistogramVals[112],
            f113: pt10ysHistogramVals[113],
            f114: pt10ysHistogramVals[114],
            f115: pt10ysHistogramVals[115],
            f116: pt10ysHistogramVals[116],
            f117: pt10ysHistogramVals[117],
            f118: pt10ysHistogramVals[118],
            f119: pt10ysHistogramVals[119],
            f120: pt13ysHistogramVals[0],
            f121: pt13ysHistogramVals[1],
            f122: pt13ysHistogramVals[2],
            f123: pt13ysHistogramVals[3],
            f124: pt13ysHistogramVals[4],
            f125: pt13ysHistogramVals[5],
            f126: pt13ysHistogramVals[6],
            f127: pt13ysHistogramVals[7],
            f128: pt13ysHistogramVals[8],
            f129: pt13ysHistogramVals[9],
            f130: pt13ysHistogramVals[10],
            f131: pt13ysHistogramVals[11],
            f132: pt13ysHistogramVals[12],
            f133: pt13ysHistogramVals[13],
            f134: pt13ysHistogramVals[14],
            f135: pt13ysHistogramVals[15],
            f136: pt13ysHistogramVals[16],
            f137: pt13ysHistogramVals[17],
            f138: pt13ysHistogramVals[18],
            f139: pt13ysHistogramVals[19],
            f140: pt13ysHistogramVals[20],
            f141: pt13ysHistogramVals[21],
            f142: pt13ysHistogramVals[22],
            f143: pt13ysHistogramVals[23],
            f144: pt13ysHistogramVals[24],
            f145: pt13ysHistogramVals[25],
            f146: pt13ysHistogramVals[26],
            f147: pt13ysHistogramVals[27],
            f148: pt13ysHistogramVals[28],
            f149: pt13ysHistogramVals[29],
            f150: pt13ysHistogramVals[30],
            f151: pt13ysHistogramVals[31],
            f152: pt13ysHistogramVals[32],
            f153: pt13ysHistogramVals[33],
            f154: pt13ysHistogramVals[34],
            f155: pt13ysHistogramVals[35],
            f156: pt13ysHistogramVals[36],
            f157: pt13ysHistogramVals[37],
            f158: pt13ysHistogramVals[38],
            f159: pt13ysHistogramVals[39],
            f160: pt13ysHistogramVals[40],
            f161: pt13ysHistogramVals[41],
            f162: pt13ysHistogramVals[42],
            f163: pt13ysHistogramVals[43],
            f164: pt13ysHistogramVals[44],
            f165: pt13ysHistogramVals[45],
            f166: pt13ysHistogramVals[46],
            f167: pt13ysHistogramVals[47],
            f168: pt13ysHistogramVals[48],
            f169: pt13ysHistogramVals[49],
            f170: pt13ysHistogramVals[50],
            f171: pt13ysHistogramVals[51],
            f172: pt13ysHistogramVals[52],
            f173: pt13ysHistogramVals[53],
            f174: pt13ysHistogramVals[54],
            f175: pt13ysHistogramVals[55],
            f176: pt13ysHistogramVals[56],
            f177: pt13ysHistogramVals[57],
            f178: pt13ysHistogramVals[58],
            f179: pt13ysHistogramVals[59],
            f180: pt13ysHistogramVals[60],
            f181: pt13ysHistogramVals[61],
            f182: pt13ysHistogramVals[62],
            f183: pt13ysHistogramVals[63],
            f184: pt13ysHistogramVals[64],
            f185: pt13ysHistogramVals[65],
            f186: pt13ysHistogramVals[66],
            f187: pt13ysHistogramVals[67],
            f188: pt13ysHistogramVals[68],
            f189: pt13ysHistogramVals[69],
            f190: pt13ysHistogramVals[70],
            f191: pt13ysHistogramVals[71],
            f192: pt13ysHistogramVals[72],
            f193: pt13ysHistogramVals[73],
            f194: pt13ysHistogramVals[74],
            f195: pt13ysHistogramVals[75],
            f196: pt13ysHistogramVals[76],
            f197: pt13ysHistogramVals[77],
            f198: pt13ysHistogramVals[78],
            f199: pt13ysHistogramVals[79],
            f200: pt13ysHistogramVals[80],
            f201: pt13ysHistogramVals[81],
            f202: pt13ysHistogramVals[82],
            f203: pt13ysHistogramVals[83],
            f204: pt13ysHistogramVals[84],
            f205: pt13ysHistogramVals[85],
            f206: pt13ysHistogramVals[86],
            f207: pt13ysHistogramVals[87],
            f208: pt13ysHistogramVals[88],
            f209: pt13ysHistogramVals[89],
            f210: pt13ysHistogramVals[90],
            f211: pt13ysHistogramVals[91],
            f212: pt13ysHistogramVals[92],
            f213: pt13ysHistogramVals[93],
            f214: pt13ysHistogramVals[94],
            f215: pt13ysHistogramVals[95],
            f216: pt13ysHistogramVals[96],
            f217: pt13ysHistogramVals[97],
            f218: pt13ysHistogramVals[98],
            f219: pt13ysHistogramVals[99],
            f220: pt13ysHistogramVals[100],
            f221: pt13ysHistogramVals[101],
            f222: pt13ysHistogramVals[102],
            f223: pt13ysHistogramVals[103],
            f224: pt13ysHistogramVals[104],
            f225: pt13ysHistogramVals[105],
            f226: pt13ysHistogramVals[106],
            f227: pt13ysHistogramVals[107],
            f228: pt13ysHistogramVals[108],
            f229: pt13ysHistogramVals[109],
            f230: pt13ysHistogramVals[110],
            f231: pt13ysHistogramVals[111],
            f232: pt13ysHistogramVals[112],
            f233: pt13ysHistogramVals[113],
            f234: pt13ysHistogramVals[114],
            f235: pt13ysHistogramVals[115],
            f236: pt13ysHistogramVals[116],
            f237: pt13ysHistogramVals[117],
            f238: pt13ysHistogramVals[118],
            f239: pt13ysHistogramVals[119],
            f240: leftLegAngleHistogramVals[0],
            f241: leftLegAngleHistogramVals[1],
            f242: leftLegAngleHistogramVals[2],
            f243: leftLegAngleHistogramVals[3],
            f244: leftLegAngleHistogramVals[4],
            f245: leftLegAngleHistogramVals[5],
            f246: leftLegAngleHistogramVals[6],
            f247: leftLegAngleHistogramVals[7],
            f248: leftLegAngleHistogramVals[8],
            f249: leftLegAngleHistogramVals[9],
            f250: leftLegAngleHistogramVals[10],
            f251: leftLegAngleHistogramVals[11],
            f252: leftLegAngleHistogramVals[12],
            f253: leftLegAngleHistogramVals[13],
            f254: leftLegAngleHistogramVals[14],
            f255: leftLegAngleHistogramVals[15],
            f256: leftLegAngleHistogramVals[16],
            f257: leftLegAngleHistogramVals[17],
            f258: leftLegAngleHistogramVals[18],
            f259: leftLegAngleHistogramVals[19],
            f260: leftLegAngleHistogramVals[20],
            f261: leftLegAngleHistogramVals[21],
            f262: leftLegAngleHistogramVals[22],
            f263: leftLegAngleHistogramVals[23],
            f264: leftLegAngleHistogramVals[24],
            f265: leftLegAngleHistogramVals[25],
            f266: leftLegAngleHistogramVals[26],
            f267: leftLegAngleHistogramVals[27],
            f268: leftLegAngleHistogramVals[28],
            f269: leftLegAngleHistogramVals[29],
            f270: leftLegAngleHistogramVals[30],
            f271: leftLegAngleHistogramVals[31],
            f272: leftLegAngleHistogramVals[32],
            f273: leftLegAngleHistogramVals[33],
            f274: leftLegAngleHistogramVals[34],
            f275: leftLegAngleHistogramVals[35],
            f276: leftLegAngleHistogramVals[36],
            f277: leftLegAngleHistogramVals[37],
            f278: leftLegAngleHistogramVals[38],
            f279: leftLegAngleHistogramVals[39],
            f280: leftLegAngleHistogramVals[40],
            f281: leftLegAngleHistogramVals[41],
            f282: leftLegAngleHistogramVals[42],
            f283: leftLegAngleHistogramVals[43],
            f284: leftLegAngleHistogramVals[44],
            f285: leftLegAngleHistogramVals[45],
            f286: leftLegAngleHistogramVals[46],
            f287: leftLegAngleHistogramVals[47],
            f288: leftLegAngleHistogramVals[48],
            f289: leftLegAngleHistogramVals[49],
            f290: leftLegAngleHistogramVals[50],
            f291: leftLegAngleHistogramVals[51],
            f292: leftLegAngleHistogramVals[52],
            f293: leftLegAngleHistogramVals[53],
            f294: leftLegAngleHistogramVals[54],
            f295: leftLegAngleHistogramVals[55],
            f296: leftLegAngleHistogramVals[56],
            f297: leftLegAngleHistogramVals[57],
            f298: leftLegAngleHistogramVals[58],
            f299: leftLegAngleHistogramVals[59],
            f300: leftLegAngleHistogramVals[60],
            f301: leftLegAngleHistogramVals[61],
            f302: leftLegAngleHistogramVals[62],
            f303: leftLegAngleHistogramVals[63],
            f304: leftLegAngleHistogramVals[64],
            f305: leftLegAngleHistogramVals[65],
            f306: leftLegAngleHistogramVals[66],
            f307: leftLegAngleHistogramVals[67],
            f308: leftLegAngleHistogramVals[68],
            f309: leftLegAngleHistogramVals[69],
            f310: leftLegAngleHistogramVals[70],
            f311: leftLegAngleHistogramVals[71],
            f312: leftLegAngleHistogramVals[72],
            f313: leftLegAngleHistogramVals[73],
            f314: leftLegAngleHistogramVals[74],
            f315: leftLegAngleHistogramVals[75],
            f316: leftLegAngleHistogramVals[76],
            f317: leftLegAngleHistogramVals[77],
            f318: leftLegAngleHistogramVals[78],
            f319: leftLegAngleHistogramVals[79],
            f320: leftLegAngleHistogramVals[80],
            f321: leftLegAngleHistogramVals[81],
            f322: leftLegAngleHistogramVals[82],
            f323: leftLegAngleHistogramVals[83],
            f324: leftLegAngleHistogramVals[84],
            f325: leftLegAngleHistogramVals[85],
            f326: leftLegAngleHistogramVals[86],
            f327: leftLegAngleHistogramVals[87],
            f328: leftLegAngleHistogramVals[88],
            f329: leftLegAngleHistogramVals[89],
            f330: leftLegAngleHistogramVals[90],
            f331: leftLegAngleHistogramVals[91],
            f332: leftLegAngleHistogramVals[92],
            f333: leftLegAngleHistogramVals[93],
            f334: leftLegAngleHistogramVals[94],
            f335: leftLegAngleHistogramVals[95],
            f336: leftLegAngleHistogramVals[96],
            f337: leftLegAngleHistogramVals[97],
            f338: leftLegAngleHistogramVals[98],
            f339: leftLegAngleHistogramVals[99],
            f340: leftLegAngleHistogramVals[100],
            f341: leftLegAngleHistogramVals[101],
            f342: leftLegAngleHistogramVals[102],
            f343: leftLegAngleHistogramVals[103],
            f344: leftLegAngleHistogramVals[104],
            f345: leftLegAngleHistogramVals[105],
            f346: leftLegAngleHistogramVals[106],
            f347: leftLegAngleHistogramVals[107],
            f348: leftLegAngleHistogramVals[108],
            f349: leftLegAngleHistogramVals[109],
            f350: leftLegAngleHistogramVals[110],
            f351: leftLegAngleHistogramVals[111],
            f352: leftLegAngleHistogramVals[112],
            f353: leftLegAngleHistogramVals[113],
            f354: leftLegAngleHistogramVals[114],
            f355: leftLegAngleHistogramVals[115],
            f356: leftLegAngleHistogramVals[116],
            f357: leftLegAngleHistogramVals[117],
            f358: leftLegAngleHistogramVals[118],
            f359: leftLegAngleHistogramVals[119],
            f360: rightLegAngleHistogramVals[0],
            f361: rightLegAngleHistogramVals[1],
            f362: rightLegAngleHistogramVals[2],
            f363: rightLegAngleHistogramVals[3],
            f364: rightLegAngleHistogramVals[4],
            f365: rightLegAngleHistogramVals[5],
            f366: rightLegAngleHistogramVals[6],
            f367: rightLegAngleHistogramVals[7],
            f368: rightLegAngleHistogramVals[8],
            f369: rightLegAngleHistogramVals[9],
            f370: rightLegAngleHistogramVals[10],
            f371: rightLegAngleHistogramVals[11],
            f372: rightLegAngleHistogramVals[12],
            f373: rightLegAngleHistogramVals[13],
            f374: rightLegAngleHistogramVals[14],
            f375: rightLegAngleHistogramVals[15],
            f376: rightLegAngleHistogramVals[16],
            f377: rightLegAngleHistogramVals[17],
            f378: rightLegAngleHistogramVals[18],
            f379: rightLegAngleHistogramVals[19],
            f380: rightLegAngleHistogramVals[20],
            f381: rightLegAngleHistogramVals[21],
            f382: rightLegAngleHistogramVals[22],
            f383: rightLegAngleHistogramVals[23],
            f384: rightLegAngleHistogramVals[24],
            f385: rightLegAngleHistogramVals[25],
            f386: rightLegAngleHistogramVals[26],
            f387: rightLegAngleHistogramVals[27],
            f388: rightLegAngleHistogramVals[28],
            f389: rightLegAngleHistogramVals[29],
            f390: rightLegAngleHistogramVals[30],
            f391: rightLegAngleHistogramVals[31],
            f392: rightLegAngleHistogramVals[32],
            f393: rightLegAngleHistogramVals[33],
            f394: rightLegAngleHistogramVals[34],
            f395: rightLegAngleHistogramVals[35],
            f396: rightLegAngleHistogramVals[36],
            f397: rightLegAngleHistogramVals[37],
            f398: rightLegAngleHistogramVals[38],
            f399: rightLegAngleHistogramVals[39],
            f400: rightLegAngleHistogramVals[40],
            f401: rightLegAngleHistogramVals[41],
            f402: rightLegAngleHistogramVals[42],
            f403: rightLegAngleHistogramVals[43],
            f404: rightLegAngleHistogramVals[44],
            f405: rightLegAngleHistogramVals[45],
            f406: rightLegAngleHistogramVals[46],
            f407: rightLegAngleHistogramVals[47],
            f408: rightLegAngleHistogramVals[48],
            f409: rightLegAngleHistogramVals[49],
            f410: rightLegAngleHistogramVals[50],
            f411: rightLegAngleHistogramVals[51],
            f412: rightLegAngleHistogramVals[52],
            f413: rightLegAngleHistogramVals[53],
            f414: rightLegAngleHistogramVals[54],
            f415: rightLegAngleHistogramVals[55],
            f416: rightLegAngleHistogramVals[56],
            f417: rightLegAngleHistogramVals[57],
            f418: rightLegAngleHistogramVals[58],
            f419: rightLegAngleHistogramVals[59],
            f420: rightLegAngleHistogramVals[60],
            f421: rightLegAngleHistogramVals[61],
            f422: rightLegAngleHistogramVals[62],
            f423: rightLegAngleHistogramVals[63],
            f424: rightLegAngleHistogramVals[64],
            f425: rightLegAngleHistogramVals[65],
            f426: rightLegAngleHistogramVals[66],
            f427: rightLegAngleHistogramVals[67],
            f428: rightLegAngleHistogramVals[68],
            f429: rightLegAngleHistogramVals[69],
            f430: rightLegAngleHistogramVals[70],
            f431: rightLegAngleHistogramVals[71],
            f432: rightLegAngleHistogramVals[72],
            f433: rightLegAngleHistogramVals[73],
            f434: rightLegAngleHistogramVals[74],
            f435: rightLegAngleHistogramVals[75],
            f436: rightLegAngleHistogramVals[76],
            f437: rightLegAngleHistogramVals[77],
            f438: rightLegAngleHistogramVals[78],
            f439: rightLegAngleHistogramVals[79],
            f440: rightLegAngleHistogramVals[80],
            f441: rightLegAngleHistogramVals[81],
            f442: rightLegAngleHistogramVals[82],
            f443: rightLegAngleHistogramVals[83],
            f444: rightLegAngleHistogramVals[84],
            f445: rightLegAngleHistogramVals[85],
            f446: rightLegAngleHistogramVals[86],
            f447: rightLegAngleHistogramVals[87],
            f448: rightLegAngleHistogramVals[88],
            f449: rightLegAngleHistogramVals[89],
            f450: rightLegAngleHistogramVals[90],
            f451: rightLegAngleHistogramVals[91],
            f452: rightLegAngleHistogramVals[92],
            f453: rightLegAngleHistogramVals[93],
            f454: rightLegAngleHistogramVals[94],
            f455: rightLegAngleHistogramVals[95],
            f456: rightLegAngleHistogramVals[96],
            f457: rightLegAngleHistogramVals[97],
            f458: rightLegAngleHistogramVals[98],
            f459: rightLegAngleHistogramVals[99],
            f460: rightLegAngleHistogramVals[100],
            f461: rightLegAngleHistogramVals[101],
            f462: rightLegAngleHistogramVals[102],
            f463: rightLegAngleHistogramVals[103],
            f464: rightLegAngleHistogramVals[104],
            f465: rightLegAngleHistogramVals[105],
            f466: rightLegAngleHistogramVals[106],
            f467: rightLegAngleHistogramVals[107],
            f468: rightLegAngleHistogramVals[108],
            f469: rightLegAngleHistogramVals[109],
            f470: rightLegAngleHistogramVals[110],
            f471: rightLegAngleHistogramVals[111],
            f472: rightLegAngleHistogramVals[112],
            f473: rightLegAngleHistogramVals[113],
            f474: rightLegAngleHistogramVals[114],
            f475: rightLegAngleHistogramVals[115],
            f476: rightLegAngleHistogramVals[116],
            f477: rightLegAngleHistogramVals[117],
            f478: rightLegAngleHistogramVals[118],
            f479: rightLegAngleHistogramVals[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = backLegScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    
    func getFSPrediction(_ model: feetSpacingXGBoost, _ feetDistanceHistogramVals: [Double]) -> Double  {
        
        /* Generates a feet spacing score based on probability
           histograms of feet distances. */
        
        guard let feetSpacingScore = try? model.prediction(input: feetSpacingXGBoostInput(
            f0: feetDistanceHistogramVals[0],
            f1: feetDistanceHistogramVals[1],
            f2: feetDistanceHistogramVals[2],
            f3: feetDistanceHistogramVals[3],
            f4: feetDistanceHistogramVals[4],
            f5: feetDistanceHistogramVals[5],
            f6: feetDistanceHistogramVals[6],
            f7: feetDistanceHistogramVals[7],
            f8: feetDistanceHistogramVals[8],
            f9: feetDistanceHistogramVals[9],
            f10: feetDistanceHistogramVals[10],
            f11: feetDistanceHistogramVals[11],
            f12: feetDistanceHistogramVals[12],
            f13: feetDistanceHistogramVals[13],
            f14: feetDistanceHistogramVals[14],
            f15: feetDistanceHistogramVals[15],
            f16: feetDistanceHistogramVals[16],
            f17: feetDistanceHistogramVals[17],
            f18: feetDistanceHistogramVals[18],
            f19: feetDistanceHistogramVals[19],
            f20: feetDistanceHistogramVals[20],
            f21: feetDistanceHistogramVals[21],
            f22: feetDistanceHistogramVals[22],
            f23: feetDistanceHistogramVals[23],
            f24: feetDistanceHistogramVals[24],
            f25: feetDistanceHistogramVals[25],
            f26: feetDistanceHistogramVals[26],
            f27: feetDistanceHistogramVals[27],
            f28: feetDistanceHistogramVals[28],
            f29: feetDistanceHistogramVals[29],
            f30: feetDistanceHistogramVals[30],
            f31: feetDistanceHistogramVals[31],
            f32: feetDistanceHistogramVals[32],
            f33: feetDistanceHistogramVals[33],
            f34: feetDistanceHistogramVals[34],
            f35: feetDistanceHistogramVals[35],
            f36: feetDistanceHistogramVals[36],
            f37: feetDistanceHistogramVals[37],
            f38: feetDistanceHistogramVals[38],
            f39: feetDistanceHistogramVals[39],
            f40: feetDistanceHistogramVals[40],
            f41: feetDistanceHistogramVals[41],
            f42: feetDistanceHistogramVals[42],
            f43: feetDistanceHistogramVals[43],
            f44: feetDistanceHistogramVals[44],
            f45: feetDistanceHistogramVals[45],
            f46: feetDistanceHistogramVals[46],
            f47: feetDistanceHistogramVals[47],
            f48: feetDistanceHistogramVals[48],
            f49: feetDistanceHistogramVals[49],
            f50: feetDistanceHistogramVals[50],
            f51: feetDistanceHistogramVals[51],
            f52: feetDistanceHistogramVals[52],
            f53: feetDistanceHistogramVals[53],
            f54: feetDistanceHistogramVals[54],
            f55: feetDistanceHistogramVals[55],
            f56: feetDistanceHistogramVals[56],
            f57: feetDistanceHistogramVals[57],
            f58: feetDistanceHistogramVals[58],
            f59: feetDistanceHistogramVals[59],
            f60: feetDistanceHistogramVals[60],
            f61: feetDistanceHistogramVals[61],
            f62: feetDistanceHistogramVals[62],
            f63: feetDistanceHistogramVals[63],
            f64: feetDistanceHistogramVals[64],
            f65: feetDistanceHistogramVals[65],
            f66: feetDistanceHistogramVals[66],
            f67: feetDistanceHistogramVals[67],
            f68: feetDistanceHistogramVals[68],
            f69: feetDistanceHistogramVals[69],
            f70: feetDistanceHistogramVals[70],
            f71: feetDistanceHistogramVals[71],
            f72: feetDistanceHistogramVals[72],
            f73: feetDistanceHistogramVals[73],
            f74: feetDistanceHistogramVals[74],
            f75: feetDistanceHistogramVals[75],
            f76: feetDistanceHistogramVals[76],
            f77: feetDistanceHistogramVals[77],
            f78: feetDistanceHistogramVals[78],
            f79: feetDistanceHistogramVals[79],
            f80: feetDistanceHistogramVals[80],
            f81: feetDistanceHistogramVals[81],
            f82: feetDistanceHistogramVals[82],
            f83: feetDistanceHistogramVals[83],
            f84: feetDistanceHistogramVals[84],
            f85: feetDistanceHistogramVals[85],
            f86: feetDistanceHistogramVals[86],
            f87: feetDistanceHistogramVals[87],
            f88: feetDistanceHistogramVals[88],
            f89: feetDistanceHistogramVals[89],
            f90: feetDistanceHistogramVals[90],
            f91: feetDistanceHistogramVals[91],
            f92: feetDistanceHistogramVals[92],
            f93: feetDistanceHistogramVals[93],
            f94: feetDistanceHistogramVals[94],
            f95: feetDistanceHistogramVals[95],
            f96: feetDistanceHistogramVals[96],
            f97: feetDistanceHistogramVals[97],
            f98: feetDistanceHistogramVals[98],
            f99: feetDistanceHistogramVals[99],
            f100: feetDistanceHistogramVals[100],
            f101: feetDistanceHistogramVals[101],
            f102: feetDistanceHistogramVals[102],
            f103: feetDistanceHistogramVals[103],
            f104: feetDistanceHistogramVals[104],
            f105: feetDistanceHistogramVals[105],
            f106: feetDistanceHistogramVals[106],
            f107: feetDistanceHistogramVals[107],
            f108: feetDistanceHistogramVals[108],
            f109: feetDistanceHistogramVals[109],
            f110: feetDistanceHistogramVals[110],
            f111: feetDistanceHistogramVals[111],
            f112: feetDistanceHistogramVals[112],
            f113: feetDistanceHistogramVals[113],
            f114: feetDistanceHistogramVals[114],
            f115: feetDistanceHistogramVals[115],
            f116: feetDistanceHistogramVals[116],
            f117: feetDistanceHistogramVals[117],
            f118: feetDistanceHistogramVals[118],
            f119: feetDistanceHistogramVals[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = feetSpacingScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    
    func getJHPrediction(_ model: jumpHeightXGBoost, _ pt10ysHistogramVals: [Double], _ pt13ysHistogramVals: [Double]) -> Double  {
        
        /* Generates a jump height score based on probability histograms
         of feet positions. */
        
        guard let jumpHeightScore = try? model.prediction(input: jumpHeightXGBoostInput(
            f0: (pt10ysHistogramVals[0] + pt13ysHistogramVals[0]),
            f1: (pt10ysHistogramVals[1] + pt13ysHistogramVals[1]),
            f2: (pt10ysHistogramVals[2] + pt13ysHistogramVals[2]),
            f3: (pt10ysHistogramVals[3] + pt13ysHistogramVals[3]),
            f4: (pt10ysHistogramVals[4] + pt13ysHistogramVals[4]),
            f5: (pt10ysHistogramVals[5] + pt13ysHistogramVals[5]),
            f6: (pt10ysHistogramVals[6] + pt13ysHistogramVals[6]),
            f7: (pt10ysHistogramVals[7] + pt13ysHistogramVals[7]),
            f8: (pt10ysHistogramVals[8] + pt13ysHistogramVals[8]),
            f9: (pt10ysHistogramVals[9] + pt13ysHistogramVals[9]),
            f10: (pt10ysHistogramVals[10] + pt13ysHistogramVals[10]),
            f11: (pt10ysHistogramVals[11] + pt13ysHistogramVals[11]),
            f12: (pt10ysHistogramVals[12] + pt13ysHistogramVals[12]),
            f13: (pt10ysHistogramVals[13] + pt13ysHistogramVals[13]),
            f14: (pt10ysHistogramVals[14] + pt13ysHistogramVals[14]),
            f15: (pt10ysHistogramVals[15] + pt13ysHistogramVals[15]),
            f16: (pt10ysHistogramVals[16] + pt13ysHistogramVals[16]),
            f17: (pt10ysHistogramVals[17] + pt13ysHistogramVals[17]),
            f18: (pt10ysHistogramVals[18] + pt13ysHistogramVals[18]),
            f19: (pt10ysHistogramVals[19] + pt13ysHistogramVals[19]),
            f20: (pt10ysHistogramVals[20] + pt13ysHistogramVals[20]),
            f21: (pt10ysHistogramVals[21] + pt13ysHistogramVals[21]),
            f22: (pt10ysHistogramVals[22] + pt13ysHistogramVals[22]),
            f23: (pt10ysHistogramVals[23] + pt13ysHistogramVals[23]),
            f24: (pt10ysHistogramVals[24] + pt13ysHistogramVals[24]),
            f25: (pt10ysHistogramVals[25] + pt13ysHistogramVals[25]),
            f26: (pt10ysHistogramVals[26] + pt13ysHistogramVals[26]),
            f27: (pt10ysHistogramVals[27] + pt13ysHistogramVals[27]),
            f28: (pt10ysHistogramVals[28] + pt13ysHistogramVals[28]),
            f29: (pt10ysHistogramVals[29] + pt13ysHistogramVals[29]),
            f30: (pt10ysHistogramVals[30] + pt13ysHistogramVals[30]),
            f31: (pt10ysHistogramVals[31] + pt13ysHistogramVals[31]),
            f32: (pt10ysHistogramVals[32] + pt13ysHistogramVals[32]),
            f33: (pt10ysHistogramVals[33] + pt13ysHistogramVals[33]),
            f34: (pt10ysHistogramVals[34] + pt13ysHistogramVals[34]),
            f35: (pt10ysHistogramVals[35] + pt13ysHistogramVals[35]),
            f36: (pt10ysHistogramVals[36] + pt13ysHistogramVals[36]),
            f37: (pt10ysHistogramVals[37] + pt13ysHistogramVals[37]),
            f38: (pt10ysHistogramVals[38] + pt13ysHistogramVals[38]),
            f39: (pt10ysHistogramVals[39] + pt13ysHistogramVals[39]),
            f40: (pt10ysHistogramVals[40] + pt13ysHistogramVals[40]),
            f41: (pt10ysHistogramVals[41] + pt13ysHistogramVals[41]),
            f42: (pt10ysHistogramVals[42] + pt13ysHistogramVals[42]),
            f43: (pt10ysHistogramVals[43] + pt13ysHistogramVals[43]),
            f44: (pt10ysHistogramVals[44] + pt13ysHistogramVals[44]),
            f45: (pt10ysHistogramVals[45] + pt13ysHistogramVals[45]),
            f46: (pt10ysHistogramVals[46] + pt13ysHistogramVals[46]),
            f47: (pt10ysHistogramVals[47] + pt13ysHistogramVals[47]),
            f48: (pt10ysHistogramVals[48] + pt13ysHistogramVals[48]),
            f49: (pt10ysHistogramVals[49] + pt13ysHistogramVals[49]),
            f50: (pt10ysHistogramVals[50] + pt13ysHistogramVals[50]),
            f51: (pt10ysHistogramVals[51] + pt13ysHistogramVals[51]),
            f52: (pt10ysHistogramVals[52] + pt13ysHistogramVals[52]),
            f53: (pt10ysHistogramVals[53] + pt13ysHistogramVals[53]),
            f54: (pt10ysHistogramVals[54] + pt13ysHistogramVals[54]),
            f55: (pt10ysHistogramVals[55] + pt13ysHistogramVals[55]),
            f56: (pt10ysHistogramVals[56] + pt13ysHistogramVals[56]),
            f57: (pt10ysHistogramVals[57] + pt13ysHistogramVals[57]),
            f58: (pt10ysHistogramVals[58] + pt13ysHistogramVals[58]),
            f59: (pt10ysHistogramVals[59] + pt13ysHistogramVals[59]),
            f60: (pt10ysHistogramVals[60] + pt13ysHistogramVals[60]),
            f61: (pt10ysHistogramVals[61] + pt13ysHistogramVals[61]),
            f62: (pt10ysHistogramVals[62] + pt13ysHistogramVals[62]),
            f63: (pt10ysHistogramVals[63] + pt13ysHistogramVals[63]),
            f64: (pt10ysHistogramVals[64] + pt13ysHistogramVals[64]),
            f65: (pt10ysHistogramVals[65] + pt13ysHistogramVals[65]),
            f66: (pt10ysHistogramVals[66] + pt13ysHistogramVals[66]),
            f67: (pt10ysHistogramVals[67] + pt13ysHistogramVals[67]),
            f68: (pt10ysHistogramVals[68] + pt13ysHistogramVals[68]),
            f69: (pt10ysHistogramVals[69] + pt13ysHistogramVals[69]),
            f70: (pt10ysHistogramVals[70] + pt13ysHistogramVals[70]),
            f71: (pt10ysHistogramVals[71] + pt13ysHistogramVals[71]),
            f72: (pt10ysHistogramVals[72] + pt13ysHistogramVals[72]),
            f73: (pt10ysHistogramVals[73] + pt13ysHistogramVals[73]),
            f74: (pt10ysHistogramVals[74] + pt13ysHistogramVals[74]),
            f75: (pt10ysHistogramVals[75] + pt13ysHistogramVals[75]),
            f76: (pt10ysHistogramVals[76] + pt13ysHistogramVals[76]),
            f77: (pt10ysHistogramVals[77] + pt13ysHistogramVals[77]),
            f78: (pt10ysHistogramVals[78] + pt13ysHistogramVals[78]),
            f79: (pt10ysHistogramVals[79] + pt13ysHistogramVals[79]),
            f80: (pt10ysHistogramVals[80] + pt13ysHistogramVals[80]),
            f81: (pt10ysHistogramVals[81] + pt13ysHistogramVals[81]),
            f82: (pt10ysHistogramVals[82] + pt13ysHistogramVals[82]),
            f83: (pt10ysHistogramVals[83] + pt13ysHistogramVals[83]),
            f84: (pt10ysHistogramVals[84] + pt13ysHistogramVals[84]),
            f85: (pt10ysHistogramVals[85] + pt13ysHistogramVals[85]),
            f86: (pt10ysHistogramVals[86] + pt13ysHistogramVals[86]),
            f87: (pt10ysHistogramVals[87] + pt13ysHistogramVals[87]),
            f88: (pt10ysHistogramVals[88] + pt13ysHistogramVals[88]),
            f89: (pt10ysHistogramVals[89] + pt13ysHistogramVals[89]),
            f90: (pt10ysHistogramVals[90] + pt13ysHistogramVals[90]),
            f91: (pt10ysHistogramVals[91] + pt13ysHistogramVals[91]),
            f92: (pt10ysHistogramVals[92] + pt13ysHistogramVals[92]),
            f93: (pt10ysHistogramVals[93] + pt13ysHistogramVals[93]),
            f94: (pt10ysHistogramVals[94] + pt13ysHistogramVals[94]),
            f95: (pt10ysHistogramVals[95] + pt13ysHistogramVals[95]),
            f96: (pt10ysHistogramVals[96] + pt13ysHistogramVals[96]),
            f97: (pt10ysHistogramVals[97] + pt13ysHistogramVals[97]),
            f98: (pt10ysHistogramVals[98] + pt13ysHistogramVals[98]),
            f99: (pt10ysHistogramVals[99] + pt13ysHistogramVals[99]),
            f100: (pt10ysHistogramVals[100] + pt13ysHistogramVals[100]),
            f101: (pt10ysHistogramVals[101] + pt13ysHistogramVals[101]),
            f102: (pt10ysHistogramVals[102] + pt13ysHistogramVals[102]),
            f103: (pt10ysHistogramVals[103] + pt13ysHistogramVals[103]),
            f104: (pt10ysHistogramVals[104] + pt13ysHistogramVals[104]),
            f105: (pt10ysHistogramVals[105] + pt13ysHistogramVals[105]),
            f106: (pt10ysHistogramVals[106] + pt13ysHistogramVals[106]),
            f107: (pt10ysHistogramVals[107] + pt13ysHistogramVals[107]),
            f108: (pt10ysHistogramVals[108] + pt13ysHistogramVals[108]),
            f109: (pt10ysHistogramVals[109] + pt13ysHistogramVals[109]),
            f110: (pt10ysHistogramVals[110] + pt13ysHistogramVals[110]),
            f111: (pt10ysHistogramVals[111] + pt13ysHistogramVals[111]),
            f112: (pt10ysHistogramVals[112] + pt13ysHistogramVals[112]),
            f113: (pt10ysHistogramVals[113] + pt13ysHistogramVals[113]),
            f114: (pt10ysHistogramVals[114] + pt13ysHistogramVals[114]),
            f115: (pt10ysHistogramVals[115] + pt13ysHistogramVals[115]),
            f116: (pt10ysHistogramVals[116] + pt13ysHistogramVals[116]),
            f117: (pt10ysHistogramVals[117] + pt13ysHistogramVals[117]),
            f118: (pt10ysHistogramVals[118] + pt13ysHistogramVals[118]),
            f119: (pt10ysHistogramVals[119] + pt13ysHistogramVals[119])
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = jumpHeightScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getLAPrediction(_ model: leftArmStraightXGBoost, _ leftArmAngleHistogramVals: [Double], _ rightArmAngleHistogramVals: [Double]) -> Double  {
        
        /* Generates a left/right-arm straight score based on probability
         histograms of left and right arm angles. */
        
        guard let leftArmScore = try? model.prediction(input: leftArmStraightXGBoostInput(
            f0: leftArmAngleHistogramVals[0],
            f1: leftArmAngleHistogramVals[1],
            f2: leftArmAngleHistogramVals[2],
            f3: leftArmAngleHistogramVals[3],
            f4: leftArmAngleHistogramVals[4],
            f5: leftArmAngleHistogramVals[5],
            f6: leftArmAngleHistogramVals[6],
            f7: leftArmAngleHistogramVals[7],
            f8: leftArmAngleHistogramVals[8],
            f9: leftArmAngleHistogramVals[9],
            f10: leftArmAngleHistogramVals[10],
            f11: leftArmAngleHistogramVals[11],
            f12: leftArmAngleHistogramVals[12],
            f13: leftArmAngleHistogramVals[13],
            f14: leftArmAngleHistogramVals[14],
            f15: leftArmAngleHistogramVals[15],
            f16: leftArmAngleHistogramVals[16],
            f17: leftArmAngleHistogramVals[17],
            f18: leftArmAngleHistogramVals[18],
            f19: leftArmAngleHistogramVals[19],
            f20: leftArmAngleHistogramVals[20],
            f21: leftArmAngleHistogramVals[21],
            f22: leftArmAngleHistogramVals[22],
            f23: leftArmAngleHistogramVals[23],
            f24: leftArmAngleHistogramVals[24],
            f25: leftArmAngleHistogramVals[25],
            f26: leftArmAngleHistogramVals[26],
            f27: leftArmAngleHistogramVals[27],
            f28: leftArmAngleHistogramVals[28],
            f29: leftArmAngleHistogramVals[29],
            f30: leftArmAngleHistogramVals[30],
            f31: leftArmAngleHistogramVals[31],
            f32: leftArmAngleHistogramVals[32],
            f33: leftArmAngleHistogramVals[33],
            f34: leftArmAngleHistogramVals[34],
            f35: leftArmAngleHistogramVals[35],
            f36: leftArmAngleHistogramVals[36],
            f37: leftArmAngleHistogramVals[37],
            f38: leftArmAngleHistogramVals[38],
            f39: leftArmAngleHistogramVals[39],
            f40: leftArmAngleHistogramVals[40],
            f41: leftArmAngleHistogramVals[41],
            f42: leftArmAngleHistogramVals[42],
            f43: leftArmAngleHistogramVals[43],
            f44: leftArmAngleHistogramVals[44],
            f45: leftArmAngleHistogramVals[45],
            f46: leftArmAngleHistogramVals[46],
            f47: leftArmAngleHistogramVals[47],
            f48: leftArmAngleHistogramVals[48],
            f49: leftArmAngleHistogramVals[49],
            f50: leftArmAngleHistogramVals[50],
            f51: leftArmAngleHistogramVals[51],
            f52: leftArmAngleHistogramVals[52],
            f53: leftArmAngleHistogramVals[53],
            f54: leftArmAngleHistogramVals[54],
            f55: leftArmAngleHistogramVals[55],
            f56: leftArmAngleHistogramVals[56],
            f57: leftArmAngleHistogramVals[57],
            f58: leftArmAngleHistogramVals[58],
            f59: leftArmAngleHistogramVals[59],
            f60: leftArmAngleHistogramVals[60],
            f61: leftArmAngleHistogramVals[61],
            f62: leftArmAngleHistogramVals[62],
            f63: leftArmAngleHistogramVals[63],
            f64: leftArmAngleHistogramVals[64],
            f65: leftArmAngleHistogramVals[65],
            f66: leftArmAngleHistogramVals[66],
            f67: leftArmAngleHistogramVals[67],
            f68: leftArmAngleHistogramVals[68],
            f69: leftArmAngleHistogramVals[69],
            f70: leftArmAngleHistogramVals[70],
            f71: leftArmAngleHistogramVals[71],
            f72: leftArmAngleHistogramVals[72],
            f73: leftArmAngleHistogramVals[73],
            f74: leftArmAngleHistogramVals[74],
            f75: leftArmAngleHistogramVals[75],
            f76: leftArmAngleHistogramVals[76],
            f77: leftArmAngleHistogramVals[77],
            f78: leftArmAngleHistogramVals[78],
            f79: leftArmAngleHistogramVals[79],
            f80: leftArmAngleHistogramVals[80],
            f81: leftArmAngleHistogramVals[81],
            f82: leftArmAngleHistogramVals[82],
            f83: leftArmAngleHistogramVals[83],
            f84: leftArmAngleHistogramVals[84],
            f85: leftArmAngleHistogramVals[85],
            f86: leftArmAngleHistogramVals[86],
            f87: leftArmAngleHistogramVals[87],
            f88: leftArmAngleHistogramVals[88],
            f89: leftArmAngleHistogramVals[89],
            f90: leftArmAngleHistogramVals[90],
            f91: leftArmAngleHistogramVals[91],
            f92: leftArmAngleHistogramVals[92],
            f93: leftArmAngleHistogramVals[93],
            f94: leftArmAngleHistogramVals[94],
            f95: leftArmAngleHistogramVals[95],
            f96: leftArmAngleHistogramVals[96],
            f97: leftArmAngleHistogramVals[97],
            f98: leftArmAngleHistogramVals[98],
            f99: leftArmAngleHistogramVals[99],
            f100: leftArmAngleHistogramVals[100],
            f101: leftArmAngleHistogramVals[101],
            f102: leftArmAngleHistogramVals[102],
            f103: leftArmAngleHistogramVals[103],
            f104: leftArmAngleHistogramVals[104],
            f105: leftArmAngleHistogramVals[105],
            f106: leftArmAngleHistogramVals[106],
            f107: leftArmAngleHistogramVals[107],
            f108: leftArmAngleHistogramVals[108],
            f109: leftArmAngleHistogramVals[109],
            f110: leftArmAngleHistogramVals[110],
            f111: leftArmAngleHistogramVals[111],
            f112: leftArmAngleHistogramVals[112],
            f113: leftArmAngleHistogramVals[113],
            f114: leftArmAngleHistogramVals[114],
            f115: leftArmAngleHistogramVals[115],
            f116: leftArmAngleHistogramVals[116],
            f117: leftArmAngleHistogramVals[117],
            f118: leftArmAngleHistogramVals[118],
            f119: leftArmAngleHistogramVals[119],
            f120: rightArmAngleHistogramVals[0],
            f121: rightArmAngleHistogramVals[1],
            f122: rightArmAngleHistogramVals[2],
            f123: rightArmAngleHistogramVals[3],
            f124: rightArmAngleHistogramVals[4],
            f125: rightArmAngleHistogramVals[5],
            f126: rightArmAngleHistogramVals[6],
            f127: rightArmAngleHistogramVals[7],
            f128: rightArmAngleHistogramVals[8],
            f129: rightArmAngleHistogramVals[9],
            f130: rightArmAngleHistogramVals[10],
            f131: rightArmAngleHistogramVals[11],
            f132: rightArmAngleHistogramVals[12],
            f133: rightArmAngleHistogramVals[13],
            f134: rightArmAngleHistogramVals[14],
            f135: rightArmAngleHistogramVals[15],
            f136: rightArmAngleHistogramVals[16],
            f137: rightArmAngleHistogramVals[17],
            f138: rightArmAngleHistogramVals[18],
            f139: rightArmAngleHistogramVals[19],
            f140: rightArmAngleHistogramVals[20],
            f141: rightArmAngleHistogramVals[21],
            f142: rightArmAngleHistogramVals[22],
            f143: rightArmAngleHistogramVals[23],
            f144: rightArmAngleHistogramVals[24],
            f145: rightArmAngleHistogramVals[25],
            f146: rightArmAngleHistogramVals[26],
            f147: rightArmAngleHistogramVals[27],
            f148: rightArmAngleHistogramVals[28],
            f149: rightArmAngleHistogramVals[29],
            f150: rightArmAngleHistogramVals[30],
            f151: rightArmAngleHistogramVals[31],
            f152: rightArmAngleHistogramVals[32],
            f153: rightArmAngleHistogramVals[33],
            f154: rightArmAngleHistogramVals[34],
            f155: rightArmAngleHistogramVals[35],
            f156: rightArmAngleHistogramVals[36],
            f157: rightArmAngleHistogramVals[37],
            f158: rightArmAngleHistogramVals[38],
            f159: rightArmAngleHistogramVals[39],
            f160: rightArmAngleHistogramVals[40],
            f161: rightArmAngleHistogramVals[41],
            f162: rightArmAngleHistogramVals[42],
            f163: rightArmAngleHistogramVals[43],
            f164: rightArmAngleHistogramVals[44],
            f165: rightArmAngleHistogramVals[45],
            f166: rightArmAngleHistogramVals[46],
            f167: rightArmAngleHistogramVals[47],
            f168: rightArmAngleHistogramVals[48],
            f169: rightArmAngleHistogramVals[49],
            f170: rightArmAngleHistogramVals[50],
            f171: rightArmAngleHistogramVals[51],
            f172: rightArmAngleHistogramVals[52],
            f173: rightArmAngleHistogramVals[53],
            f174: rightArmAngleHistogramVals[54],
            f175: rightArmAngleHistogramVals[55],
            f176: rightArmAngleHistogramVals[56],
            f177: rightArmAngleHistogramVals[57],
            f178: rightArmAngleHistogramVals[58],
            f179: rightArmAngleHistogramVals[59],
            f180: rightArmAngleHistogramVals[60],
            f181: rightArmAngleHistogramVals[61],
            f182: rightArmAngleHistogramVals[62],
            f183: rightArmAngleHistogramVals[63],
            f184: rightArmAngleHistogramVals[64],
            f185: rightArmAngleHistogramVals[65],
            f186: rightArmAngleHistogramVals[66],
            f187: rightArmAngleHistogramVals[67],
            f188: rightArmAngleHistogramVals[68],
            f189: rightArmAngleHistogramVals[69],
            f190: rightArmAngleHistogramVals[70],
            f191: rightArmAngleHistogramVals[71],
            f192: rightArmAngleHistogramVals[72],
            f193: rightArmAngleHistogramVals[73],
            f194: rightArmAngleHistogramVals[74],
            f195: rightArmAngleHistogramVals[75],
            f196: rightArmAngleHistogramVals[76],
            f197: rightArmAngleHistogramVals[77],
            f198: rightArmAngleHistogramVals[78],
            f199: rightArmAngleHistogramVals[79],
            f200: rightArmAngleHistogramVals[80],
            f201: rightArmAngleHistogramVals[81],
            f202: rightArmAngleHistogramVals[82],
            f203: rightArmAngleHistogramVals[83],
            f204: rightArmAngleHistogramVals[84],
            f205: rightArmAngleHistogramVals[85],
            f206: rightArmAngleHistogramVals[86],
            f207: rightArmAngleHistogramVals[87],
            f208: rightArmAngleHistogramVals[88],
            f209: rightArmAngleHistogramVals[89],
            f210: rightArmAngleHistogramVals[90],
            f211: rightArmAngleHistogramVals[91],
            f212: rightArmAngleHistogramVals[92],
            f213: rightArmAngleHistogramVals[93],
            f214: rightArmAngleHistogramVals[94],
            f215: rightArmAngleHistogramVals[95],
            f216: rightArmAngleHistogramVals[96],
            f217: rightArmAngleHistogramVals[97],
            f218: rightArmAngleHistogramVals[98],
            f219: rightArmAngleHistogramVals[99],
            f220: rightArmAngleHistogramVals[100],
            f221: rightArmAngleHistogramVals[101],
            f222: rightArmAngleHistogramVals[102],
            f223: rightArmAngleHistogramVals[103],
            f224: rightArmAngleHistogramVals[104],
            f225: rightArmAngleHistogramVals[105],
            f226: rightArmAngleHistogramVals[106],
            f227: rightArmAngleHistogramVals[107],
            f228: rightArmAngleHistogramVals[108],
            f229: rightArmAngleHistogramVals[109],
            f230: rightArmAngleHistogramVals[110],
            f231: rightArmAngleHistogramVals[111],
            f232: rightArmAngleHistogramVals[112],
            f233: rightArmAngleHistogramVals[113],
            f234: rightArmAngleHistogramVals[114],
            f235: rightArmAngleHistogramVals[115],
            f236: rightArmAngleHistogramVals[116],
            f237: rightArmAngleHistogramVals[117],
            f238: rightArmAngleHistogramVals[118],
            f239: rightArmAngleHistogramVals[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = leftArmScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getLBPrediction(_ model: legsBentXGBoost, _ leftLegAngleHistogramVals: [Double], _ rightLegAngleHistogramVals: [Double]) -> Double  {
        
        /* Generates a leg bending score based on probability histograms
          of left and right leg angles. */
        
        guard let legsBendScore = try? model.prediction(input: legsBentXGBoostInput(
            f0: leftLegAngleHistogramVals[0],
            f1: leftLegAngleHistogramVals[1],
            f2: leftLegAngleHistogramVals[2],
            f3: leftLegAngleHistogramVals[3],
            f4: leftLegAngleHistogramVals[4],
            f5: leftLegAngleHistogramVals[5],
            f6: leftLegAngleHistogramVals[6],
            f7: leftLegAngleHistogramVals[7],
            f8: leftLegAngleHistogramVals[8],
            f9: leftLegAngleHistogramVals[9],
            f10: leftLegAngleHistogramVals[10],
            f11: leftLegAngleHistogramVals[11],
            f12: leftLegAngleHistogramVals[12],
            f13: leftLegAngleHistogramVals[13],
            f14: leftLegAngleHistogramVals[14],
            f15: leftLegAngleHistogramVals[15],
            f16: leftLegAngleHistogramVals[16],
            f17: leftLegAngleHistogramVals[17],
            f18: leftLegAngleHistogramVals[18],
            f19: leftLegAngleHistogramVals[19],
            f20: leftLegAngleHistogramVals[20],
            f21: leftLegAngleHistogramVals[21],
            f22: leftLegAngleHistogramVals[22],
            f23: leftLegAngleHistogramVals[23],
            f24: leftLegAngleHistogramVals[24],
            f25: leftLegAngleHistogramVals[25],
            f26: leftLegAngleHistogramVals[26],
            f27: leftLegAngleHistogramVals[27],
            f28: leftLegAngleHistogramVals[28],
            f29: leftLegAngleHistogramVals[29],
            f30: leftLegAngleHistogramVals[30],
            f31: leftLegAngleHistogramVals[31],
            f32: leftLegAngleHistogramVals[32],
            f33: leftLegAngleHistogramVals[33],
            f34: leftLegAngleHistogramVals[34],
            f35: leftLegAngleHistogramVals[35],
            f36: leftLegAngleHistogramVals[36],
            f37: leftLegAngleHistogramVals[37],
            f38: leftLegAngleHistogramVals[38],
            f39: leftLegAngleHistogramVals[39],
            f40: leftLegAngleHistogramVals[40],
            f41: leftLegAngleHistogramVals[41],
            f42: leftLegAngleHistogramVals[42],
            f43: leftLegAngleHistogramVals[43],
            f44: leftLegAngleHistogramVals[44],
            f45: leftLegAngleHistogramVals[45],
            f46: leftLegAngleHistogramVals[46],
            f47: leftLegAngleHistogramVals[47],
            f48: leftLegAngleHistogramVals[48],
            f49: leftLegAngleHistogramVals[49],
            f50: leftLegAngleHistogramVals[50],
            f51: leftLegAngleHistogramVals[51],
            f52: leftLegAngleHistogramVals[52],
            f53: leftLegAngleHistogramVals[53],
            f54: leftLegAngleHistogramVals[54],
            f55: leftLegAngleHistogramVals[55],
            f56: leftLegAngleHistogramVals[56],
            f57: leftLegAngleHistogramVals[57],
            f58: leftLegAngleHistogramVals[58],
            f59: leftLegAngleHistogramVals[59],
            f60: leftLegAngleHistogramVals[60],
            f61: leftLegAngleHistogramVals[61],
            f62: leftLegAngleHistogramVals[62],
            f63: leftLegAngleHistogramVals[63],
            f64: leftLegAngleHistogramVals[64],
            f65: leftLegAngleHistogramVals[65],
            f66: leftLegAngleHistogramVals[66],
            f67: leftLegAngleHistogramVals[67],
            f68: leftLegAngleHistogramVals[68],
            f69: leftLegAngleHistogramVals[69],
            f70: leftLegAngleHistogramVals[70],
            f71: leftLegAngleHistogramVals[71],
            f72: leftLegAngleHistogramVals[72],
            f73: leftLegAngleHistogramVals[73],
            f74: leftLegAngleHistogramVals[74],
            f75: leftLegAngleHistogramVals[75],
            f76: leftLegAngleHistogramVals[76],
            f77: leftLegAngleHistogramVals[77],
            f78: leftLegAngleHistogramVals[78],
            f79: leftLegAngleHistogramVals[79],
            f80: leftLegAngleHistogramVals[80],
            f81: leftLegAngleHistogramVals[81],
            f82: leftLegAngleHistogramVals[82],
            f83: leftLegAngleHistogramVals[83],
            f84: leftLegAngleHistogramVals[84],
            f85: leftLegAngleHistogramVals[85],
            f86: leftLegAngleHistogramVals[86],
            f87: leftLegAngleHistogramVals[87],
            f88: leftLegAngleHistogramVals[88],
            f89: leftLegAngleHistogramVals[89],
            f90: leftLegAngleHistogramVals[90],
            f91: leftLegAngleHistogramVals[91],
            f92: leftLegAngleHistogramVals[92],
            f93: leftLegAngleHistogramVals[93],
            f94: leftLegAngleHistogramVals[94],
            f95: leftLegAngleHistogramVals[95],
            f96: leftLegAngleHistogramVals[96],
            f97: leftLegAngleHistogramVals[97],
            f98: leftLegAngleHistogramVals[98],
            f99: leftLegAngleHistogramVals[99],
            f100: leftLegAngleHistogramVals[100],
            f101: leftLegAngleHistogramVals[101],
            f102: leftLegAngleHistogramVals[102],
            f103: leftLegAngleHistogramVals[103],
            f104: leftLegAngleHistogramVals[104],
            f105: leftLegAngleHistogramVals[105],
            f106: leftLegAngleHistogramVals[106],
            f107: leftLegAngleHistogramVals[107],
            f108: leftLegAngleHistogramVals[108],
            f109: leftLegAngleHistogramVals[109],
            f110: leftLegAngleHistogramVals[110],
            f111: leftLegAngleHistogramVals[111],
            f112: leftLegAngleHistogramVals[112],
            f113: leftLegAngleHistogramVals[113],
            f114: leftLegAngleHistogramVals[114],
            f115: leftLegAngleHistogramVals[115],
            f116: leftLegAngleHistogramVals[116],
            f117: leftLegAngleHistogramVals[117],
            f118: leftLegAngleHistogramVals[118],
            f119: leftLegAngleHistogramVals[119],
            f120: rightLegAngleHistogramVals[0],
            f121: rightLegAngleHistogramVals[1],
            f122: rightLegAngleHistogramVals[2],
            f123: rightLegAngleHistogramVals[3],
            f124: rightLegAngleHistogramVals[4],
            f125: rightLegAngleHistogramVals[5],
            f126: rightLegAngleHistogramVals[6],
            f127: rightLegAngleHistogramVals[7],
            f128: rightLegAngleHistogramVals[8],
            f129: rightLegAngleHistogramVals[9],
            f130: rightLegAngleHistogramVals[10],
            f131: rightLegAngleHistogramVals[11],
            f132: rightLegAngleHistogramVals[12],
            f133: rightLegAngleHistogramVals[13],
            f134: rightLegAngleHistogramVals[14],
            f135: rightLegAngleHistogramVals[15],
            f136: rightLegAngleHistogramVals[16],
            f137: rightLegAngleHistogramVals[17],
            f138: rightLegAngleHistogramVals[18],
            f139: rightLegAngleHistogramVals[19],
            f140: rightLegAngleHistogramVals[20],
            f141: rightLegAngleHistogramVals[21],
            f142: rightLegAngleHistogramVals[22],
            f143: rightLegAngleHistogramVals[23],
            f144: rightLegAngleHistogramVals[24],
            f145: rightLegAngleHistogramVals[25],
            f146: rightLegAngleHistogramVals[26],
            f147: rightLegAngleHistogramVals[27],
            f148: rightLegAngleHistogramVals[28],
            f149: rightLegAngleHistogramVals[29],
            f150: rightLegAngleHistogramVals[30],
            f151: rightLegAngleHistogramVals[31],
            f152: rightLegAngleHistogramVals[32],
            f153: rightLegAngleHistogramVals[33],
            f154: rightLegAngleHistogramVals[34],
            f155: rightLegAngleHistogramVals[35],
            f156: rightLegAngleHistogramVals[36],
            f157: rightLegAngleHistogramVals[37],
            f158: rightLegAngleHistogramVals[38],
            f159: rightLegAngleHistogramVals[39],
            f160: rightLegAngleHistogramVals[40],
            f161: rightLegAngleHistogramVals[41],
            f162: rightLegAngleHistogramVals[42],
            f163: rightLegAngleHistogramVals[43],
            f164: rightLegAngleHistogramVals[44],
            f165: rightLegAngleHistogramVals[45],
            f166: rightLegAngleHistogramVals[46],
            f167: rightLegAngleHistogramVals[47],
            f168: rightLegAngleHistogramVals[48],
            f169: rightLegAngleHistogramVals[49],
            f170: rightLegAngleHistogramVals[50],
            f171: rightLegAngleHistogramVals[51],
            f172: rightLegAngleHistogramVals[52],
            f173: rightLegAngleHistogramVals[53],
            f174: rightLegAngleHistogramVals[54],
            f175: rightLegAngleHistogramVals[55],
            f176: rightLegAngleHistogramVals[56],
            f177: rightLegAngleHistogramVals[57],
            f178: rightLegAngleHistogramVals[58],
            f179: rightLegAngleHistogramVals[59],
            f180: rightLegAngleHistogramVals[60],
            f181: rightLegAngleHistogramVals[61],
            f182: rightLegAngleHistogramVals[62],
            f183: rightLegAngleHistogramVals[63],
            f184: rightLegAngleHistogramVals[64],
            f185: rightLegAngleHistogramVals[65],
            f186: rightLegAngleHistogramVals[66],
            f187: rightLegAngleHistogramVals[67],
            f188: rightLegAngleHistogramVals[68],
            f189: rightLegAngleHistogramVals[69],
            f190: rightLegAngleHistogramVals[70],
            f191: rightLegAngleHistogramVals[71],
            f192: rightLegAngleHistogramVals[72],
            f193: rightLegAngleHistogramVals[73],
            f194: rightLegAngleHistogramVals[74],
            f195: rightLegAngleHistogramVals[75],
            f196: rightLegAngleHistogramVals[76],
            f197: rightLegAngleHistogramVals[77],
            f198: rightLegAngleHistogramVals[78],
            f199: rightLegAngleHistogramVals[79],
            f200: rightLegAngleHistogramVals[80],
            f201: rightLegAngleHistogramVals[81],
            f202: rightLegAngleHistogramVals[82],
            f203: rightLegAngleHistogramVals[83],
            f204: rightLegAngleHistogramVals[84],
            f205: rightLegAngleHistogramVals[85],
            f206: rightLegAngleHistogramVals[86],
            f207: rightLegAngleHistogramVals[87],
            f208: rightLegAngleHistogramVals[88],
            f209: rightLegAngleHistogramVals[89],
            f210: rightLegAngleHistogramVals[90],
            f211: rightLegAngleHistogramVals[91],
            f212: rightLegAngleHistogramVals[92],
            f213: rightLegAngleHistogramVals[93],
            f214: rightLegAngleHistogramVals[94],
            f215: rightLegAngleHistogramVals[95],
            f216: rightLegAngleHistogramVals[96],
            f217: rightLegAngleHistogramVals[97],
            f218: rightLegAngleHistogramVals[98],
            f219: rightLegAngleHistogramVals[99],
            f220: rightLegAngleHistogramVals[100],
            f221: rightLegAngleHistogramVals[101],
            f222: rightLegAngleHistogramVals[102],
            f223: rightLegAngleHistogramVals[103],
            f224: rightLegAngleHistogramVals[104],
            f225: rightLegAngleHistogramVals[105],
            f226: rightLegAngleHistogramVals[106],
            f227: rightLegAngleHistogramVals[107],
            f228: rightLegAngleHistogramVals[108],
            f229: rightLegAngleHistogramVals[109],
            f230: rightLegAngleHistogramVals[110],
            f231: rightLegAngleHistogramVals[111],
            f232: rightLegAngleHistogramVals[112],
            f233: rightLegAngleHistogramVals[113],
            f234: rightLegAngleHistogramVals[114],
            f235: rightLegAngleHistogramVals[115],
            f236: rightLegAngleHistogramVals[116],
            f237: rightLegAngleHistogramVals[117],
            f238: rightLegAngleHistogramVals[118],
            f239: rightLegAngleHistogramVals[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = legsBendScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getSTPrediction(_ model: shoulderTimingXGBoost, _ shoulderDistanceHistogramVals: [Double], _ leftLegAngleHistogramVals: [Double], _ rightLegAngleHistogramVals: [Double]) -> Double  {
        
        /* Generates a shoulder rotation timing score based on probability
         histograms of lshoulder distances and left and right leg angles. */
        
        guard let shoulderTimingScore = try? model.prediction(input: shoulderTimingXGBoostInput(
            f0: leftLegAngleHistogramVals[0],
            f1: leftLegAngleHistogramVals[1],
            f2: leftLegAngleHistogramVals[2],
            f3: leftLegAngleHistogramVals[3],
            f4: leftLegAngleHistogramVals[4],
            f5: leftLegAngleHistogramVals[5],
            f6: leftLegAngleHistogramVals[6],
            f7: leftLegAngleHistogramVals[7],
            f8: leftLegAngleHistogramVals[8],
            f9: leftLegAngleHistogramVals[9],
            f10: leftLegAngleHistogramVals[10],
            f11: leftLegAngleHistogramVals[11],
            f12: leftLegAngleHistogramVals[12],
            f13: leftLegAngleHistogramVals[13],
            f14: leftLegAngleHistogramVals[14],
            f15: leftLegAngleHistogramVals[15],
            f16: leftLegAngleHistogramVals[16],
            f17: leftLegAngleHistogramVals[17],
            f18: leftLegAngleHistogramVals[18],
            f19: leftLegAngleHistogramVals[19],
            f20: leftLegAngleHistogramVals[20],
            f21: leftLegAngleHistogramVals[21],
            f22: leftLegAngleHistogramVals[22],
            f23: leftLegAngleHistogramVals[23],
            f24: leftLegAngleHistogramVals[24],
            f25: leftLegAngleHistogramVals[25],
            f26: leftLegAngleHistogramVals[26],
            f27: leftLegAngleHistogramVals[27],
            f28: leftLegAngleHistogramVals[28],
            f29: leftLegAngleHistogramVals[29],
            f30: leftLegAngleHistogramVals[30],
            f31: leftLegAngleHistogramVals[31],
            f32: leftLegAngleHistogramVals[32],
            f33: leftLegAngleHistogramVals[33],
            f34: leftLegAngleHistogramVals[34],
            f35: leftLegAngleHistogramVals[35],
            f36: leftLegAngleHistogramVals[36],
            f37: leftLegAngleHistogramVals[37],
            f38: leftLegAngleHistogramVals[38],
            f39: leftLegAngleHistogramVals[39],
            f40: leftLegAngleHistogramVals[40],
            f41: leftLegAngleHistogramVals[41],
            f42: leftLegAngleHistogramVals[42],
            f43: leftLegAngleHistogramVals[43],
            f44: leftLegAngleHistogramVals[44],
            f45: leftLegAngleHistogramVals[45],
            f46: leftLegAngleHistogramVals[46],
            f47: leftLegAngleHistogramVals[47],
            f48: leftLegAngleHistogramVals[48],
            f49: leftLegAngleHistogramVals[49],
            f50: leftLegAngleHistogramVals[50],
            f51: leftLegAngleHistogramVals[51],
            f52: leftLegAngleHistogramVals[52],
            f53: leftLegAngleHistogramVals[53],
            f54: leftLegAngleHistogramVals[54],
            f55: leftLegAngleHistogramVals[55],
            f56: leftLegAngleHistogramVals[56],
            f57: leftLegAngleHistogramVals[57],
            f58: leftLegAngleHistogramVals[58],
            f59: leftLegAngleHistogramVals[59],
            f60: leftLegAngleHistogramVals[60],
            f61: leftLegAngleHistogramVals[61],
            f62: leftLegAngleHistogramVals[62],
            f63: leftLegAngleHistogramVals[63],
            f64: leftLegAngleHistogramVals[64],
            f65: leftLegAngleHistogramVals[65],
            f66: leftLegAngleHistogramVals[66],
            f67: leftLegAngleHistogramVals[67],
            f68: leftLegAngleHistogramVals[68],
            f69: leftLegAngleHistogramVals[69],
            f70: leftLegAngleHistogramVals[70],
            f71: leftLegAngleHistogramVals[71],
            f72: leftLegAngleHistogramVals[72],
            f73: leftLegAngleHistogramVals[73],
            f74: leftLegAngleHistogramVals[74],
            f75: leftLegAngleHistogramVals[75],
            f76: leftLegAngleHistogramVals[76],
            f77: leftLegAngleHistogramVals[77],
            f78: leftLegAngleHistogramVals[78],
            f79: leftLegAngleHistogramVals[79],
            f80: leftLegAngleHistogramVals[80],
            f81: leftLegAngleHistogramVals[81],
            f82: leftLegAngleHistogramVals[82],
            f83: leftLegAngleHistogramVals[83],
            f84: leftLegAngleHistogramVals[84],
            f85: leftLegAngleHistogramVals[85],
            f86: leftLegAngleHistogramVals[86],
            f87: leftLegAngleHistogramVals[87],
            f88: leftLegAngleHistogramVals[88],
            f89: leftLegAngleHistogramVals[89],
            f90: leftLegAngleHistogramVals[90],
            f91: leftLegAngleHistogramVals[91],
            f92: leftLegAngleHistogramVals[92],
            f93: leftLegAngleHistogramVals[93],
            f94: leftLegAngleHistogramVals[94],
            f95: leftLegAngleHistogramVals[95],
            f96: leftLegAngleHistogramVals[96],
            f97: leftLegAngleHistogramVals[97],
            f98: leftLegAngleHistogramVals[98],
            f99: leftLegAngleHistogramVals[99],
            f100: leftLegAngleHistogramVals[100],
            f101: leftLegAngleHistogramVals[101],
            f102: leftLegAngleHistogramVals[102],
            f103: leftLegAngleHistogramVals[103],
            f104: leftLegAngleHistogramVals[104],
            f105: leftLegAngleHistogramVals[105],
            f106: leftLegAngleHistogramVals[106],
            f107: leftLegAngleHistogramVals[107],
            f108: leftLegAngleHistogramVals[108],
            f109: leftLegAngleHistogramVals[109],
            f110: leftLegAngleHistogramVals[110],
            f111: leftLegAngleHistogramVals[111],
            f112: leftLegAngleHistogramVals[112],
            f113: leftLegAngleHistogramVals[113],
            f114: leftLegAngleHistogramVals[114],
            f115: leftLegAngleHistogramVals[115],
            f116: leftLegAngleHistogramVals[116],
            f117: leftLegAngleHistogramVals[117],
            f118: leftLegAngleHistogramVals[118],
            f119: leftLegAngleHistogramVals[119],
            f120: rightLegAngleHistogramVals[0],
            f121: rightLegAngleHistogramVals[1],
            f122: rightLegAngleHistogramVals[2],
            f123: rightLegAngleHistogramVals[3],
            f124: rightLegAngleHistogramVals[4],
            f125: rightLegAngleHistogramVals[5],
            f126: rightLegAngleHistogramVals[6],
            f127: rightLegAngleHistogramVals[7],
            f128: rightLegAngleHistogramVals[8],
            f129: rightLegAngleHistogramVals[9],
            f130: rightLegAngleHistogramVals[10],
            f131: rightLegAngleHistogramVals[11],
            f132: rightLegAngleHistogramVals[12],
            f133: rightLegAngleHistogramVals[13],
            f134: rightLegAngleHistogramVals[14],
            f135: rightLegAngleHistogramVals[15],
            f136: rightLegAngleHistogramVals[16],
            f137: rightLegAngleHistogramVals[17],
            f138: rightLegAngleHistogramVals[18],
            f139: rightLegAngleHistogramVals[19],
            f140: rightLegAngleHistogramVals[20],
            f141: rightLegAngleHistogramVals[21],
            f142: rightLegAngleHistogramVals[22],
            f143: rightLegAngleHistogramVals[23],
            f144: rightLegAngleHistogramVals[24],
            f145: rightLegAngleHistogramVals[25],
            f146: rightLegAngleHistogramVals[26],
            f147: rightLegAngleHistogramVals[27],
            f148: rightLegAngleHistogramVals[28],
            f149: rightLegAngleHistogramVals[29],
            f150: rightLegAngleHistogramVals[30],
            f151: rightLegAngleHistogramVals[31],
            f152: rightLegAngleHistogramVals[32],
            f153: rightLegAngleHistogramVals[33],
            f154: rightLegAngleHistogramVals[34],
            f155: rightLegAngleHistogramVals[35],
            f156: rightLegAngleHistogramVals[36],
            f157: rightLegAngleHistogramVals[37],
            f158: rightLegAngleHistogramVals[38],
            f159: rightLegAngleHistogramVals[39],
            f160: rightLegAngleHistogramVals[40],
            f161: rightLegAngleHistogramVals[41],
            f162: rightLegAngleHistogramVals[42],
            f163: rightLegAngleHistogramVals[43],
            f164: rightLegAngleHistogramVals[44],
            f165: rightLegAngleHistogramVals[45],
            f166: rightLegAngleHistogramVals[46],
            f167: rightLegAngleHistogramVals[47],
            f168: rightLegAngleHistogramVals[48],
            f169: rightLegAngleHistogramVals[49],
            f170: rightLegAngleHistogramVals[50],
            f171: rightLegAngleHistogramVals[51],
            f172: rightLegAngleHistogramVals[52],
            f173: rightLegAngleHistogramVals[53],
            f174: rightLegAngleHistogramVals[54],
            f175: rightLegAngleHistogramVals[55],
            f176: rightLegAngleHistogramVals[56],
            f177: rightLegAngleHistogramVals[57],
            f178: rightLegAngleHistogramVals[58],
            f179: rightLegAngleHistogramVals[59],
            f180: rightLegAngleHistogramVals[60],
            f181: rightLegAngleHistogramVals[61],
            f182: rightLegAngleHistogramVals[62],
            f183: rightLegAngleHistogramVals[63],
            f184: rightLegAngleHistogramVals[64],
            f185: rightLegAngleHistogramVals[65],
            f186: rightLegAngleHistogramVals[66],
            f187: rightLegAngleHistogramVals[67],
            f188: rightLegAngleHistogramVals[68],
            f189: rightLegAngleHistogramVals[69],
            f190: rightLegAngleHistogramVals[70],
            f191: rightLegAngleHistogramVals[71],
            f192: rightLegAngleHistogramVals[72],
            f193: rightLegAngleHistogramVals[73],
            f194: rightLegAngleHistogramVals[74],
            f195: rightLegAngleHistogramVals[75],
            f196: rightLegAngleHistogramVals[76],
            f197: rightLegAngleHistogramVals[77],
            f198: rightLegAngleHistogramVals[78],
            f199: rightLegAngleHistogramVals[79],
            f200: rightLegAngleHistogramVals[80],
            f201: rightLegAngleHistogramVals[81],
            f202: rightLegAngleHistogramVals[82],
            f203: rightLegAngleHistogramVals[83],
            f204: rightLegAngleHistogramVals[84],
            f205: rightLegAngleHistogramVals[85],
            f206: rightLegAngleHistogramVals[86],
            f207: rightLegAngleHistogramVals[87],
            f208: rightLegAngleHistogramVals[88],
            f209: rightLegAngleHistogramVals[89],
            f210: rightLegAngleHistogramVals[90],
            f211: rightLegAngleHistogramVals[91],
            f212: rightLegAngleHistogramVals[92],
            f213: rightLegAngleHistogramVals[93],
            f214: rightLegAngleHistogramVals[94],
            f215: rightLegAngleHistogramVals[95],
            f216: rightLegAngleHistogramVals[96],
            f217: rightLegAngleHistogramVals[97],
            f218: rightLegAngleHistogramVals[98],
            f219: rightLegAngleHistogramVals[99],
            f220: rightLegAngleHistogramVals[100],
            f221: rightLegAngleHistogramVals[101],
            f222: rightLegAngleHistogramVals[102],
            f223: rightLegAngleHistogramVals[103],
            f224: rightLegAngleHistogramVals[104],
            f225: rightLegAngleHistogramVals[105],
            f226: rightLegAngleHistogramVals[106],
            f227: rightLegAngleHistogramVals[107],
            f228: rightLegAngleHistogramVals[108],
            f229: rightLegAngleHistogramVals[109],
            f230: rightLegAngleHistogramVals[110],
            f231: rightLegAngleHistogramVals[111],
            f232: rightLegAngleHistogramVals[112],
            f233: rightLegAngleHistogramVals[113],
            f234: rightLegAngleHistogramVals[114],
            f235: rightLegAngleHistogramVals[115],
            f236: rightLegAngleHistogramVals[116],
            f237: rightLegAngleHistogramVals[117],
            f238: rightLegAngleHistogramVals[118],
            f239: rightLegAngleHistogramVals[119],
            f240: shoulderDistanceHistogramVals[0],
            f241: shoulderDistanceHistogramVals[1],
            f242: shoulderDistanceHistogramVals[2],
            f243: shoulderDistanceHistogramVals[3],
            f244: shoulderDistanceHistogramVals[4],
            f245: shoulderDistanceHistogramVals[5],
            f246: shoulderDistanceHistogramVals[6],
            f247: shoulderDistanceHistogramVals[7],
            f248: shoulderDistanceHistogramVals[8],
            f249: shoulderDistanceHistogramVals[9],
            f250: shoulderDistanceHistogramVals[10],
            f251: shoulderDistanceHistogramVals[11],
            f252: shoulderDistanceHistogramVals[12],
            f253: shoulderDistanceHistogramVals[13],
            f254: shoulderDistanceHistogramVals[14],
            f255: shoulderDistanceHistogramVals[15],
            f256: shoulderDistanceHistogramVals[16],
            f257: shoulderDistanceHistogramVals[17],
            f258: shoulderDistanceHistogramVals[18],
            f259: shoulderDistanceHistogramVals[19],
            f260: shoulderDistanceHistogramVals[20],
            f261: shoulderDistanceHistogramVals[21],
            f262: shoulderDistanceHistogramVals[22],
            f263: shoulderDistanceHistogramVals[23],
            f264: shoulderDistanceHistogramVals[24],
            f265: shoulderDistanceHistogramVals[25],
            f266: shoulderDistanceHistogramVals[26],
            f267: shoulderDistanceHistogramVals[27],
            f268: shoulderDistanceHistogramVals[28],
            f269: shoulderDistanceHistogramVals[29],
            f270: shoulderDistanceHistogramVals[30],
            f271: shoulderDistanceHistogramVals[31],
            f272: shoulderDistanceHistogramVals[32],
            f273: shoulderDistanceHistogramVals[33],
            f274: shoulderDistanceHistogramVals[34],
            f275: shoulderDistanceHistogramVals[35],
            f276: shoulderDistanceHistogramVals[36],
            f277: shoulderDistanceHistogramVals[37],
            f278: shoulderDistanceHistogramVals[38],
            f279: shoulderDistanceHistogramVals[39],
            f280: shoulderDistanceHistogramVals[40],
            f281: shoulderDistanceHistogramVals[41],
            f282: shoulderDistanceHistogramVals[42],
            f283: shoulderDistanceHistogramVals[43],
            f284: shoulderDistanceHistogramVals[44],
            f285: shoulderDistanceHistogramVals[45],
            f286: shoulderDistanceHistogramVals[46],
            f287: shoulderDistanceHistogramVals[47],
            f288: shoulderDistanceHistogramVals[48],
            f289: shoulderDistanceHistogramVals[49],
            f290: shoulderDistanceHistogramVals[50],
            f291: shoulderDistanceHistogramVals[51],
            f292: shoulderDistanceHistogramVals[52],
            f293: shoulderDistanceHistogramVals[53],
            f294: shoulderDistanceHistogramVals[54],
            f295: shoulderDistanceHistogramVals[55],
            f296: shoulderDistanceHistogramVals[56],
            f297: shoulderDistanceHistogramVals[57],
            f298: shoulderDistanceHistogramVals[58],
            f299: shoulderDistanceHistogramVals[59],
            f300: shoulderDistanceHistogramVals[60],
            f301: shoulderDistanceHistogramVals[61],
            f302: shoulderDistanceHistogramVals[62],
            f303: shoulderDistanceHistogramVals[63],
            f304: shoulderDistanceHistogramVals[64],
            f305: shoulderDistanceHistogramVals[65],
            f306: shoulderDistanceHistogramVals[66],
            f307: shoulderDistanceHistogramVals[67],
            f308: shoulderDistanceHistogramVals[68],
            f309: shoulderDistanceHistogramVals[69],
            f310: shoulderDistanceHistogramVals[70],
            f311: shoulderDistanceHistogramVals[71],
            f312: shoulderDistanceHistogramVals[72],
            f313: shoulderDistanceHistogramVals[73],
            f314: shoulderDistanceHistogramVals[74],
            f315: shoulderDistanceHistogramVals[75],
            f316: shoulderDistanceHistogramVals[76],
            f317: shoulderDistanceHistogramVals[77],
            f318: shoulderDistanceHistogramVals[78],
            f319: shoulderDistanceHistogramVals[79],
            f320: shoulderDistanceHistogramVals[80],
            f321: shoulderDistanceHistogramVals[81],
            f322: shoulderDistanceHistogramVals[82],
            f323: shoulderDistanceHistogramVals[83],
            f324: shoulderDistanceHistogramVals[84],
            f325: shoulderDistanceHistogramVals[85],
            f326: shoulderDistanceHistogramVals[86],
            f327: shoulderDistanceHistogramVals[87],
            f328: shoulderDistanceHistogramVals[88],
            f329: shoulderDistanceHistogramVals[89],
            f330: shoulderDistanceHistogramVals[90],
            f331: shoulderDistanceHistogramVals[91],
            f332: shoulderDistanceHistogramVals[92],
            f333: shoulderDistanceHistogramVals[93],
            f334: shoulderDistanceHistogramVals[94],
            f335: shoulderDistanceHistogramVals[95],
            f336: shoulderDistanceHistogramVals[96],
            f337: shoulderDistanceHistogramVals[97],
            f338: shoulderDistanceHistogramVals[98],
            f339: shoulderDistanceHistogramVals[99],
            f340: shoulderDistanceHistogramVals[100],
            f341: shoulderDistanceHistogramVals[101],
            f342: shoulderDistanceHistogramVals[102],
            f343: shoulderDistanceHistogramVals[103],
            f344: shoulderDistanceHistogramVals[104],
            f345: shoulderDistanceHistogramVals[105],
            f346: shoulderDistanceHistogramVals[106],
            f347: shoulderDistanceHistogramVals[107],
            f348: shoulderDistanceHistogramVals[108],
            f349: shoulderDistanceHistogramVals[109],
            f350: shoulderDistanceHistogramVals[110],
            f351: shoulderDistanceHistogramVals[111],
            f352: shoulderDistanceHistogramVals[112],
            f353: shoulderDistanceHistogramVals[113],
            f354: shoulderDistanceHistogramVals[114],
            f355: shoulderDistanceHistogramVals[115],
            f356: shoulderDistanceHistogramVals[116],
            f357: shoulderDistanceHistogramVals[117],
            f358: shoulderDistanceHistogramVals[118],
            f359: shoulderDistanceHistogramVals[119]
            )) else {
            fatalError("Unexpected runtime error.")
        }
        let to_return = shoulderTimingScore.featureValue(for: "target")!
        return Double(to_return.int64Value)
    }
    func getTHPrediction(_ model: tossHeightXGBoost, _ pt2xsHistogramVals: [Double], _ pt3xsHistogramVals: [Double], _ pt4xsHistogramVals: [Double], _ pt5xsHistogramVals: [Double], _ pt6xsHistogramVals: [Double], _ pt7xsHistogramVals: [Double], _ pt2ysHistogramVals: [Double], _ pt3ysHistogramVals: [Double], _ pt4ysHistogramVals: [Double], _ pt5ysHistogramVals: [Double], _ pt6ysHistogramVals: [Double], _ pt7ysHistogramVals: [Double]) -> Double  {
        
        /* Generates a toss height score based on probability
         histograms of multiple keypoints. */
        
        guard let tossHeightScore = try? model.prediction(input: tossHeightXGBoostInput(
            f0: pt2xsHistogramVals[0],
            f1: pt2xsHistogramVals[1],
            f2: pt2xsHistogramVals[2],
            f3: pt2xsHistogramVals[3],
            f4: pt2xsHistogramVals[4],
            f5: pt2xsHistogramVals[5],
            f6: pt2xsHistogramVals[6],
            f7: pt2xsHistogramVals[7],
            f8: pt2xsHistogramVals[8],
            f9: pt2xsHistogramVals[9],
            f10: pt2xsHistogramVals[10],
            f11: pt2xsHistogramVals[11],
            f12: pt2xsHistogramVals[12],
            f13: pt2xsHistogramVals[13],
            f14: pt2xsHistogramVals[14],
            f15: pt2xsHistogramVals[15],
            f16: pt2xsHistogramVals[16],
            f17: pt2xsHistogramVals[17],
            f18: pt2xsHistogramVals[18],
            f19: pt2xsHistogramVals[19],
            f20: pt2xsHistogramVals[20],
            f21: pt2xsHistogramVals[21],
            f22: pt2xsHistogramVals[22],
            f23: pt2xsHistogramVals[23],
            f24: pt2xsHistogramVals[24],
            f25: pt2xsHistogramVals[25],
            f26: pt2xsHistogramVals[26],
            f27: pt2xsHistogramVals[27],
            f28: pt2xsHistogramVals[28],
            f29: pt2xsHistogramVals[29],
            f30: pt2xsHistogramVals[30],
            f31: pt2xsHistogramVals[31],
            f32: pt2xsHistogramVals[32],
            f33: pt2xsHistogramVals[33],
            f34: pt2xsHistogramVals[34],
            f35: pt2xsHistogramVals[35],
            f36: pt2xsHistogramVals[36],
            f37: pt2xsHistogramVals[37],
            f38: pt2xsHistogramVals[38],
            f39: pt2xsHistogramVals[39],
            f40: pt2xsHistogramVals[40],
            f41: pt2xsHistogramVals[41],
            f42: pt2xsHistogramVals[42],
            f43: pt2xsHistogramVals[43],
            f44: pt2xsHistogramVals[44],
            f45: pt2xsHistogramVals[45],
            f46: pt2xsHistogramVals[46],
            f47: pt2xsHistogramVals[47],
            f48: pt2xsHistogramVals[48],
            f49: pt2xsHistogramVals[49],
            f50: pt2xsHistogramVals[50],
            f51: pt2xsHistogramVals[51],
            f52: pt2xsHistogramVals[52],
            f53: pt2xsHistogramVals[53],
            f54: pt2xsHistogramVals[54],
            f55: pt2xsHistogramVals[55],
            f56: pt2xsHistogramVals[56],
            f57: pt2xsHistogramVals[57],
            f58: pt2xsHistogramVals[58],
            f59: pt2xsHistogramVals[59],
            f60: pt2xsHistogramVals[60],
            f61: pt2xsHistogramVals[61],
            f62: pt2xsHistogramVals[62],
            f63: pt2xsHistogramVals[63],
            f64: pt2xsHistogramVals[64],
            f65: pt2xsHistogramVals[65],
            f66: pt2xsHistogramVals[66],
            f67: pt2xsHistogramVals[67],
            f68: pt2xsHistogramVals[68],
            f69: pt2xsHistogramVals[69],
            f70: pt2xsHistogramVals[70],
            f71: pt2xsHistogramVals[71],
            f72: pt2xsHistogramVals[72],
            f73: pt2xsHistogramVals[73],
            f74: pt2xsHistogramVals[74],
            f75: pt2xsHistogramVals[75],
            f76: pt2xsHistogramVals[76],
            f77: pt2xsHistogramVals[77],
            f78: pt2xsHistogramVals[78],
            f79: pt2xsHistogramVals[79],
            f80: pt2xsHistogramVals[80],
            f81: pt2xsHistogramVals[81],
            f82: pt2xsHistogramVals[82],
            f83: pt2xsHistogramVals[83],
            f84: pt2xsHistogramVals[84],
            f85: pt2xsHistogramVals[85],
            f86: pt2xsHistogramVals[86],
            f87: pt2xsHistogramVals[87],
            f88: pt2xsHistogramVals[88],
            f89: pt2xsHistogramVals[89],
            f90: pt2xsHistogramVals[90],
            f91: pt2xsHistogramVals[91],
            f92: pt2xsHistogramVals[92],
            f93: pt2xsHistogramVals[93],
            f94: pt2xsHistogramVals[94],
            f95: pt2xsHistogramVals[95],
            f96: pt2xsHistogramVals[96],
            f97: pt2xsHistogramVals[97],
            f98: pt2xsHistogramVals[98],
            f99: pt2xsHistogramVals[99],
            f100: pt2xsHistogramVals[100],
            f101: pt2xsHistogramVals[101],
            f102: pt2xsHistogramVals[102],
            f103: pt2xsHistogramVals[103],
            f104: pt2xsHistogramVals[104],
            f105: pt2xsHistogramVals[105],
            f106: pt2xsHistogramVals[106],
            f107: pt2xsHistogramVals[107],
            f108: pt2xsHistogramVals[108],
            f109: pt2xsHistogramVals[109],
            f110: pt2xsHistogramVals[110],
            f111: pt2xsHistogramVals[111],
            f112: pt2xsHistogramVals[112],
            f113: pt2xsHistogramVals[113],
            f114: pt2xsHistogramVals[114],
            f115: pt2xsHistogramVals[115],
            f116: pt2xsHistogramVals[116],
            f117: pt2xsHistogramVals[117],
            f118: pt2xsHistogramVals[118],
            f119: pt2xsHistogramVals[119],
            f120: pt2ysHistogramVals[0],
            f121: pt2ysHistogramVals[1],
            f122: pt2ysHistogramVals[2],
            f123: pt2ysHistogramVals[3],
            f124: pt2ysHistogramVals[4],
            f125: pt2ysHistogramVals[5],
            f126: pt2ysHistogramVals[6],
            f127: pt2ysHistogramVals[7],
            f128: pt2ysHistogramVals[8],
            f129: pt2ysHistogramVals[9],
            f130: pt2ysHistogramVals[10],
            f131: pt2ysHistogramVals[11],
            f132: pt2ysHistogramVals[12],
            f133: pt2ysHistogramVals[13],
            f134: pt2ysHistogramVals[14],
            f135: pt2ysHistogramVals[15],
            f136: pt2ysHistogramVals[16],
            f137: pt2ysHistogramVals[17],
            f138: pt2ysHistogramVals[18],
            f139: pt2ysHistogramVals[19],
            f140: pt2ysHistogramVals[20],
            f141: pt2ysHistogramVals[21],
            f142: pt2ysHistogramVals[22],
            f143: pt2ysHistogramVals[23],
            f144: pt2ysHistogramVals[24],
            f145: pt2ysHistogramVals[25],
            f146: pt2ysHistogramVals[26],
            f147: pt2ysHistogramVals[27],
            f148: pt2ysHistogramVals[28],
            f149: pt2ysHistogramVals[29],
            f150: pt2ysHistogramVals[30],
            f151: pt2ysHistogramVals[31],
            f152: pt2ysHistogramVals[32],
            f153: pt2ysHistogramVals[33],
            f154: pt2ysHistogramVals[34],
            f155: pt2ysHistogramVals[35],
            f156: pt2ysHistogramVals[36],
            f157: pt2ysHistogramVals[37],
            f158: pt2ysHistogramVals[38],
            f159: pt2ysHistogramVals[39],
            f160: pt2ysHistogramVals[40],
            f161: pt2ysHistogramVals[41],
            f162: pt2ysHistogramVals[42],
            f163: pt2ysHistogramVals[43],
            f164: pt2ysHistogramVals[44],
            f165: pt2ysHistogramVals[45],
            f166: pt2ysHistogramVals[46],
            f167: pt2ysHistogramVals[47],
            f168: pt2ysHistogramVals[48],
            f169: pt2ysHistogramVals[49],
            f170: pt2ysHistogramVals[50],
            f171: pt2ysHistogramVals[51],
            f172: pt2ysHistogramVals[52],
            f173: pt2ysHistogramVals[53],
            f174: pt2ysHistogramVals[54],
            f175: pt2ysHistogramVals[55],
            f176: pt2ysHistogramVals[56],
            f177: pt2ysHistogramVals[57],
            f178: pt2ysHistogramVals[58],
            f179: pt2ysHistogramVals[59],
            f180: pt2ysHistogramVals[60],
            f181: pt2ysHistogramVals[61],
            f182: pt2ysHistogramVals[62],
            f183: pt2ysHistogramVals[63],
            f184: pt2ysHistogramVals[64],
            f185: pt2ysHistogramVals[65],
            f186: pt2ysHistogramVals[66],
            f187: pt2ysHistogramVals[67],
            f188: pt2ysHistogramVals[68],
            f189: pt2ysHistogramVals[69],
            f190: pt2ysHistogramVals[70],
            f191: pt2ysHistogramVals[71],
            f192: pt2ysHistogramVals[72],
            f193: pt2ysHistogramVals[73],
            f194: pt2ysHistogramVals[74],
            f195: pt2ysHistogramVals[75],
            f196: pt2ysHistogramVals[76],
            f197: pt2ysHistogramVals[77],
            f198: pt2ysHistogramVals[78],
            f199: pt2ysHistogramVals[79],
            f200: pt2ysHistogramVals[80],
            f201: pt2ysHistogramVals[81],
            f202: pt2ysHistogramVals[82],
            f203: pt2ysHistogramVals[83],
            f204: pt2ysHistogramVals[84],
            f205: pt2ysHistogramVals[85],
            f206: pt2ysHistogramVals[86],
            f207: pt2ysHistogramVals[87],
            f208: pt2ysHistogramVals[88],
            f209: pt2ysHistogramVals[89],
            f210: pt2ysHistogramVals[90],
            f211: pt2ysHistogramVals[91],
            f212: pt2ysHistogramVals[92],
            f213: pt2ysHistogramVals[93],
            f214: pt2ysHistogramVals[94],
            f215: pt2ysHistogramVals[95],
            f216: pt2ysHistogramVals[96],
            f217: pt2ysHistogramVals[97],
            f218: pt2ysHistogramVals[98],
            f219: pt2ysHistogramVals[99],
            f220: pt2ysHistogramVals[100],
            f221: pt2ysHistogramVals[101],
            f222: pt2ysHistogramVals[102],
            f223: pt2ysHistogramVals[103],
            f224: pt2ysHistogramVals[104],
            f225: pt2ysHistogramVals[105],
            f226: pt2ysHistogramVals[106],
            f227: pt2ysHistogramVals[107],
            f228: pt2ysHistogramVals[108],
            f229: pt2ysHistogramVals[109],
            f230: pt2ysHistogramVals[110],
            f231: pt2ysHistogramVals[111],
            f232: pt2ysHistogramVals[112],
            f233: pt2ysHistogramVals[113],
            f234: pt2ysHistogramVals[114],
            f235: pt2ysHistogramVals[115],
            f236: pt2ysHistogramVals[116],
            f237: pt2ysHistogramVals[117],
            f238: pt2ysHistogramVals[118],
            f239: pt2ysHistogramVals[119],
            f240: pt3xsHistogramVals[0],
            f241: pt3xsHistogramVals[1],
            f242: pt3xsHistogramVals[2],
            f243: pt3xsHistogramVals[3],
            f244: pt3xsHistogramVals[4],
            f245: pt3xsHistogramVals[5],
            f246: pt3xsHistogramVals[6],
            f247: pt3xsHistogramVals[7],
            f248: pt3xsHistogramVals[8],
            f249: pt3xsHistogramVals[9],
            f250: pt3xsHistogramVals[10],
            f251: pt3xsHistogramVals[11],
            f252: pt3xsHistogramVals[12],
            f253: pt3xsHistogramVals[13],
            f254: pt3xsHistogramVals[14],
            f255: pt3xsHistogramVals[15],
            f256: pt3xsHistogramVals[16],
            f257: pt3xsHistogramVals[17],
            f258: pt3xsHistogramVals[18],
            f259: pt3xsHistogramVals[19],
            f260: pt3xsHistogramVals[20],
            f261: pt3xsHistogramVals[21],
            f262: pt3xsHistogramVals[22],
            f263: pt3xsHistogramVals[23],
            f264: pt3xsHistogramVals[24],
            f265: pt3xsHistogramVals[25],
            f266: pt3xsHistogramVals[26],
            f267: pt3xsHistogramVals[27],
            f268: pt3xsHistogramVals[28],
            f269: pt3xsHistogramVals[29],
            f270: pt3xsHistogramVals[30],
            f271: pt3xsHistogramVals[31],
            f272: pt3xsHistogramVals[32],
            f273: pt3xsHistogramVals[33],
            f274: pt3xsHistogramVals[34],
            f275: pt3xsHistogramVals[35],
            f276: pt3xsHistogramVals[36],
            f277: pt3xsHistogramVals[37],
            f278: pt3xsHistogramVals[38],
            f279: pt3xsHistogramVals[39],
            f280: pt3xsHistogramVals[40],
            f281: pt3xsHistogramVals[41],
            f282: pt3xsHistogramVals[42],
            f283: pt3xsHistogramVals[43],
            f284: pt3xsHistogramVals[44],
            f285: pt3xsHistogramVals[45],
            f286: pt3xsHistogramVals[46],
            f287: pt3xsHistogramVals[47],
            f288: pt3xsHistogramVals[48],
            f289: pt3xsHistogramVals[49],
            f290: pt3xsHistogramVals[50],
            f291: pt3xsHistogramVals[51],
            f292: pt3xsHistogramVals[52],
            f293: pt3xsHistogramVals[53],
            f294: pt3xsHistogramVals[54],
            f295: pt3xsHistogramVals[55],
            f296: pt3xsHistogramVals[56],
            f297: pt3xsHistogramVals[57],
            f298: pt3xsHistogramVals[58],
            f299: pt3xsHistogramVals[59],
            f300: pt3xsHistogramVals[60],
            f301: pt3xsHistogramVals[61],
            f302: pt3xsHistogramVals[62],
            f303: pt3xsHistogramVals[63],
            f304: pt3xsHistogramVals[64],
            f305: pt3xsHistogramVals[65],
            f306: pt3xsHistogramVals[66],
            f307: pt3xsHistogramVals[67],
            f308: pt3xsHistogramVals[68],
            f309: pt3xsHistogramVals[69],
            f310: pt3xsHistogramVals[70],
            f311: pt3xsHistogramVals[71],
            f312: pt3xsHistogramVals[72],
            f313: pt3xsHistogramVals[73],
            f314: pt3xsHistogramVals[74],
            f315: pt3xsHistogramVals[75],
            f316: pt3xsHistogramVals[76],
            f317: pt3xsHistogramVals[77],
            f318: pt3xsHistogramVals[78],
            f319: pt3xsHistogramVals[79],
            f320: pt3xsHistogramVals[80],
            f321: pt3xsHistogramVals[81],
            f322: pt3xsHistogramVals[82],
            f323: pt3xsHistogramVals[83],
            f324: pt3xsHistogramVals[84],
            f325: pt3xsHistogramVals[85],
            f326: pt3xsHistogramVals[86],
            f327: pt3xsHistogramVals[87],
            f328: pt3xsHistogramVals[88],
            f329: pt3xsHistogramVals[89],
            f330: pt3xsHistogramVals[90],
            f331: pt3xsHistogramVals[91],
            f332: pt3xsHistogramVals[92],
            f333: pt3xsHistogramVals[93],
            f334: pt3xsHistogramVals[94],
            f335: pt3xsHistogramVals[95],
            f336: pt3xsHistogramVals[96],
            f337: pt3xsHistogramVals[97],
            f338: pt3xsHistogramVals[98],
            f339: pt3xsHistogramVals[99],
            f340: pt3xsHistogramVals[100],
            f341: pt3xsHistogramVals[101],
            f342: pt3xsHistogramVals[102],
            f343: pt3xsHistogramVals[103],
            f344: pt3xsHistogramVals[104],
            f345: pt3xsHistogramVals[105],
            f346: pt3xsHistogramVals[106],
            f347: pt3xsHistogramVals[107],
            f348: pt3xsHistogramVals[108],
            f349: pt3xsHistogramVals[109],
            f350: pt3xsHistogramVals[110],
            f351: pt3xsHistogramVals[111],
            f352: pt3xsHistogramVals[112],
            f353: pt3xsHistogramVals[113],
            f354: pt3xsHistogramVals[114],
            f355: pt3xsHistogramVals[115],
            f356: pt3xsHistogramVals[116],
            f357: pt3xsHistogramVals[117],
            f358: pt3xsHistogramVals[118],
            f359: pt3xsHistogramVals[119],
            f360: pt3ysHistogramVals[0],
            f361: pt3ysHistogramVals[1],
            f362: pt3ysHistogramVals[2],
            f363: pt3ysHistogramVals[3],
            f364: pt3ysHistogramVals[4],
            f365: pt3ysHistogramVals[5],
            f366: pt3ysHistogramVals[6],
            f367: pt3ysHistogramVals[7],
            f368: pt3ysHistogramVals[8],
            f369: pt3ysHistogramVals[9],
            f370: pt3ysHistogramVals[10],
            f371: pt3ysHistogramVals[11],
            f372: pt3ysHistogramVals[12],
            f373: pt3ysHistogramVals[13],
            f374: pt3ysHistogramVals[14],
            f375: pt3ysHistogramVals[15],
            f376: pt3ysHistogramVals[16],
            f377: pt3ysHistogramVals[17],
            f378: pt3ysHistogramVals[18],
            f379: pt3ysHistogramVals[19],
            f380: pt3ysHistogramVals[20],
            f381: pt3ysHistogramVals[21],
            f382: pt3ysHistogramVals[22],
            f383: pt3ysHistogramVals[23],
            f384: pt3ysHistogramVals[24],
            f385: pt3ysHistogramVals[25],
            f386: pt3ysHistogramVals[26],
            f387: pt3ysHistogramVals[27],
            f388: pt3ysHistogramVals[28],
            f389: pt3ysHistogramVals[29],
            f390: pt3ysHistogramVals[30],
            f391: pt3ysHistogramVals[31],
            f392: pt3ysHistogramVals[32],
            f393: pt3ysHistogramVals[33],
            f394: pt3ysHistogramVals[34],
            f395: pt3ysHistogramVals[35],
            f396: pt3ysHistogramVals[36],
            f397: pt3ysHistogramVals[37],
            f398: pt3ysHistogramVals[38],
            f399: pt3ysHistogramVals[39],
            f400: pt3ysHistogramVals[40],
            f401: pt3ysHistogramVals[41],
            f402: pt3ysHistogramVals[42],
            f403: pt3ysHistogramVals[43],
            f404: pt3ysHistogramVals[44],
            f405: pt3ysHistogramVals[45],
            f406: pt3ysHistogramVals[46],
            f407: pt3ysHistogramVals[47],
            f408: pt3ysHistogramVals[48],
            f409: pt3ysHistogramVals[49],
            f410: pt3ysHistogramVals[50],
            f411: pt3ysHistogramVals[51],
            f412: pt3ysHistogramVals[52],
            f413: pt3ysHistogramVals[53],
            f414: pt3ysHistogramVals[54],
            f415: pt3ysHistogramVals[55],
            f416: pt3ysHistogramVals[56],
            f417: pt3ysHistogramVals[57],
            f418: pt3ysHistogramVals[58],
            f419: pt3ysHistogramVals[59],
            f420: pt3ysHistogramVals[60],
            f421: pt3ysHistogramVals[61],
            f422: pt3ysHistogramVals[62],
            f423: pt3ysHistogramVals[63],
            f424: pt3ysHistogramVals[64],
            f425: pt3ysHistogramVals[65],
            f426: pt3ysHistogramVals[66],
            f427: pt3ysHistogramVals[67],
            f428: pt3ysHistogramVals[68],
            f429: pt3ysHistogramVals[69],
            f430: pt3ysHistogramVals[70],
            f431: pt3ysHistogramVals[71],
            f432: pt3ysHistogramVals[72],
            f433: pt3ysHistogramVals[73],
            f434: pt3ysHistogramVals[74],
            f435: pt3ysHistogramVals[75],
            f436: pt3ysHistogramVals[76],
            f437: pt3ysHistogramVals[77],
            f438: pt3ysHistogramVals[78],
            f439: pt3ysHistogramVals[79],
            f440: pt3ysHistogramVals[80],
            f441: pt3ysHistogramVals[81],
            f442: pt3ysHistogramVals[82],
            f443: pt3ysHistogramVals[83],
            f444: pt3ysHistogramVals[84],
            f445: pt3ysHistogramVals[85],
            f446: pt3ysHistogramVals[86],
            f447: pt3ysHistogramVals[87],
            f448: pt3ysHistogramVals[88],
            f449: pt3ysHistogramVals[89],
            f450: pt3ysHistogramVals[90],
            f451: pt3ysHistogramVals[91],
            f452: pt3ysHistogramVals[92],
            f453: pt3ysHistogramVals[93],
            f454: pt3ysHistogramVals[94],
            f455: pt3ysHistogramVals[95],
            f456: pt3ysHistogramVals[96],
            f457: pt3ysHistogramVals[97],
            f458: pt3ysHistogramVals[98],
            f459: pt3ysHistogramVals[99],
            f460: pt3ysHistogramVals[100],
            f461: pt3ysHistogramVals[101],
            f462: pt3ysHistogramVals[102],
            f463: pt3ysHistogramVals[103],
            f464: pt3ysHistogramVals[104],
            f465: pt3ysHistogramVals[105],
            f466: pt3ysHistogramVals[106],
            f467: pt3ysHistogramVals[107],
            f468: pt3ysHistogramVals[108],
            f469: pt3ysHistogramVals[109],
            f470: pt3ysHistogramVals[110],
            f471: pt3ysHistogramVals[111],
            f472: pt3ysHistogramVals[112],
            f473: pt3ysHistogramVals[113],
            f474: pt3ysHistogramVals[114],
            f475: pt3ysHistogramVals[115],
            f476: pt3ysHistogramVals[116],
            f477: pt3ysHistogramVals[117],
            f478: pt3ysHistogramVals[118],
            f479: pt3ysHistogramVals[119],
            f480: pt4xsHistogramVals[0],
            f481: pt4xsHistogramVals[1],
            f482: pt4xsHistogramVals[2],
            f483: pt4xsHistogramVals[3],
            f484: pt4xsHistogramVals[4],
            f485: pt4xsHistogramVals[5],
            f486: pt4xsHistogramVals[6],
            f487: pt4xsHistogramVals[7],
            f488: pt4xsHistogramVals[8],
            f489: pt4xsHistogramVals[9],
            f490: pt4xsHistogramVals[10],
            f491: pt4xsHistogramVals[11],
            f492: pt4xsHistogramVals[12],
            f493: pt4xsHistogramVals[13],
            f494: pt4xsHistogramVals[14],
            f495: pt4xsHistogramVals[15],
            f496: pt4xsHistogramVals[16],
            f497: pt4xsHistogramVals[17],
            f498: pt4xsHistogramVals[18],
            f499: pt4xsHistogramVals[19],
            f500: pt4xsHistogramVals[20],
            f501: pt4xsHistogramVals[21],
            f502: pt4xsHistogramVals[22],
            f503: pt4xsHistogramVals[23],
            f504: pt4xsHistogramVals[24],
            f505: pt4xsHistogramVals[25],
            f506: pt4xsHistogramVals[26],
            f507: pt4xsHistogramVals[27],
            f508: pt4xsHistogramVals[28],
            f509: pt4xsHistogramVals[29],
            f510: pt4xsHistogramVals[30],
            f511: pt4xsHistogramVals[31],
            f512: pt4xsHistogramVals[32],
            f513: pt4xsHistogramVals[33],
            f514: pt4xsHistogramVals[34],
            f515: pt4xsHistogramVals[35],
            f516: pt4xsHistogramVals[36],
            f517: pt4xsHistogramVals[37],
            f518: pt4xsHistogramVals[38],
            f519: pt4xsHistogramVals[39],
            f520: pt4xsHistogramVals[40],
            f521: pt4xsHistogramVals[41],
            f522: pt4xsHistogramVals[42],
            f523: pt4xsHistogramVals[43],
            f524: pt4xsHistogramVals[44],
            f525: pt4xsHistogramVals[45],
            f526: pt4xsHistogramVals[46],
            f527: pt4xsHistogramVals[47],
            f528: pt4xsHistogramVals[48],
            f529: pt4xsHistogramVals[49],
            f530: pt4xsHistogramVals[50],
            f531: pt4xsHistogramVals[51],
            f532: pt4xsHistogramVals[52],
            f533: pt4xsHistogramVals[53],
            f534: pt4xsHistogramVals[54],
            f535: pt4xsHistogramVals[55],
            f536: pt4xsHistogramVals[56],
            f537: pt4xsHistogramVals[57],
            f538: pt4xsHistogramVals[58],
            f539: pt4xsHistogramVals[59],
            f540: pt4xsHistogramVals[60],
            f541: pt4xsHistogramVals[61],
            f542: pt4xsHistogramVals[62],
            f543: pt4xsHistogramVals[63],
            f544: pt4xsHistogramVals[64],
            f545: pt4xsHistogramVals[65],
            f546: pt4xsHistogramVals[66],
            f547: pt4xsHistogramVals[67],
            f548: pt4xsHistogramVals[68],
            f549: pt4xsHistogramVals[69],
            f550: pt4xsHistogramVals[70],
            f551: pt4xsHistogramVals[71],
            f552: pt4xsHistogramVals[72],
            f553: pt4xsHistogramVals[73],
            f554: pt4xsHistogramVals[74],
            f555: pt4xsHistogramVals[75],
            f556: pt4xsHistogramVals[76],
            f557: pt4xsHistogramVals[77],
            f558: pt4xsHistogramVals[78],
            f559: pt4xsHistogramVals[79],
            f560: pt4xsHistogramVals[80],
            f561: pt4xsHistogramVals[81],
            f562: pt4xsHistogramVals[82],
            f563: pt4xsHistogramVals[83],
            f564: pt4xsHistogramVals[84],
            f565: pt4xsHistogramVals[85],
            f566: pt4xsHistogramVals[86],
            f567: pt4xsHistogramVals[87],
            f568: pt4xsHistogramVals[88],
            f569: pt4xsHistogramVals[89],
            f570: pt4xsHistogramVals[90],
            f571: pt4xsHistogramVals[91],
            f572: pt4xsHistogramVals[92],
            f573: pt4xsHistogramVals[93],
            f574: pt4xsHistogramVals[94],
            f575: pt4xsHistogramVals[95],
            f576: pt4xsHistogramVals[96],
            f577: pt4xsHistogramVals[97],
            f578: pt4xsHistogramVals[98],
            f579: pt4xsHistogramVals[99],
            f580: pt4xsHistogramVals[100],
            f581: pt4xsHistogramVals[101],
            f582: pt4xsHistogramVals[102],
            f583: pt4xsHistogramVals[103],
            f584: pt4xsHistogramVals[104],
            f585: pt4xsHistogramVals[105],
            f586: pt4xsHistogramVals[106],
            f587: pt4xsHistogramVals[107],
            f588: pt4xsHistogramVals[108],
            f589: pt4xsHistogramVals[109],
            f590: pt4xsHistogramVals[110],
            f591: pt4xsHistogramVals[111],
            f592: pt4xsHistogramVals[112],
            f593: pt4xsHistogramVals[113],
            f594: pt4xsHistogramVals[114],
            f595: pt4xsHistogramVals[115],
            f596: pt4xsHistogramVals[116],
            f597: pt4xsHistogramVals[117],
            f598: pt4xsHistogramVals[118],
            f599: pt4xsHistogramVals[119],
            f600: pt4ysHistogramVals[0],
            f601: pt4ysHistogramVals[1],
            f602: pt4ysHistogramVals[2],
            f603: pt4ysHistogramVals[3],
            f604: pt4ysHistogramVals[4],
            f605: pt4ysHistogramVals[5],
            f606: pt4ysHistogramVals[6],
            f607: pt4ysHistogramVals[7],
            f608: pt4ysHistogramVals[8],
            f609: pt4ysHistogramVals[9],
            f610: pt4ysHistogramVals[10],
            f611: pt4ysHistogramVals[11],
            f612: pt4ysHistogramVals[12],
            f613: pt4ysHistogramVals[13],
            f614: pt4ysHistogramVals[14],
            f615: pt4ysHistogramVals[15],
            f616: pt4ysHistogramVals[16],
            f617: pt4ysHistogramVals[17],
            f618: pt4ysHistogramVals[18],
            f619: pt4ysHistogramVals[19],
            f620: pt4ysHistogramVals[20],
            f621: pt4ysHistogramVals[21],
            f622: pt4ysHistogramVals[22],
            f623: pt4ysHistogramVals[23],
            f624: pt4ysHistogramVals[24],
            f625: pt4ysHistogramVals[25],
            f626: pt4ysHistogramVals[26],
            f627: pt4ysHistogramVals[27],
            f628: pt4ysHistogramVals[28],
            f629: pt4ysHistogramVals[29],
            f630: pt4ysHistogramVals[30],
            f631: pt4ysHistogramVals[31],
            f632: pt4ysHistogramVals[32],
            f633: pt4ysHistogramVals[33],
            f634: pt4ysHistogramVals[34],
            f635: pt4ysHistogramVals[35],
            f636: pt4ysHistogramVals[36],
            f637: pt4ysHistogramVals[37],
            f638: pt4ysHistogramVals[38],
            f639: pt4ysHistogramVals[39],
            f640: pt4ysHistogramVals[40],
            f641: pt4ysHistogramVals[41],
            f642: pt4ysHistogramVals[42],
            f643: pt4ysHistogramVals[43],
            f644: pt4ysHistogramVals[44],
            f645: pt4ysHistogramVals[45],
            f646: pt4ysHistogramVals[46],
            f647: pt4ysHistogramVals[47],
            f648: pt4ysHistogramVals[48],
            f649: pt4ysHistogramVals[49],
            f650: pt4ysHistogramVals[50],
            f651: pt4ysHistogramVals[51],
            f652: pt4ysHistogramVals[52],
            f653: pt4ysHistogramVals[53],
            f654: pt4ysHistogramVals[54],
            f655: pt4ysHistogramVals[55],
            f656: pt4ysHistogramVals[56],
            f657: pt4ysHistogramVals[57],
            f658: pt4ysHistogramVals[58],
            f659: pt4ysHistogramVals[59],
            f660: pt4ysHistogramVals[60],
            f661: pt4ysHistogramVals[61],
            f662: pt4ysHistogramVals[62],
            f663: pt4ysHistogramVals[63],
            f664: pt4ysHistogramVals[64],
            f665: pt4ysHistogramVals[65],
            f666: pt4ysHistogramVals[66],
            f667: pt4ysHistogramVals[67],
            f668: pt4ysHistogramVals[68],
            f669: pt4ysHistogramVals[69],
            f670: pt4ysHistogramVals[70],
            f671: pt4ysHistogramVals[71],
            f672: pt4ysHistogramVals[72],
            f673: pt4ysHistogramVals[73],
            f674: pt4ysHistogramVals[74],
            f675: pt4ysHistogramVals[75],
            f676: pt4ysHistogramVals[76],
            f677: pt4ysHistogramVals[77],
            f678: pt4ysHistogramVals[78],
            f679: pt4ysHistogramVals[79],
            f680: pt4ysHistogramVals[80],
            f681: pt4ysHistogramVals[81],
            f682: pt4ysHistogramVals[82],
            f683: pt4ysHistogramVals[83],
            f684: pt4ysHistogramVals[84],
            f685: pt4ysHistogramVals[85],
            f686: pt4ysHistogramVals[86],
            f687: pt4ysHistogramVals[87],
            f688: pt4ysHistogramVals[88],
            f689: pt4ysHistogramVals[89],
            f690: pt4ysHistogramVals[90],
            f691: pt4ysHistogramVals[91],
            f692: pt4ysHistogramVals[92],
            f693: pt4ysHistogramVals[93],
            f694: pt4ysHistogramVals[94],
            f695: pt4ysHistogramVals[95],
            f696: pt4ysHistogramVals[96],
            f697: pt4ysHistogramVals[97],
            f698: pt4ysHistogramVals[98],
            f699: pt4ysHistogramVals[99],
            f700: pt4ysHistogramVals[100],
            f701: pt4ysHistogramVals[101],
            f702: pt4ysHistogramVals[102],
            f703: pt4ysHistogramVals[103],
            f704: pt4ysHistogramVals[104],
            f705: pt4ysHistogramVals[105],
            f706: pt4ysHistogramVals[106],
            f707: pt4ysHistogramVals[107],
            f708: pt4ysHistogramVals[108],
            f709: pt4ysHistogramVals[109],
            f710: pt4ysHistogramVals[110],
            f711: pt4ysHistogramVals[111],
            f712: pt4ysHistogramVals[112],
            f713: pt4ysHistogramVals[113],
            f714: pt4ysHistogramVals[114],
            f715: pt4ysHistogramVals[115],
            f716: pt4ysHistogramVals[116],
            f717: pt4ysHistogramVals[117],
            f718: pt4ysHistogramVals[118],
            f719: pt4ysHistogramVals[119],
            f720: pt5xsHistogramVals[0],
            f721: pt5xsHistogramVals[1],
            f722: pt5xsHistogramVals[2],
            f723: pt5xsHistogramVals[3],
            f724: pt5xsHistogramVals[4],
            f725: pt5xsHistogramVals[5],
            f726: pt5xsHistogramVals[6],
            f727: pt5xsHistogramVals[7],
            f728: pt5xsHistogramVals[8],
            f729: pt5xsHistogramVals[9],
            f730: pt5xsHistogramVals[10],
            f731: pt5xsHistogramVals[11],
            f732: pt5xsHistogramVals[12],
            f733: pt5xsHistogramVals[13],
            f734: pt5xsHistogramVals[14],
            f735: pt5xsHistogramVals[15],
            f736: pt5xsHistogramVals[16],
            f737: pt5xsHistogramVals[17],
            f738: pt5xsHistogramVals[18],
            f739: pt5xsHistogramVals[19],
            f740: pt5xsHistogramVals[20],
            f741: pt5xsHistogramVals[21],
            f742: pt5xsHistogramVals[22],
            f743: pt5xsHistogramVals[23],
            f744: pt5xsHistogramVals[24],
            f745: pt5xsHistogramVals[25],
            f746: pt5xsHistogramVals[26],
            f747: pt5xsHistogramVals[27],
            f748: pt5xsHistogramVals[28],
            f749: pt5xsHistogramVals[29],
            f750: pt5xsHistogramVals[30],
            f751: pt5xsHistogramVals[31],
            f752: pt5xsHistogramVals[32],
            f753: pt5xsHistogramVals[33],
            f754: pt5xsHistogramVals[34],
            f755: pt5xsHistogramVals[35],
            f756: pt5xsHistogramVals[36],
            f757: pt5xsHistogramVals[37],
            f758: pt5xsHistogramVals[38],
            f759: pt5xsHistogramVals[39],
            f760: pt5xsHistogramVals[40],
            f761: pt5xsHistogramVals[41],
            f762: pt5xsHistogramVals[42],
            f763: pt5xsHistogramVals[43],
            f764: pt5xsHistogramVals[44],
            f765: pt5xsHistogramVals[45],
            f766: pt5xsHistogramVals[46],
            f767: pt5xsHistogramVals[47],
            f768: pt5xsHistogramVals[48],
            f769: pt5xsHistogramVals[49],
            f770: pt5xsHistogramVals[50],
            f771: pt5xsHistogramVals[51],
            f772: pt5xsHistogramVals[52],
            f773: pt5xsHistogramVals[53],
            f774: pt5xsHistogramVals[54],
            f775: pt5xsHistogramVals[55],
            f776: pt5xsHistogramVals[56],
            f777: pt5xsHistogramVals[57],
            f778: pt5xsHistogramVals[58],
            f779: pt5xsHistogramVals[59],
            f780: pt5xsHistogramVals[60],
            f781: pt5xsHistogramVals[61],
            f782: pt5xsHistogramVals[62],
            f783: pt5xsHistogramVals[63],
            f784: pt5xsHistogramVals[64],
            f785: pt5xsHistogramVals[65],
            f786: pt5xsHistogramVals[66],
            f787: pt5xsHistogramVals[67],
            f788: pt5xsHistogramVals[68],
            f789: pt5xsHistogramVals[69],
            f790: pt5xsHistogramVals[70],
            f791: pt5xsHistogramVals[71],
            f792: pt5xsHistogramVals[72],
            f793: pt5xsHistogramVals[73],
            f794: pt5xsHistogramVals[74],
            f795: pt5xsHistogramVals[75],
            f796: pt5xsHistogramVals[76],
            f797: pt5xsHistogramVals[77],
            f798: pt5xsHistogramVals[78],
            f799: pt5xsHistogramVals[79],
            f800: pt5xsHistogramVals[80],
            f801: pt5xsHistogramVals[81],
            f802: pt5xsHistogramVals[82],
            f803: pt5xsHistogramVals[83],
            f804: pt5xsHistogramVals[84],
            f805: pt5xsHistogramVals[85],
            f806: pt5xsHistogramVals[86],
            f807: pt5xsHistogramVals[87],
            f808: pt5xsHistogramVals[88],
            f809: pt5xsHistogramVals[89],
            f810: pt5xsHistogramVals[90],
            f811: pt5xsHistogramVals[91],
            f812: pt5xsHistogramVals[92],
            f813: pt5xsHistogramVals[93],
            f814: pt5xsHistogramVals[94],
            f815: pt5xsHistogramVals[95],
            f816: pt5xsHistogramVals[96],
            f817: pt5xsHistogramVals[97],
            f818: pt5xsHistogramVals[98],
            f819: pt5xsHistogramVals[99],
            f820: pt5xsHistogramVals[100],
            f821: pt5xsHistogramVals[101],
            f822: pt5xsHistogramVals[102],
            f823: pt5xsHistogramVals[103],
            f824: pt5xsHistogramVals[104],
            f825: pt5xsHistogramVals[105],
            f826: pt5xsHistogramVals[106],
            f827: pt5xsHistogramVals[107],
            f828: pt5xsHistogramVals[108],
            f829: pt5xsHistogramVals[109],
            f830: pt5xsHistogramVals[110],
            f831: pt5xsHistogramVals[111],
            f832: pt5xsHistogramVals[112],
            f833: pt5xsHistogramVals[113],
            f834: pt5xsHistogramVals[114],
            f835: pt5xsHistogramVals[115],
            f836: pt5xsHistogramVals[116],
            f837: pt5xsHistogramVals[117],
            f838: pt5xsHistogramVals[118],
            f839: pt5xsHistogramVals[119],
            f840: pt5ysHistogramVals[0],
            f841: pt5ysHistogramVals[1],
            f842: pt5ysHistogramVals[2],
            f843: pt5ysHistogramVals[3],
            f844: pt5ysHistogramVals[4],
            f845: pt5ysHistogramVals[5],
            f846: pt5ysHistogramVals[6],
            f847: pt5ysHistogramVals[7],
            f848: pt5ysHistogramVals[8],
            f849: pt5ysHistogramVals[9],
            f850: pt5ysHistogramVals[10],
            f851: pt5ysHistogramVals[11],
            f852: pt5ysHistogramVals[12],
            f853: pt5ysHistogramVals[13],
            f854: pt5ysHistogramVals[14],
            f855: pt5ysHistogramVals[15],
            f856: pt5ysHistogramVals[16],
            f857: pt5ysHistogramVals[17],
            f858: pt5ysHistogramVals[18],
            f859: pt5ysHistogramVals[19],
            f860: pt5ysHistogramVals[20],
            f861: pt5ysHistogramVals[21],
            f862: pt5ysHistogramVals[22],
            f863: pt5ysHistogramVals[23],
            f864: pt5ysHistogramVals[24],
            f865: pt5ysHistogramVals[25],
            f866: pt5ysHistogramVals[26],
            f867: pt5ysHistogramVals[27],
            f868: pt5ysHistogramVals[28],
            f869: pt5ysHistogramVals[29],
            f870: pt5ysHistogramVals[30],
            f871: pt5ysHistogramVals[31],
            f872: pt5ysHistogramVals[32],
            f873: pt5ysHistogramVals[33],
            f874: pt5ysHistogramVals[34],
            f875: pt5ysHistogramVals[35],
            f876: pt5ysHistogramVals[36],
            f877: pt5ysHistogramVals[37],
            f878: pt5ysHistogramVals[38],
            f879: pt5ysHistogramVals[39],
            f880: pt5ysHistogramVals[40],
            f881: pt5ysHistogramVals[41],
            f882: pt5ysHistogramVals[42],
            f883: pt5ysHistogramVals[43],
            f884: pt5ysHistogramVals[44],
            f885: pt5ysHistogramVals[45],
            f886: pt5ysHistogramVals[46],
            f887: pt5ysHistogramVals[47],
            f888: pt5ysHistogramVals[48],
            f889: pt5ysHistogramVals[49],
            f890: pt5ysHistogramVals[50],
            f891: pt5ysHistogramVals[51],
            f892: pt5ysHistogramVals[52],
            f893: pt5ysHistogramVals[53],
            f894: pt5ysHistogramVals[54],
            f895: pt5ysHistogramVals[55],
            f896: pt5ysHistogramVals[56],
            f897: pt5ysHistogramVals[57],
            f898: pt5ysHistogramVals[58],
            f899: pt5ysHistogramVals[59],
            f900: pt5ysHistogramVals[60],
            f901: pt5ysHistogramVals[61],
            f902: pt5ysHistogramVals[62],
            f903: pt5ysHistogramVals[63],
            f904: pt5ysHistogramVals[64],
            f905: pt5ysHistogramVals[65],
            f906: pt5ysHistogramVals[66],
            f907: pt5ysHistogramVals[67],
            f908: pt5ysHistogramVals[68],
            f909: pt5ysHistogramVals[69],
            f910: pt5ysHistogramVals[70],
            f911: pt5ysHistogramVals[71],
            f912: pt5ysHistogramVals[72],
            f913: pt5ysHistogramVals[73],
            f914: pt5ysHistogramVals[74],
            f915: pt5ysHistogramVals[75],
            f916: pt5ysHistogramVals[76],
            f917: pt5ysHistogramVals[77],
            f918: pt5ysHistogramVals[78],
            f919: pt5ysHistogramVals[79],
            f920: pt5ysHistogramVals[80],
            f921: pt5ysHistogramVals[81],
            f922: pt5ysHistogramVals[82],
            f923: pt5ysHistogramVals[83],
            f924: pt5ysHistogramVals[84],
            f925: pt5ysHistogramVals[85],
            f926: pt5ysHistogramVals[86],
            f927: pt5ysHistogramVals[87],
            f928: pt5ysHistogramVals[88],
            f929: pt5ysHistogramVals[89],
            f930: pt5ysHistogramVals[90],
            f931: pt5ysHistogramVals[91],
            f932: pt5ysHistogramVals[92],
            f933: pt5ysHistogramVals[93],
            f934: pt5ysHistogramVals[94],
            f935: pt5ysHistogramVals[95],
            f936: pt5ysHistogramVals[96],
            f937: pt5ysHistogramVals[97],
            f938: pt5ysHistogramVals[98],
            f939: pt5ysHistogramVals[99],
            f940: pt5ysHistogramVals[100],
            f941: pt5ysHistogramVals[101],
            f942: pt5ysHistogramVals[102],
            f943: pt5ysHistogramVals[103],
            f944: pt5ysHistogramVals[104],
            f945: pt5ysHistogramVals[105],
            f946: pt5ysHistogramVals[106],
            f947: pt5ysHistogramVals[107],
            f948: pt5ysHistogramVals[108],
            f949: pt5ysHistogramVals[109],
            f950: pt5ysHistogramVals[110],
            f951: pt5ysHistogramVals[111],
            f952: pt5ysHistogramVals[112],
            f953: pt5ysHistogramVals[113],
            f954: pt5ysHistogramVals[114],
            f955: pt5ysHistogramVals[115],
            f956: pt5ysHistogramVals[116],
            f957: pt5ysHistogramVals[117],
            f958: pt5ysHistogramVals[118],
            f959: pt5ysHistogramVals[119],
            f960: pt6xsHistogramVals[0],
            f961: pt6xsHistogramVals[1],
            f962: pt6xsHistogramVals[2],
            f963: pt6xsHistogramVals[3],
            f964: pt6xsHistogramVals[4],
            f965: pt6xsHistogramVals[5],
            f966: pt6xsHistogramVals[6],
            f967: pt6xsHistogramVals[7],
            f968: pt6xsHistogramVals[8],
            f969: pt6xsHistogramVals[9],
            f970: pt6xsHistogramVals[10],
            f971: pt6xsHistogramVals[11],
            f972: pt6xsHistogramVals[12],
            f973: pt6xsHistogramVals[13],
            f974: pt6xsHistogramVals[14],
            f975: pt6xsHistogramVals[15],
            f976: pt6xsHistogramVals[16],
            f977: pt6xsHistogramVals[17],
            f978: pt6xsHistogramVals[18],
            f979: pt6xsHistogramVals[19],
            f980: pt6xsHistogramVals[20],
            f981: pt6xsHistogramVals[21],
            f982: pt6xsHistogramVals[22],
            f983: pt6xsHistogramVals[23],
            f984: pt6xsHistogramVals[24],
            f985: pt6xsHistogramVals[25],
            f986: pt6xsHistogramVals[26],
            f987: pt6xsHistogramVals[27],
            f988: pt6xsHistogramVals[28],
            f989: pt6xsHistogramVals[29],
            f990: pt6xsHistogramVals[30],
            f991: pt6xsHistogramVals[31],
            f992: pt6xsHistogramVals[32],
            f993: pt6xsHistogramVals[33],
            f994: pt6xsHistogramVals[34],
            f995: pt6xsHistogramVals[35],
            f996: pt6xsHistogramVals[36],
            f997: pt6xsHistogramVals[37],
            f998: pt6xsHistogramVals[38],
            f999: pt6xsHistogramVals[39],
            f1000: pt6xsHistogramVals[40],
            f1001: pt6xsHistogramVals[41],
            f1002: pt6xsHistogramVals[42],
            f1003: pt6xsHistogramVals[43],
            f1004: pt6xsHistogramVals[44],
            f1005: pt6xsHistogramVals[45],
            f1006: pt6xsHistogramVals[46],
            f1007: pt6xsHistogramVals[47],
            f1008: pt6xsHistogramVals[48],
            f1009: pt6xsHistogramVals[49],
            f1010: pt6xsHistogramVals[50],
            f1011: pt6xsHistogramVals[51],
            f1012: pt6xsHistogramVals[52],
            f1013: pt6xsHistogramVals[53],
            f1014: pt6xsHistogramVals[54],
            f1015: pt6xsHistogramVals[55],
            f1016: pt6xsHistogramVals[56],
            f1017: pt6xsHistogramVals[57],
            f1018: pt6xsHistogramVals[58],
            f1019: pt6xsHistogramVals[59],
            f1020: pt6xsHistogramVals[60],
            f1021: pt6xsHistogramVals[61],
            f1022: pt6xsHistogramVals[62],
            f1023: pt6xsHistogramVals[63],
            f1024: pt6xsHistogramVals[64],
            f1025: pt6xsHistogramVals[65],
            f1026: pt6xsHistogramVals[66],
            f1027: pt6xsHistogramVals[67],
            f1028: pt6xsHistogramVals[68],
            f1029: pt6xsHistogramVals[69],
            f1030: pt6xsHistogramVals[70],
            f1031: pt6xsHistogramVals[71],
            f1032: pt6xsHistogramVals[72],
            f1033: pt6xsHistogramVals[73],
            f1034: pt6xsHistogramVals[74],
            f1035: pt6xsHistogramVals[75],
            f1036: pt6xsHistogramVals[76],
            f1037: pt6xsHistogramVals[77],
            f1038: pt6xsHistogramVals[78],
            f1039: pt6xsHistogramVals[79],
            f1040: pt6xsHistogramVals[80],
            f1041: pt6xsHistogramVals[81],
            f1042: pt6xsHistogramVals[82],
            f1043: pt6xsHistogramVals[83],
            f1044: pt6xsHistogramVals[84],
            f1045: pt6xsHistogramVals[85],
            f1046: pt6xsHistogramVals[86],
            f1047: pt6xsHistogramVals[87],
            f1048: pt6xsHistogramVals[88],
            f1049: pt6xsHistogramVals[89],
            f1050: pt6xsHistogramVals[90],
            f1051: pt6xsHistogramVals[91],
            f1052: pt6xsHistogramVals[92],
            f1053: pt6xsHistogramVals[93],
            f1054: pt6xsHistogramVals[94],
            f1055: pt6xsHistogramVals[95],
            f1056: pt6xsHistogramVals[96],
            f1057: pt6xsHistogramVals[97],
            f1058: pt6xsHistogramVals[98],
            f1059: pt6xsHistogramVals[99],
            f1060: pt6xsHistogramVals[100],
            f1061: pt6xsHistogramVals[101],
            f1062: pt6xsHistogramVals[102],
            f1063: pt6xsHistogramVals[103],
            f1064: pt6xsHistogramVals[104],
            f1065: pt6xsHistogramVals[105],
            f1066: pt6xsHistogramVals[106],
            f1067: pt6xsHistogramVals[107],
            f1068: pt6xsHistogramVals[108],
            f1069: pt6xsHistogramVals[109],
            f1070: pt6xsHistogramVals[110],
            f1071: pt6xsHistogramVals[111],
            f1072: pt6xsHistogramVals[112],
            f1073: pt6xsHistogramVals[113],
            f1074: pt6xsHistogramVals[114],
            f1075: pt6xsHistogramVals[115],
            f1076: pt6xsHistogramVals[116],
            f1077: pt6xsHistogramVals[117],
            f1078: pt6xsHistogramVals[118],
            f1079: pt6xsHistogramVals[119],
            f1080: pt6ysHistogramVals[0],
            f1081: pt6ysHistogramVals[1],
            f1082: pt6ysHistogramVals[2],
            f1083: pt6ysHistogramVals[3],
            f1084: pt6ysHistogramVals[4],
            f1085: pt6ysHistogramVals[5],
            f1086: pt6ysHistogramVals[6],
            f1087: pt6ysHistogramVals[7],
            f1088: pt6ysHistogramVals[8],
            f1089: pt6ysHistogramVals[9],
            f1090: pt6ysHistogramVals[10],
            f1091: pt6ysHistogramVals[11],
            f1092: pt6ysHistogramVals[12],
            f1093: pt6ysHistogramVals[13],
            f1094: pt6ysHistogramVals[14],
            f1095: pt6ysHistogramVals[15],
            f1096: pt6ysHistogramVals[16],
            f1097: pt6ysHistogramVals[17],
            f1098: pt6ysHistogramVals[18],
            f1099: pt6ysHistogramVals[19],
            f1100: pt6ysHistogramVals[20],
            f1101: pt6ysHistogramVals[21],
            f1102: pt6ysHistogramVals[22],
            f1103: pt6ysHistogramVals[23],
            f1104: pt6ysHistogramVals[24],
            f1105: pt6ysHistogramVals[25],
            f1106: pt6ysHistogramVals[26],
            f1107: pt6ysHistogramVals[27],
            f1108: pt6ysHistogramVals[28],
            f1109: pt6ysHistogramVals[29],
            f1110: pt6ysHistogramVals[30],
            f1111: pt6ysHistogramVals[31],
            f1112: pt6ysHistogramVals[32],
            f1113: pt6ysHistogramVals[33],
            f1114: pt6ysHistogramVals[34],
            f1115: pt6ysHistogramVals[35],
            f1116: pt6ysHistogramVals[36],
            f1117: pt6ysHistogramVals[37],
            f1118: pt6ysHistogramVals[38],
            f1119: pt6ysHistogramVals[39],
            f1120: pt6ysHistogramVals[40],
            f1121: pt6ysHistogramVals[41],
            f1122: pt6ysHistogramVals[42],
            f1123: pt6ysHistogramVals[43],
            f1124: pt6ysHistogramVals[44],
            f1125: pt6ysHistogramVals[45],
            f1126: pt6ysHistogramVals[46],
            f1127: pt6ysHistogramVals[47],
            f1128: pt6ysHistogramVals[48],
            f1129: pt6ysHistogramVals[49],
            f1130: pt6ysHistogramVals[50],
            f1131: pt6ysHistogramVals[51],
            f1132: pt6ysHistogramVals[52],
            f1133: pt6ysHistogramVals[53],
            f1134: pt6ysHistogramVals[54],
            f1135: pt6ysHistogramVals[55],
            f1136: pt6ysHistogramVals[56],
            f1137: pt6ysHistogramVals[57],
            f1138: pt6ysHistogramVals[58],
            f1139: pt6ysHistogramVals[59],
            f1140: pt6ysHistogramVals[60],
            f1141: pt6ysHistogramVals[61],
            f1142: pt6ysHistogramVals[62],
            f1143: pt6ysHistogramVals[63],
            f1144: pt6ysHistogramVals[64],
            f1145: pt6ysHistogramVals[65],
            f1146: pt6ysHistogramVals[66],
            f1147: pt6ysHistogramVals[67],
            f1148: pt6ysHistogramVals[68],
            f1149: pt6ysHistogramVals[69],
            f1150: pt6ysHistogramVals[70],
            f1151: pt6ysHistogramVals[71],
            f1152: pt6ysHistogramVals[72],
            f1153: pt6ysHistogramVals[73],
            f1154: pt6ysHistogramVals[74],
            f1155: pt6ysHistogramVals[75],
            f1156: pt6ysHistogramVals[76],
            f1157: pt6ysHistogramVals[77],
            f1158: pt6ysHistogramVals[78],
            f1159: pt6ysHistogramVals[79],
            f1160: pt6ysHistogramVals[80],
            f1161: pt6ysHistogramVals[81],
            f1162: pt6ysHistogramVals[82],
            f1163: pt6ysHistogramVals[83],
            f1164: pt6ysHistogramVals[84],
            f1165: pt6ysHistogramVals[85],
            f1166: pt6ysHistogramVals[86],
            f1167: pt6ysHistogramVals[87],
            f1168: pt6ysHistogramVals[88],
            f1169: pt6ysHistogramVals[89],
            f1170: pt6ysHistogramVals[90],
            f1171: pt6ysHistogramVals[91],
            f1172: pt6ysHistogramVals[92],
            f1173: pt6ysHistogramVals[93],
            f1174: pt6ysHistogramVals[94],
            f1175: pt6ysHistogramVals[95],
            f1176: pt6ysHistogramVals[96],
            f1177: pt6ysHistogramVals[97],
            f1178: pt6ysHistogramVals[98],
            f1179: pt6ysHistogramVals[99],
            f1180: pt6ysHistogramVals[100],
            f1181: pt6ysHistogramVals[101],
            f1182: pt6ysHistogramVals[102],
            f1183: pt6ysHistogramVals[103],
            f1184: pt6ysHistogramVals[104],
            f1185: pt6ysHistogramVals[105],
            f1186: pt6ysHistogramVals[106],
            f1187: pt6ysHistogramVals[107],
            f1188: pt6ysHistogramVals[108],
            f1189: pt6ysHistogramVals[109],
            f1190: pt6ysHistogramVals[110],
            f1191: pt6ysHistogramVals[111],
            f1192: pt6ysHistogramVals[112],
            f1193: pt6ysHistogramVals[113],
            f1194: pt6ysHistogramVals[114],
            f1195: pt6ysHistogramVals[115],
            f1196: pt6ysHistogramVals[116],
            f1197: pt6ysHistogramVals[117],
            f1198: pt6ysHistogramVals[118],
            f1199: pt6ysHistogramVals[119],
            f1200: pt7xsHistogramVals[0],
            f1201: pt7xsHistogramVals[1],
            f1202: pt7xsHistogramVals[2],
            f1203: pt7xsHistogramVals[3],
            f1204: pt7xsHistogramVals[4],
            f1205: pt7xsHistogramVals[5],
            f1206: pt7xsHistogramVals[6],
            f1207: pt7xsHistogramVals[7],
            f1208: pt7xsHistogramVals[8],
            f1209: pt7xsHistogramVals[9],
            f1210: pt7xsHistogramVals[10],
            f1211: pt7xsHistogramVals[11],
            f1212: pt7xsHistogramVals[12],
            f1213: pt7xsHistogramVals[13],
            f1214: pt7xsHistogramVals[14],
            f1215: pt7xsHistogramVals[15],
            f1216: pt7xsHistogramVals[16],
            f1217: pt7xsHistogramVals[17],
            f1218: pt7xsHistogramVals[18],
            f1219: pt7xsHistogramVals[19],
            f1220: pt7xsHistogramVals[20],
            f1221: pt7xsHistogramVals[21],
            f1222: pt7xsHistogramVals[22],
            f1223: pt7xsHistogramVals[23],
            f1224: pt7xsHistogramVals[24],
            f1225: pt7xsHistogramVals[25],
            f1226: pt7xsHistogramVals[26],
            f1227: pt7xsHistogramVals[27],
            f1228: pt7xsHistogramVals[28],
            f1229: pt7xsHistogramVals[29],
            f1230: pt7xsHistogramVals[30],
            f1231: pt7xsHistogramVals[31],
            f1232: pt7xsHistogramVals[32],
            f1233: pt7xsHistogramVals[33],
            f1234: pt7xsHistogramVals[34],
            f1235: pt7xsHistogramVals[35],
            f1236: pt7xsHistogramVals[36],
            f1237: pt7xsHistogramVals[37],
            f1238: pt7xsHistogramVals[38],
            f1239: pt7xsHistogramVals[39],
            f1240: pt7xsHistogramVals[40],
            f1241: pt7xsHistogramVals[41],
            f1242: pt7xsHistogramVals[42],
            f1243: pt7xsHistogramVals[43],
            f1244: pt7xsHistogramVals[44],
            f1245: pt7xsHistogramVals[45],
            f1246: pt7xsHistogramVals[46],
            f1247: pt7xsHistogramVals[47],
            f1248: pt7xsHistogramVals[48],
            f1249: pt7xsHistogramVals[49],
            f1250: pt7xsHistogramVals[50],
            f1251: pt7xsHistogramVals[51],
            f1252: pt7xsHistogramVals[52],
            f1253: pt7xsHistogramVals[53],
            f1254: pt7xsHistogramVals[54],
            f1255: pt7xsHistogramVals[55],
            f1256: pt7xsHistogramVals[56],
            f1257: pt7xsHistogramVals[57],
            f1258: pt7xsHistogramVals[58],
            f1259: pt7xsHistogramVals[59],
            f1260: pt7xsHistogramVals[60],
            f1261: pt7xsHistogramVals[61],
            f1262: pt7xsHistogramVals[62],
            f1263: pt7xsHistogramVals[63],
            f1264: pt7xsHistogramVals[64],
            f1265: pt7xsHistogramVals[65],
            f1266: pt7xsHistogramVals[66],
            f1267: pt7xsHistogramVals[67],
            f1268: pt7xsHistogramVals[68],
            f1269: pt7xsHistogramVals[69],
            f1270: pt7xsHistogramVals[70],
            f1271: pt7xsHistogramVals[71],
            f1272: pt7xsHistogramVals[72],
            f1273: pt7xsHistogramVals[73],
            f1274: pt7xsHistogramVals[74],
            f1275: pt7xsHistogramVals[75],
            f1276: pt7xsHistogramVals[76],
            f1277: pt7xsHistogramVals[77],
            f1278: pt7xsHistogramVals[78],
            f1279: pt7xsHistogramVals[79],
            f1280: pt7xsHistogramVals[80],
            f1281: pt7xsHistogramVals[81],
            f1282: pt7xsHistogramVals[82],
            f1283: pt7xsHistogramVals[83],
            f1284: pt7xsHistogramVals[84],
            f1285: pt7xsHistogramVals[85],
            f1286: pt7xsHistogramVals[86],
            f1287: pt7xsHistogramVals[87],
            f1288: pt7xsHistogramVals[88],
            f1289: pt7xsHistogramVals[89],
            f1290: pt7xsHistogramVals[90],
            f1291: pt7xsHistogramVals[91],
            f1292: pt7xsHistogramVals[92],
            f1293: pt7xsHistogramVals[93],
            f1294: pt7xsHistogramVals[94],
            f1295: pt7xsHistogramVals[95],
            f1296: pt7xsHistogramVals[96],
            f1297: pt7xsHistogramVals[97],
            f1298: pt7xsHistogramVals[98],
            f1299: pt7xsHistogramVals[99],
            f1300: pt7xsHistogramVals[100],
            f1301: pt7xsHistogramVals[101],
            f1302: pt7xsHistogramVals[102],
            f1303: pt7xsHistogramVals[103],
            f1304: pt7xsHistogramVals[104],
            f1305: pt7xsHistogramVals[105],
            f1306: pt7xsHistogramVals[106],
            f1307: pt7xsHistogramVals[107],
            f1308: pt7xsHistogramVals[108],
            f1309: pt7xsHistogramVals[109],
            f1310: pt7xsHistogramVals[110],
            f1311: pt7xsHistogramVals[111],
            f1312: pt7xsHistogramVals[112],
            f1313: pt7xsHistogramVals[113],
            f1314: pt7xsHistogramVals[114],
            f1315: pt7xsHistogramVals[115],
            f1316: pt7xsHistogramVals[116],
            f1317: pt7xsHistogramVals[117],
            f1318: pt7xsHistogramVals[118],
            f1319: pt7xsHistogramVals[119],
            f1320: pt7ysHistogramVals[0],
            f1321: pt7ysHistogramVals[1],
            f1322: pt7ysHistogramVals[2],
            f1323: pt7ysHistogramVals[3],
            f1324: pt7ysHistogramVals[4],
            f1325: pt7ysHistogramVals[5],
            f1326: pt7ysHistogramVals[6],
            f1327: pt7ysHistogramVals[7],
            f1328: pt7ysHistogramVals[8],
            f1329: pt7ysHistogramVals[9],
            f1330: pt7ysHistogramVals[10],
            f1331: pt7ysHistogramVals[11],
            f1332: pt7ysHistogramVals[12],
            f1333: pt7ysHistogramVals[13],
            f1334: pt7ysHistogramVals[14],
            f1335: pt7ysHistogramVals[15],
            f1336: pt7ysHistogramVals[16],
            f1337: pt7ysHistogramVals[17],
            f1338: pt7ysHistogramVals[18],
            f1339: pt7ysHistogramVals[19],
            f1340: pt7ysHistogramVals[20],
            f1341: pt7ysHistogramVals[21],
            f1342: pt7ysHistogramVals[22],
            f1343: pt7ysHistogramVals[23],
            f1344: pt7ysHistogramVals[24],
            f1345: pt7ysHistogramVals[25],
            f1346: pt7ysHistogramVals[26],
            f1347: pt7ysHistogramVals[27],
            f1348: pt7ysHistogramVals[28],
            f1349: pt7ysHistogramVals[29],
            f1350: pt7ysHistogramVals[30],
            f1351: pt7ysHistogramVals[31],
            f1352: pt7ysHistogramVals[32],
            f1353: pt7ysHistogramVals[33],
            f1354: pt7ysHistogramVals[34],
            f1355: pt7ysHistogramVals[35],
            f1356: pt7ysHistogramVals[36],
            f1357: pt7ysHistogramVals[37],
            f1358: pt7ysHistogramVals[38],
            f1359: pt7ysHistogramVals[39],
            f1360: pt7ysHistogramVals[40],
            f1361: pt7ysHistogramVals[41],
            f1362: pt7ysHistogramVals[42],
            f1363: pt7ysHistogramVals[43],
            f1364: pt7ysHistogramVals[44],
            f1365: pt7ysHistogramVals[45],
            f1366: pt7ysHistogramVals[46],
            f1367: pt7ysHistogramVals[47],
            f1368: pt7ysHistogramVals[48],
            f1369: pt7ysHistogramVals[49],
            f1370: pt7ysHistogramVals[50],
            f1371: pt7ysHistogramVals[51],
            f1372: pt7ysHistogramVals[52],
            f1373: pt7ysHistogramVals[53],
            f1374: pt7ysHistogramVals[54],
            f1375: pt7ysHistogramVals[55],
            f1376: pt7ysHistogramVals[56],
            f1377: pt7ysHistogramVals[57],
            f1378: pt7ysHistogramVals[58],
            f1379: pt7ysHistogramVals[59],
            f1380: pt7ysHistogramVals[60],
            f1381: pt7ysHistogramVals[61],
            f1382: pt7ysHistogramVals[62],
            f1383: pt7ysHistogramVals[63],
            f1384: pt7ysHistogramVals[64],
            f1385: pt7ysHistogramVals[65],
            f1386: pt7ysHistogramVals[66],
            f1387: pt7ysHistogramVals[67],
            f1388: pt7ysHistogramVals[68],
            f1389: pt7ysHistogramVals[69],
            f1390: pt7ysHistogramVals[70],
            f1391: pt7ysHistogramVals[71],
            f1392: pt7ysHistogramVals[72],
            f1393: pt7ysHistogramVals[73],
            f1394: pt7ysHistogramVals[74],
            f1395: pt7ysHistogramVals[75],
            f1396: pt7ysHistogramVals[76],
            f1397: pt7ysHistogramVals[77],
            f1398: pt7ysHistogramVals[78],
            f1399: pt7ysHistogramVals[79],
            f1400: pt7ysHistogramVals[80],
            f1401: pt7ysHistogramVals[81],
            f1402: pt7ysHistogramVals[82],
            f1403: pt7ysHistogramVals[83],
            f1404: pt7ysHistogramVals[84],
            f1405: pt7ysHistogramVals[85],
            f1406: pt7ysHistogramVals[86],
            f1407: pt7ysHistogramVals[87],
            f1408: pt7ysHistogramVals[88],
            f1409: pt7ysHistogramVals[89],
            f1410: pt7ysHistogramVals[90],
            f1411: pt7ysHistogramVals[91],
            f1412: pt7ysHistogramVals[92],
            f1413: pt7ysHistogramVals[93],
            f1414: pt7ysHistogramVals[94],
            f1415: pt7ysHistogramVals[95],
            f1416: pt7ysHistogramVals[96],
            f1417: pt7ysHistogramVals[97],
            f1418: pt7ysHistogramVals[98],
            f1419: pt7ysHistogramVals[99],
            f1420: pt7ysHistogramVals[100],
            f1421: pt7ysHistogramVals[101],
            f1422: pt7ysHistogramVals[102],
            f1423: pt7ysHistogramVals[103],
            f1424: pt7ysHistogramVals[104],
            f1425: pt7ysHistogramVals[105],
            f1426: pt7ysHistogramVals[106],
            f1427: pt7ysHistogramVals[107],
            f1428: pt7ysHistogramVals[108],
            f1429: pt7ysHistogramVals[109],
            f1430: pt7ysHistogramVals[110],
            f1431: pt7ysHistogramVals[111],
            f1432: pt7ysHistogramVals[112],
            f1433: pt7ysHistogramVals[113],
            f1434: pt7ysHistogramVals[114],
            f1435: pt7ysHistogramVals[115],
            f1436: pt7ysHistogramVals[116],
            f1437: pt7ysHistogramVals[117],
            f1438: pt7ysHistogramVals[118],
            f1439: pt7ysHistogramVals[119]
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
