//  Views/PhotoGalleryView.swift
import SwiftUI

struct PhotoGalleryView: View {
    let photos: [HolePhoto]
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhoto: HolePhoto?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.2, blue: 0.1),
                        Color(red: 0.02, green: 0.15, blue: 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if photos.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        Text("No Photos Yet")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        Text("Take photos during your round to see them here!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(photos) { photo in
                                PhotoThumbnail(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Round Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
                
                if !photos.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: createCollageImage(),
                            preview: SharePreview(
                                "Golf Round Photos",
                                image: createCollageImage()
                            )
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
        }
    }
    
    private func createCollageImage() -> Image {
        // For simple implementation, just use first photo
        // In production, you could create a real collage
        if let firstPhoto = photos.first, let uiImage = firstPhoto.image {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
}

struct PhotoThumbnail: View {
    let photo: HolePhoto
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Placeholder if image fails to load
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.3))
                    }
            }
            
            HStack {
                Text("Hole \(photo.holeNumber)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(photo.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            if let caption = photo.caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .frame(width: 150)
    }
}

struct PhotoDetailView: View {
    let photo: HolePhoto
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    if let image = photo.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                    
                    VStack(spacing: 8) {
                        Text("Hole \(photo.holeNumber)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        Text(photo.formattedTime)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        if let caption = photo.caption {
                            Text(caption)
                                .font(.body)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if let image = photo.image {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("Hole \(photo.holeNumber)")) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PhotoGalleryView(photos: [])
}
