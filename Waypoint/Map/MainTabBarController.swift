//  Project: Waypoint
//  Course: CS371L
//
//  MainTabBarController.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/7/25.
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // ensure that we always load into the map at first
        self.selectedIndex = 2
    }
}
