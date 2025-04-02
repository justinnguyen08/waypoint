//
//  FirestoreManager.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/1/25.
//


import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    let db = Firestore.firestore()
    
    private init() {} // Prevents instantiation outside the class
}
