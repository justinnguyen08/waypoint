//  Project: Waypoint
//  Course: CS371L
//
//  RemoveViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 3/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseAuth

class RemoveViewController: UIViewController {
    
    @IBOutlet weak var username: UILabel!
    var selectedUsername: String?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        username.text = selectedUsername!
    }

    @IBAction func removeButtonPressed(_ sender: Any) {
        let uniqueUsername = username.text!
        let db = Firestore.firestore()
        let currentUser = Auth.auth().currentUser
        db.collection("users").document(currentUser!.uid).getDocument {
            (currentUserSnapshot, error) in
            if let error = error {
                print("Error fetching current user: \(error.localizedDescription)")
                return
            }
            guard let currentUserData = currentUserSnapshot?.data(),
                  let currentUsername = currentUserData["username"] as? String else { return }
            let currentUserStruct = User(uid: currentUser!.uid, username: currentUsername)
            let currentUserDict: [String: Any] = [
                "uid": currentUserStruct.uid,
                "username": currentUserStruct.username
            ]
            db.collection("users").whereField("username", isEqualTo: uniqueUsername).getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    return
                }
                if let documents = snapshot?.documents, !documents.isEmpty {
                    if let document = documents.first {
                        let targetUserUUID = document.documentID
                        print("Found user UUID: \(targetUserUUID)")
                        // Adding the current user in the target's database
                        db.collection("users").document(targetUserUUID).updateData([
                            "friends": FieldValue.arrayRemove([currentUserDict])
                        ]) { error in
                            if let error = error {
                                print("Error updating pendingUsers: \(error.localizedDescription)")
                            } else {
                                print("Successfully added \(currentUserStruct.username) to \(targetUserUUID)'s pendingUsers.")
                            }
                        }
                        // Adding the target in the current users' database
                        let targetUserDict: [String: Any] = [
                            "uid": targetUserUUID,
                            "username": uniqueUsername
                        ]
                        
                        db.collection("users").document(currentUser!.uid).updateData(["friends": FieldValue.arrayRemove([targetUserDict])]) {
                            error in
                            if let error = error {
                                print("Error updating friends: \(error.localizedDescription)")
                            } else {
                                print("Successfully added \(targetUserUUID) to \(currentUserStruct.username)'s friends.")
                            }
                        }
                    }
                } else {
                    print("No user found with username: \(uniqueUsername)")
                }
            }
            
        }
    }

}
