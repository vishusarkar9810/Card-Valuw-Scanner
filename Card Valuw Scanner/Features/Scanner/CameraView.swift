import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Check if camera is available, otherwise use photo library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
            
            // Configure camera settings for better card scanning
            if let cameraDevice = AVCaptureDevice.default(for: .video) {
                do {
                    try cameraDevice.lockForConfiguration()
                    
                    // Auto-enable flash for better text recognition in various lighting conditions
                    picker.cameraFlashMode = .auto
                    
                    // Set focus mode to continuous auto focus for better card detection
                    if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                        cameraDevice.focusMode = .continuousAutoFocus
                    }
                    
                    // Enable auto exposure for better image quality
                    if cameraDevice.isExposureModeSupported(.continuousAutoExposure) {
                        cameraDevice.exposureMode = .continuousAutoExposure
                    }
                    
                    cameraDevice.unlockForConfiguration()
                } catch {
                    print("Error configuring camera: \(error.localizedDescription)")
                }
            }
        } else {
            // Fallback to photo library for simulator or devices without camera
            picker.sourceType = .photoLibrary
        }
        
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Process the captured image to crop to the card area if possible
                parent.capturedImage = processCardImage(image)
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
        
        // Process the captured image to focus on the card
        private func processCardImage(_ image: UIImage) -> UIImage {
            // Normalize image orientation
            let normalizedImage = normalizeImageOrientation(image)
            
            // For now, just return the normalized image
            // The actual card cropping will be handled by CardScannerService
            return normalizedImage
        }
        
        // Normalize image orientation to .up
        private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up {
                return image
            }
            
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return normalizedImage ?? image
        }
    }
}

// A more advanced camera view that provides a card scanning overlay
struct CardScannerCameraView_Impl: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var showingTips: Bool = true
    @State private var tipIndex: Int = 0
    @State private var showingFlashlight: Bool = false
    @State private var isFlashlightOn: Bool = false
    
    // Tips for better card scanning
    private let scanningTips = [
        "Position the card within the green frame",
        "Ensure good lighting to see card details",
        "Hold the camera steady to avoid blur",
        "Avoid glare on the card surface",
        "Make sure the card name is clearly visible"
    ]
    
    var body: some View {
        ZStack {
            // Show different UI based on source type
            if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraView(capturedImage: $capturedImage, isPresented: $isPresented)
                    .overlay(cameraOverlay)
                    .overlay(tipsOverlay, alignment: .top)
                    .overlay(controlsOverlay, alignment: .bottom)
            } else {
                // Photo library view doesn't need the overlay
            CameraView(capturedImage: $capturedImage, isPresented: $isPresented)
            }
        }
        .onAppear {
            // Set the appropriate source type based on device capabilities
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                sourceType = .camera
                // Start the tip rotation timer
                startTipRotation()
                
                // Check if flashlight is available
                if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
                    showingFlashlight = true
                }
            } else {
                sourceType = .photoLibrary
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // Camera overlay with card frame
    private var cameraOverlay: some View {
        VStack {
            Spacer()
            
            // Card frame overlay
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 3)
                .frame(width: 300, height: 420) // Standard card aspect ratio
                .padding(.vertical, 40)
                .overlay(
                    // Corner markers for better positioning guidance
                    ZStack {
                        // Top left corner
                        Path { path in
                            path.move(to: CGPoint(x: -20, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 20))
                        }
                        .stroke(Color.green, lineWidth: 5)
                        .offset(x: -150, y: -210)
                        
                        // Top right corner
                        Path { path in
                            path.move(to: CGPoint(x: 20, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 20))
                        }
                        .stroke(Color.green, lineWidth: 5)
                        .offset(x: 150, y: -210)
                        
                        // Bottom left corner
                        Path { path in
                            path.move(to: CGPoint(x: -20, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: -20))
                        }
                        .stroke(Color.green, lineWidth: 5)
                        .offset(x: -150, y: 210)
                        
                        // Bottom right corner
                        Path { path in
                            path.move(to: CGPoint(x: 20, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: -20))
                        }
                        .stroke(Color.green, lineWidth: 5)
                        .offset(x: 150, y: 210)
                        
                        // Target areas for important card information
            VStack {
                            // Card name area
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 200, height: 30)
                                .offset(y: -170)
                                .overlay(
                                    Text("Card Name")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                        .offset(y: -170)
                                )
                            
                            // Card number area
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 60, height: 20)
                                .offset(y: 180)
                                .overlay(
                                    Text("Number")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                        .offset(y: 180)
                                )
                        }
                    }
                )
                .background(
                    // Semi-transparent overlay outside the card area
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .mask(
                            Rectangle()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .frame(width: 300, height: 420)
                                        .blendMode(.destinationOut)
                                )
                        )
                )
            
                Spacer()
                
            // Add space at the bottom to avoid overlapping with system UI
            Spacer().frame(height: 100)
        }
    }
    
    // Tips overlay at the top of the screen
    private var tipsOverlay: some View {
        if showingTips {
            return AnyView(
                Text(scanningTips[tipIndex])
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.top, 50)
                    .transition(.opacity)
                    .id(tipIndex) // Force view to update when tip changes
            )
        } else {
            return AnyView(EmptyView())
        }
    }
    
    // Controls overlay at the bottom of the screen
    private var controlsOverlay: some View {
        HStack {
            // Cancel button
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
                
                Spacer()
                
            // Flashlight toggle button (only if available)
            if showingFlashlight {
                Button(action: toggleFlashlight) {
                    Image(systemName: isFlashlightOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
    
    // Start rotating through tips
    private func startTipRotation() {
        // Create a timer that changes the tip every 3 seconds
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            withAnimation(.easeInOut) {
                tipIndex = (tipIndex + 1) % scanningTips.count
            }
        }
    }
    
    // Toggle device flashlight
    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if isFlashlightOn {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: 0.7) // Set to 70% brightness
            }
            
            isFlashlightOn.toggle()
            device.unlockForConfiguration()
        } catch {
            print("Error toggling flashlight: \(error.localizedDescription)")
        }
    }
} 