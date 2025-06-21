import SwiftUI
import AVFoundation
import Vision
import UIKit

// Notification name for card capture
extension Notification.Name {
    static let captureCardPhoto = Notification.Name("captureCardPhoto")
}

struct LiveCardScannerView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showFlash = false
    @State private var isProcessing = false
    @State private var detectedRectangle: CGRect?
    @State private var stabilizedRectangleCount = 0
    @State private var lastStableRectangle: CGRect?
    @State private var showTips = true
    @State private var torchIsOn = false
    
    // For rectangle stability detection
    private let stabilityThreshold = 10
    private let rectangleSimilarityThreshold: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Camera view
            CardCameraView(
                detectedRectangle: $detectedRectangle,
                capturedImage: $capturedImage,
                isProcessing: $isProcessing,
                torchIsOn: $torchIsOn
            )
            .edgesIgnoringSafeArea(.all)
            
            // Overlay for detected card
            if let rect = detectedRectangle {
                GeometryReader { geometry in
                    let scaledRect = CGRect(
                        x: rect.origin.x * geometry.size.width,
                        y: rect.origin.y * geometry.size.height,
                        width: rect.width * geometry.size.width,
                        height: rect.height * geometry.size.height
                    )
                    
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geometry.size))
                        path.addRect(scaledRect)
                    }
                    .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    
                    // Draw rectangle border
                    Rectangle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: scaledRect.width, height: scaledRect.height)
                        .position(x: scaledRect.midX, y: scaledRect.midY)
                    
                    // Corner markers
                    Group {
                        // Top left
                        CornerMarker()
                            .position(x: scaledRect.minX, y: scaledRect.minY)
                        
                        // Top right
                        CornerMarker()
                            .position(x: scaledRect.maxX, y: scaledRect.minY)
                        
                        // Bottom left
                        CornerMarker()
                            .position(x: scaledRect.minX, y: scaledRect.maxY)
                        
                        // Bottom right
                        CornerMarker()
                            .position(x: scaledRect.maxX, y: scaledRect.maxY)
                    }
                }
            }
            
            // Flash effect when capturing
            if showFlash {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showFlash = false
                        }
                    }
            }
            
            // Tips overlay
            if showTips {
                VStack {
                    Spacer()
                    Text("Position the card within the frame")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
                .onAppear {
                    // Hide tips after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showTips = false
                        }
                    }
                }
            }
            
            // Controls overlay
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    // Flashlight toggle
                    Button(action: {
                        torchIsOn.toggle()
                    }) {
                        Image(systemName: torchIsOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                .padding(.top, 44)
                
                Spacer()
                
                // Capture button
                Button(action: {
                    captureCard()
                }) {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        )
                }
                .disabled(isProcessing)
                .padding(.bottom, 30)
            }
        }
        .onChange(of: detectedRectangle) { _, newRect in
            if let newRect = newRect, let lastRect = lastStableRectangle {
                // Check if the new rectangle is similar to the last stable one
                if isRectangleSimilar(newRect, to: lastRect) {
                    stabilizedRectangleCount += 1
                    
                    // If we've seen a stable rectangle for enough frames, auto-capture
                    if stabilizedRectangleCount >= stabilityThreshold {
                        captureCard()
                        stabilizedRectangleCount = 0
                    }
                } else {
                    // Reset stability counter
                    stabilizedRectangleCount = 0
                    lastStableRectangle = newRect
                }
            } else if let newRect = newRect {
                lastStableRectangle = newRect
            }
        }
    }
    
    private func captureCard() {
        guard !isProcessing else { return }
        
        withAnimation {
            showFlash = true
            isProcessing = true
        }
        
        // Trigger the photo capture via notification
        NotificationCenter.default.post(name: .captureCardPhoto, object: nil)
        
        // After a short delay, dismiss this view
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
    
    private func isRectangleSimilar(_ rect1: CGRect, to rect2: CGRect) -> Bool {
        let xDiff = abs(rect1.origin.x - rect2.origin.x) * 100
        let yDiff = abs(rect1.origin.y - rect2.origin.y) * 100
        let widthDiff = abs(rect1.width - rect2.width) * 100
        let heightDiff = abs(rect1.height - rect2.height) * 100
        
        return xDiff < rectangleSimilarityThreshold &&
               yDiff < rectangleSimilarityThreshold &&
               widthDiff < rectangleSimilarityThreshold &&
               heightDiff < rectangleSimilarityThreshold
    }
}

// Corner marker for rectangle corners
struct CornerMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
            
            Circle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 12, height: 12)
        }
    }
}

// A simpler implementation using UIViewControllerRepresentable
struct CardCameraView: UIViewControllerRepresentable {
    @Binding var detectedRectangle: CGRect?
    @Binding var capturedImage: UIImage?
    @Binding var isProcessing: Bool
    @Binding var torchIsOn: Bool
    
