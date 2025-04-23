//
//  TagTableViewCell.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/20/25.
//

import UIKit

class TagTableViewCell: UITableViewCell {

    
    @IBOutlet weak var profilePictureView: UIImageView!
    
    @IBOutlet weak var usernameLabel: UILabel!
    
    @IBOutlet weak var tagButton: UIButton!
    
    var tagIndex: Int!
    var uid: String!
    var prevVC: TagFriendsViewController!
    

    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    @IBAction func tagButtonPressed(_ sender: Any) {
        Task{
            let _ = await prevVC.tagSomeone(uidToTag: uid, index: tagIndex)
        }
    }
    
}
