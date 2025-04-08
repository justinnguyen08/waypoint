//  Project: Waypoint
//  Course: CS371L
//
//  ProfileViewController.swift
//  Waypoint
//
//  Created by Justin Nguyen on 3/5/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class ProfileViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var friendsLabel: UILabel!
    @IBOutlet weak var streakLabel: UILabel!
    @IBOutlet weak var mapCollectionView: UIImageView!
    
    let dataItems = Array(repeating: "person.fill", count: 6)
    
    // The current user's profile fetched from Firestore.
    var userProfile: UserProfile?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Set up tap gesture for mapCollectionView (triggers a segue).
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped))
        mapCollectionView.addGestureRecognizer(tapGesture)
        mapCollectionView.isUserInteractionEnabled = true
        
        // Fetch the current user's profile data from Firestore.
        fetchUserProfile()
    }
    
    // MARK: - Data Fetching
    func fetchUserProfile() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("No current user is logged in.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(currentUserID)
        
        // Listen for realtime updates. Cached data (if available) is delivered immediately.
        userRef.addSnapshotListener { [weak self] (snapshot, error) in
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot,
                  snapshot.exists,
                  let data = snapshot.data() else {
                print("User profile document does not exist.")
                return
            }
            
            if let profile = UserProfile(id: snapshot.documentID, data: data) {
                self?.userProfile = profile
                DispatchQueue.main.async {
                    self?.updateProfileLabels()
                }
            } else {
                print("Failed to decode user profile from data.")
            }
        }
    }

    
    // MARK: - UI Update
    func updateProfileLabels() {
        guard let user = userProfile else { return }
        
        nicknameLabel.text = user.nickname
        usernameLabel.text = user.username
        // Assuming score represents points.
        pointsLabel.text = "\(user.score ?? 0)"
        // Display the count of friend IDs.
        friendsLabel.text = "\(user.friends.count)"
        streakLabel.text = "\(user.streak ?? 0)"
    }
    
    // MARK: - Tap Gesture Action
    @objc func mapImageTapped() {
        performSegue(withIdentifier: "MapDetailSegue", sender: self)
    }
    
    // MARK: - UICollectionViewDataSource Methods
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
         return dataItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath) as! PlaceholderCollectionViewCell
        let symbolName = dataItems[indexPath.item]
        cell.PlaceholderImageView.image = UIImage(systemName: symbolName)
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout Methods
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let spacing: CGFloat = 16
        let totalHorizontalSpacing = spacing * (columns - 1)
        let sectionInsets: CGFloat = spacing * 2
        
        let availableWidth = collectionView.bounds.width - totalHorizontalSpacing - sectionInsets
        let cellWidth = availableWidth / columns
        
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 16
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)

    }
}
