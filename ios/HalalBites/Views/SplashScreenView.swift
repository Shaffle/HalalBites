import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.8
    @State private var glowScale = 0.3
    @State private var glowOpacity = 0.0
    @State private var ringScale = 0.5
    @State private var ringOpacity = 0.0
    private let brandTeal = Color(red: 0.0, green: 0.58, blue: 0.56)

    var body: some View {
        if isActive {
            ContentView()
        } else {
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

                Image("SafaLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(.horizontal, 24)
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

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isActive = true
                    }
                }
            }
        }
    }
}
