//  Project: Waypoint
//  Course: CS371L
//
//  FeedInfo.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/7/25.
//

import UIKit

// handle feed information
class FeedInfo{
    var username: String!
    var indicator: String!
    var profilePicture: UIImage!
    var mainPicture: UIImage!
    var likes: [String]!
    var comments: [[String : Any]]!
    var uid: String!
    var monthlyChallengeIndex: Int!
    var postID: String!
    
    init(username: String!, indicator: String!, profilePicture: UIImage!, mainPicture: UIImage!, likes: [String]!, comments: [[String : Any]]!, uid: String!, monthlyChallngeIndex: Int!, postID: String!) {
        self.username = username
        self.indicator = indicator
        self.profilePicture = profilePicture
        self.mainPicture = mainPicture
        self.likes = likes
        self.comments = comments
        self.uid = uid
        self.monthlyChallengeIndex = monthlyChallngeIndex
        self.postID = postID
    }
    
    func describe() {
        print("""
        🔎 FeedInfo Debug:
        ------------------
        Username: \(username ?? "nil")
        Indicator: \(indicator ?? "nil")
        UID: \(uid ?? "nil")
        PostID: \(postID ?? "nil")
        Monthly Challenge Index: \(monthlyChallengeIndex ?? -1)
        Likes Count: \(likes?.count ?? 0)
        Comments Count: \(comments?.count ?? 0)
        Profile Picture: \(profilePicture != nil ? "✅" : "❌")
        Main Picture: \(mainPicture != nil ? "✅" : "❌")
        ------------------
        """)
    }

}
