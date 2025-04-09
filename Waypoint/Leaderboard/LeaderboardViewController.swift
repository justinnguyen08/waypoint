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
    @IBOutlet weak var dateSegment: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    var currentLeaderboardToDisplay: [LeaderboardEntry] = []
    var mockLeaderboard: [LeaderboardEntry] = []
    var leaderboardCellIdentifier = "LeaderboardCell"
    
    // store all UIDs that we care about
    var allUIds: [String] = []
    
    // allows us access into the Google Firebase Firestore
    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        scopeSegment.isHidden = true
        dateSegment.isHidden = true
        tableView.isHidden = true
    }
    
    // load the users and update the leaderboard
    override func viewWillAppear(_ animated: Bool) {
        getAllUsers {
            self.loadInformation{
                self.scopeSegment.isHidden = false
                self.dateSegment.isHidden = false
                self.tableView.isHidden = false
                // because our default segment is friends we do this
                for item in self.mockLeaderboard {
                    if(item.isFriend){ // if they are friends then count them
                        self.currentLeaderboardToDisplay.append(item)
                    }
                }
                self.tableView.reloadData()
                self.scopeSegment.selectedSegmentIndex = 0
                self.dateSegment.selectedSegmentIndex = 0
            }
        }
    }
    
    // get every user that has an account in the app
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
            
            guard let data = document?.data(),
                  let friends = data["friends"] as? [[String: Any]],
                  let weeklyScore = data["weeklyChallengeScore"] as? Int,
                  let monthlyScore = data["monthlyChallengeScore"] as? Int,
                  let username = data["username"] as? String,
                  let location = data["location"] as? GeoPoint
            else {
                print("Current user document is missing required fields or has incorrect types")
                return
            }
            
            currentUserFriends = friends
            currentUserWeeklyScore = weeklyScore
            currentUserMonthlyScore = monthlyScore
            currentUserUsername = username
            
            // https://developer.apple.com/documentation/corelocation/clgeocoder
            // https://developer.apple.com/documentation/corelocation/clplacemark
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
                              let otherLocation = innerData["locatiin"] as? GeoPoint
                                
                        else {
                            print("Other user document \(otherUID) is missing required fields or has incorrect types")
                            return
                        }
                        
                        // https://developer.apple.com/documentation/corelocation/clgeocoder
                        // https://developer.apple.com/documentation/corelocation/clplacemark
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
                                isFriend: isFriend,
                                location: city))
                                handler()
                            } else {
                                self.mockLeaderboard.append(LeaderboardEntry(
                                username: currentUserUsername,
                                weeklyScore: currentUserWeeklyScore,
                                monthlyScore: currentUserMonthlyScore,
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
        cell.points.text = String(dateSegment.selectedSegmentIndex == 0 ? currentEntry.weeklyScore : currentEntry.monthlyScore)
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
        tableView.reloadData()
    }
    
    // change between weekly and monthly scores
    @IBAction func onDateChange(_ sender: Any) {
        if dateSegment.selectedSegmentIndex == 0{ // Weekly
            currentLeaderboardToDisplay.sort(by: {$0.weeklyScore > $1.weeklyScore})
        }
        else{ // Monthly
            currentLeaderboardToDisplay.sort(by: {$0.monthlyScore > $1.monthlyScore})
        }
        tableView.reloadData()
    }
}
