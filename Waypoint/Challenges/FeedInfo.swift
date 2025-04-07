//
//  FeedInfo.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/7/25.
//
import UIKit

public struct CommentInfo{
    var profilePicture: UIImage!
    var comment: String!
    var likes: Int!
}

class FeedInfo{
    var username: String!
    var indicator: String!
    var profilePicture: UIImage!
    var mainPicture: UIImage!
    var likes: Int!
    var comments: [CommentInfo]!
    
    var uid: String!
    
    init(username: String!, indicator: String!, profilePicture: UIImage!, mainPicture: UIImage!, likes: Int!, comments: [CommentInfo]!, uid: String!) {
        self.username = username
        self.indicator = indicator
        self.profilePicture = profilePicture
        self.mainPicture = mainPicture
        self.likes = likes
        self.comments = comments
        self.uid = uid
    }
}
