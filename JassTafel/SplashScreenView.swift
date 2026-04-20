import SwiftUI

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    @ViewBuilder
    private var appIcon: some View {
        if let uiImage = UIImage(named: "AppIcon") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "suit.club.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.accentColor)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                appIcon
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: .primary.opacity(0.15), radius: 10, y: 5)

                Text("JassTafel")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}
