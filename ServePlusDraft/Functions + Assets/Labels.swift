//
//  Labels.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 2/24/21.
//
//  Classes for reusable label styles

import Foundation
import UIKit

class UILabelStroked: UILabel {
    var strokedText: String = "" {
        willSet(text) {
            let strokeTextAttributes = [
                NSAttributedString.Key.strokeColor :  UIColor(red: 0.0, green: 44/255, blue: 248/255, alpha: 1),
                NSAttributedString.Key.foregroundColor : UIColor.white,
                NSAttributedString.Key.strokeWidth : -2.0
            ] as [NSAttributedString.Key : Any]
            
            attributedText = NSMutableAttributedString(string: text, attributes: strokeTextAttributes)
        }
    }
}

class FeedbackLabel: UILabel {
    var labelText: String = "" {
        willSet(text) {
            let font = UIFont(name: "HelveticaNeue", size: 32)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.darkGray
            shadow.shadowBlurRadius = 3

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font as Any,
                .foregroundColor: UIColor.green,
                .shadow: shadow
            ]
            attributedText = NSMutableAttributedString(string: text, attributes: textAttributes)
        }
    }
}

class RankLabel: UILabel {
    var labelText: String = "" {
        willSet(text) {
            let font = UIFont(name: "HelveticaNeue", size: 32)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.darkGray
            shadow.shadowBlurRadius = 3

            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font as Any,
                .foregroundColor: UIColor.black,
                .shadow: shadow
            ]
            attributedText = NSMutableAttributedString(string: text, attributes: textAttributes)
        }
    }
}
