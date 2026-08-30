import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var userStore: UserStore

    @State private var isRegisterMode = false
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)

                Text("Namaz Vakitleri")
                    .font(.title)
                    .fontWeight(.light)
                    .foregroundColor(.white)

                VStack(spacing: 14) {
                    TextField("Kullanıcı adı", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    SecureField("Şifre (en az 6 karakter)", text: $password)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)

                    if isRegisterMode {
                        SecureField("Şifre (tekrar)", text: $confirmPassword)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    submit()
                } label: {
                    Text(isRegisterMode ? "Hesap Oluştur" : "Giriş Yap")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                Button {
                    isRegisterMode.toggle()
                    errorMessage = nil
                } label: {
                    Text(isRegisterMode ? "Zaten hesabın var mı? Giriş yap" : "Hesabın yok mu? Hesap oluştur")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }

                Spacer()
                Spacer()
            }
        }
    }

    private func submit() {
        errorMessage = nil
        if isRegisterMode {
            guard password == confirmPassword else {
                errorMessage = "Şifreler eşleşmiyor."
                return
            }
            switch userStore.register(username: username, password: password) {
            case .success: break
            case .failure(let error): errorMessage = error.errorDescription
            }
        } else {
            switch userStore.login(username: username, password: password) {
            case .success: break
            case .failure(let error): errorMessage = error.errorDescription
            }
        }
    }
}

#Preview {
    AuthView().environmentObject(UserStore())
}
