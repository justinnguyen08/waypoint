//  Project: Waypoint
//  Course: CS371L
//
//  LoginViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/8/25.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController,UITextFieldDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBOutlet weak var logoImage: UIImageView!
    @IBOutlet weak var errorLabel: UILabel!
    
    let loginSegueIdentifier = "loginSuccessfulSegue"
   
    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.delegate = self
        passwordTextField.delegate = self
        logoImage.image = UIImage(named: "Waypoint-Logo")
        // sign out
        do{
            try Auth.auth().signOut()
        }
        catch let error as NSError{
            errorLabel.text = "error signing out"
        }
        
        // if we are a valid user then segue into main screen
        Auth.auth().addStateDidChangeListener(){
            (auth, user) in
            if user != nil{
                self.performSegue(withIdentifier: self.loginSegueIdentifier, sender: nil)
                self.emailTextField.text = nil
                self.passwordTextField.text = nil
            }
        }
    }
    
    // attempt to sign in if the login button is pressed
    @IBAction func loginButtonPressed(_ sender: Any) {
        Auth.auth().signIn(withEmail: emailTextField.text!, password: passwordTextField.text!){
            (authResult, error) in
            if let error = error as NSError?{
                self.errorLabel.text = "\(error.localizedDescription)"
            }
            else{
                self.errorLabel.text = ""
            }
        }
    }
    
    // Keyboard dismissal functions
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}
