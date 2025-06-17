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
                if cameraDevice.hasTorch {
                    try? cameraDevice.lockForConfiguration()
                    // Auto-enable flash for better text recognition in various lighting conditions
                    picker.cameraFlashMode = .auto
                    cameraDevice.unlockForConfiguration()
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
            // For now, just return the original image
            // In a future enhancement, we could add card edge detection and cropping
            return image
        }
    }
}

// A more advanced camera view that provides a card scanning overlay
struct CardScannerCameraView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var showingTips: Bool = true
    @State private var tipIndex: Int = 0
    
    // Tips for better card scanning
    private let scanningTips = [
        "Position the card within the frame",
        "Ensure good lighting",
        "Hold the camera steady",
        "Avoid glare on the card"
    ]
    
    var body: some View {
        ZStack {
            // Show different UI based on source type
            if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraView(capturedImage: $capturedImage, isPresented: $isPresented)
                    .overlay(cameraOverlay)
                    .overlay(tipsOverlay, alignment: .top)
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
                .stroke(Color.white, lineWidth: 3)
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
                    }
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
    
    // Start rotating through tips
    private func startTipRotation() {
        // Create a timer that changes the tip every 3 seconds
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            withAnimation(.easeInOut) {
                tipIndex = (tipIndex + 1) % scanningTips.count
            }
        }
    }
} 