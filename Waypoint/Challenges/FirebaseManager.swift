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

class FirebaseManager{
    
    let storageRef = Storage.storage().reference()
    let db = Firestore.firestore()

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
}
