//  Project: Waypoint
//  Course: CS371L
//
//  LeaderboardViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/4/25.
//

import UIKit

// every leaderboard entry will have this format
struct LeaderboardEntry{
    let username: String
    let weeklyScore: Int
    let monthlyScore: Int
    let isFriend: Bool
    let date: Date
}

// fake data for now
let mockLeaderboard: [LeaderboardEntry] = [
    LeaderboardEntry(username: "Alice", weeklyScore: 1200, monthlyScore: 2400, isFriend: true, date: Date()),
    LeaderboardEntry(username: "Bob", weeklyScore: 950, monthlyScore: 1900, isFriend: false, date: Date()),
    LeaderboardEntry(username: "Charlie", weeklyScore: 1100, monthlyScore: 2200, isFriend: true, date: Date()),
    LeaderboardEntry(username: "David", weeklyScore: 890, monthlyScore: 1800, isFriend: false, date: Date()),
    LeaderboardEntry(username: "Eve", weeklyScore: 1300, monthlyScore: 2600, isFriend: true, date: Date())
]

class LeaderboardViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var scopeSegment: UISegmentedControl!
    @IBOutlet weak var dateSegment: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!
    
    var currentLeaderboardToDisplay: [LeaderboardEntry] = []
    var leaderboardCellIdentifier = "LeaderboardCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.dataSource = self
        tableView.delegate = self
        
        // default segment is friends
        for item in mockLeaderboard {
            if(item.isFriend){ // if they are friends then count them
                currentLeaderboardToDisplay.append(item)
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
