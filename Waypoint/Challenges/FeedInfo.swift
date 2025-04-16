//  Project: Waypoint
//  Course: CS371L
//
//  FeedInfo.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/7/25.
//

import UIKit

// every coment will have this information
public struct CommentInfo{
    var profilePicture: UIImage!
    var comment: String!
    var likes: Int!
}

// handle feed information
class FeedInfo{
    var username: String!
    var indicator: String!
    var profilePicture: UIImage!
    var mainPicture: UIImage!
    var likes: [String]!
    var comments: [CommentInfo]!
    var uid: String!
    var monthlyChallengeIndex: Int!
    var postID: String!
    
    init(username: String!, indicator: String!, profilePicture: UIImage!, mainPicture: UIImage!, likes: [String]!, comments: [CommentInfo]!, uid: String!, monthlyChallngeIndex: Int!, postID: String!) {
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
}
