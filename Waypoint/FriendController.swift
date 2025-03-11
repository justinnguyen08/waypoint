//
//  ViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 2/28/25.
//

import UIKit

public let addFriendsArray = ["Lebron", "Steph", "Giannis"]
public let removeFriendsArray = ["Pranv", "Justin", "Tony"]

class FriendController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var friendProfileView: UITableView!
    @IBOutlet weak var pendingFriendView: UITableView!
    @IBOutlet weak var suggestedFriendView: UITableView!
    
    @IBOutlet weak var segCtrl: UISegmentedControl!
    
    @IBOutlet weak var currentFriendsView: UIView!
    @IBOutlet weak var suggestFriendView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        friendProfileView.delegate = self
        friendProfileView.dataSource = self
        
        pendingFriendView.delegate = self
        pendingFriendView.dataSource = self
        
        suggestedFriendView.delegate = self
        suggestedFriendView.dataSource = self
        
        suggestFriendView.isHidden = true
        currentFriendsView.isHidden = false
        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func friendSegCtlrPressed(_ sender: Any) {
        switch segCtrl.selectedSegmentIndex {
        case 0:
            suggestFriendView.isHidden = true
            currentFriendsView.isHidden = false
            
            friendProfileView.reloadData()
        case 1:
            suggestFriendView.isHidden = false
            currentFriendsView.isHidden = true
        
            suggestedFriendView.reloadData()
            pendingFriendView.reloadData()
        default:
            print("Should Not happen")
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segCtrl?.selectedSegmentIndex == 0 {
            return removeFriendsArray.count
        } else {
            return addFriendsArray.count

        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segCtrl?.selectedSegmentIndex == 0 {
            print("here")
            let cell: CustomTableViewCell = friendProfileView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as! CustomTableViewCell
            cell.customProfileName.text? = removeFriendsArray[indexPath.row]
            return cell
            
            // TODO: Why is this not working??
        } else if segCtrl?.selectedSegmentIndex == 1 && tableView == pendingFriendView {
            let cell: PendingCustomTableViewCell = pendingFriendView.dequeueReusableCell(withIdentifier: "pendingCell", for: indexPath) as! PendingCustomTableViewCell
            cell.pendingProfileName.text? = addFriendsArray[indexPath.row]
            return cell
        } else {
            let cell: SuggestedCustomViewTableCell = suggestedFriendView.dequeueReusableCell(withIdentifier: "suggestCell", for: indexPath) as! SuggestedCustomViewTableCell
            cell.profileName.text? = addFriendsArray[indexPath.row]
            return cell
        }
        
    }
    
    
    
}

