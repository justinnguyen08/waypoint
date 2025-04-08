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

// every leaderboard entry will have this format
struct LeaderboardEntry{
    let username: String
    let weeklyScore: Int
    let monthlyScore: Int
    let isFriend: Bool
}

class LeaderboardViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var scopeSegment: UISegmentedControl!
    @IBOutlet weak var dateSegment: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    var currentLeaderboardToDisplay: [LeaderboardEntry] = []
    var mockLeaderboard: [LeaderboardEntry] = []
    var leaderboardCellIdentifier = "LeaderboardCell"
    
    var allUIds: [String] = []
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        //
        getAllUsers {
            self.loadInformation()
            
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
    
    func loadInformation() {
        self.mockLeaderboard = []
        self.currentLeaderboardToDisplay = []
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User is not logged in!")
            return
        }

        var currentUserUsername: String = ""
        var currentUserWeeklyScore: Int = 0
        var currentUserMonthlyScore: Int = 0
        var currentUserFriends: [String] = []

        db.collection("users").document(uid).getDocument { (document, error) in
            if let error = error {
                print("Error getting current user information: \(error.localizedDescription)")
                return
            }

            guard let data = document?.data(),
                  let friends = data["friends"] as? [String],
                  let weeklyScore = data["weeklyChallengeScore"] as? Int,
                  let monthlyScore = data["monthlyChallengeScore"] as? Int,
                  let username = data["username"] as? String else {
                print("Current user document is missing required fields or has incorrect types")
                return
            }

            currentUserFriends = friends
            currentUserWeeklyScore = weeklyScore
            currentUserMonthlyScore = monthlyScore
            currentUserUsername = username

            self.mockLeaderboard.append(LeaderboardEntry(
                username: currentUserUsername,
                weeklyScore: currentUserWeeklyScore,
                monthlyScore: currentUserMonthlyScore,
                isFriend: true))

            for otherUID in self.allUIds {
                if uid != otherUID {
                    let isFriend = currentUserFriends.contains(otherUID)

                    self.db.collection("users").document(otherUID).getDocument { (document, error) in
                        if let error = error {
                            print("Error getting other user information: \(error.localizedDescription)")
                            return
                        }

                        guard let innerData = document?.data(),
                              let otherUsername = innerData["username"] as? String,
                              let otherWeeklyScore = innerData["weeklyChallengeScore"] as? Int,
                              let otherMonthlyScore = innerData["monthlyChallengeScore"] as? Int else {
                            print("Other user document \(otherUID) is missing required fields or has incorrect types")
                            return
                        }

                        self.mockLeaderboard.append(LeaderboardEntry(
                            username: otherUsername,
                            weeklyScore: otherWeeklyScore,
                            monthlyScore: otherMonthlyScore,
                            isFriend: isFriend))
                        
                    }
                }
            }
            
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

    
    
    // table view function
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentLeaderboardToDisplay.count
    }
    
    // table view function
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: leaderboardCellIdentifier, for: indexPath) as! LeaderboardViewCell
        let currentEntry = currentLeaderboardToDisplay[indexPath.row]
        cell.username.text = currentEntry.username
        cell.place.text = String(indexPath.row)
        cell.points.text = String(dateSegment.selectedSegmentIndex == 0 ? currentEntry.weeklyScore : currentEntry.monthlyScore)
        
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