    func makeUIViewController(context: Context) -> CardCameraViewController {
        let controller = CardCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CardCameraViewController, context: Context) {
        uiViewController.torchEnabled = torchIsOn
        uiViewController.isProcessing = isProcessing
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CardCameraViewControllerDelegate {
        var parent: CardCameraView
        
        init(_ parent: CardCameraView) {
            self.parent = parent
            super.init()
            
            // Register for capture notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCaptureNotification(_:)),
                name: .captureCardPhoto,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func handleCaptureNotification(_ notification: Notification) {
            // Trigger capture in the view controller
            if let viewController = notification.object as? CardCameraViewController {
                viewController.capturePhoto()
            } else {
                // If notification doesn't contain the view controller, find it
                if let appDelegate = UIApplication.shared.delegate,
                   let window = appDelegate.window ?? UIApplication.shared.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    func findCardCameraViewController(_ viewController: UIViewController) -> CardCameraViewController? {
                        if let vc = viewController as? CardCameraViewController {
                            return vc
                        }
                        
                        for child in viewController.children {
                            if let found = findCardCameraViewController(child) {
                                return found
                            }
                        }
                        
                        if let presented = viewController.presentedViewController {
                            return findCardCameraViewController(presented)
                        }
                        
                        return nil
                    }
                    
                    if let cameraVC = findCardCameraViewController(rootViewController) {
                        cameraVC.capturePhoto()
                    }
                }
            }
        }
        
        func cameraViewController(_ controller: CardCameraViewController, didDetectRectangle rectangle: CGRect?) {
            parent.detectedRectangle = rectangle
        }
        
        func cameraViewController(_ controller: CardCameraViewController, didCapturePhoto photo: UIImage) {
            parent.capturedImage = photo
            parent.isProcessing = false
        }
    }
}

// Protocol for camera view controller delegate
protocol CardCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CardCameraViewController, didDetectRectangle rectangle: CGRect?)
    func cameraViewController(_ controller: CardCameraViewController, didCapturePhoto photo: UIImage)
}

