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
        
    }
    
    // create account into firebase
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        Auth.auth().createUser(withEmail: validEmail, password: validPassword) { authResult, error in
            if let error = error as NSError? {
                self.statusLabel.text = "\(error.localizedDescription)"
                return
            } else {
                self.statusLabel.text = ""
            }
            
            // Ensure user authentication was successful before proceeding
            guard let userID = Auth.auth().currentUser?.uid else { return }

            // Add a new document with the user's ID
            let userData: [String: Any] = [
                "birthday": "Ada",
                "friends": [],
                "phoneNumber": "Lovelace",
                "nickname": "Lovelace",
                "score": 1,
                "streak": 1,
                "username": "Ada"
            ]

            FirestoreManager.shared.db.collection("users").document(userID).setData(userData) { error in
                if let error = error {
                    print("Error adding document: \(error)")
                } else {
                    print("Document successfully added for user ID: \(userID)")
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
