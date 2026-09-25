import SwiftUI
import GoogleMobileAds

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if !showSplash {
                MainTabView()
                    .transition(.opacity)
            }

            if showSplash {
                SplashView(isFinished: Binding(
                    get: { !showSplash },
                    set: { finished in
                        guard finished else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSplash = false
                        }
                    }
                ))
                .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .utility).async {
                MobileAds.shared.start(completionHandler: nil)
            }
        }
    }
}

#Preview {
    RootView()
}
