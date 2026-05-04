import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.8
    @State private var glowScale = 0.3
    @State private var glowOpacity = 0.0
    @State private var ringScale = 0.5
    @State private var ringOpacity = 0.0
    @State private var zoomScale = 1.0
    @State private var zoomOpacity = 1.0
    @State private var showContent = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Binding var pendingItinerary: Itinerary?
    private let brandTeal = Color(red: 0.0, green: 0.58, blue: 0.56)

    var body: some View {
        ZStack {
            if showContent {
                if hasCompletedOnboarding {
                    ContentView(pendingItinerary: $pendingItinerary)
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }

            if !isActive {
                splashContent
                    .scaleEffect(zoomScale)
                    .opacity(zoomOpacity)
            }
        }
    }

    private var splashContent: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [brandTeal.opacity(0.25), brandTeal.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            Circle()
                .stroke(brandTeal.opacity(0.35), lineWidth: 2)
                .frame(width: 320, height: 320)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .stroke(brandTeal.opacity(0.2), lineWidth: 1.5)
                .frame(width: 450, height: 450)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Image("SplashIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: 200)
                .shadow(color: brandTeal.opacity(0.3), radius: 20, y: 8)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }

            withAnimation(.easeOut(duration: 1.4)) {
                glowScale = 2.5
                glowOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showContent = true

                withAnimation(.easeIn(duration: 0.5)) {
                    zoomScale = 5.0
                    zoomOpacity = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isActive = true
                }
            }
        }
    }

}
