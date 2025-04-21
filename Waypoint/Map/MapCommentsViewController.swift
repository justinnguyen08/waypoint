//
//  MapCommentsViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/20/25.
//

import UIKit
import FirebaseAuth

class MapCommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    var allComments: [CommentInfo]!
    
    @IBOutlet weak var profilePictureView: UIImageView!
    @IBOutlet weak var commentTextField: UITextField!
    @IBOutlet weak var postCommentButton: UIButton!
    @IBOutlet weak var commentTable: UITableView!
    @IBOutlet weak var sendCommentView: UIView!
    
    var profilePicture: UIImage!
    var prevVC: FullPhotoViewController!
    var postID: String!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        commentTable.delegate = self
        commentTable.dataSource = self
        commentTextField.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    
    // https://www.youtube.com/watch?v=O4tP7egAV1I
    // when the keyboard appears, move the view higher
    @objc func keyboardWillShow(sender: NSNotification){
        guard let userInfo = sender.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else{
            return
        }
        let value = keyboardFrame.cgRectValue.height
        view.frame.origin.y = view.frame.origin.y - value
    }
    
    // https://www.youtube.com/watch?v=O4tP7egAV1I
    // when the keyboard dissapears, move the view back down to normal
    @objc func keyboardWillHide(notification: NSNotification){
        view.frame.origin.y = 0
    }
    
    // get the profile picture ready!
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        profilePictureView.image = profilePicture
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        prevVC.comments = allComments
    }
    
    @IBAction func commentButtonPressed(_ sender: Any) {
        // https://www.swiftbysundell.com/articles/connecting-async-await-with-other-swift-code/
         guard let text = commentTextField.text else{
             return
         }
         guard !text.isEmpty else{
             return
         }
         guard let uid = Auth.auth().currentUser?.uid else{
             return
         }
//         // build a new comment and insert it into the table now
        let newComment = CommentInfo(uid: uid, profilePicture: profilePicture, comment: text, likes: [], username: prevVC.username, timestamp: Date().timeIntervalSince1970)
//
         allComments.append(newComment)
         commentTable.insertRows(at: [IndexPath(row: allComments.count - 1, section: 0)], with: .automatic)
         commentTextField.text = ""
        prevVC.comments.append(newComment)
         Task {
             // post the actual comment to the firebase
             await prevVC.postComment(commentText: text, postID: postID)
         }
    }
    
    // when the comment button is pressed then go up the chain to like a comment!
    func handleCommentLike(commentIndex: Int) async -> Bool{
        guard let uid = Auth.auth().currentUser?.uid else {
            return false
        }
        
        var likes = allComments[commentIndex].likes!
        let currentLiked = likes.contains(uid)
        
        if currentLiked{
            likes.removeAll { $0 == uid }
        }
        else{
            likes.append(uid)
        }
        allComments[commentIndex].likes = likes
        
        if let cell = commentTable.cellForRow(at: IndexPath(row: commentIndex, section: 0)) as? CommentTableViewCell{
            let imageName = likes.contains(uid) ? "hand.thumbsup.fill" : "hand.thumbsup"
            cell.commentLikeButton.setImage(UIImage(systemName: imageName), for: .normal)
            cell.commentLikeCountLabel.text = "\(likes.count)"
        }
        
        
        // reload this row
        commentTable.reloadRows(at: [IndexPath(row: commentIndex, section: 0)], with: .automatic)
        
        prevVC.comments[commentIndex].likes = likes
//        // actually enter into database
        let _ = await prevVC.handleCommentLike(postID: postID, commentIndex: commentIndex)
        return !currentLiked
    }
    
    
    
    
    // table view functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allComments.count
    }
    
    // Called when 'return' key pressed
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // table view functions
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MapCommentCell", for: indexPath) as! MapCommentsTableViewCell
        
        let commentInfo = allComments[indexPath.row]
        cell.commentTextLabel.text = commentInfo.comment
        cell.commentProfilePicture.image = commentInfo.profilePicture
        cell.commentLikeCountLabel.text = String(commentInfo.likes.count)
        cell.delegate = self
        cell.commentIndex = indexPath.row
        cell.usernameLabel.text = commentInfo.username
        let uid = Auth.auth().currentUser?.uid ?? ""
        if commentInfo.likes.contains(uid){
            cell.commentLikeButton.setImage(UIImage(systemName: "hand.thumbsup.fill"), for: .normal)
        }
        else{
            cell.commentLikeButton.setImage(UIImage(systemName: "hand.thumbsup"), for: .normal)
        }
        return cell
    }

}
