//
//  ViewController.swift
//  TestVNHandPose
//
//  Created by Nguyễn Minh Hiếu on 11/11/20.
//

import UIKit
import ARKit
import Vision
import Foundation
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var sceneView: ARSCNView!
//    private var cameraView: CameraView { view as! CameraView }
    @IBOutlet weak var cameraView: CameraView!
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
//    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    private let handelFingerDataQueue = DispatchQueue(label: "HandleFinger")
    var visionRequests = [VNRequest]()
    private var cameraFeedSession: AVCaptureSession?
    var testNode : SCNNode = SCNNode()
    var handNode : SCNNode? = nil
    var cameraNode: SCNNode = SCNNode()
    var watchNode: SCNNode = SCNNode()
    var watchOverlayContent: SCNReferenceNode? = nil
    var spotLight: SCNNode? = nil
    private var gestureProcessor = HandGestureProcessor()
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupWatchNode(with: Item(id: 1, name: "1", model: "1", thumbItem: "1", actualSize:Size(width: 5, height: 10, depth: 10)))
        self.loopCoreMLUpdata()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        let configure = ARWorldTrackingConfiguration()
        self.sceneView.session.run(configure)
//        self.sceneView.session.delegate = self
    }
    
//    func handleFinger(){
//        handelFingerDataQueue.async {
//            <#code#>
//        }
//    }
//    func setupAVSession() throws {
//        // Select a front facing camera, make an input.
//        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
//            return
////            throw AppError.captureSessionSetup(reason: "Could not find a front facing camera.")
//        }
//
//        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
//            return
////            throw AppError.captureSessionSetup(reason: "Could not create video device input.")
//        }
//
//        let session = AVCaptureSession()
//        session.beginConfiguration()
//        session.sessionPreset = AVCaptureSession.Preset.high
//
//        // Add a video input.
//        guard session.canAddInput(deviceInput) else {
//            return
////            throw AppError.captureSessionSetup(reason: "Could not add video device input to the session")
//        }
//        session.addInput(deviceInput)
//
//        let dataOutput = AVCaptureVideoDataOutput()
//        if session.canAddOutput(dataOutput) {
//            session.addOutput(dataOutput)
//            // Add a video data output.
//            dataOutput.alwaysDiscardsLateVideoFrames = true
//            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
////            dataOutput.setSampleBufferDelegate(self, queue: <#T##DispatchQueue?#>)
////            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
//        } else {
////            throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
//        }
//        session.commitConfiguration()
//        cameraFeedSession = session
//}
    func setupWatchNode(with item: Item) {
        
        guard let url = item.url, let overlayContent = SCNReferenceNode(url: url) else { return }
        print(item.url!)
        watchOverlayContent?.removeFromParentNode()
        watchOverlayContent = overlayContent
        watchOverlayContent?.load()
        
        
        let width = overlayContent.boundingBox.max.x - overlayContent.boundingBox.min.x
        let scale = Float(item.actualSize.width) / (width * 100.0)
        
        overlayContent.scale = .init(scale, scale, scale)
//        watchNode.eulerAngles = SCNVector3()
        watchNode.position = .init(0.0, 0.0, -0.2)
        watchNode.addChildNode(self.watchOverlayContent!)
//        watchNode.frame.widt
        self.sceneView.scene.rootNode.addChildNode(watchNode)
    }
    
    func processPoints(indexMCP: CGPoint?, littleMCP : CGPoint?,wrist : CGPoint?,middleMCP : CGPoint?, thumbCMC: CGPoint?) {
        // Check that we have both points.
        guard let indexPoint = indexMCP, let littlePoint = littleMCP,let wristPoint = wrist ,let midPoint = middleMCP else {
            // If there were no observations for more than 2 seconds reset gesture processor.
//            if Date().timeIntervalSince(lastObservationTimestamp) > 2 {
//                gestureProcessor.reset()
//            }
//            cameraView.showPoints([], color: .clear)
            return
        }
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
        let previewLayer = cameraView.previewLayer
        let indexPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: indexPoint)
        let littlePointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: littlePoint)
        let wristPointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: wristPoint)
        let middlePointConverted = previewLayer.layerPointConverted(fromCaptureDevicePoint: midPoint)
        print(midPoint.x)
        if thumbCMC!.y > wrist!.y {
            print("Left hand")
            self.watchNode.eulerAngles.x = -Float(gestureProcessor.getAngleX((indexPointConverted,littlePointConverted,wristPointConverted,.zero)))
            self.watchNode.eulerAngles.z = (Float(gestureProcessor.getAngleZ((.zero,.zero,wristPointConverted,middlePointConverted))) - Float.pi/2)
        } else {
            print("Right hand")
            self.watchNode.eulerAngles.x = Float(gestureProcessor.getAngleX((indexPointConverted,littlePointConverted,wristPointConverted,.zero)))
            self.watchNode.eulerAngles.z = -(Float(gestureProcessor.getAngleZ((.zero,.zero,wristPointConverted,middlePointConverted))) - Float.pi/2)
        }
        
        // Process new points
        
