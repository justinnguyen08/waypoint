//  Project: Waypoint
//  Course: CS371L
//
//  CommentTableViewCell.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/17/25.
//

import UIKit

class CommentTableViewCell: UITableViewCell {
    
    @IBOutlet weak var commentProfilePicture: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var commentTextLabel: UILabel!
    @IBOutlet weak var commentLikeButton: UIButton!
    @IBOutlet weak var commentLikeCountLabel: UILabel!
    
    var delegate: ChallengeFeedCommentViewController!
    var commentIndex: Int!
    
    // if we like then we just let our parent handle it
    @IBAction func commentLikeButtonPressed(_ sender: Any) {
        // https://www.swiftbysundell.com/articles/connecting-async-await-with-other-swift-code/
        Task{
            let _ = await delegate.handleCommentLike(commentIndex: self.commentIndex)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
