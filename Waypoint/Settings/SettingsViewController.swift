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
import FirebaseStorage
import Photos
import UserNotifications

class SettingsViewController: UITableViewController {
    
    @IBOutlet weak var notificationSwitch: UISwitch!
    @IBOutlet weak var darkModeSwitch: UISwitch!
    @IBOutlet weak var profilePic: UIImageView!
    
    var exportProgressView: UIView?
    var progressBar: UIProgressView?
    var progressLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        profilePic.layer.cornerRadius = profilePic.frame.width / 2
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        
        // sync switch
        if self.traitCollection.userInterfaceStyle == .dark {
            darkModeSwitch.isOn = true
        }
        else {
            darkModeSwitch.isOn = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getProfilePic()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        print("Tapped section: \(indexPath.section), row: \(indexPath.row)")
        // export photos is in section 3
        if indexPath.section == 3 {
            let confirmAlert = UIAlertController(
                title: "Export All Photos?",
                message: "This will save all your pictures to your device's photo library. Do you want to continue?",
                preferredStyle: .alert
            )

            confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            confirmAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                self.exportAllPicsAndChallengesToPhotos()
            }))

            self.present(confirmAlert, animated: true)
        }
        // sign out button is in section 4
        else if indexPath.section == 4 {
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
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
          DispatchQueue.main.async {
            if sender.isOn {
              switch settings.authorizationStatus {
              case .notDetermined:
                let alert = UIAlertController(
                  title: "Enable Notifications?",
                  message: "Would you like to receive alerts, sounds, and badge updates?",
                  preferredStyle: .alert
                )
                alert.addAction(.init(title: "Yes", style: .default) { _ in
                  center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                      if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                      } else {
                        // User tapped “Don’t Allow” in system prompt
                        sender.setOn(false, animated: true)
                      }
                    }
                  }
                })
                alert.addAction(.init(title: "No", style: .cancel) { _ in
                  sender.setOn(false, animated: true)
                })
                self.present(alert, animated: true)
                
              case .denied:
                // already denied in Settings — guide them to Settings.app
                let alert = UIAlertController(
                  title: "Notifications Disabled",
                  message: "To enable, go to Settings → Notifications → YourApp.",
                  preferredStyle: .alert
                )
                alert.addAction(.init(title: "Open Settings", style: .default) { _ in
                  UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                })
                alert.addAction(.init(title: "Cancel", style: .cancel) { _ in
                  sender.setOn(false, animated: true)
                })
                self.present(alert, animated: true)
                
              case .authorized, .provisional, .ephemeral:
                UIApplication.shared.registerForRemoteNotifications()
                
              @unknown default:
                sender.setOn(false, animated: true)
              }
              
            } else {
              // unregister & clear delivered/pending notifications
              UIApplication.shared.unregisterForRemoteNotifications()
              center.removeAllPendingNotificationRequests()
              center.removeAllDeliveredNotifications()
              UIApplication.shared.applicationIconBadgeNumber = 0
            }
          }
        }
    }
    
    @IBAction func darkModeSwitchChanged(_ sender: UISwitch) {
        let dark = sender.isOn
        UserDefaults.standard.set(dark, forKey: "isDarkMode")
        applyStyle(dark: dark)
    }
    
    private func applyStyle(dark: Bool) {
        let style: UIUserInterfaceStyle = dark ? .dark : .light

        UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap     { $0.windows }
          .forEach { window in
            UIView.transition(
              with: window,
              duration: 0.3,
              options: .transitionCrossDissolve,
              animations: {
                window.overrideUserInterfaceStyle = style
                window.backgroundColor = UIColor(named: "AppBackground")
              },
              completion: nil
            )
          }
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // retrieve and show profile picture
    func getProfilePic() {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            profilePic.image = UIImage(systemName: "person.crop.circle")
            return
        }
        let userId = user.uid
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let profilePicRef = storageRef.child("\(userId)/profile_pic.jpg")
        profilePicRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("Error fetching profile picture: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.profilePic.image = UIImage(systemName: "person.crop.circle")
                }
                return
            }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.profilePic.image = image
                }
            }
        }
    }
    
    
    func exportAllPicsAndChallengesToPhotos() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let baseRef = Storage.storage().reference().child(currentUID)

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Photos access denied.")
                return
            }
            
            DispatchQueue.main.async {
                self.showExportProgressView()
            }
            
            
            let group = DispatchGroup()
            var totalImages = 0
            var completedImages = 0

            func updateProgress() {
                DispatchQueue.main.async {
                    let progress = Float(completedImages) / Float(max(totalImages, 1))
                    self.progressBar?.setProgress(progress, animated: true)
                    self.progressLabel?.text = "Exporting photos... (\(completedImages)/\(totalImages))"
                }
            }

            func exportAndCount(from folder: StorageReference) {
                group.enter()
                folder.listAll { result, error in
                    guard let items = result?.items else {
                        group.leave()
                        return
                    }

                    totalImages += items.count
                    let innerGroup = DispatchGroup()

                    for imageRef in items {
                        innerGroup.enter()
                        imageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                            if let data = data, let image = UIImage(data: data) {
                                PHPhotoLibrary.shared().performChanges({
                                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                                }) { success, error in
                                    completedImages += 1
                                    updateProgress()
                                    innerGroup.leave()
                                }
                            } else {
                                completedImages += 1
                                updateProgress()
                                innerGroup.leave()
                            }
                        }
                    }

                    innerGroup.notify(queue: .main) {
                        group.leave()
                    }
                }
            }

            // Start exporting
            exportAndCount(from: baseRef.child("all_pics"))

            baseRef.child("challenges").listAll { result, error in
                for folder in result?.prefixes ?? [] {
                    exportAndCount(from: folder)
                }

                group.notify(queue: .main) {
                    self.hideExportProgressView()
                    let doneAlert = UIAlertController(title: "Done", message: "All photos have been exported!", preferredStyle: .alert)
                    doneAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(doneAlert, animated: true)
                }
            }
        }
    }

    func exportImages(in folder: StorageReference) {
        folder.listAll { result, error in
            if let error = error {
                print("Error listing items in \(folder.fullPath): \(error.localizedDescription)")
                return
            }

            for imageRef in result!.items {
                imageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    if let error = error {
                        print("Error downloading \(imageRef.fullPath): \(error.localizedDescription)")
                        return
                    }

                    guard let data = data, let image = UIImage(data: data) else { return }

                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        if success {
                            print("Saved: \(imageRef.name)")
                        } else {
                            print("Failed saving \(imageRef.name): \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
        }
        
    }
    
    func showExportProgressView() {
        let backgroundView = UIView(frame: CGRect(x: 40, y: self.view.center.y - 40, width: self.view.frame.width - 80, height: 100))
        backgroundView.backgroundColor = UIColor.systemBackground
        backgroundView.layer.cornerRadius = 12
        backgroundView.layer.shadowOpacity = 0.3
        backgroundView.layer.shadowRadius = 6
        backgroundView.layer.shadowOffset = CGSize(width: 0, height: 2)

        let label = UILabel(frame: CGRect(x: 10, y: 10, width: backgroundView.frame.width - 20, height: 20))
        label.text = "Exporting photos..."
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)

        let progress = UIProgressView(progressViewStyle: .default)
        progress.frame = CGRect(x: 10, y: 50, width: backgroundView.frame.width - 20, height: 10)
        progress.progress = 0.0
        progress.tintColor = .systemBlue

        backgroundView.addSubview(label)
        backgroundView.addSubview(progress)

        self.view.addSubview(backgroundView)

        self.exportProgressView = backgroundView
        self.progressBar = progress
        self.progressLabel = label
    }
    
    func hideExportProgressView() {
        DispatchQueue.main.async {
            self.exportProgressView?.removeFromSuperview()
            self.exportProgressView = nil
            self.progressBar = nil
            self.progressLabel = nil
        }
    }


    
    
    
}