//        gestureProcessor.processPointsPair((thumbPointConverted, indexPointConverted))
    }
   
    func loopCoreMLUpdata(){
        handelFingerDataQueue.async {
            self.updateCoreML()
            self.loopCoreMLUpdata()
        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        var indexMCP: CGPoint?
        var littleMCP: CGPoint?
        var midMCP : CGPoint?
        var thumbCMC : CGPoint?
        var wrist : CGPoint?
        
        defer {
            DispatchQueue.main.async {
                self.processPoints(indexMCP: indexMCP, littleMCP: littleMCP, wrist: wrist, middleMCP: midMCP, thumbCMC: thumbCMC)
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage , orientation: .down, options: [:])
        handPoseRequest.maximumHandCount = 1
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            // Continue only when a hand was detected in the frame.
            // Since we set the maximumHandCount property of the request to 1, there will be at most one observation.
            guard let observation = handPoseRequest.results?.first else {
                return
            }
            // Get points for thumb and index finger.
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let thumbFingerPoints = try observation.recognizedPoints(.thumb)
            let wristHandPoint = try observation.recognizedPoint(.wrist)
            // Look for tip points.
            guard let indexMCPPoint = indexFingerPoints[.indexMCP], let littleMCPPoint = littleFingerPoints[.littleMCP], let middleMCPPoint = middleFingerPoints[.middleMCP], let thumbCMCPoint = thumbFingerPoints[.thumbCMC] else {
                return
            }
            // Ignore low confidence points.
            guard indexMCPPoint.confidence > 0.3 && littleMCPPoint.confidence > 0.3 else {
                return
            }
            // Convert points from Vision coordinates to AVFoundation coordinates.
            indexMCP = CGPoint(x: indexMCPPoint.location.x, y: 1 - indexMCPPoint.location.y)
            littleMCP = CGPoint(x: littleMCPPoint.location.x, y: 1 - littleMCPPoint.location.y)
            wrist = CGPoint(x: wristHandPoint.location.x, y: 1 - wristHandPoint.location.y)
            
            midMCP = CGPoint(x: middleMCPPoint.location.x
                             , y: 1 - middleMCPPoint.location.y)
            
            thumbCMC = CGPoint(x: thumbCMCPoint.location.x, y: 1 - thumbCMCPoint.location.y)

        } catch {
//            cameraFeedSession?.stopRunning()
//            let error = AppError.visionError(error: error)
//            DispatchQueue.main.async {
//                error.displayInViewController(self)
//            }
        }
        
    }
}


//extension ViewController : ARSessionDelegate  {
//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
////


struct Item: Identifiable, Hashable, Decodable {
    var id: Int
    var name: String
    var model: String
    var thumbItem: String
//    var jointPoint: JointPointType
    var actualSize: Size
    
    var url: URL? {
        return Bundle.main.url(forResource: "Apple_Watch.usdz", withExtension: nil)
    }
}

struct Size: Hashable, Decodable {
    var width: Double
    var height: Double
    var depth: Double
    
    static let zero = Size(width: .zero, height: .zero, depth: .zero)
}
