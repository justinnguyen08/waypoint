//  Project: Waypoint
//  Course: CS371L
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
    @IBOutlet weak var noDataLabel: UILabel!
    
    // variables for controlling the feed
    var feed: [FeedInfo] = []
    var allUIds: [String] = []
    var didDailyChallenge: Bool = false
    var didMonthChallenge: [Bool] = [false, false, false, false, false]
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
    }
    
    // When the view appears, recreate the feed
    override func viewWillAppear(_ animated: Bool) {
        tableView.isHidden = true
        noDataLabel.isHidden = false
        getAllUsers{
            self.loadTableInformation()
        }
    }
    
    // get all of the current user's friends and set up which challenge photos to look for
    func getAllUsers(handler: @escaping () -> Void){
        guard let uid = Auth.auth().currentUser?.uid else{
            print("user is not logged in")
            return
        }
        db.collection("users").document(uid).getDocument(){
            (document, error) in
            if let error = error{
                print("Error fetching logged in user document: \(error.localizedDescription)")
                return
            }
            else{
                if let document = document, let data = document.data(),
                   let getDailyChallenge = data["getDailyChallenge"] as? TimeInterval,
                   let didMonthlyChallenges = data["didMonthlyChallenges"] as? [Bool],
                   let currentUserFriendsList = data["friends"] as? [[String: Any]]{

                    let calendar = Calendar.current
                    self.didDailyChallenge = calendar.isDateInToday(Date(timeIntervalSince1970: getDailyChallenge))
                    self.didMonthChallenge = didMonthlyChallenges
                    self.allUIds = [uid]
                    for entry in currentUserFriendsList{
                        self.allUIds.append(entry["uid"] as! String)
                    }
                    handler()
                }
                else{
                    print("Error fetching logged in user document")
                }
            }
        }
    }
    
    // grab information from Firebase and update the table
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
                    
                    // get that user's profile picture
                    // if we cannot get that user's profile picture abandon that user
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
                            // only get them if the logged in user has also completed that challenge
                            if self.didDailyChallenge{
                                dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
                                    [weak self] (data, error) in
                                    if let error = error{
                                        print("Error fetching daily photo for \(uid): \(error.localizedDescription)")
                                    }
                                    else{
                                        if let data = data, let image = UIImage(data: data){
                                            newFeedMainPicture = image
                                            let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "daily", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComments, uid: uid, monthlyChallngeIndex: -1)
                                            self?.feed.append(dailyImageIntoFeed)
                                            self?.tableView.reloadData()
                                            self?.tableView.isHidden = false
                                            self?.noDataLabel.isHidden = true
                                        }
                                    }
                                }
                            }
                            
                            // get all of their monthly challenge if it exists
                            // only get them if the logged in user has also completed that challenge
                            for index in 1..<6{
                                let monthlyChallengePicRef = storageRef.child("\(uid)/challenges/monthlyChallenges/\(index - 1).jpg")
                                
                                if self.didMonthChallenge[index - 1]{
                                    monthlyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
                                        [weak self] (data, error) in
                                        if let error = error{
                                            print("Error fetching monthly photo for \(uid): \(error.localizedDescription)")
                                        }
                                        else{
                                            if let data = data, let image = UIImage(data: data){
                                                let newFeedMainPicture = image
                                                let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "monthly", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComments, uid: uid, monthlyChallngeIndex: index)
                                                self?.feed.append(dailyImageIntoFeed)
                                                self?.tableView.reloadData()
                                                self?.tableView.isHidden = false
                                                self?.noDataLabel.isHidden = true
                                            }
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
    
    // table view specific functions (conforming)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! FeedTableViewCell
        let cInfo = feed[indexPath.row]
        cell.selectionStyle = .none
        cell.usernameLabel.text = cInfo.username
        cell.typeLabel.text = "\(cInfo.indicator!)" + "\(cInfo.indicator! == "monthly" ? " challenge \(String(cInfo.monthlyChallengeIndex))" : "")"
        cell.profilePictureView.image = cInfo.profilePicture
        cell.mainImageView.image = cInfo.mainPicture
        return cell
    }
}
