//  Project: Waypoint
//  Course: CS371L
//
//  LeaderboardViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/4/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

// every leaderboard entry will have this format
struct LeaderboardEntry{
    let uid: String
    let profilePicture: UIImage
    let username: String
    let weeklyScore: Int
    let monthlyScore: Int
    let isFriend: Bool
    let location: String
}

class LeaderboardViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var scopeSegment: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var placeLabel: UILabel!
    
    @IBOutlet weak var pointsLabel: UILabel!
    
    var currentLeaderboardToDisplay: [LeaderboardEntry] = []
    var mockLeaderboard: [LeaderboardEntry] = []
    var leaderboardCellIdentifier = "LeaderboardCell"
    
    // store all UIDs that we care about
    var allUIds: [String] = []
    let db = Firestore.firestore()
    let manager = FirebaseManager()
    
    var currentDateScope = "weekly"
    var titleLabel = UILabel()
    
    var spinnerManager = SpinnerManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        scopeSegment.isHidden = true
        tableView.isHidden = true
        placeLabel.isHidden = true
        pointsLabel.isHidden = true
        
        scopeSegment.layer.cornerRadius = 16
        scopeSegment.clipsToBounds = true
        
        // sets the nav bar title at first
        titleLabel.text = "Leaderboard - Weekly"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 30)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.sizeToFit()
        let leftItem = UIBarButtonItem(customView: titleLabel)
        self.navigationItem.leftBarButtonItem = leftItem
        spinnerManager.showSpinner(view: view)
    }
    
    // load the users and update the leaderboard
    override func viewWillAppear(_ animated: Bool) {
        scopeSegment.selectedSegmentIndex = 0
        getAllUsers {
            self.loadTableInformation()
        }
    }
    
    // get every user that has an account in the app
    func getAllUsers(handler: @escaping () -> Void){
        db.collection("users").getDocuments {
            (snapshot, error) in
            if let error = error{
                print("Error fetching users: \(error.localizedDescription)")
                return
            }
            var fetchedUIDs: [String] = []
            for document in snapshot!.documents{
                if document.documentID != "example"{
                    fetchedUIDs.append(document.documentID)
                    
                }
            }
            self.allUIds = fetchedUIDs
            handler()
        }
    }

    // load the table
    func loadTableInformation(){
        self.mockLeaderboard = []
        self.currentLeaderboardToDisplay = []
        
        guard let uid = Auth.auth().currentUser?.uid else{
            print("user is not logged in!")
            return
        }
        Task{
            let currentUserData = await self.manager.getUserDocumentData(uid: uid)
            var friends = currentUserData?["friends"] as? [[String : Any]] ?? []
            let username = currentUserData?["username"] as? String ?? ""
            guard !username.isEmpty else{
                return
            }
            
            // get all info for friends and yourself
            friends.append(["uid" : uid, "username" : username])
            let allInfo = await withTaskGroup(of: LeaderboardEntry.self) { group in
                for uid in allUIds{
                    group.addTask{
                        await self.getChallengesInformation(uid: uid, friends: friends)
                    }
                }
                var results: [LeaderboardEntry] = []
                for await result in group{
                    results.append(result)
                }
                
                return results
            }
            
            // first sort by weekly score by default
            self.mockLeaderboard = allInfo
            self.mockLeaderboard.sort{
                $0.weeklyScore > $1.weeklyScore
            }
            
            DispatchQueue.main.async {
                self.scopeSegment.isHidden = false
                self.tableView.isHidden = false
                self.placeLabel.isHidden = false
                self.pointsLabel.isHidden = false
                
                // because our default segment is friends we do this
                self.currentLeaderboardToDisplay = []
                for item in self.mockLeaderboard {
                    if(item.isFriend){ // if they are friends then count them
                        self.currentLeaderboardToDisplay.append(item)
                    }
                }
                self.currentLeaderboardToDisplay = Array(self.currentLeaderboardToDisplay.prefix(100))
                self.spinnerManager.hideSpinner()
                self.tableView.reloadData()
                self.currentDateScope = "weekly"
            }
        }
    }
    
    // get the information!
    func getChallengesInformation(uid: String, friends: [[String : Any]]) async -> LeaderboardEntry{
        async let userDataTask = manager.getUserDocumentData(uid: uid)
        async let profilePictureTask = manager.getProfilePicture(uid: uid)
        
        let userData = await userDataTask
        let profilePicture: UIImage = await profilePictureTask ?? UIImage(systemName: "person.fill")!
        let username = userData?["username"] ?? "unknown user"
        let weeklyScore = userData?["weeklyChallengeScore"] ?? 0
        let monthlyScore = userData?["monthlyChallengeScore"] ?? 0
        let location = userData?["location"] as? GeoPoint ?? GeoPoint(latitude: 0, longitude: 0)
        
        
        // reverse geocode location snippet inspired from
        // https://developer.apple.com/documentation/corelocation/clgeocoder
        // https://developer.apple.com/documentation/corelocation/clplacemark
        let swiftLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        async let cityNameTask = CLGeocoder().reverseGeocodeLocation(swiftLocation)
        var cityName: String?
        
        do{
            cityName = try await cityNameTask.first?.locality
        }
        catch{
            cityName = "Austin"
        }
        
        let isFriend = friends.contains { entry in
            entry["uid"] as! String == uid
        }
        return LeaderboardEntry(uid: uid, profilePicture: profilePicture, username: username as! String, weeklyScore: weeklyScore as! Int , monthlyScore: monthlyScore as! Int, isFriend: isFriend, location: cityName!)
    }
    
    // table view function
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentLeaderboardToDisplay.count
    }
    
    // table view function
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: leaderboardCellIdentifier, for: indexPath) as! LeaderboardViewCell
        let currentEntry = currentLeaderboardToDisplay[indexPath.row]
        cell.profilePic.image = currentEntry.profilePicture
        cell.profilePic.layer.cornerRadius = cell.profilePic.frame.width / 2
        cell.profilePic.contentMode = .scaleAspectFill
        cell.profilePic.clipsToBounds = true
        cell.username.text = currentEntry.username
        cell.place.text = String(indexPath.row + 1)
        cell.points.text = String(currentDateScope == "weekly" ? currentEntry.weeklyScore : currentEntry.monthlyScore)
        if scopeSegment.selectedSegmentIndex == 1{
            cell.location.text = currentEntry.location
        }
        else{
            cell.location.text = ""
        }
        return cell
    }
    
    // change between friend and global scope
    @IBAction func onScopeChange(_ sender: Any) {
        currentLeaderboardToDisplay = []
        if scopeSegment.selectedSegmentIndex == 0{ // Friends
            for item in mockLeaderboard {
                if(item.isFriend){ // if they are friends then count them
                    currentLeaderboardToDisplay.append(item)
                }
            }
        }
        else{ // Global
            currentLeaderboardToDisplay = mockLeaderboard
        }
        if currentDateScope == "weekly" { // Weekly
            currentLeaderboardToDisplay.sort(by: {$0.weeklyScore > $1.weeklyScore})
            // https://stackoverflow.com/questions/28527797/how-to-return-first-5-objects-of-array-in-swift
            currentLeaderboardToDisplay = Array(currentLeaderboardToDisplay.prefix(100))
        }
        else{ // Monthly
            currentLeaderboardToDisplay.sort(by: {$0.monthlyScore > $1.monthlyScore})
            // https://stackoverflow.com/questions/28527797/how-to-return-first-5-objects-of-array-in-swift
            currentLeaderboardToDisplay = Array(currentLeaderboardToDisplay.prefix(100))
        }
        tableView.reloadData()
    }
    
    
    
    @IBAction func filterTapped(_ sender: Any) {
        let controller = UIAlertController(
            title: "Leaderboard Filter",
            message: "Weekly or Monthly!",
            preferredStyle: .actionSheet)
        
        controller.addAction(UIAlertAction(title: "Weekly", style: .default, handler: { _ in
            self.currentLeaderboardToDisplay.sort(by: {$0.weeklyScore > $1.weeklyScore})
            self.currentDateScope = "weekly"
            self.titleLabel.text = "Leaderboard - Weekly"
            let leftItem = UIBarButtonItem(customView: self.titleLabel)
            self.navigationItem.leftBarButtonItem = leftItem
            self.tableView.reloadData()
        }))
        
        controller.addAction(UIAlertAction(title: "Monthly", style: .default, handler: { _ in
            self.currentLeaderboardToDisplay.sort(by: {$0.monthlyScore > $1.monthlyScore})
            self.currentDateScope = "monthly"
            self.titleLabel.text = "Leaderboard - Monthly"
            let leftItem = UIBarButtonItem(customView: self.titleLabel)
            self.navigationItem.leftBarButtonItem = leftItem
            self.tableView.reloadData()
        }))
        
        present(controller, animated: true)
    }
    
}
