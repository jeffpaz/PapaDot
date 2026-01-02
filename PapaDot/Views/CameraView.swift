//  Views/CameraView.swift
import SwiftUI
import UIKit

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    let holeNumber: Int
    let onPhotoTaken: (UIImage, String?) -> Void
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var caption = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if let image = capturedImage {
                        // Preview mode
                        VStack(spacing: 20) {
                            Text("Hole \(holeNumber)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            // Image preview
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 400)
                                .cornerRadius(16)
                                .shadow(radius: 10)
                                .padding(.horizontal, 20)
                            
                            // Caption input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Caption (optional)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                TextField("e.g., Perfect drive!", text: $caption)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(0.15))
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                            
                            // Action buttons
                            VStack(spacing: 12) {
                                // Save button
                                Button {
                                    onPhotoTaken(image, caption.isEmpty ? nil : caption)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Save Photo")
                                            .font(.headline.bold())
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [.green, .green.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                
                                // Retake button
                                Button {
                                    capturedImage = nil
                                    caption = ""
                                    showCamera = true
                                } label: {
                                    HStack {
                                        Image(systemName: "camera.rotate")
                                        Text("Retake")
                                            .font(.headline)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        // Camera launcher
                        VStack(spacing: 24) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.white)
                            
                            Text("Hole \(holeNumber)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Capture this moment!")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Button {
                                showCamera = true
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                        .font(.headline.bold())
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $capturedImage)
            }
        }
    }
}

// MARK: - Image Picker (Camera)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    CameraView(holeNumber: 7) { image, caption in
        print("Photo taken: \(caption ?? "no caption")")
    }
}
