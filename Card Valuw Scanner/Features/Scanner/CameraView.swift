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
                parent.capturedImage = image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// A more advanced camera view that provides a card scanning overlay
struct CardScannerCameraView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    var body: some View {
        ZStack {
            // Show different UI based on source type
            if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraView(capturedImage: $capturedImage, isPresented: $isPresented)
                    .overlay(cameraOverlay)
            } else {
                // Photo library view doesn't need the overlay
                CameraView(capturedImage: $capturedImage, isPresented: $isPresented)
            }
        }
        .onAppear {
            // Set the appropriate source type based on device capabilities
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                sourceType = .camera
            } else {
                sourceType = .photoLibrary
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // Camera overlay with card frame - but WITHOUT a custom capture button
    private var cameraOverlay: some View {
        VStack {
            Spacer()
            
            Text("Position the card within the frame")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
            
            // Card frame overlay
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 300, height: 420) // Standard card aspect ratio
                .padding(.vertical, 40)
            
            Spacer()
            
            // Remove the custom capture button that was causing the overlap
            // Let the system's native camera button handle the capture
            Spacer().frame(height: 100) // Add space at the bottom to avoid overlapping with system UI
        }
    }
} 