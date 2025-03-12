//
//  CreateAccountAdditionalInfoViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/8/25.
//

import UIKit
import FirebaseAuth

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
    
    
    @IBAction func uploadPhotoButtonPressed(_ sender: Any) {
    }
    
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        
        Auth.auth().createUser(withEmail: validEmail,
                               password: validPassword) {
            (authResult,error) in
            if let error = error as NSError? {
                self.statusLabel.text = "\(error.localizedDescription)"
            } else {
                self.statusLabel.text = ""
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
