//
//  TabBarController.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/4/21.
//
//  Tab Bar controller for navigating between the recording tab,
//  the review tab and the analysis tab.

import UIKit

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.selectedIndex = 1

    }
}
