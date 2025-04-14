//
//  FullPhotoViewController.swift
//  Waypoint
//
//  Created by Pranav Sridhar on 4/14/25.
//

import UIKit

class FullPhotoViewController: UIViewController {
    
    
    @IBOutlet weak var photoView: UIImageView!
    var photo: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        photoView.contentMode = .scaleAspectFit
        photoView.image = photo
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
