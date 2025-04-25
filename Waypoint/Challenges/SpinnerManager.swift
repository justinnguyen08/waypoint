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
