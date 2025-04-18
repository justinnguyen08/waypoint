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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        var toReplaceComments : [[String : Any]] = []
        for comment in allComments{
            let toAdd: [String : Any] = ["uid" : comment.uid, "comment" : comment.comment, "likes" : comment.likes, "timestamp" : comment.timestamp]
            toReplaceComments.append(toAdd)
        }
        prevVC.feed[index].comments = toReplaceComments
        prevVC.tableView.reloadRows(at: [IndexPath(row: self.index, section: 0)], with: .automatic)
    }
    
    // when the comment button is pressed then go up the chain to post a comment
    @IBAction func commentButtonPressed(_ sender: Any) {
       // https://www.swiftbysundell.com/articles/connecting-async-await-with-other-swift-code/
        Task {
            // post the actual comment to the firebase
            await prevVC.postComment(commentText: commentTextField.text ?? "", postID: postID, index: index)
            let newComments = await prevVC.getNewData(index: index)
            self.allComments = newComments
            self.commentTextField.text = ""
            self.commentTable.reloadData()
        }
    }
    
    func manualReload(){
        commentTable.reloadData()
    }
    
    // when the comment button is pressed then go up the chain to like a comment!
    func handleCommentLike(commentIndex: Int) async -> Bool{
        let result = await prevVC.handleCommentLike(postID: postID, rowIndex: index, commentIndex: commentIndex)
        let newComments = await prevVC.getNewData(index: index)
        self.allComments = newComments
        self.commentTable.reloadRows(at: [IndexPath(row: commentIndex, section: 0)], with: .automatic)
        return result
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentTableViewCell
        
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
