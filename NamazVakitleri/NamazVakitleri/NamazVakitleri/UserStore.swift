import Foundation
import Foundation
import Combine

struct AppUser: Codable, Identifiable {
    var id: String { username }
    var username: String
    var password: String   // Demo amaçlı düz metin - gerçek bir uygulamada hash'lenmelidir!
    var isPro: Bool
    var profileImageData: Data?
}

final class UserStore: ObservableObject {
    @Published private(set) var users: [AppUser] = []
    @Published private(set) var currentUsername: String?

    private let usersKey = "namazvakitleri_users"
    private let sessionKey = "namazvakitleri_currentUser"

    enum AuthError: LocalizedError {
        case usernameTaken
        case passwordTooShort
        case invalidCredentials
        case usernameEmpty

        var errorDescription: String? {
            switch self {
            case .usernameTaken: return "Bu kullanıcı adı zaten alınmış."
            case .passwordTooShort: return "Şifre en az 6 karakter olmalı."
            case .invalidCredentials: return "Kullanıcı adı ya da şifre hatalı."
            case .usernameEmpty: return "Kullanıcı adı boş olamaz."
            }
        }
    }

    init() {
        loadUsers()
        seedDemoAccountsIfNeeded()
        currentUsername = UserDefaults.standard.string(forKey: sessionKey)
    }

    var currentUser: AppUser? {
        guard let name = currentUsername else { return nil }
        return users.first { $0.username.lowercased() == name.lowercased() }
    }

    var isLoggedIn: Bool { currentUser != nil }

    private func seedDemoAccountsIfNeeded() {
        var didAdd = false
        if !users.contains(where: { $0.username == "demo_standart" }) {
            users.append(AppUser(username: "demo_standart", password: "123456", isPro: false, profileImageData: nil))
            didAdd = true
        }
        if !users.contains(where: { $0.username == "demo_pro" }) {
            users.append(AppUser(username: "demo_pro", password: "123456", isPro: true, profileImageData: nil))
            didAdd = true
        }
        if didAdd { saveUsers() }
    }

    private func isUsernameTaken(_ username: String, excluding: String? = nil) -> Bool {
        users.contains {
            $0.username.lowercased() == username.lowercased() &&
            $0.username.lowercased() != (excluding?.lowercased() ?? "")
        }
    }

    func register(username: String, password: String) -> Result<Void, AuthError> {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(.usernameEmpty) }
        guard password.count >= 6 else { return .failure(.passwordTooShort) }
        guard !isUsernameTaken(trimmed) else { return .failure(.usernameTaken) }

        let newUser = AppUser(username: trimmed, password: password, isPro: false, profileImageData: nil)
        users.append(newUser)
        saveUsers()
        setSession(username: trimmed)
        return .success(())
    }

    func login(username: String, password: String) -> Result<Void, AuthError> {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard let user = users.first(where: {
            $0.username.lowercased() == trimmed.lowercased() && $0.password == password
        }) else {
            return .failure(.invalidCredentials)
        }
        setSession(username: user.username)
        return .success(())
    }

    func logout() {
        currentUsername = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    func updateUsername(_ newUsername: String) -> Result<Void, AuthError> {
        let trimmed = newUsername.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(.usernameEmpty) }
        guard let current = currentUsername,
              let index = users.firstIndex(where: { $0.username == current }) else {
            return .failure(.invalidCredentials)
        }
        guard !isUsernameTaken(trimmed, excluding: current) else { return .failure(.usernameTaken) }

        users[index].username = trimmed
        saveUsers()
        setSession(username: trimmed)
        return .success(())
    }

    func updateProfileImage(_ data: Data?) {
        guard let current = currentUsername,
              let index = users.firstIndex(where: { $0.username == current }) else { return }
        users[index].profileImageData = data
        saveUsers()
    }

    func setProStatus(_ isPro: Bool) {
        guard let current = currentUsername,
              let index = users.firstIndex(where: { $0.username == current }) else { return }
        users[index].isPro = isPro
        saveUsers()
    }

    private func setSession(username: String) {
        currentUsername = username
        UserDefaults.standard.set(username, forKey: sessionKey)
    }

    private func saveUsers() {
        if let data = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(data, forKey: usersKey)
        }
    }

    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let decoded = try? JSONDecoder().decode([AppUser].self, from: data) {
            users = decoded
        }
    }
}
