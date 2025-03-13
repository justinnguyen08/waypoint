//  Project: Waypoint
//  Course: CS371L
//
//  TagFriendsViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 3/11/25.
//

import UIKit

class TagFriendsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tagFriendsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tagFriendsTableView.delegate = self
        tagFriendsTableView.dataSource = self
    }
    
    // Setting up table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userOne", for: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userTwo", for: indexPath)
            return cell
        }
    }
}
