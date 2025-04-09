//
//  ChallengeFeedViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/28/25.
//

import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

class ChallengeFeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    var feed: [FeedInfo] = []
    var allUIds: [String] = []
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        getAllUsers{
            self.loadTableInformation()
        }
    }
    
    func getAllUsers(completion: @escaping () -> Void){
        db.collection("users").getDocuments {
            (snapshot, error) in
            if let error = error{
                print("Error fetching users: \(error.localizedDescription)")
                return
            }
            var fetchedUIDs: [String] = []
            for document in snapshot!.documents{
                fetchedUIDs.append(document.documentID)
            }
            self.allUIds = fetchedUIDs
            completion()
        }
    }
    
    
    func loadTableInformation(){
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let currentMomentInTime = Date()
        let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
        
        for uid in allUIds{
            
            let dailyChallengePicRef = storageRef.child("\(uid)/challenges/dailyChallenge/\(weekdayIndex).jpg")
            
            let profilePicRef = storageRef.child("\(uid)/profile_pic.jpg")
            
            var newFeedUsername: String!
            var newFeedProfilePicture: UIImage!
            
            // first ensure that we can access the user document from firebase
            db.collection("users").document(uid).getDocument() { document, error in
                if let error = error{
                    print("Error reading user document: \(error.localizedDescription)")
                }
                else if let data = document?.data(){
                    newFeedUsername = data["username"] as? String
                    
                    // get the user profile picture
                    profilePicRef.getData(maxSize: 10 * 1024 * 1024) {
                         data, error in
                        if let error = error{
                            print("Error fetching profile picture for \(uid): \(error.localizedDescription)")
                        }
                        else if let data = data, let image = UIImage(data: data){
                            
                            newFeedProfilePicture = image
                            var newFeedMainPicture: UIImage!
                            let newFeedLikes = 0
                            let newFeedComments: [CommentInfo] = []
                            
                            // get their daily challenge if it exists
                            dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
                                [weak self] data, error in
                                if let error = error{
                                    print("Error fetching daily photo for \(uid)")
                                }
                                else{
                                    if let data = data, let image = UIImage(data: data){
                                        newFeedMainPicture = image
                                        let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "daily", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComments, uid: uid)
                                        self?.feed.append(dailyImageIntoFeed)
                                        self?.tableView.reloadData()
                                    }
                                }
                            }
                            
                            // get their monthly challenge if it exists
                            for index in 1..<6{
                                let monthlyChallengePicRef = storageRef.child("\(uid)/challenges/monthlyChallenges/\(index).jpg")
                                
                                monthlyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
                                    [weak self] data, error in
                                    if let error = error{
                                        print("Error fetching monthly photo for \(uid): \(error.localizedDescription)")
                                    }
                                    else{
                                        if let data = data, let image = UIImage(data: data){
                                            let newFeedMainPicture = image
                                            let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "monthly", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComments, uid: uid)
                                            self?.feed.append(dailyImageIntoFeed)
                                            self?.tableView.reloadData()
                                            
                                        }
                                    }
                                }
                            }
                            
                        }
                    }
                }
                else{
                    print("Error getting document")
                }
            }
            
            
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! FeedTableViewCell
        
        let cInfo = feed[indexPath.row]
        cell.selectionStyle = .none
        
        cell.usernameLabel.text = cInfo.username
        cell.typeLabel.text = cInfo.indicator
        cell.profilePictureView.image = cInfo.profilePicture
        cell.mainImageView.image = cInfo.mainPicture
        
        return cell
    }

}
