//  Project: Waypoint
//  Course: CS371L
//
//  CreateAccountAdditionalInfoViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/8/25.
//

import UIKit
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage

class CreateAccountAdditionalInfoViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    
    var validEmail: String!
    var validPassword: String!
    
    var picker = UIImagePickerController()
    private var selectedProfileImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nicknameTextField.delegate = self
        picker.delegate = self
        profilePic.layer.cornerRadius = profilePic.frame.width / 2
        profilePic.clipsToBounds = true
        profilePic.contentMode = .scaleAspectFill
        profilePic.layer.borderColor = UIColor.black.cgColor
        profilePic.layer.borderWidth = 1
    }
    
    // upload profile picture
    @IBAction func uploadPhotoButtonPressed(_ sender: Any) {
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
    
    // create account into firebase
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        
        let enteredUsername = usernameTextField.text ?? ""	
        let db = Firestore.firestore()
        
        // check if username is unique
        db.collection("users").whereField("username", isEqualTo: enteredUsername)
            .getDocuments { [weak self] (querySnapshot, error) in
                if let error = error {
                    // add ui changes to main dispatch queue
                    DispatchQueue.main.async {
                        self?.statusLabel.text = "Error checking username: \(error.localizedDescription)"
                    }
                    return
                }
                
                if let snapshot = querySnapshot, !snapshot.documents.isEmpty {
                    DispatchQueue.main.async {
                        self?.statusLabel.text = "Username is already taken. Please choose another."
                    }
                    return
                } else {
                    Auth.auth().createUser(withEmail: self!.validEmail, password: self!.validPassword) { authResult, error in
                        if let error = error {
                            DispatchQueue.main.async {
                                self?.statusLabel.text = error.localizedDescription
                            }
                            return
                        } else {
                            DispatchQueue.main.async {
                                self?.statusLabel.text = ""
                            }
                        }
                        
                        guard let userID = Auth.auth().currentUser?.uid else { return }

                        let userData: [String: Any] = [
                            "friends": [],
                            "nickname": self!.nicknameTextField.text ?? "",
                            "score": 0,
                            "streak": 0,
                            "username": enteredUsername,
                            "pendingFriends": [],
                            "didMonthlyChallenges": [false, false, false, false, false],
                            "getDailyChallenge": 0,
                            "weeklyChallengeScore": 0,
                            "monthlyChallengeScore": 0,
                            "challengeStreak": 0,
                            "lastChallengeCompletedDate": 0,
                            "location": GeoPoint(latitude: 30.2672, longitude: -97.7431),
                            "lastDailyPhotoDate": 0
                        ]
                        db.collection("users").document(userID).setData(userData) { error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    self?.statusLabel.text = "Error adding document: \(error.localizedDescription)"
                                } else {
                                    self?.statusLabel.text = "Account successfully created!"
                                }
                            }
                        }
                        
                        // updating user's profile image
                        guard let image = self!.selectedProfileImage,
                              let data = image.jpegData(compressionQuality: 0.8) else {
                              return
                        }
                        let ref = Storage.storage().reference().child("\(userID)/profile_pic.jpg")
                        let meta = StorageMetadata()
                        meta.contentType = "image/jpeg"
                        
                        ref.putData(data, metadata: meta) { _, error in
                          if let error = error {
                            print("Storage error:", error)
                          }
                            print("profile picture from registration uploaded")
                        }
                    }
                }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
      
    // when image is picked from picker display that image as selected profile picture
    func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let key: UIImagePickerController.InfoKey = info[.editedImage] != nil ? .editedImage : .originalImage
        guard let image = info[key] as? UIImage else { return }
        
        // preview
        profilePic.image = image
        
        selectedProfileImage = image

    }
    
    // Called when 'return' key pressed
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

    
