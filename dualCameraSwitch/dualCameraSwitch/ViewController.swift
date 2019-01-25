//
//  ViewController.swift
//  dualCameraSwitch
//
//  Created by Aleksandar Ristanovic on 1/25/19.
//  Copyright © 2019 Aleksandar Ristanovic. All rights reserved.
//

import UIKit
import AVFoundation
import Photos


class ViewController: UIViewController {
    
    @IBOutlet weak var numberOfCapturesTextField: UITextField!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var logOutputTextView: UITextView!
    
    private var switchState: Bool = true
    
    private let captureSession = AVCaptureSession()
    private var capturePhotoOutput = AVCapturePhotoOutput()
    private var currentVideoDeviceInput: AVCaptureDeviceInput!
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                               mediaType: .video, position: .unspecified)
    
    private var photoData: Data?
    private var numberOfCaptures: Int = 0
    
    // New session try out
    //    private let backCameraSession = AVCaptureSession()
    private var backCameraInput: AVCaptureDeviceInput!
    //    private let backCapturePhotoOutput = AVCapturePhotoOutput()
    
    //    private let frontCameraSession = AVCaptureSession()
    private var frontCameraInput: AVCaptureDeviceInput!
    //    private let frontCapturePhotoOutput = AVCapturePhotoOutput()
    
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AVCaptureDevice.requestAccess(for: .video) { (value) in
            DispatchQueue.main.async {
                if value == true {
                    self.setupBackCamera()
                    self.setupFrontCamera()
                    self.setupSession()
                } else {
                    //                    self.showAlert()
                }
                //                self.updateUIFor(permissionGranted: value)
            }
        }
    }
    
    private func setupBackCamera() {
        
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!) else {
            print("Error: Could not set input on a capture session.")
            return 
        }
        backCameraInput = videoDeviceInput
    }
    
    private func setupFrontCamera() {
        
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice!) else {
            print("Error: Could not set input on a capture session.")
            return 
        }
        frontCameraInput = videoDeviceInput
    }
    
    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        //Setting capture output
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        captureSession.addOutput(capturePhotoOutput)
        
        currentVideoDeviceInput = backCameraInput
        
        // Commit configuration and start running
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    private func changeCamera() {
        let currentVideoDevice = self.currentVideoDeviceInput.device
        let currentPosition = currentVideoDevice.position
        
        log(message: "changing \(currentPosition.rawValue == 1 ? "back -> front" : "front -> back" )")
        let startTime = Date()
        
        self.captureSession.beginConfiguration()
        
        // Remove the existing device input first, since the system doesn't support simultaneous use of the rear and front cameras.
        self.captureSession.removeInput(self.currentVideoDeviceInput)
        
        if currentPosition == .back {
            if self.captureSession.canAddInput(frontCameraInput) {
                self.captureSession.addInput(frontCameraInput)
                self.currentVideoDeviceInput = frontCameraInput
            } else {
                log(message:"Could not add input for front camera")
            }
        } else if currentPosition == .front {
            if self.captureSession.canAddInput(backCameraInput) {
                self.captureSession.addInput(backCameraInput)
                self.currentVideoDeviceInput = backCameraInput
            } else {
                log(message:"Could not add input for back camera")
            }
        }
        self.captureSession.commitConfiguration()
        
        log(message: "Changed camera -> \(Date().timeIntervalSince1970 - startTime.timeIntervalSince1970) ")
    }
    
    @IBAction func numberChanged(_ sender: UITextField) {
        captureButton.isEnabled = (sender.text?.count ?? 0) > 0
    }
    
    @IBAction func capturePressed(_ sender: UIButton) {
        log(message: "Capture button pressed")
        numberOfCapturesTextField.resignFirstResponder()
        numberOfCaptures = Int(numberOfCapturesTextField.text ?? "0") ?? 0
        
        for _ in 0..<numberOfCaptures*2 {
            sessionQueue.async {
                self.changeCamera()
                if self.switchState {
                    // Sleep thread, so we can get camera ready for capture - Images will not be green and will be clear
                    if self.currentVideoDeviceInput.device.position == .front {
                        // under 30000 the image could become green / camera probably not adjusted yet
                        usleep(30000)
                    } else if self.currentVideoDeviceInput.device.position == .back {
                        // under 100000 the image is dark - camera probably not adjusted yet
                        usleep(100000)
                    } 
                    let photoSettings = AVCapturePhotoSettings()
                    self.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
                }
            }
        }
    }
    
    @IBAction func switchChanged(_ sender: UISwitch) {
        switchState = sender.isOn
    }
    
    @IBAction func clearPressed(_ sender: UIButton) {
        clearLog()
    }
}

extension ViewController {
    func log(message: String) {
        DispatchQueue.main.async {
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone(abbreviation: "GMT") //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "H:m:ss.SSSS" //Specify your format that you want
            let strDate = dateFormatter.string(from: date)
            self.logOutputTextView.text = self.logOutputTextView.text.appending("\n \(strDate) \(message)")
            let bottom = NSMakeRange(self.logOutputTextView.text.count - 1, 1)
            self.logOutputTextView.scrollRangeToVisible(bottom)
            print("\n \(strDate) \(message)")
        }
    }
    
    func clearLog() {
        logOutputTextView.text = ""
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: photoData, options: options)
                    
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurred while saving photo to photo library: \(error)")
                    }
                }
                )
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        log(message: "PhotoOutput didFinishProcessingPhoto")
        if let error = error {
            log(message: "Error capturing photo: \(error)")
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }
}
