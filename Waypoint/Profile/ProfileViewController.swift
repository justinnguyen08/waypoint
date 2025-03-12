//  Project: Waypoint
//  Course: CS371L
//
//  ProfileViewController.swift
//  Waypoint
//
//  Created by Justin Nguyen on 3/5/25.
//

import UIKit

class ProfileViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate{
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var friendsLabel: UILabel!
    @IBOutlet weak var streakLabel: UILabel!
    @IBOutlet weak var mapCollectionView: UIImageView!
    
    let dataItems = Array(repeating: "person.fill", count: 6)
        
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self  // Important for flow layout callbacks
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped))
        mapCollectionView.addGestureRecognizer(tapGesture)
        mapCollectionView.isUserInteractionEnabled = true
    }
    
    @objc func mapImageTapped() {
        performSegue(withIdentifier: "MapDetailSegue", sender: self)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
         return dataItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell",
                                                      for: indexPath) as! PlaceholderCollectionViewCell
        let symbolName = dataItems[indexPath.item]
        cell.PlaceholderImageView.image = UIImage(systemName: symbolName)
        return cell
    }
    
    // setting appropriate spacing (3 column layout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let spacing: CGFloat = 16
        
        let totalHorizontalSpacing = spacing * (columns - 1)
        let sectionInsets: CGFloat = spacing * 2
        
        // Calculate available width
        let availableWidth = collectionView.bounds.width - totalHorizontalSpacing - sectionInsets
        let cellWidth = availableWidth / columns
        
        // Make them square
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
}
