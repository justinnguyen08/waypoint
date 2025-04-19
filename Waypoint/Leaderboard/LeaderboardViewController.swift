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
    let username: String
    let weeklyScore: Int
    let monthlyScore: Int
    let isFriend: Bool
    let location: String
}

class LeaderboardViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var scopeSegment: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    var currentLeaderboardToDisplay: [LeaderboardEntry] = []
    var mockLeaderboard: [LeaderboardEntry] = []
    var leaderboardCellIdentifier = "LeaderboardCell"
    
    // store all UIDs that we care about
    var allUIds: [String] = []
    let db = Firestore.firestore()
    let manager = FirebaseManager()
    
    var profilePictureCache: [String : UIImage] = [:]
    var usernameCache: [String : String] = [:]
    
    var currentDateScope = "weekly"

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        scopeSegment.isHidden = true
        tableView.isHidden = true
    }
    
    // load the users and update the leaderboard
    override func viewWillAppear(_ animated: Bool) {
        getAllUsers {
            self.loadInformation{
                self.scopeSegment.isHidden = false
                self.tableView.isHidden = false
                // because our default segment is friends we do this
                self.currentLeaderboardToDisplay = []
                for item in self.mockLeaderboard {
                    if(item.isFriend){ // if they are friends then count them
                        self.currentLeaderboardToDisplay.append(item)
                    }
                }
                self.tableView.reloadData()
                self.scopeSegment.selectedSegmentIndex = 0
                self.currentDateScope = "weekly"
            }
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
    
    
    func loadInformation2(){
        self.mockLeaderboard = []
        self.currentLeaderboardToDisplay = []
        
        guard let uid = Auth.auth().currentUser?.uid else{
            print("user is not logged in!")
            return
        }
        Task{
            async let userData = self.manager
        }
    }
    
    // load the information and update the table
    func loadInformation(handler: @escaping () -> Void) {
        self.mockLeaderboard = []
        self.currentLeaderboardToDisplay = []
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in!")
            return
        }
        var currentUserUsername: String = ""
        var currentUserWeeklyScore: Int = 0
        var currentUserMonthlyScore: Int = 0
        var currentUserFriends: [[String: Any]] = []
        
        db.collection("users").document(uid).getDocument {
            (document, error) in
            if let error = error {
                print("Error getting current user information: \(error.localizedDescription)")
                return
            }
            
            guard let data = document?.data() else {
                print("Failed to get data from document")
                return
            }

            guard let friends = data["friends"] as? [[String: Any]] else {
                print("Missing or invalid 'friends' field")
                return
            }

            guard let weeklyScore = data["weeklyChallengeScore"] as? Int else {
                print("Missing or invalid 'weeklyChallengeScore' field")
                return
            }

            guard let monthlyScore = data["monthlyChallengeScore"] as? Int else {
                print("Missing or invalid 'monthlyChallengeScore' field")
                return
            }

            guard let username = data["username"] as? String else {
                print("Missing or invalid 'username' field")
                return
            }

            guard let location = data["location"] as? GeoPoint else {
                print("Missing or invalid 'location' field")
                return
            }

            
            currentUserFriends = friends
            currentUserWeeklyScore = weeklyScore
            currentUserMonthlyScore = monthlyScore
            currentUserUsername = username
            
            // reverse geocode location snippet inspired from 
            // https://developer.apple.com/documentation/corelocation/clgeocoder
            // https://developer.apple.com/documentation/corelocation/clplacemark
            // https://stackoverflow.com/questions/24345296/swift-clgeocoder-reversegeocodelocation-completionhandler-closure
            let swiftLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            CLGeocoder().reverseGeocodeLocation(swiftLocation) { (placemarks, error) in
                if let error = error {
                    print("Error in reverse geocoding: \(error.localizedDescription)")
                    return
                }
                if let placemark = placemarks?[0],
                   let city = placemark.locality {
                    self.mockLeaderboard.append(LeaderboardEntry(
                    username: currentUserUsername,
                    weeklyScore: currentUserWeeklyScore,
                    monthlyScore: currentUserMonthlyScore,
                    isFriend: true,
                    location: city))
                    handler()
                } else {
                    self.mockLeaderboard.append(LeaderboardEntry(
                    username: currentUserUsername,
                    weeklyScore: currentUserWeeklyScore,
                    monthlyScore: currentUserMonthlyScore,
                    isFriend: true,
                    location: "n/a"))
                    handler()
                }
            }

            // get information from all users except ourselves
            for otherUID in self.allUIds {
                if uid != otherUID {
                    var isFriend = false
                    for entry in currentUserFriends {
                        if let friendUID = entry["uid"] as? String, friendUID == otherUID {
                            isFriend = true
                            break
                        }
                    }
                    
                    self.db.collection("users").document(otherUID).getDocument { (document, error) in
                        if let error = error {
                            print("Error getting other user information: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let innerData = document?.data(),
                              let otherUsername = innerData["username"] as? String,
                              let otherWeeklyScore = innerData["weeklyChallengeScore"] as? Int,
                              let otherMonthlyScore = innerData["monthlyChallengeScore"] as? Int,
                              let otherLocation = innerData["location"] as? GeoPoint
                                
                        else {
                            print("Other user document \(otherUID) is missing required fields or has incorrect types")
                            return
                        }
                        
                        // reverse geocode location snippet inspired from
                        // https://developer.apple.com/documentation/corelocation/clgeocoder
                        // https://developer.apple.com/documentation/corelocation/clplacemark
                        // https://stackoverflow.com/questions/24345296/swift-clgeocoder-reversegeocodelocation-completionhandler-closure
                        let swiftLocation = CLLocation(latitude: otherLocation.latitude, longitude: otherLocation.longitude)
                        CLGeocoder().reverseGeocodeLocation(swiftLocation) { (placemarks, error) in
                            if let error = error {
                                print("Error in reverse geocoding: \(error.localizedDescription)")
                                return
                            }
                            if let placemark = placemarks?[0],
                               let city = placemark.locality {
                                self.mockLeaderboard.append(LeaderboardEntry(
                                username: otherUsername,
                                weeklyScore: otherWeeklyScore,
                                monthlyScore: otherMonthlyScore,
                                isFriend: isFriend,
                                location: city))
                                handler()
                            } else {
                                self.mockLeaderboard.append(LeaderboardEntry(
                                username: otherUsername,
                                weeklyScore: otherWeeklyScore,
                                monthlyScore: otherMonthlyScore,
                                isFriend: isFriend,
                                location: "n/a"))
                                handler()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // table view function
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentLeaderboardToDisplay.count
    }
    
    // table view function
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: leaderboardCellIdentifier, for: indexPath) as! LeaderboardViewCell
        let currentEntry = currentLeaderboardToDisplay[indexPath.row]
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
        }
        else{ // Monthly
            currentLeaderboardToDisplay.sort(by: {$0.monthlyScore > $1.monthlyScore})
        }
        tableView.reloadData()
    }
    
    
    
    @IBAction func filterTapped(_ sender: Any) {
        
        let controller = UIAlertController(
            title: "Alert Controller",
            message: "Weekly or Monthly!",
            preferredStyle: .actionSheet)
        
        
        controller.addAction(UIAlertAction(title: "Weekly", style: .default, handler: { _ in
            self.currentLeaderboardToDisplay.sort(by: {$0.weeklyScore > $1.weeklyScore})
            self.currentDateScope = "weekly"
            self.tableView.reloadData()
        }))
        
        controller.addAction(UIAlertAction(title: "Monthly", style: .default, handler: { _ in
            self.currentLeaderboardToDisplay.sort(by: {$0.monthlyScore > $1.monthlyScore})
            self.currentDateScope = "monthly"
            self.tableView.reloadData()
        }))
        
        present(controller, animated: true)
    }
    
}
