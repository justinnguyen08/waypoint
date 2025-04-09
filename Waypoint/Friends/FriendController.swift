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
import FirebaseStorage

public struct User {
    let uid: String
    let username: String
}

public var addFriendsArray: [User] = []     // all users
public var removeFriendsArray: [User] = []  // current friends
public var pendingFriendsArray: [User] = [] // pending friends
public var suggestedFriends: [User] = []    // suggested friends

class FriendController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate,
                        UITextFieldDelegate{
    
    @IBOutlet weak var friendProfileView: UITableView!
    @IBOutlet weak var pendingFriendView: UITableView!
    @IBOutlet weak var suggestedFriendView: UITableView!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    @IBOutlet weak var segCtrl: UISegmentedControl!
    
    @IBOutlet weak var currentFriendsView: UIView!
    @IBOutlet weak var suggestFriendView: UIView!
    
    var filteredUsers: [User] = []
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        friendProfileView.delegate = self
        friendProfileView.dataSource = self
        pendingFriendView.delegate = self
        pendingFriendView.dataSource = self
        suggestedFriendView.delegate = self
        suggestedFriendView.dataSource = self
        searchBar.delegate = self
        
        suggestFriendView.isHidden = true
        currentFriendsView.isHidden = false
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated")
            return
        }
        
        // Loads all the data but makes sure that one happens after the other as they
        // depend on each other
        suggestedFriend {
            self.getCurrentFriend(uid: uid) {
                self.pendingFriends(uid: uid) {
                    addFriendsArray.removeAll { user in
                        // makes sure that the users that are not in pending and are already your friend
                        return removeFriendsArray.contains(where: { $0.uid == user.uid }) ||
                        pendingFriendsArray.contains(where: { $0.uid == user.uid })
                    }
                    DispatchQueue.main.async {
                        self.pendingFriendView.reloadData()
                        self.suggestedFriendView.reloadData()
                        self.friendProfileView.reloadData()
                    }
                    self.filteredUsers = addFriendsArray
                }
            }
        }
    }

    
    override func viewWillAppear(_ animated: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated")
            return
        }
        
        // Loads all the data but makes sure that one happens after the other as they
        // depend on each other
        suggestedFriend {
            self.getCurrentFriend(uid: uid) {
                self.pendingFriends(uid: uid) {
                    addFriendsArray.removeAll { user in
                        // makes sure that the users that are not in pending and are already your friend
                        return removeFriendsArray.contains(where: { $0.uid == user.uid }) ||
                        pendingFriendsArray.contains(where: { $0.uid == user.uid })
                    }
                    DispatchQueue.main.async {
                        self.pendingFriendView.reloadData()
                        self.suggestedFriendView.reloadData()
                        self.friendProfileView.reloadData()
                    }
                }
            }
        }
        filteredUsers = addFriendsArray
    }
    
    // get all the users that are in your pending users
    // https://medium.com/@dhavalkansara51/completion-handler-in-swift-with-escaping-and-nonescaping-closures-1ea717dc93a4
    // https://medium.com/@bestiosdevelope/what-do-mean-escaping-and-nonescaping-closures-in-swift-d404d721f39d
    func pendingFriends(uid: String, handler: @escaping () -> Void) {
        db.collection("users").document(uid).getDocument { (document, error) in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }

            // gets the data from the firestore storage
            if let document = document, document.exists {
                if let pendingFriendsData = document.data()?["pendingFriends"] as? [[String: Any]] {
                    var pendingList: [User] = []
                    for friendInfo in pendingFriendsData {
                        if let uid = friendInfo["uid"] as? String,
                           let username = friendInfo["username"] as? String {
                            let friend = User(uid: uid, username: username)
                            pendingList.append(friend)
                        }
                    }
                    pendingFriendsArray = pendingList
                    DispatchQueue.main.async {
                        self.pendingFriendView.reloadData()
                    }
                    handler() 
                } else {
                    print("No pending friends data found")
                }
            } else {
                print("Document does not exist or failed to fetch data")
            }
        }
    }
    
    // gets suggested users
    // https://medium.com/@dhavalkansara51/completion-handler-in-swift-with-escaping-and-nonescaping-closures-1ea717dc93a4
    // https://medium.com/@bestiosdevelope/what-do-mean-escaping-and-nonescaping-closures-in-swift-d404d721f39d
    func suggestedFriend(handler: @escaping () -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user logged in")
            return
        }
        // Get all users that are not you
        db.collection("users").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching users: \(error.localizedDescription)")
                return
            }
            var fetchedUsers: [User] = []
            for document in snapshot!.documents {
                let data = document.data()
                let user = User(
                    uid: document.documentID,
                    username: data["username"] as? String ?? "No Name"
                )
                if document.documentID != currentUser.uid {
                    fetchedUsers.append(user)
                }
            }
            addFriendsArray = fetchedUsers
            // Only shows like the first 10, but you can search for all the names
            suggestedFriends = Array(addFriendsArray.prefix(10))
            handler()
        }
    }
    
    // get current friends
    // https://medium.com/@dhavalkansara51/completion-handler-in-swift-with-escaping-and-nonescaping-closures-1ea717dc93a4
    // https://medium.com/@bestiosdevelope/what-do-mean-escaping-and-nonescaping-closures-in-swift-d404d721f39d
    func getCurrentFriend(uid: String, handler: @escaping () -> Void) {
        db.collection("users").document(uid).getDocument { (document, error) in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                return
            }
            // Get all the users that are listed as your friends
            if let document = document, document.exists {
                if let friendsData = document.data()?["friends"] as? [[String: Any]] {
                    var friendsList: [User] = []
                    for friendInfo in friendsData {
                        if let uid = friendInfo["uid"] as? String,
                           let username = friendInfo["username"] as? String {
                            let friend = User(uid: uid, username: username)
                            friendsList.append(friend)
                        }
                    }
                    removeFriendsArray = friendsList
                    DispatchQueue.main.async {
                        self.friendProfileView.reloadData()
                    }
                    handler()
                } else {
                    print("No current friends data found")
                }
            } else {
                print("Document does not exist or failed to fetch data")
            }
        }
    }

    
    @IBAction func friendSegCtlrPressed(_ sender: Any) {
        // Depending on what segctrl is clicked I change the view
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
    
    // Fetches the image from storage to for any reference such as profile or regular pics
    func fetchImage(from ref: StorageReference, for imageView: UIImageView, fallback: String) {
        imageView.image = UIImage(systemName: fallback)  
        ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("Error fetching \(ref.fullPath): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    imageView.image = UIImage(systemName: fallback)
                }
            } else if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }
        }
        imageView.layer.cornerRadius = imageView.frame.width / 2
        imageView.contentMode = .scaleAspectFill
    }
    
    // Get the count of the how many rows should show up
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segCtrl?.selectedSegmentIndex == 0 {
            return removeFriendsArray.count
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            return pendingFriendsArray.count
        } else {
            return filteredUsers.count
        }
    }
    
    // Depicts what each cell should be, with the profile pic, username, and buttons
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let storage = Storage.storage()
        if segCtrl?.selectedSegmentIndex == 0 {
            let cell: RemoveTableViewCell = friendProfileView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as! RemoveTableViewCell
            cell.customProfileName.text = removeFriendsArray[indexPath.row].username
            let profilePicRef = storage.reference().child("\(removeFriendsArray[indexPath.row].uid)/profile_pic.jpg")
            fetchImage(from: profilePicRef, for: cell.profilePic, fallback: "person.circle")
            cell.profilePic.layer.cornerRadius = cell.profilePic.frame.width / 2
            cell.profilePic.contentMode = .scaleAspectFill
            return cell
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            let cell: PendingCustomTableViewCell = pendingFriendView.dequeueReusableCell(withIdentifier: "pendingCell", for: indexPath) as! PendingCustomTableViewCell
            cell.pendingProfileName.text = pendingFriendsArray[indexPath.row].username
            let profilePicRef = storage.reference().child("\(pendingFriendsArray[indexPath.row].uid)/profile_pic.jpg")
            fetchImage(from: profilePicRef, for: cell.profilePicture, fallback: "person.circle")
            cell.profilePicture.layer.cornerRadius = cell.profilePicture.frame.width / 2
            cell.profilePicture.contentMode = .scaleAspectFill
            return cell
        } else {
            let cell: SuggestedCustomViewTableCell = suggestedFriendView.dequeueReusableCell(withIdentifier: "suggestCell", for: indexPath) as! SuggestedCustomViewTableCell
            cell.profileName.text = filteredUsers[indexPath.row].username
            let profilePicRef = storage.reference().child("\(filteredUsers[indexPath.row].uid)/profile_pic.jpg")
            fetchImage(from: profilePicRef, for: cell.profilePic, fallback: "person.circle")
            cell.profilePic.layer.cornerRadius = cell.profilePic.frame.width / 2
            cell.profilePic.contentMode = .scaleAspectFill
            cell.updateButtonState()
            return cell
        }
    }

    // code to deselect the rows once they are clicked
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if segCtrl?.selectedSegmentIndex == 1 && tableView == suggestedFriendView {
            tableView.deselectRow(at: indexPath, animated: true)
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            tableView.deselectRow(at: indexPath, animated: true)
        } else if segCtrl?.selectedSegmentIndex == 0 {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    // Makes sure to properly handle the segues
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
            selectedUser = removeFriendsArray[indexPath.row]
            destinationVC.selectedUsername = selectedUser.username
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            // If the search text is empty, show all users
            filteredUsers = addFriendsArray
        } else {
            // Filter the users based on the search text (case-insensitive)
            filteredUsers = addFriendsArray.filter { user in
                return user.username.lowercased().contains(searchText.lowercased())
            }
        }
        suggestedFriendView.reloadData()
    }

    // Clear search when cancel button is tapped
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filteredUsers = addFriendsArray
        suggestedFriendView.reloadData()
    }
    
    // Helps to dismiss the keyboard when the return is presed
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    // Helps to dismiss the keyboard when you click out of it
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}


