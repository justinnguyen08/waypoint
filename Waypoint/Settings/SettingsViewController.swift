//  Project: Waypoint
//  Course: CS371L
//
//  SettingsViewController.swift
//  Waypoint
//
//  Created by Justin Nguyen on 3/5/25.
//

import UIKit

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()  
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // if row 0 is "personal"
        if indexPath.section == 0 && indexPath.row == 0 {
            // segue to different detailed screen
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    @IBAction func lightModeSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            // enable light mode
        }
        else {
            // disable light mode
        }
    }
}
