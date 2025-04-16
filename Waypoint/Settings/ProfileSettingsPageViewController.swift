//  Project: Waypoint
//  Course: CS371L
//
//  ProfileSettingsPageViewController.swift
//  Waypoint
//
//  Created by Justin Nguyen on 4/16/25.
//

import UIKit
import AVFoundation
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class ProfileSettingsPageViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var picker = UIImagePickerController()
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    
    private var selectedProfileImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        picker.delegate = self
        profilePic.layer.cornerRadius = profilePic.frame.width / 2
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        getProfilePic()
    }
    
    @IBAction func uploadPhotoButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: "Profile Picture",
                                          message: "Choose a source",
                                          preferredStyle: .actionSheet)
            
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
          alert.addAction(.init(title: "Take Photo", style: .default) { _ in
            self.presentPicker(source: .camera)
          })
        }
        alert.addAction(.init(title: "Photo Library", style: .default) { _ in
          self.presentPicker(source: .photoLibrary)
        })
        alert.addAction(.init(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
        
    }
    
    private func presentPicker(source: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = source
        picker.allowsEditing = true       // let user crop
        present(picker, animated: true)
    }
    
    @IBAction func saveAndExitTapped(_ sender: Any) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        // only send non‑empty values
        let nickInput = nicknameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userInput = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var updates = [String: Any]()
        if !nickInput.isEmpty { updates["nickname"] = nickInput }
        if !userInput.isEmpty { updates["username"] = userInput }
        
        func finish() {
          if let nav = self.navigationController {
            nav.popViewController(animated: true)
          } else {
            self.dismiss(animated: true, completion: nil)
          }
        }
        
        // update in firebase first if possible
        if !updates.isEmpty {
            userRef.updateData(updates) { error in
            if let error = error {
              print("Firestore error:", error)
              finish()
              return
            }
            // uplaod image if possible
            self.uploadImageIfNeeded(uid: uid, completion: finish)
          }
        } else {
          // no text update, chcek image
          uploadImageIfNeeded(uid: uid, completion: finish)
        }
    }
    
    // upload the selected image if present
    private func uploadImageIfNeeded(uid: String, completion: @escaping ()->Void) {
        guard let image = selectedProfileImage,
              let data = image.jpegData(compressionQuality: 0.8) else {
            
              completion()
              return
        }
        let ref = Storage.storage().reference().child("\(uid)/profile_pic.jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        
        ref.putData(data, metadata: meta) { _, error in
          if let error = error {
            print("Storage error:", error)
          }
          completion()
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
      
    func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let key: UIImagePickerController.InfoKey = info[.editedImage] != nil ? .editedImage : .originalImage
        guard let image = info[key] as? UIImage else { return }
        
        // preview
        profilePic.image = image
        
        selectedProfileImage = image

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
}
