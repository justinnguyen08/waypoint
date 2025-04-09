//
//  UserProfile.swift
//  Waypoint
//
//  Created by Justin Nguyen on 3/31/2025.
//

import Foundation
import FirebaseFirestore

/// A class representing a user profile stored in Firestore.
class UserProfile {
    var id: String?
    var nickname: String
    var username: String
    var profilePicture: String?
    
    // List of friend document IDs.
    var friends: [User]
    
    // Additional properties
    var streak: Int?
    var score: Int?
    
    // Designated initializer.
    init(id: String? = nil,
         nickname: String,
         username: String,
         profilePicture: String? = nil,
         friends: [User] = [],
         streak: Int? = 0,
         score: Int? = 0) {
        self.id = id
        self.nickname = nickname
        self.username = username
        self.profilePicture = profilePicture
        self.friends = friends
        self.streak = streak
        self.score = score
    }
    
    /// Convenience initializer that creates a UserProfile from Firestore data.
    /// - Parameters:
    ///   - id: The document ID.
    ///   - data: A dictionary containing the Firestore fields.
    convenience init?(id: String, data: [String: Any]) {
        // Ensure required fields exist.
        guard let nickname = data["nickname"] as? String,
              let username = data["username"] as? String else {
            return nil
        }
        
        let profilePicture = data["profilePicture"] as? String
        
        // Build a local variable for friends.
        var friendsArray: [User] = []
        if let friendsData = data["friends"] as? [[String: Any]] {
            for friendInfo in friendsData {
                if let uid = friendInfo["uid"] as? String,
                   let uname = friendInfo["username"] as? String {
                    let friend = User(uid: uid, username: uname)
                    friendsArray.append(friend)
                }
            }
            print("This is how many friends you have: \(friendsArray.count)")
        }
        
        let streak = data["streak"] as? Int
        let score = data["score"] as? Int
        
        // with all necessary data, call the designated initializer.
        self.init(id: id,
                  nickname: nickname,
                  username: username,
                  profilePicture: profilePicture,
                  friends: friendsArray,
                  streak: streak,
                  score: score)
    }

}

