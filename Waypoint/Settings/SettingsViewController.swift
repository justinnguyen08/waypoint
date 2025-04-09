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
        // sign out button is in section 4
        if indexPath.section == 4{
            // create sign out alert
            let alert = UIAlertController(title: "Sign Out",
                                          message: "Are you sure you want to sign out?",
                                          preferredStyle: .alert)
            
            // cancel action
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            // sign out action
            alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { _ in
                do {
                    try Auth.auth().signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
                
                // instantiate the login view controller
                let storyboard = UIStoryboard(name: "Login", bundle: nil)
                guard let loginVC = storyboard.instantiateInitialViewController() else { return }
                loginVC.modalPresentationStyle = .fullScreen
                
                // replace the root view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let sceneDelegate = windowScene.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    window.rootViewController = loginVC
                    
                    // animate a transition
                    UIView.transition(with: window, duration: 0.5, options: .transitionFlipFromLeft, animations: nil, completion: nil)
                }
            }))
            self.present(alert, animated: true, completion: nil)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    
    // return height of 0 for header and footer in table view
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    @IBAction func notificationsButtonTapped(_ sender: UISwitch) {
        if sender.isOn {
            // request notification permission if notifications are being enabled
        } else {
            // no notification permission
        }
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
