//  Project: Waypoint
//  Course: CS371L
//
//  MapCollectionViewController.swift
//  Waypoint
//
//  Created by Justin Nguyen on 4/9/25.
//

import UIKit
import MapKit
import CoreLocation
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

class MapCollectionViewController: UIViewController {
    
    @IBOutlet weak var datePicker: UIDatePicker!
    var mapVC: MapViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        datePicker.maximumDate = Date()
        datePicker.datePickerMode = .date
        
        datePicker.addAction(
            UIAction { [weak self] _ in
                guard let self = self,
                      let mapVC = self.mapVC
                else { return }
                
                let pickedDate = self.datePicker.date
//                mapVC.targetDate = dateString
                mapVC.refreshAllPins(date: readableDate(from: pickedDate))
            },
            for: .valueChanged
        )
    }
    
    func readableDate(from date: Date) -> String {
        let fmt = DateFormatter()
        // user’s timezone
        fmt.calendar = Calendar.current
        fmt.timeZone = .current
        fmt.locale   = Locale(identifier: "en_US_POSIX")
        // e.g. 2025‑04‑17
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? MapViewController {
            mapVC = destination
        }
    }
}
