import SwiftUI

struct RootView: View {
    @StateObject private var userStore = UserStore()

    var body: some View {
        Group {
            if userStore.isLoggedIn {
                ContentView()
            } else {
                AuthView()
            }
        }
        .environmentObject(userStore)
    }
}

#Preview {
    RootView()
}
