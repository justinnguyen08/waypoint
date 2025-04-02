//  Project: Waypoint
//  Course: CS371L
//
//  ChallengesViewController.swift
//  Waypoint
//
//  Created by Tony Ngo on 3/10/25.
//

import UIKit

var challengeText = ["Testing"]

class ChallengesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    

    @IBOutlet weak var dailyView: UIView!
    
    @IBOutlet weak var monthlyView: UIView!
    @IBOutlet weak var monthlyTableView: UITableView!
    
    @IBOutlet weak var segmentControl: UISegmentedControl!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        dailyView.isHidden = false
        monthlyView.isHidden = true
        view.bringSubviewToFront(dailyView)
        
        monthlyTableView.delegate = self
        monthlyTableView.dataSource = self
    }
    
    @IBAction func onSegmentChange(_ sender: Any) {
        
        switch segmentControl.selectedSegmentIndex {
        case 0: // daily view
            dailyView.isHidden = false
            monthlyView.isHidden = true
            view.bringSubviewToFront(dailyView)
            
        case 1: // monthly view
            monthlyView.isHidden = false
            dailyView.isHidden = true
            monthlyTableView.reloadData()
            view.bringSubviewToFront(monthlyView)
            
        case 2: // segue to feed page
            performSegue(withIdentifier: "ChallengeFeedSegue", sender: self)
        default:
            print("should never get here")
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return challengeText.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = monthlyTableView.dequeueReusableCell(withIdentifier: "challengeCell", for: indexPath)
        cell.textLabel?.text = challengeText[indexPath.row]
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
