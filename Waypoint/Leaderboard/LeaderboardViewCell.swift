//  Project: Waypoint
//  Course: CS371L
//
//  LeaderboardViewCell.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/6/25.
//

import UIKit

// this class handles the custom cell for the leaderboard table view
class LeaderboardViewCell: UITableViewCell {
    @IBOutlet weak var place: UILabel!
    @IBOutlet weak var profilePic: UIImageView!
    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var points: UILabel!
}
