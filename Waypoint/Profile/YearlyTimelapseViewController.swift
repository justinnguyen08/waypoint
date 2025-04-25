//  Project: Waypoint
//  Course: CS371L
//
//  YearlyTimelapseViewController.swift
//  Waypoint
//
//  Created by Tarun Somisetty on 4/18/25.
//

import UIKit
import FirebaseStorage
import FirebaseAuth

class YearlyTimelapseViewController: UIViewController {

    @IBOutlet weak var yearlyTimelapsPictures: UIImageView!
    
    private var queue: DispatchQueue!
    var imageUrls: [URL] = []
    var currentIndex: Int = 0
    var slideshowTimer: Timer?
    var basePath = ""


    // Sets up the image view for the yearly timelapse to work as a presentation
    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = Auth.auth().currentUser {
            print("User is signed in with uid: \(user.uid)")
            basePath = "\(user.uid)/"
            fetchAllImageURLs(uuid: user.uid)
        } else {
            print("No user is signed in.")
        }
        yearlyTimelapsPictures.layer.cornerRadius = 16
        yearlyTimelapsPictures.layer.masksToBounds = true
        yearlyTimelapsPictures.layer.shadowColor = UIColor.black.cgColor
        yearlyTimelapsPictures.layer.shadowOpacity = 0.25
        yearlyTimelapsPictures.layer.shadowOffset = CGSize(width: 0, height: 2)
        yearlyTimelapsPictures.layer.shadowRadius = 8
        yearlyTimelapsPictures.contentMode = .scaleAspectFit

    }
    
    // Gets all the image urls using the functions from the firebase commands to store all the urls, and
    // send it to start the slideshow
    func fetchAllImageURLs(uuid: String) {
        Task {
            do {
                let storageRef = Storage.storage().reference().child(basePath)
                let result = try await storageRef.listAllAsync()
                var urls: [URL] = []

                for folderRef in result.prefixes {
                    do {
                        let folderResult = try await folderRef.listAllAsync()
                        if let dailyItem = folderResult.items.first(where: { $0.name.contains("daily_pic.jpg") }) ?? folderResult.items.first {
                            // fetch image url
                            let url = try await dailyItem.downloadURLAsync()
                            urls.append(url)
                        }
                    } catch {
                        print("Error processing folder \(folderRef.name): \(error)")
                    }
                }
                
                // sort images and start slideshow video
                await MainActor.run {
                    self.imageUrls = urls.sorted { $0.absoluteString < $1.absoluteString }
                    self.startSlideshow()
                }
            } catch {
                print("Top-level error: \(error)")
            }
        }
    }
    
    // runs slideshow video of each image
    func startSlideshow() {
        guard !imageUrls.isEmpty else { return }
        showImage(index: currentIndex)

        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.showImage(index: self.currentIndex)
            self.currentIndex = (self.currentIndex + 1) % self.imageUrls.count
        }
    }
    
    // shows the images, and presents it in the image view
    func showImage(index: Int) {
        let url = imageUrls[index]
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let image = UIImage(data: data) else {
                return
            }
            DispatchQueue.main.async {
                if self.yearlyTimelapsPictures.image?.pngData() != image.pngData() {
                    UIView.transition(with: self.yearlyTimelapsPictures,
                                      duration: 1.0,
                                      options: [.transitionCrossDissolve],
                                      animations: {
                        self.yearlyTimelapsPictures.alpha = 0
                        self.yearlyTimelapsPictures.image = image
                        self.yearlyTimelapsPictures.alpha = 1
                    })
                }
            }
        }.resume()
    }

    // Makes sure that slideshow stops when you leave the screen
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        slideshowTimer?.invalidate()
    }

}

extension StorageReference {
    
    // lists all folders shown in firebase asynchronously
    func listAllAsync() async throws -> StorageListResult {
        try await withCheckedThrowingContinuation { continuation in
            self.listAll { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    // To download a url from firebase asynchronously
    func downloadURLAsync() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.downloadURL { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                }
            }
        }
    }
}
