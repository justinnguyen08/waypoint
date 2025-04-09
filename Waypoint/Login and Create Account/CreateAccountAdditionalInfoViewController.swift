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

class CreateAccountAdditionalInfoViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var profilePicture: UIImageView!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var birthdayTextField: UITextField!
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    
    var validEmail: String!
    var validPassword: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nicknameTextField.delegate = self
        // Do any additional setup after loading the view.
    }
    
    // upload profile picture
    @IBAction func uploadPhotoButtonPressed(_ sender: Any) {
        // no functionality yet, but it is complete in profile settings
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
                            "didMonthlyChallenge": [false, false, false, false, false],
                            "getDailyChallenge": 0,
                            "weeklyChallengeScore": 0,
                            "monthlyChallengeScore": 0,
                            "challengeStreak": 0,
                            "lastChallengeCompletedDate": 0,
                            "Location": GeoPoint(latitude: 30.2672, longitude: -97.7431),
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
                    }
                }
        }
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