// View controller that handles camera functionality
class CardCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    weak var delegate: CardCameraViewControllerDelegate?
    
    var torchEnabled: Bool = false {
        didSet {
            toggleTorch(torchEnabled)
        }
    }
    
    var isProcessing: Bool = false
    
    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var rectangleRequest: VNDetectRectanglesRequest?
    private var lastFrameTime = Date()
    private let frameProcessingInterval: TimeInterval = 0.1 // Process 10 frames per second
    
    // Add a new method for rectangle stabilization to reduce jitter
    private var previousRectangles: [CGRect] = []
    private let maxPreviousRectangles = 5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupVision()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    private func setupCamera() {
        // Setup camera
        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        // Configure camera for high quality
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
        } catch {
            print("Error configuring camera: \(error)")
        }
        
        // Setup input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Error setting up camera input: \(error)")
            return
        }
        
        // Setup video output
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        
        // Setup photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            // Use maxPhotoDimensions instead of deprecated isHighResolutionCaptureEnabled
            if #available(iOS 16.0, *) {
                // Get the supported dimensions from the active format
                if let device = AVCaptureDevice.default(for: .video),
                   let supportedDimensions = device.activeFormat.supportedMaxPhotoDimensions.first {
                    photoOutput.maxPhotoDimensions = supportedDimensions
                }
            } else {
                // For iOS 15 and below, use the deprecated API
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    private func setupVision() {
        // Setup rectangle detection request
        rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
            guard let self = self, error == nil else { return }
            
            // Get detected rectangles
            guard let results = request.results as? [VNRectangleObservation] else {
                DispatchQueue.main.async {
                    self.delegate?.cameraViewController(self, didDetectRectangle: nil)
                }
                return
            }
            
            // Filter rectangles based on Pokemon card aspect ratio
            // Standard Pokemon card aspect ratio is approximately 0.71 (2.5" x 3.5")
            let cardAspectRatio: CGFloat = 0.71
            let aspectRatioTolerance: CGFloat = 0.05
            
            let cardRectangles = results.filter { rectangle in
                let aspectRatio = rectangle.boundingBox.width / rectangle.boundingBox.height
                return abs(aspectRatio - cardAspectRatio) < aspectRatioTolerance
            }
            
            // If we have card-like rectangles, use the one with highest confidence
            if let bestRectangle = cardRectangles.first {
                // Convert normalized coordinates to view coordinates
                let rect = CGRect(
                    x: bestRectangle.boundingBox.origin.x,
                    y: 1 - bestRectangle.boundingBox.origin.y - bestRectangle.boundingBox.height,
                    width: bestRectangle.boundingBox.width,
                    height: bestRectangle.boundingBox.height
                )
                
                // Apply stabilization to reduce jitter
                let stabilizedRect = self.stabilizeRectangle(rect)
                
                DispatchQueue.main.async {
                    self.delegate?.cameraViewController(self, didDetectRectangle: stabilizedRect)
                }
            } else if let bestRectangle = results.first {
                // Fallback to the best rectangle even if it doesn't match card aspect ratio
                let rect = CGRect(
                    x: bestRectangle.boundingBox.origin.x,
                    y: 1 - bestRectangle.boundingBox.origin.y - bestRectangle.boundingBox.height,
                    width: bestRectangle.boundingBox.width,
                    height: bestRectangle.boundingBox.height
                )
                
                DispatchQueue.main.async {
                    self.delegate?.cameraViewController(self, didDetectRectangle: rect)
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.cameraViewController(self, didDetectRectangle: nil)
                }
            }
        }
        
        // Configure rectangle detection with parameters optimized for Pokemon cards
        rectangleRequest?.minimumAspectRatio = 0.65 // Pokemon cards have ~0.71 aspect ratio
        rectangleRequest?.maximumAspectRatio = 0.75
        rectangleRequest?.minimumSize = 0.2 // Minimum 20% of the screen
        rectangleRequest?.maximumObservations = 3 // Get multiple rectangles to filter
        rectangleRequest?.minimumConfidence = 0.8 // Higher confidence threshold
        rectangleRequest?.quadratureTolerance = 10.0 // More tolerance for imperfect rectangles
    }
    
    // Add a new method for rectangle stabilization to reduce jitter
    private func stabilizeRectangle(_ rect: CGRect) -> CGRect {
        // Add the new rectangle to our history
        previousRectangles.append(rect)
        
        // Keep only the most recent rectangles
        if previousRectangles.count > maxPreviousRectangles {
            previousRectangles.removeFirst()
        }
        
        // If we don't have enough history, just return the current rectangle
        guard previousRectangles.count >= 3 else {
            return rect
        }
        
        // Calculate the average rectangle from recent history
        var avgX: CGFloat = 0
        var avgY: CGFloat = 0
        var avgWidth: CGFloat = 0
        var avgHeight: CGFloat = 0
        
        for prevRect in previousRectangles {
            avgX += prevRect.origin.x
            avgY += prevRect.origin.y
            avgWidth += prevRect.width
            avgHeight += prevRect.height
        }
        
        avgX /= CGFloat(previousRectangles.count)
        avgY /= CGFloat(previousRectangles.count)
        avgWidth /= CGFloat(previousRectangles.count)
        avgHeight /= CGFloat(previousRectangles.count)
        
        // Return the stabilized rectangle
        return CGRect(x: avgX, y: avgY, width: avgWidth, height: avgHeight)
    }
    
    func toggleTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Error toggling torch: \(error)")
        }
    }
    
    func capturePhoto() {
        guard !isProcessing else { return }
        isProcessing = true
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        // Use maxPhotoDimensions instead of deprecated isHighResolutionPhotoEnabled
        if #available(iOS 16.0, *) {
            // No need to set maxPhotoDimensions in settings - the photoOutput's setting will be used
        } else {
            // Deprecated API for iOS 15 and below
            settings.isHighResolutionPhotoEnabled = true
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle frame processing
        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) >= frameProcessingInterval else { return }
        lastFrameTime = now
        
        // Process frames only if not already processing a capture
        guard !isProcessing else { return }
        
        // Create a Vision image request handler
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,
            options: [:]
        )
        
        // Perform rectangle detection
        do {
            try imageRequestHandler.perform([rectangleRequest!])
        } catch {
            print("Failed to perform rectangle detection: \(error)")
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            isProcessing = false
            return
        }
        
        // Get the current detected rectangle from the delegate
        var detectedRect: CGRect? = nil
        if let delegate = delegate as? CardCameraView.Coordinator {
            detectedRect = delegate.parent.detectedRectangle
        }
        
        // If we have a detected rectangle, crop the image to that rectangle
        if let detectedRect = detectedRect {
            let ciImage = CIImage(image: image)!
            
            // Convert normalized coordinates to pixel coordinates
            let imageSize = ciImage.extent.size
            let pixelRect = CGRect(
                x: detectedRect.origin.x * imageSize.width,
                y: (1 - detectedRect.origin.y - detectedRect.height) * imageSize.height,
                width: detectedRect.width * imageSize.width,
                height: detectedRect.height * imageSize.height
            )
            
            // Crop the image to the detected rectangle
            let croppedImage = ciImage.cropped(to: pixelRect)
            let context = CIContext()
            if let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) {
                let croppedUIImage = UIImage(cgImage: cgImage)
                delegate?.cameraViewController(self, didCapturePhoto: croppedUIImage)
                return
            }
        }
        
        // If no rectangle detected or cropping failed, use the full image
        delegate?.cameraViewController(self, didCapturePhoto: image)
    }
} 