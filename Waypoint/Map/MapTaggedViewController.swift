//
//  MapTaggedViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/20/25.
//

import UIKit

struct TaggedEntry{
    let profilePicture: UIImage
    let username: String
    let uid: String
}

class MapTaggedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var taggedTable: UITableView!
    
    var allTagged: [TaggedEntry] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        taggedTable.dataSource = self
        taggedTable.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allTagged.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaggedCell", for: indexPath)
        let current = allTagged[indexPath.row]
        cell.textLabel!.text = current.username
        cell.imageView?.image = current.profilePicture
        return cell
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
