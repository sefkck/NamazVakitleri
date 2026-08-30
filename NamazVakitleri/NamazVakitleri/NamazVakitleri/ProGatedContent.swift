import SwiftUI

struct ProGatedContent<Content: View>: View {
    @EnvironmentObject private var userStore: UserStore
    @State private var showPayment = false

    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    private var isPro: Bool {
        userStore.currentUser?.isPro == true
    }

    var body: some View {
        ZStack {
            content()
                .blur(radius: isPro ? 0 : 12)
                .disabled(!isPro)

            if !isPro {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Pro İçerik")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(title) içeriğine erişmek için Pro hesaba geç.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)
                    Button {
                        showPayment = true
                    } label: {
                        Text("Pro Ol")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(32)
            }
        }
        .sheet(isPresented: $showPayment) {
            ProPaymentView()
        }
    }
}
