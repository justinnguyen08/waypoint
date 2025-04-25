//  Project: Waypoint
//  Course: CS371L
//
//  FirebaseManager.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/16/25.
//

import Foundation
import UIKit
import FirebaseStorage
import FirebaseFirestore

// a class to help with common firebase calls
class FirebaseManager{
    let storageRef = Storage.storage().reference()
    let db = Firestore.firestore()
    
    // get the image metadata as a Dictionary or Map
    func getImageMetadata(path: String) async -> [String: String]?{
        let imageRef = storageRef.child(path)
        do{
            let metadata = try await imageRef.getMetadata()
            return metadata.customMetadata
        }
        catch{
            print("Error getting image metadata for \(path)")
            return nil
        }
    }
    
    // https://www.hackingwithswift.com/quick-start/concurrency/how-to-use-continuations-to-convert-completion-handlers-into-async-functions
    // get the profile picture
    func getProfilePicture(uid: String) async -> UIImage?{
        await withCheckedContinuation { continuation in
            let profilePicRef = storageRef.child("\(uid)/profile_pic.jpg")
            profilePicRef.getData(maxSize: 10 * 1024 * 1024){
                (data, error) in
                if let error = error{
                    print("Error getting profile picture for: \(uid): \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
                else{
                    if let data = data, let image = UIImage(data: data){
                        continuation.resume(returning: image)
                    }
                    else{
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // https://www.hackingwithswift.com/quick-start/concurrency/how-to-use-continuations-to-convert-completion-handlers-into-async-functions
    // get a challenge photo
    func getChallengePicture(path: String) async -> UIImage?{
        await withCheckedContinuation {
            continuation in
            let challengePicRef = storageRef.child(path)
            challengePicRef.getData(maxSize: 10 * 1024 * 1024){
                (data, error) in
                if let error = error{
                    print("Error getting challenge picture: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
                else{
                    if let data = data, let image = UIImage(data: data){
                        continuation.resume(returning: image)
                    }
                    else{
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    // get the user document in "users"
    func getUserDocumentData(uid: String) async -> [String: Any]?{
        let docRef = db.collection("users").document(uid)
        do{
            let document = try await docRef.getDocument()
            if document.exists{
                let dataDescription = document.data()
                return dataDescription
            }
            else{
                print("Document does not exist!")
            }
        }
        catch{
            print("Error catching user document: \(uid)")
        }
        return nil
    }
    
    // get the  post likes (likes are just strings of uids)
    func getPostLikes(collection: String, postID: String) async -> [String]?{
        let postRef = db.collection(collection).document(postID)
        
        do{
            let document = try await postRef.getDocument()
            if document.exists{
                let dataDescription = document.data()
                return dataDescription?["likes"] as? [String]
            }
        }
        catch{
            print("Error catching challenge post document: \(postID)")        }
        return nil
    }
    
    // get the comments which are of form (uid: String, username: String)
    func getPostComments(collection: String, postID: String) async -> [[String : Any]]? {
        let postRef = db.collection(collection).document(postID)
        do{
            let document = try await postRef.getDocument()
            if document.exists{
                let dataDescription = document.data()
                return dataDescription?["comments"] as? [[String : Any]]
            }
        }
        catch{
            print("Error catching challenge post document: \(postID)")
        }
        return nil
    }
    
    // get the tagged users which is an array of uids
    func getPostTagged(collection: String, postID: String) async -> [String]?{
        let postRef = db.collection(collection).document(postID)
        
        do{
            let document = try await postRef.getDocument()
            if document.exists{
                let dataDescription = document.data()
                return dataDescription?["tagged"] as? [String]
            }
        }
        catch{
            print("Error catching challenge post document: \(postID)")        }
        return nil
    }
    
    // get the friends list
    func getFriendsList(uid: String) async -> [[String : Any]]? {
        let userData: [String : Any]? = await getUserDocumentData(uid: uid)
        let friends: [[String : Any]]? = userData?["friends"] as? [[String : Any]]
        return friends
    }
}
