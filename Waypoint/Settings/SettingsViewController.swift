//  Project: Waypoint
//  Course: CS371L
//
//  SettingsViewController.swift
//  Waypoint
//
//  Created by Justin Nguyen on 3/5/25.
//

import UIKit
import FirebaseAuth

class SettingsViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()  
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // sign out button
        if indexPath.section == 5 && indexPath.row == 5 {
            do {
                try Auth.auth().signOut()
            }
            catch _ as NSError { }
            
//            // Instantiate your login view controller from its storyboard.
//            let storyboard = UIStoryboard(name: "Login", bundle: nil)
//            guard let loginVC = storyboard.instantiateInitialViewController() else { return }
//           
//            // Set full-screen presentation style.
//            loginVC.modalPresentationStyle = .fullScreen
//           
//            // Present the login VC.
//            self.present(loginVC, animated: true, completion: nil)
            // Instantiate the login view controller.
            let storyboard = UIStoryboard(name: "Login", bundle: nil)
            guard let loginVC = storyboard.instantiateInitialViewController() else { return }
            loginVC.modalPresentationStyle = .fullScreen
            
            // Replace the root view controller.
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let sceneDelegate = windowScene.delegate as? SceneDelegate,
                let window = sceneDelegate.window {
                window.rootViewController = loginVC
                
//                // Optionally add a transition animation.
//                UIView.transition(with: window,
//                                  duration: 0.5,
//                                  options: .transitionFlipFromLeft,
//                                  animations: nil,
//                                  completion: nil)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Return a smaller height (or 0 if you don't need a header)
        return 0  // Adjust as necessary
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Return a minimal height for footers
        return 0  // Adjust as necessary
    }
    
    @IBAction func lightModeSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            // enable light mode
        }
        else {
            // disable light mode
        }
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
