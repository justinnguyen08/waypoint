//  Project: Waypoint
//  Course: CS371L
//
//  FeedTableViewCell.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/7/25.
//

import UIKit

// Custom Cell for the Feed Table
class FeedTableViewCell: UITableViewCell {
    
    @IBOutlet weak var profilePictureView: UIImageView!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var likeButton: UIButton!
    @IBOutlet weak var likeLabel: UILabel!
    @IBOutlet weak var commentLabel: UILabel!
    @IBOutlet weak var commentButton: UIButton!
    
    var delegate: ChallengeFeedViewController!
    var likes: [String]!
    var index: Int!
    var uid: String!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    // ensure that the cell actually can display everything
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }
    
    @IBAction func commentButtonPressed(_ sender: Any) {
        delegate.handleCommentSegue(index: index)
    }
    
    @IBAction func likeButtonPressed(_ sender: Any) {
        // XCode suggested this @MainActor
        Task { @MainActor in
            let status: Bool = await delegate.handleLike(rowIndex: index)
            if status{
                likeButton.setImage(UIImage(systemName: "hand.thumbsup.fill"), for: .normal)
            }
            else{
                likeButton.setImage(UIImage(systemName: "hand.thumbsup"), for: .normal)
            }
        }
    }
    
}
