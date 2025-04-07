//
//  FeedTableViewCell.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/7/25.
//

import UIKit

class FeedTableViewCell: UITableViewCell {

    
    @IBOutlet weak var profilePictureView: UIImageView!
    
    @IBOutlet weak var usernameLabel: UILabel!
    
    @IBOutlet weak var typeLabel: UILabel!
    
    @IBOutlet weak var mainImageView: UIImageView!
    
    @IBOutlet weak var likeButton: UIButton!
    
    @IBOutlet weak var commentButton: UIButton!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
