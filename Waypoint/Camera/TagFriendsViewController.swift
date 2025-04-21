//  Project: Waypoint
//  Course: CS371L
//
//  TagFriendsViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 3/11/25.
//

import UIKit
import FirebaseFirestore


struct TagEntry{
    let profilePicture: UIImage
    let username: String
    let uid: String
    var isTagged: Bool
}

class TagFriendsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tagFriendsTableView: UITableView!
    
    var uid: String!
    var delegate: OpenCamViewController!
    var postID: String!
    let manager = FirebaseManager()
    
    var tableInformation: [TagEntry] = []
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tagFriendsTableView.delegate = self
        tagFriendsTableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task{
            let friends = await self.manager.getFriendsList(uid: uid)
            if let friends = friends{
                await withTaskGroup(of: TagEntry?.self) { group in
                    for friend in friends{
                        group.addTask{
                            let profilePicture = await self.manager.getProfilePicture(uid: friend["uid"] as! String)
                            
                            if let picture = profilePicture{
                                return TagEntry(profilePicture: picture, username: friend["username"] as! String, uid: friend["uid"] as! String, isTagged: false)
                            }
                            else{
                                return nil
                            }
                        }
                    }
                    
                    for await result in group{
                        if let result = result{
                            self.tableInformation.append(result)
                        }
                    }
                }
            }
            tagFriendsTableView.reloadData()
        }
    }
    
    func tagSomeone(uidToTag: String, index: Int) async -> Bool{
        
        let postReference = db.collection("mapPosts").document(postID)
        
        // copied from https://firebase.google.com/docs/firestore/manage-data/transactions
        do {
            var didTag: Bool = false
          let _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let postDocument: DocumentSnapshot
            do {
              try postDocument = transaction.getDocument(postReference)
            } catch let fetchError as NSError {
              errorPointer?.pointee = fetchError
              return false
            }

            guard var oldTags = postDocument.data()?["tagged"] as? [String] else {
              let error = NSError(
                domain: "AppErrorDomain",
                code: -1,
                userInfo: [
                  NSLocalizedDescriptionKey: "Unable to retrieve population from snapshot \(postDocument)"
                ]
              )
              errorPointer?.pointee = error
              return false
            }
              if oldTags.contains(uidToTag){
                  oldTags.removeAll { $0 == uidToTag }
              }
              else{
                  oldTags.append(uidToTag)
                  didTag = true
              }
              
              DispatchQueue.main.async {
                  self.tableInformation[index].isTagged = didTag
                  self.tagFriendsTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
              }
            transaction.updateData(["tagged": oldTags], forDocument: postReference)
              return didTag
          })
            print("Transaction successfully committed!")
            return didTag
        } catch {
          print("Transaction failed: \(error)")
        }
        return false
    }
    
    // Setting up table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableInformation.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath) as! TagTableViewCell
        let currentInfo = tableInformation[indexPath.row]
        cell.profilePictureView.image = currentInfo.profilePicture
        cell.usernameLabel.text = currentInfo.username
        cell.tagIndex = indexPath.row
        cell.uid = currentInfo.uid
        cell.prevVC = self
        
        if currentInfo.isTagged{
            cell.tagButton.setTitle("Untag", for: .normal)
        }
        else{
            cell.tagButton.setTitle("Tag", for: .normal)
        }
        return cell
    }
}
