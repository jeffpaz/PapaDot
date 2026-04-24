//  Views/BirthdaySplashView.swift
//
//  Add "Benoit50th" image to Assets.xcassets in Xcode:
//    1. Open Assets.xcassets
//    2. Right-click → New Image Set → name it "Benoit50th"
//    3. Drag Benoit50th.png into the 1x, 2x, or 3x slot
//
//  This screen shows once on first launch, then never again.

import SwiftUI

struct BirthdaySplashView: View {
    let onContinue: () -> Void

    @State private var titleOpacity = 0.0
    @State private var titleOffset = -30.0
    @State private var imageScale = 0.92
    @State private var imageOpacity = 0.0
    @State private var buttonOpacity = 0.0
    @State private var shimmerOffset = -300.0
    @State private var confettiVisible = false

    var body: some View {
        ZStack {
            // Deep green background matching app theme
            Color(red: 0.05, green: 0.2, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - "Happy 50th Benoit!" Header
                ZStack {
                    // Shimmer sweep behind text
                    LinearGradient(
                        colors: [.clear, .yellow.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 160, height: 60)
                    .offset(x: shimmerOffset)
                    .clipped()

                    VStack(spacing: 4) {
                        Text("Happy 50th")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(.yellow.opacity(0.9))
                            .tracking(4)
                            .textCase(.uppercase)

                        Text("Benoit!")
                            .font(.system(size: 52, weight: .black, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .yellow.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 24)
                .opacity(titleOpacity)
                .offset(y: titleOffset)

                // Decorative divider
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .yellow.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                    Text("🎂")
                        .font(.title3)
                    Rectangle()
                        .fill(LinearGradient(colors: [.yellow.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                }
                .padding(.horizontal, 32)
                .opacity(titleOpacity)

                Spacer().frame(height: 24)

                // MARK: - Photo
                ZStack {
                    // Glow behind photo
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.yellow.opacity(0.15))
                        .blur(radius: 20)
                        .padding(8)

                    // Gold border frame
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .white.opacity(0.6), .yellow.opacity(0.4), .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )

                    // The photo — add "Benoit50th" image to Assets.xcassets
                    Image("Benoit50th")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(22)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                .padding(.horizontal, 24)
                .scaleEffect(imageScale)
                .opacity(imageOpacity)

                Spacer().frame(height: 20)

                // Caption
                Text("A round among friends 🏌️‍♂️")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.55))
                    .italic()
                    .opacity(buttonOpacity)

                Spacer()

                // MARK: - Continue Button
                Button(action: onContinue) {
                    ZStack {
                        // Button glow
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.yellow.opacity(0.3))
                            .blur(radius: 10)

                        // Button itself
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow, Color(red: 1, green: 0.75, blue: 0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        HStack(spacing: 10) {
                            Text("Let's Play")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(Color(red: 0.05, green: 0.2, blue: 0.1))

                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0.05, green: 0.2, blue: 0.1))
                        }
                    }
                    .frame(height: 56)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(buttonOpacity)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Entrance Animations

    private func startAnimations() {
        // Title drops in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.2)) {
            titleOpacity = 1
            titleOffset = 0
        }
        // Photo scales up
        withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.45)) {
            imageOpacity = 1
            imageScale = 1.0
        }
        // Button fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.85)) {
            buttonOpacity = 1
        }
        // Shimmer sweep
        withAnimation(.easeInOut(duration: 1.4).delay(1.0)) {
            shimmerOffset = 300
        }
    }
}

#Preview {
    BirthdaySplashView { }
}
