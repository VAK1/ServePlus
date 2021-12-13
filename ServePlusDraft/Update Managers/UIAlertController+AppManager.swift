//
//  UIAlertController+AppManager.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/9/21.
//
//  Extension for alerting the user that they need
//  to update ServePlus.

import UIKit


extension UIAlertController {
    convenience init?(for status: AppUpdateManager.Status) {
        if case .noUpdate = status {
            return nil
        }

        self.init()
        self.title = "App Update"

        let updateNowAction = UIAlertAction(title: "Update now", style: .default) { _ in
            let appId = "id1578581406"
            UIApplication.shared.openAppStore(for: appId)
        }

        self.addAction(updateNowAction)

        if case .required = status {
            self.message = "You have to update the app."
        } else if case .optional = status {
            self.message = "There is a new version of the app."
            let cancelAction = UIAlertAction(title: "Not now", style: .cancel)
            self.addAction(cancelAction)
        }
    }
}
