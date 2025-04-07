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
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user loggin in")
            return
        }
        
        db.collection("users").getDocuments {
            (snapshot, error) in
            if let error = error{
                print("Error fetching users: \(error.localizedDescription)")
                return
            }
            
            var fetchedUIDs: [String] = []
            for document in snapshot!.documents{
                let data = document.data()
                fetchedUIDs.append(document.documentID as! String)
            }
            
            self.allUIds = fetchedUIDs
            completion()
        }
    }
    
    
    func loadTableInformation(){
        // get a list of all users!
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let currentMomentInTime = Date()
        let weekdayIndex = Calendar.current.component(.weekday, from: currentMomentInTime)
        
        for uid in allUIds{
            
            let dailyChallengePicRef = storageRef.child("\(uid)/challenges/dailyChallenge/\(weekdayIndex).jpg")
            
            let profilePicRef = storageRef.child("\(uid)/profile_pic.jpg")
            
            var newFeedUsername: String!
            var newFeedProfilePicture: UIImage!
            
            db.collection("users").document(uid).getDocument() { document, error in
                if let error = error{
                    print("Error reading user document: \(error.localizedDescription)")
                    return
                }
                if let data = document?.data(){
                    newFeedUsername = data["username"] as? String
                }
                else{
                    print("Error getting document")
                }
            }
            
            
            profilePicRef.getData(maxSize: 10 * 1024 * 1024) {
                 data, error in
                if let error = error{
                    print("Error fetching profile picture for \(uid)")
                    return
                }
                if let data = data, let image = UIImage(data: data){
                    newFeedProfilePicture = image
                }
            }
            var newFeedMainPicture: UIImage!
            var newFeedLikes = 0
            var newFeedComemnts: [CommentInfo] = []
            
            
            dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) {
                [weak self] data, error in
                if let error = error{
                    print("Error fetching daily photo for \(uid)")
                }
                else{
                    if let data = data, let image = UIImage(data: data){
                        newFeedMainPicture = image
                        let dailyImageIntoFeed = FeedInfo(username: newFeedUsername, indicator: "daily", profilePicture: newFeedProfilePicture, mainPicture: newFeedMainPicture, likes: newFeedLikes, comments: newFeedComemnts, uid: uid)
                        self?.feed.append(dailyImageIntoFeed)
                    }
                }
            }
            
//            for index in 1..<6{
//                let dailyChallengePicRef = storageRef.child("\(uid)/challenges/monthlyChallenges/\(index).jpg")
//                
//                
//                
//                
//            }
            
            
            
            
//            dailyChallengePicRef.getData(maxSize: 10 * 1024 * 1024) { [weak self] data, error in
//                if let error = error {
//                    print("Error fetching monthly challenge photo: \(error.localizedDescription)")
//                }
//                if let data = data, let image = UIImage(data: data) {
//                    
//                }
//            }
        }
        print("The table has \(feed.count) entries")
        tableView.reloadData()
        
        
        
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as! FeedTableViewCell
        
        var cInfo = feed[indexPath.row]
        
        cell.usernameLabel.text = cInfo.username
        cell.typeLabel.text = cInfo.indicator
        cell.profilePictureView.image = cInfo.profilePicture
        cell.mainImageView.image = cInfo.mainPicture
        
        return cell
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
