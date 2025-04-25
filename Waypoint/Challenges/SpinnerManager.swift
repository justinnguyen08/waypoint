//  Project: Waypoint
//  Course: CS371L
//
//  SpinnerManager.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/21/25.
//

import Foundation
import UIKit

// https://www.hackingwithswift.com/example-code/uikit/how-to-use-uiactivityindicatorview-to-show-a-spinner-when-work-is-happening
// spinner manager that allows us to indicate that there is activity
class SpinnerManager{
    let spinner = UIActivityIndicatorView(style: .large)
    
    func showSpinner(view: UIView){
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
    
    func hideSpinner(){
        spinner.stopAnimating()
        spinner.removeFromSuperview()
    }
    
}
