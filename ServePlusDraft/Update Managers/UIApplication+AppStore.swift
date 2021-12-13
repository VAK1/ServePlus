//
//  UIApplication+AppStore.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/9/21.
//
//  Extension for opening the url of ServePlus on the
//  App store

import UIKit
import AVFoundation
import Foundation
import CoreGraphics

extension UIApplication {
    func openAppStore(for appID: String) {
        let appStoreURL = "https://itunes.apple.com/app/\(appID)"
        guard let url = URL(string: appStoreURL) else {
            return
        }

        DispatchQueue.main.async {
            if self.canOpenURL(url) {
                self.open(url)
            }
        }
    }
}
