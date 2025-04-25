//  Project: Waypoint
//  Course: CS371L
//
//  ChallengePhotoManager.swift
//  Waypoint
//
//  Created by Tony Ngo on 4/15/25.
//

import UIKit
import AVFoundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth


class ChallengePhotoManager: NSObject, AVCapturePhotoCaptureDelegate{
    // camera information
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var preview: AVCaptureVideoPreviewLayer?
    var position: AVCaptureDevice.Position = .back
    var photoOutput: AVCapturePhotoOutput?
    var capturedData: Data?
    var flashMode: AVCaptureDevice.FlashMode = .off
    var timestamp: Date?
    
    var onImageCaptured: ((UIImage, Data) -> Void)?
    
    // Start live camera session, request access to camera if needed
    func setupCaptureSession(with position: AVCaptureDevice.Position, view: UIView) {
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Camera unavailable for position \(position.rawValue)")
            return
        }
        self.device = newDevice
        do {
            let input = try AVCaptureDeviceInput(device: self.device!)
            self.session = AVCaptureSession()
            session!.sessionPreset = .photo
            
            self.photoOutput = AVCapturePhotoOutput()

            if session!.canAddInput(input) {
                session!.addInput(input)
            } else {
                print("Cannot add input to session")
                return
            }
            
            if session!.canAddOutput(photoOutput!){
                session!.addOutput(photoOutput!)
            }
            else{
                print("Cannot add output to session")
                return
            }
            
            self.preview = AVCaptureVideoPreviewLayer(session: session!)
            self.preview!.videoGravity = .resizeAspectFill
            
            self.preview!.frame = view.bounds
            view.clipsToBounds = true
            view.layer.insertSublayer(self.preview!, at: 0)
            let queue = DispatchQueue(label: "myQueue", qos: .background)
            
            queue.async {
                self.session!.startRunning()
            }
        } catch {
            print("Unable to create input: \(error.localizedDescription)")
        }
    }
    
    func dismissCamera() {
        DispatchQueue.main.async {
            
            self.session?.stopRunning()
            self.session = nil

            // Remove preview
            self.preview?.removeFromSuperlayer()
            self.preview = nil

            // Nil out everything to release camera resources
            self.session = nil
            self.photoOutput = nil
            self.device = nil
        }
    }


    
    func toggleFlash() -> Bool{
        self.flashMode = (self.flashMode == .off) ? .on : .off
        return self.flashMode == .on
    }
    
    func flipCamera(){
        guard let currentSession = session, currentSession.isRunning else { return }
        
        let newPosition: AVCaptureDevice.Position = (position == .front) ? .back : .front
        
        currentSession.beginConfiguration()
        
        // Stopping active camera
        if let currentInput = currentSession.inputs.first as? AVCaptureDeviceInput {
            currentSession.removeInput(currentInput)
        }
        
        // Setting up device
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            print("Camera unavailable for position \(newPosition.rawValue)")
            currentSession.commitConfiguration()
            return
        }
        
        // Add to session
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if currentSession.canAddInput(newInput) {
                currentSession.addInput(newInput)
                self.device = newDevice
                self.position = newPosition
            } else {
                print("Cannot add new input to session")
            }
        } catch {
            print("Error creating new input: \(error.localizedDescription)")
        }
        
        currentSession.commitConfiguration()
    }
    
    func capturePhoto(){
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard var image = UIImage(data: imageData) else { return }
        
        timestamp = Date()
        
        if let exifMeta = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let originalDate = exifMeta[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            print("EXIF Timestamp: \(originalDate)")
        } else {
            print("Using current timestamp: \(timestamp)")
        }
        if self.position == .front {
            guard let cgImage = image.cgImage else { return }
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }
        
        // update interface with image, setting photo's properties
        DispatchQueue.main.async {
            self.session?.stopRunning()
            self.preview?.removeFromSuperlayer()
            self.capturedData = imageData
            self.onImageCaptured?(image, imageData)
        }
    }
    
    // resume the camera session
    func resumeCamera(view: UIView, position: AVCaptureDevice.Position){
        setupCaptureSession(with: position, view: view)
    }
}
