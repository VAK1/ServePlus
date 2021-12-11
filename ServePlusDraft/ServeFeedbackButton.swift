//
//  ServeFeedbackButton.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 2/21/21.
//

import UIKit

class ServeFeedbackButton : UIButton {
    
    //// Drawing Methods
    lazy var curvePath : UIBezierPath = {
        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: 186.71-151, y: 67-52.27))
        bezier2Path.addLine(to: CGPoint(x: 172.57-151, y: 81.14-52.27))
        bezier2Path.addCurve(to: CGPoint(x: 151-151, y: 72.36-52.27), controlPoint1: CGPoint(x: 166.62-151, y: 75.19-52.27), controlPoint2: CGPoint(x: 158.8-151, y: 72.27-52.27))
        bezier2Path.addCurve(to: CGPoint(x: 151-151, y: 52.36-52.27), controlPoint1: CGPoint(x: 151-151, y: 65.44-52.27), controlPoint2: CGPoint(x: 151-151, y: 58.49-52.27))
        bezier2Path.addCurve(to: CGPoint(x: 186.71-151, y: 67-52.27), controlPoint1: CGPoint(x: 163.91-151, y: 52.27-52.27), controlPoint2: CGPoint(x: 176.86-151, y: 57.15-52.27))
        bezier2Path.close()
        
        return bezier2Path
    }()
    
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        // Set shape filling color
        UIColor.red.setFill()

        // Fill the shape
        curvePath.fill()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {

        // Handling touch events

        if (curvePath.contains(point)) {
            return self

        } else {
            return nil
        }
    }
    
    @objc dynamic public class func drawCanvas1(frame targetFrame: CGRect = CGRect(x: 0, y: 0, width: 240, height: 120), resizing: ResizingBehavior = .aspectFit) {
        //// General Declarations
        let context = UIGraphicsGetCurrentContext()!
        
        //// Resize to Target Frame
        context.saveGState()
        let resizedFrame: CGRect = resizing.apply(rect: CGRect(x: 0, y: 0, width: 240, height: 120), target: targetFrame)
        context.translateBy(x: resizedFrame.minX, y: resizedFrame.minY)
        context.scaleBy(x: resizedFrame.width / 240, y: resizedFrame.height / 120)


        //// Bezier 2 Drawing
        let bezier2Path = UIBezierPath()
        bezier2Path.move(to: CGPoint(x: 186.71, y: 67))
        bezier2Path.addLine(to: CGPoint(x: 172.57, y: 81.14))
        bezier2Path.addCurve(to: CGPoint(x: 151, y: 72.36), controlPoint1: CGPoint(x: 166.62, y: 75.19), controlPoint2: CGPoint(x: 158.8, y: 72.27))
        bezier2Path.addCurve(to: CGPoint(x: 151, y: 52.36), controlPoint1: CGPoint(x: 151, y: 65.44), controlPoint2: CGPoint(x: 151, y: 58.49))
        bezier2Path.addCurve(to: CGPoint(x: 186.71, y: 67), controlPoint1: CGPoint(x: 163.91, y: 52.27), controlPoint2: CGPoint(x: 176.86, y: 57.15))
        bezier2Path.close()
        UIColor.gray.setFill()
        bezier2Path.fill()
        
        context.restoreGState()

    }




    @objc(ServeFeedbackButtonResizingBehavior)
    public enum ResizingBehavior: Int {
        case aspectFit /// The content is proportionally resized to fit into the target rectangle.
        case aspectFill /// The content is proportionally resized to completely fill the target rectangle.
        case stretch /// The content is stretched to match the entire target rectangle.
        case center /// The content is centered in the target rectangle, but it is NOT resized.

        public func apply(rect: CGRect, target: CGRect) -> CGRect {
            if rect == target || target == CGRect.zero {
                return rect
            }

            var scales = CGSize.zero
            scales.width = abs(target.width / rect.width)
            scales.height = abs(target.height / rect.height)

            switch self {
                case .aspectFit:
                    scales.width = min(scales.width, scales.height)
                    scales.height = scales.width
                case .aspectFill:
                    scales.width = max(scales.width, scales.height)
                    scales.height = scales.width
                case .stretch:
                    break
                case .center:
                    scales.width = 1
                    scales.height = 1
            }

            var result = rect.standardized
            result.size.width *= scales.width
            result.size.height *= scales.height
            result.origin.x = target.minX + (target.width - result.width) / 2
            result.origin.y = target.minY + (target.height - result.height) / 2
            return result
        }
    }
}

