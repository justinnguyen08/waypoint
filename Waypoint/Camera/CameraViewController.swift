//  Project: Waypoint
//  Course: CS371L
//
//  CameraViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 3/4/25.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController
{
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction func openBackCam(_ sender: UIButton) {
        performSegue(withIdentifier: "openBackCam", sender: sender)
    }
    @IBAction func openFrontCam(_ sender: Any) {
        performSegue(withIdentifier: "openFrontCam", sender: sender)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "openBackCam" {
            let openCamVC = segue.destination as! OpenCamViewController
            openCamVC.position = .back
        } else if segue.identifier == "openFrontCam" {
            let openCamVC = segue.destination as! OpenCamViewController
            openCamVC.position = .front
        }
    }
}
