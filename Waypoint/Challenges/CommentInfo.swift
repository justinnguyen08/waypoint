//
//  CommentInfo.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/16/25.
//

import Foundation
import UIKit

// every coment will have this information
class CommentInfo{
    var uid: String!
    var profilePicture: UIImage!
    var comment: String!
    var likes: [String]!
    var username: String!
    
    init(uid: String!, profilePicture: UIImage!, comment: String!, likes: [String]!, username: String!) {
        self.uid = uid
        self.profilePicture = profilePicture
        self.comment = comment
        self.likes = likes
        self.username = username
    }

}
