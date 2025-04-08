//
//  UserProfile.swift
//  Waypoint
//
//  Created by Justin Nguyen on 3/31/2025.
//

import Foundation
import FirebaseFirestore

/// A class representing a user profile stored in Firestore.
class UserProfile: Codable, Identifiable {
    var id: String?
    var nickname: String
    var username: String
    var profilePicture: String?
    
    // List of friend document IDs.
    var friends: [String]
    
    // Additional properties
    var streak: Int?
    var score: Int?
    
    // Designated initializer.
    init(id: String? = nil,
         nickname: String,
         username: String,
         profilePicture: String? = nil,
         friends: [String] = [],
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
        let friends = data["friends"] as? [String] ?? []
        let streak = data["streak"] as? Int
        let score = data["score"] as? Int
        
        self.init(id: id,
                  nickname: nickname,
                  username: username,
                  profilePicture: profilePicture,
                  friends: friends,
                  streak: streak,
                  score: score)
    }
}


// MARK: - Firestore Helper Methods
extension UserProfile {
    
    /// Adds a friend's document ID to the user's friend list in Firestore.
    /// - Parameters:
    ///   - friendID: The document ID of the friend to add.
    ///   - completion: Completion handler called with an optional error.
    func addFriend(friendID: String, completion: @escaping (Error?) -> Void) {
        guard let userId = self.id else {
            let error = NSError(domain: "", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "User ID is nil"])
            completion(error)
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "friends": FieldValue.arrayUnion([friendID])
        ]) { error in
            completion(error)
        }
    }
    
    /// Removes a friend's document ID from the user's friend list in Firestore.
    /// - Parameters:
    ///   - friendID: The document ID of the friend to remove.
    ///   - completion: Completion handler called with an optional error.
    func removeFriend(friendID: String, completion: @escaping (Error?) -> Void) {
        guard let userId = self.id else {
            let error = NSError(domain: "", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "User ID is nil"])
            completion(error)
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("UserProfiles").document(userId)
        
        userRef.updateData([
            "friends": FieldValue.arrayRemove([friendID])
        ]) { error in
            completion(error)
        }
    }
}

// MARK: - Creating a New UserProfile Document
extension UserProfile {
    
    /// Creates a new UserProfile document in Firestore.
    /// - Parameters:
    ///   - nickname: User's nickname.
    ///   - username: User's username.
    ///   - birthday: User's birthday.
    ///   - phoneNumber: User's phone number.
    ///   - profilePicture: Optional URL string for the profile picture.
    ///   - completion: Completion handler that returns the created UserProfile or an error.
    static func createUserProfile(nickname: String,
                                  username: String,
                                  birthday: String,
                                  phoneNumber: String,
                                  profilePicture: String? = nil,
                                  completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let db = Firestore.firestore()
        let newProfile = UserProfile(nickname: nickname,
                                     username: username,
                                     profilePicture: profilePicture,
                                     friends: [],
                                     streak: 0,
                                     score: 0)
        
        var ref: DocumentReference? = nil
        do {
            ref = try db.collection("UserProfiles").addDocument(from: newProfile) { error in
                // Safely unwrap the reference declared outside.
                guard let documentRef = ref else { return }
                
                if let error = error {
                    completion(.failure(error))
                } else {
                    // Update newProfile with the auto-generated document ID.
                    newProfile.id = documentRef.documentID
                    completion(.success(newProfile))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
