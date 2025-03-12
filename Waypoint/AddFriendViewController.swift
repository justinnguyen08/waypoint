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
        
        // Creating some connections add and pending buttons and hiding them based on what is called
        super.viewDidLoad()
        pendingButton.isHidden = true
    }
    
    
    @IBAction func addButtonPressed(_ sender: Any) {
        pendingButton.isHidden = false
        addButton.isHidden = true
    }
    
}
