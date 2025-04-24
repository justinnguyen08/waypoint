//
//  ChallengeFeedCommentViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/16/25.
//

import UIKit
import FirebaseAuth

class ChallengeFeedCommentViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    var allComments: [CommentInfo]!
    
    @IBOutlet weak var profilePictureView: UIImageView!
    @IBOutlet weak var commentTextField: UITextField!
    @IBOutlet weak var postCommentButton: UIButton!
    @IBOutlet weak var commentTable: UITableView!
    @IBOutlet weak var sendCommentView: UIView!
    
    var profilePicture: UIImage!
    var prevVC: ChallengeFeedViewController!
    var postID: String!
    var index: Int!
    
    var commentIndexWillSelect: Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        commentTable.delegate = self
        commentTable.dataSource = self
        commentTextField.delegate = self
        // https://www.youtube.com/watch?v=O4tP7egAV1I
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tableTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tableTap.cancelsTouchesInView = false
        commentTable.addGestureRecognizer(tableTap)

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
        profilePictureView.layer.cornerRadius = profilePictureView.frame.width / 2
        profilePictureView.clipsToBounds = true
        profilePictureView.contentMode = .scaleAspectFill
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        var toReplaceComments : [[String : Any]] = []
        for comment in allComments{
            let toAdd: [String : Any] = ["uid" : comment.uid!, "comment" : comment.comment!, "likes" : comment.likes!, "timestamp" : comment.timestamp!]
            toReplaceComments.append(toAdd)
        }
        prevVC.feed[index].comments = toReplaceComments
        prevVC.tableView.reloadRows(at: [IndexPath(row: self.index, section: 0)], with: .automatic)
    }
    
    // when the comment button is pressed then go up the chain to post a comment
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
        // build a new comment and insert it into the table now
        let newComment = CommentInfo(uid: uid, profilePicture: profilePicture, comment: text, likes: [], username: prevVC.usernameCache[uid] ?? "You", timestamp: Date().timeIntervalSince1970)
        
        allComments.append(newComment)
        commentTable.insertRows(at: [IndexPath(row: allComments.count - 1, section: 0)], with: .automatic)
        commentTextField.text = ""
        
        // also insert it so that when we refresh the page we get that comment too
        prevVC.feed[index].comments.append(["uid" : uid, "comment" : text, "likes" : [], "timestamp" : newComment.timestamp!])
        prevVC.tableView.reloadRows(at: [IndexPath(row: index, section: 9)], with: .automatic)
        
        Task {
            // post the actual comment to the firebase
            await prevVC.postComment(commentText: text, postID: postID, index: index)
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
        
        prevVC.feed[index].comments[commentIndex]["likes"] = likes
        prevVC.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        
        // actually enter into database
        let _ = await prevVC.handleCommentLike(postID: postID, rowIndex: index, commentIndex: commentIndex)
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
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        commentIndexWillSelect = indexPath.row
        let currentCommentUsername = allComments[commentIndexWillSelect].username
        if prevVC.currentUserUsername == currentCommentUsername{
            return indexPath
        }
        if prevVC.currentUserFriends.contains(where: { entry in
            if let currentEntryUsername = entry["username"] as? String {
                return currentEntryUsername == currentCommentUsername
            }
            return false
        }){
            performSegue(withIdentifier: "ChallengeCommentToRemoveProfile", sender: self)
        }
        else if prevVC.currentUserPendingFriends.contains(where: { entry in
            if let currentEntryUsername = entry["username"] as? String {
                return currentEntryUsername == currentCommentUsername
            }
            return false
        }){
            performSegue(withIdentifier: "ChallengeCommentToPendingProfile", sender: self)
        }
        else{
            performSegue(withIdentifier: "ChallengeCommentToAddProfile", sender: self)
        }
        return indexPath
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ChallengeCommentToRemoveProfile", let nextVC = segue.destination as? RemoveViewController {
            // get the username
            let userName = allComments[commentIndexWillSelect].username
            // if friend send to this view controller
            nextVC.selectedUsername = userName
        }
        else if segue.identifier == "ChallengeCommentToAddProfile", let nextVC = segue.destination as? AddFriendViewController{
            // get the username
            let userName = allComments[commentIndexWillSelect].username
            // if friend send to this view controller
            nextVC.selectedUsername = userName
        }
        else if segue.identifier == "ChallengeCommentToPendingProfile", let nextVC = segue.destination as? PendingViewController{
            // get the username
            let userName = allComments[commentIndexWillSelect].username
            // if friend send to this view controller
            nextVC.selectedUsername = userName
        }
    }
    
    // table view functions
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentTableViewCell
        
        let commentInfo = allComments[indexPath.row]
        cell.commentTextLabel.text = commentInfo.comment
        cell.commentProfilePicture.image = commentInfo.profilePicture
        cell.commentProfilePicture.layer.cornerRadius = cell.commentProfilePicture.frame.width / 2
        cell.commentProfilePicture.clipsToBounds = true
        cell.commentProfilePicture.contentMode = .scaleAspectFill
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
