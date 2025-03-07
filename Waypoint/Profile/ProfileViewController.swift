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
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view.
//        collectionView.dataSource = self
//        collectionView.delegate = self
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return 6
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PlaceholderCell", for: indexPath) as! PlaceholderCollectionViewCell
//        cell.PlaceholderImageView.image = UIImage(systemName: "person.fill")
//        return cell
//    }
//    
//    func collectionView(_ collectionView: UICollectionView,
//                            layout collectionViewLayout: UICollectionViewLayout,
//                            sizeForItemAt indexPath: IndexPath) -> CGSize {
//            // Example: 3 columns, some spacing
//            let spacing: CGFloat = 16   // space between cells + section insets
//            let totalHorizontalSpacing = spacing * 4 // (left + right insets + 2 gaps between 3 cells)
//
//            // Subtract the total spacing from the collection view width
//            let availableWidth = collectionView.bounds.width - totalHorizontalSpacing
//            // Divide by 3 for three columns
//            let cellWidth = availableWidth / 3
//            // Make cells square
//            return CGSize(width: cellWidth, height: cellWidth)
//        }
//
//        func collectionView(_ collectionView: UICollectionView,
//                            layout collectionViewLayout: UICollectionViewLayout,
//                            insetForSectionAt section: Int) -> UIEdgeInsets {
//            // For example, 16-pt padding on each side
//            return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
//        }	
//
//        func collectionView(_ collectionView: UICollectionView,
//                            layout collectionViewLayout: UICollectionViewLayout,
//                            minimumLineSpacingForSectionAt section: Int) -> CGFloat {
//            return 16 // vertical spacing
//        }
//
//        func collectionView(_ collectionView: UICollectionView,
//                            layout collectionViewLayout: UICollectionViewLayout,
//                            minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
//            return 16 // horizontal spacing
//        }
    let dataItems = Array(repeating: "person.fill", count: 6)
        
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self  // Important for flow layout callbacks
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
