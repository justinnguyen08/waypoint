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
import FirebaseStorage
import CoreLocation

class ProfileViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var pinnedImageView: UIImageView!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var friendsLabel: UILabel!
    @IBOutlet weak var streakLabel: UILabel!
    @IBOutlet weak var mapCollectionView: UIImageView!
    
    var imageReferences: [StorageReference] = []
    let imageCache = NSCache<NSString, UIImage>()
    
    // current user's profile  from Firestore.
    var userProfile: UserProfile?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // segue for mapCollectionView
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped))
        mapCollectionView.addGestureRecognizer(tapGesture)
        mapCollectionView.isUserInteractionEnabled = true
        
        // fetch profile data
        fetchUserProfile()
        
        fetchProfileAndPinnedImages()
        fetchUserImages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // fetch profile pic
        if let userId = Auth.auth().currentUser?.uid {
            
            let storage = Storage.storage()
            let profilePicRef = storage.reference().child("\(userId)/profile_pic.jpg")
            
            fetchImage(from: profilePicRef, for: avatarImageView, fallback: "person.circle")
            avatarImageView.layer.cornerRadius = avatarImageView.frame.height / 2
            avatarImageView.contentMode = .scaleAspectFill
        }
        else {
            print("No user logged in, cannot fetch profile or pinned images")
            avatarImageView.image = UIImage(systemName: "person.circle")
        }
        
    }
    
    func fetchProfileAndPinnedImages() {
        if let userId = Auth.auth().currentUser?.uid {
            let storage = Storage.storage()
            let profilePicRef = storage.reference().child("\(userId)/profile_pic.jpg")
            let pinnedPicRef = storage.reference().child("\(userId)/pinned_pic.jpg")
            
            // Fetch profile pic
//            fetchImage(from: profilePicRef, for: avatarImageView, fallback: "person.circle")
//            avatarImageView.layer.cornerRadius = avatarImageView.frame.height / 2
//            avatarImageView.contentMode = .scaleAspectFill
            
            // Fetch pinned pic
            fetchImage(from: pinnedPicRef, for: pinnedImageView, fallback: "pin.circle")
        } else {
            print("No user logged in, cannot fetch profile or pinned images")
            avatarImageView.image = UIImage(systemName: "person.circle")
            pinnedImageView.image = UIImage(systemName: "pin.circle")
        }
    }
    
    func fetchImage(from ref: StorageReference, for imageView: UIImageView, fallback: String) {
        let path = ref.fullPath as NSString
        if let cachedImage = imageCache.object(forKey: path) {
            imageView.image = cachedImage
        } else {
            imageView.image = UIImage(systemName: fallback)  // Placeholder while loading
            ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
                if let error = error {
                    print("Error fetching \(path): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        imageView.image = UIImage(systemName: fallback)
                    }
                } else if let data = data, let image = UIImage(data: data) {
                    self.imageCache.setObject(image, forKey: path)
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }
        }
    }
    
    func fetchUserImages() {
        if let userId = Auth.auth().currentUser?.uid {
            let storage = Storage.storage()
            let allPicsRef = storage.reference().child("\(userId)/all_pics")
            
            allPicsRef.listAll { [weak self] (result, error) in
                if let error = error {
                    print("Error listing images: \(error.localizedDescription)")
                    return
                }
                if let result = result {
                    self?.imageReferences = result.items.sorted { ref1, ref2 in
                        let time1 = Double(ref1.name.replacingOccurrences(of: ".jpg", with: "")) ?? 0
                        let time2 = Double(ref2.name.replacingOccurrences(of: ".jpg", with: "")) ?? 0
                        return time1 > time2
                    }
                    DispatchQueue.main.async {
                        self?.collectionView.reloadData()
                    }
                }
            }
        } else {
            print("No user logged in, cannot fetch images")
        }
    }
    
    // fetch user profile data
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

    // update labels shown on profile
    func updateProfileLabels() {
        guard let user = userProfile else { return }
        
        nicknameLabel.text = user.nickname
        usernameLabel.text = user.username
        pointsLabel.text = "\(user.score ?? 0)"
        // Display the count of friend IDs.
        friendsLabel.text = "\(user.friends.count)"
        streakLabel.text = "\(user.streak ?? 0)"
    }
    
    // creates a segue for MapCollectionView
    @objc func mapImageTapped() {
        performSegue(withIdentifier: "MapDetailSegue", sender: self)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
         return imageReferences.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath) as! PlaceholderCollectionViewCell
        let imageRef = imageReferences[indexPath.item]
        let imagePath = imageRef.fullPath as NSString
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: imagePath) {
            cell.PlaceholderImageView.image = cachedImage
        } else {
            // Set a placeholder while loading
            cell.PlaceholderImageView.image = nil  // Or UIImage(systemName: "photo")
            print("Fetching image: \(imagePath)")
            
            imageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                if let error = error {
                    print("Error fetching image \(imagePath): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        cell.PlaceholderImageView.image = UIImage(systemName: "exclamationmark.triangle")
                    }
                } else if let data = data, let image = UIImage(data: data) {
                    self.imageCache.setObject(image, forKey: imagePath)
                    DispatchQueue.main.async {
                        cell.PlaceholderImageView.image = image
                    }
                } else {
                    print("Data fetched but no valid image for \(imagePath)")
                    DispatchQueue.main.async {
                        cell.PlaceholderImageView.image = UIImage(systemName: "questionmark")
                    }
                }
            }
        }
        
        return cell
    }
    
    // show full photo after tapping on collection item in Profile
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageRef = imageReferences[indexPath.item]

        imageRef.getMetadata { [weak self] metadata, error in
            guard let self = self else { return }
            if let error = error {
            print("Error fetching metadata:", error)
            return
      }
        let postID = metadata?.customMetadata?["postID"]
        let latitude = metadata?.customMetadata?["latitude"]
        let longitude = metadata?.customMetadata?["longitude"]
        let lat = Double(latitude!)
        let long = Double(longitude!)
        let coord = CLLocationCoordinate2D(latitude: Double(lat!), longitude: Double(long!))
        imageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
          if let error = error {
            print("Error downloading image:", error)
            return
          }
          guard let data = data, let image = UIImage(data: data) else {
            print("No image data")
            return
          }

          DispatchQueue.main.async {
            let storyboard = UIStoryboard(name: "Map", bundle: nil)
            guard let fullVC = storyboard.instantiateViewController(withIdentifier: "FullPhotoViewController")
                as? FullPhotoViewController
            else {
              return
            }
            fullVC.photo  = image
            fullVC.postID = postID
//            coordinates = CLLocation(latitude: latitude, longitude: longitude)
            fullVC.location = coord
              fullVC.modalPresentationStyle = .pageSheet
            self.present(fullVC, animated: true, completion: nil)
          }
        }
      }
    }
    
    // the next 4 collection view functions deal with spacing for displaying photos
    // displaying x rows, each row having 3 columns of photos
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
