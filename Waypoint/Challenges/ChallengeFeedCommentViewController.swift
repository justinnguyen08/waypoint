//
//  ChallengeFeedCommentViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/16/25.
//

import UIKit

class ChallengeFeedCommentViewController: UITabBarController, UITableViewDelegate, UITableViewDataSource {
    
    
    var allComments: [CommentInfo]!
    
    
    @IBOutlet weak var commentTable: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allComments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "", for: indexPath)
        
        return cell
    }

}
