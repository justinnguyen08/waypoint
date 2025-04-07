//  Project: Waypoint
//  Course: CS371L
//
//  ViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 2/28/25.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

public struct User {
    let uid: String
//    let email: String
    let username: String
//    let photoURL: String
}

public var addFriendsArray: [User] = []
public var removeFriendsArray: [User] = []
public var pendingFriendsArray: [User] = []

class FriendController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var friendProfileView: UITableView!
    @IBOutlet weak var pendingFriendView: UITableView!
    @IBOutlet weak var suggestedFriendView: UITableView!
    
    @IBOutlet weak var segCtrl: UISegmentedControl!
    
    @IBOutlet weak var currentFriendsView: UIView!
    @IBOutlet weak var suggestFriendView: UIView!
    
    
    let db = Firestore.firestore()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        friendProfileView.delegate = self
        friendProfileView.dataSource = self
        pendingFriendView.delegate = self
        pendingFriendView.dataSource = self
        suggestedFriendView.delegate = self
        suggestedFriendView.dataSource = self
        suggestFriendView.isHidden = true
        currentFriendsView.isHidden = false
        // Do any additional setup after loading the view.
        
        suggestedFriend()
        
        guard let uid = Auth.auth().currentUser?.uid else {
                print("User not authenticated")
                return
        }

        getCurrentFriend(uid: uid)
        pendingFriends(uid: uid)
        
        print(removeFriendsArray)
        
        
        pendingFriendView.reloadData()
        suggestedFriendView.reloadData()
        friendProfileView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else {
                print("User not authenticated")
                return
        }
        suggestedFriend()
        pendingFriends(uid: uid)
        getCurrentFriend(uid: uid)
        pendingFriendView.reloadData()
        suggestedFriendView.reloadData()
        friendProfileView.reloadData()
    }
    
    func pendingFriends(uid: String) {
        db.collection("users").document(uid).getDocument { (document, error) in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                print("Document Data: \(document.data() ?? [:])")  // Debugging print

                // Fetch the pendingFriends array
                if let pendingFriendsData = document.data()?["pendingFriends"] as? [[String: Any]] {
                    print("Pending Friends Data: \(pendingFriendsData)")  // Debugging print
                    
                    var pendingList: [User] = []
                    
                    // Iterate through the pending friends array
                    for friendInfo in pendingFriendsData {
                        if let uid = friendInfo["uid"] as? String,
                           let username = friendInfo["username"] as? String {
                            let friend = User(uid: uid, username: username)
                            pendingList.append(friend)
                        }
                    }
                    
                    // Update the pendingFriendsArray
                    pendingFriendsArray = pendingList
                    
                    // Reload the table view to display the changes
                    DispatchQueue.main.async {
                        self.pendingFriendView.reloadData()
                    }
                } else {
                    print("No pending friends data found")
                }
            } else {
                print("Document does not exist or failed to fetch data")
            }
        }
    }

    
    func suggestedFriend() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user logged in")
            return
        }
        db.collection("users").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching users: \(error.localizedDescription)")
                return
            }
            var fetchedUsers: [User] = [] // Temporary array to store users
            for document in snapshot!.documents {
                let data = document.data()
                let user = User(
                    uid: data["uid"] as? String ?? "Unknown UID",
                    username: data["username"] as? String ?? "No Name"
                )
                
                if document.documentID != currentUser.uid {
                    fetchedUsers.append(user)
                }
                addFriendsArray = fetchedUsers
            }
        }
    }

    
    func getCurrentFriend(uid: String) {
        db.collection("users").document(uid).getDocument { (document, error) in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                print("Document Data: \(document.data() ?? [:])")

                // Fetch the friends array
                if let friendsData = document.data()?["friends"] as? [[String: Any]] {
                    print("Current Friends Data: \(friendsData)")

                    var friendsList: [User] = []

                    // Iterate through the friends array
                    for friendInfo in friendsData {
                        if let uid = friendInfo["uid"] as? String,
                           let username = friendInfo["username"] as? String {
                            let friend = User(uid: uid, username: username)
                            friendsList.append(friend)
                        }
                    }

                    // Update the removeFriendsArray
                    removeFriendsArray = friendsList

                    // Reload the table view to reflect changes
                    DispatchQueue.main.async {
                        self.friendProfileView.reloadData()
                    }
                } else {
                    print("No current friends data found")
                }
            } else {
                print("Document does not exist or failed to fetch data")
            }
        }
    }

    
    
    @IBAction func friendSegCtlrPressed(_ sender: Any) {
        // Depending on what segctrl is clicked I changed the view
        switch segCtrl.selectedSegmentIndex {
        case 0:
            suggestFriendView.isHidden = true
            currentFriendsView.isHidden = false
            
            friendProfileView.reloadData()
        case 1:
            suggestFriendView.isHidden = false
            currentFriendsView.isHidden = true
        
            suggestedFriendView.reloadData()
            pendingFriendView.reloadData()
        default:
            print("Should Not happen")
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segCtrl?.selectedSegmentIndex == 0 {
            return removeFriendsArray.count
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            return pendingFriendsArray.count
        } else {
            return addFriendsArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segCtrl?.selectedSegmentIndex == 0 {
            let cell: CustomTableViewCell = friendProfileView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as! CustomTableViewCell
            cell.customProfileName.text = removeFriendsArray[indexPath.row].username  // Extract display name
            return cell
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            let cell: PendingCustomTableViewCell = pendingFriendView.dequeueReusableCell(withIdentifier: "pendingCell", for: indexPath) as! PendingCustomTableViewCell
            cell.pendingProfileName.text = pendingFriendsArray[indexPath.row].username  // Extract display name
            return cell
        } else {
            let cell: SuggestedCustomViewTableCell = suggestedFriendView.dequeueReusableCell(withIdentifier: "suggestCell", for: indexPath) as! SuggestedCustomViewTableCell
            cell.profileName.text = addFriendsArray[indexPath.row].username  // Extract display name
            return cell
        }
    }

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // code to deselect the rows once they are clicked
        if segCtrl?.selectedSegmentIndex == 1 && tableView == suggestedFriendView {
            tableView.deselectRow(at: indexPath, animated: true)
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            tableView.deselectRow(at: indexPath, animated: true)
        } else if segCtrl?.selectedSegmentIndex == 0 {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addSegue",
           let destinationVC = segue.destination as? AddFriendViewController,
           let indexPath = suggestedFriendView.indexPathForSelectedRow {
                var selectedUser: User
                selectedUser = addFriendsArray[indexPath.row]
                destinationVC.selectedUsernameA = selectedUser.username
        } else if segue.identifier == "pendingSegue", let destinationVC = segue.destination as? PendingViewController, let indexPath = pendingFriendView.indexPathForSelectedRow {
            var selectedUser: User
            selectedUser = pendingFriendsArray[indexPath.row]
            destinationVC.selectedUsername = selectedUser.username
        } else if segue.identifier == "removeSegue", let destinationVC = segue.destination as? RemoveViewController, let indexPath = friendProfileView.indexPathForSelectedRow {
            var selectedUser: User
//            print(removeFriendsArray)
            selectedUser = removeFriendsArray[indexPath.row]
            destinationVC.selectedUsername = selectedUser.username
        }
    }

    
    
    
}

