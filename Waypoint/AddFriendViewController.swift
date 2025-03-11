//
//  AddFriendViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/10/25.
//

import UIKit

class AddFriendViewController: UIViewController {

    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var pendingButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pendingButton.isHidden = true
    }
    
    
    @IBAction func addButtonPressed(_ sender: Any) {
        pendingButton.isHidden = false
        addButton.isHidden = true
    }
    
}
