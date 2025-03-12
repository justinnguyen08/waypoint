//
//  LoginViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/8/25.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {
    
    
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var errorLabel: UILabel!
    
    let loginSegueIdentifier = "loginSuccessfulSegue"
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do{
            try Auth.auth().signOut()
        }
        catch let error as NSError{
            errorLabel.text = "error signing out"
        }

        // Do any additional setup after loading the view.
        Auth.auth().addStateDidChangeListener(){
            (auth, user) in
            if user != nil{
                self.performSegue(withIdentifier: self.loginSegueIdentifier, sender: nil)
                self.emailTextField.text = nil
                self.passwordTextField.text = nil
            }
        }
    }
    

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
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
