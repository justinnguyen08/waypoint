//  Project: Waypoint
//  Course: CS371L
//
//  CreateAccountViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/8/25.
//

import UIKit
import FirebaseAuth

class CreateAccountViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    // from CS371L Code Library
    func isValidEmail(_ email: String) -> Bool {
       let emailRegEx =
           "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
       let emailPred = NSPredicate(format:"SELF MATCHES %@",
           emailRegEx)
       return emailPred.evaluate(with: email)
    }
      
    func isValidPassword(_ password: String) -> Bool {
       let minPasswordLength = 6
       return password.count >= minPasswordLength
    }
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        if (isValidEmail(emailTextField.text!) && isValidPassword(passwordTextField.text!)){
            performSegue(withIdentifier: "AdditionalInfoSegue", sender: self)
        }
        else{
            self.errorLabel.text = "Invalid email or password"
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
    
    // send the data over to the next screen to continue creating the account
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "AdditionalInfoSegue",
           let nextVC = segue.destination as? CreateAccountAdditionalInfoViewController{
                nextVC.validEmail = emailTextField.text!
                nextVC.validPassword = passwordTextField.text!
        }
    }
    
}
