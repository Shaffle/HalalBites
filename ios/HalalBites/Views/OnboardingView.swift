import SwiftUI

struct OnboardingView: View {
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileCity") private var profileCity = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var nameInput = ""
    @State private var cityInput = ""
    @State private var shake = false

    private let brandTeal = Color(red: 0.0, green: 0.58, blue: 0.56)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.bottom, 12)

            Text("Welcome to Safa Halal")
                .font(.title.bold())
                .padding(.bottom, 4)

            Text("Let's set up your profile")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 36)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Name")
                        .font(.subheadline.bold())
                    TextField("Enter your name", text: $nameInput)
                        .textContentType(.name)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(shake ? Color.red : Color.clear, lineWidth: 1.5)
                        )
                    if shake {
                        Text("Name is required")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Home City")
                            .font(.subheadline.bold())
                        Text("(optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("e.g. Chandler, AZ", text: $cityInput)
                        .textContentType(.addressCity)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                let trimmed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                        shake = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        shake = false
                    }
                    return
                }
                profileName = trimmed
                profileCity = cityInput.trimmingCharacters(in: .whitespacesAndNewlines)
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(brandTeal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}
