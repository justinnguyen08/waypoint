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


    override func viewDidLoad() {
        super.viewDidLoad()
        if let user = Auth.auth().currentUser {
            print("User is signed in with uid: \(user.uid)")
            basePath = "\(user.uid)/"
            fetchAllImageURLs(uuid: user.uid)
            
        } else {
            print("No user is signed in.")
        }
    }
    
    // Get's all the imageURLs for a specific user
//    func fetchAllImageURLs(uuid: String) {
//        Task {
//            do {
//                let storageRef = Storage.storage().reference().child(basePath)
//                let result = try await storageRef.listAllAsync()
//                var imgs: [UIImage] = []
//
//                for folderRef in result.prefixes {
//                    do {
//                        let folderResult = try await folderRef.listAllAsync()
//                        if let dailyItem = folderResult.items.first(where: { $0.name.contains("daily_pic.jpg") }) ?? folderResult.items.first {
//                            dailyItem.getData(maxSize: 10 * 1024 * 1024) { [weak self] dataResult in
//                                guard let self = self else { return }
//                                switch dataResult {
//                                case .failure(let error):
//                                    print("Error downloading daily picture: \(error.localizedDescription)")
//                                    return
//                                case .success(let data):
//                                    guard let img = UIImage(data: data) else { return }
//                                    imgs.append(img)
//                                }
//                            }
//                        }
//                    } catch {
//                        print("Error processing folder \(folderRef.name): \(error)")
//                    }
//                }
//
//                if img.count == result.prefixes.count {
//                    
//                }
//        
//            } catch {
//                print("Top-level error: \(error)")
//            }
//        }
//    }
    
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
                            let url = try await dailyItem.downloadURLAsync()
                            urls.append(url)
                        }
                    } catch {
                        print("Error processing folder \(folderRef.name): \(error)")
                    }
                }

                await MainActor.run {
                    self.imageUrls = urls.sorted { $0.absoluteString < $1.absoluteString }
                    self.startSlideshow()
                }
            } catch {
                print("Top-level error: \(error)")
            }
        }
    }




    func startSlideshow() {
        guard !imageUrls.isEmpty else { return }
        showImage(index: currentIndex)

        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.currentIndex = (self.currentIndex + 1) % self.imageUrls.count
            self.showImage(index: self.currentIndex)
        }
    }
    
    func showImage(index: Int) {
            let url = imageUrls[index]
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data,
                      let image = UIImage(data: data) else {
                    return
                }
                DispatchQueue.main.async {
                    UIView.transition(with: self.yearlyTimelapsPictures,
                                      duration: 1.0,
                                      options: .transitionCrossDissolve,
                                      animations: {
                                          self.yearlyTimelapsPictures.image = image
                                      },
                                      completion: nil)
                }
            }.resume()
        }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        slideshowTimer?.invalidate()
    }

}

extension StorageReference {
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
