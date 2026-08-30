import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    @State private var newUsername: String = ""
    @State private var usernameError: String?
    @State private var usernameSuccess: String?

    @State private var showImageSourceMenu = false
    @State private var showCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    @State private var showPayment = false

    private var profileImage: UIImage? {
        if let pickedImage { return pickedImage }
        if let data = userStore.currentUser?.profileImageData {
            return UIImage(data: data)
        }
        return nil
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Button {
                                showImageSourceMenu = true
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    if let profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 96, height: 96)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 96, height: 96)
                                            .foregroundColor(.gray)
                                    }
                                    Image(systemName: "camera.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                        .background(Circle().fill(.white))
                                }
                            }
                            Text(userStore.currentUser?.username ?? "")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("Hesap Türü") {
                    HStack {
                        Text("Tür")
                        Spacer()
                        Text(userStore.currentUser?.isPro == true ? "Pro" : "Standart")
                            .fontWeight(.semibold)
                            .foregroundStyle(userStore.currentUser?.isPro == true ? .orange : .secondary)
                    }

                    if userStore.currentUser?.isPro == true {
                        Button(role: .destructive) {
                            userStore.setProStatus(false)
                        } label: {
                            Text("Pro Hesabını İptal Et")
                        }
                    } else {
                        Button {
                            showPayment = true
                        } label: {
                            Text("Pro Hesap Ol")
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section("Kullanıcı Adını Değiştir") {
                    TextField("Yeni kullanıcı adı", text: $newUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let usernameError {
                        Text(usernameError).font(.footnote).foregroundColor(.red)
                    }
                    if let usernameSuccess {
                        Text(usernameSuccess).font(.footnote).foregroundColor(.green)
                    }

                    Button("Kaydet") {
                        updateUsername()
                    }
                }

                Section {
                    Button(role: .destructive) {
                        userStore.logout()
                    } label: {
                        Text("Çıkış Yap")
                    }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
            .confirmationDialog("Profil fotoğrafı", isPresented: $showImageSourceMenu) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Kameradan Çek") { showCamera = true }
                }
                PhotosPicker("Galeriden Seç", selection: $photoPickerItem, matching: .images)
                if profileImage != nil {
                    Button("Fotoğrafı Kaldır", role: .destructive) {
                        pickedImage = nil
                        userStore.updateProfileImage(nil)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker(image: $pickedImage)
            }
            .sheet(isPresented: $showPayment) {
                ProPaymentView()
            }
            .onChange(of: pickedImage) { _, newValue in
                if let newValue, let data = newValue.jpegData(compressionQuality: 0.8) {
                    userStore.updateProfileImage(data)
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        pickedImage = uiImage
                        userStore.updateProfileImage(uiImage.jpegData(compressionQuality: 0.8))
                    }
                }
            }
            .onAppear {
                newUsername = userStore.currentUser?.username ?? ""
            }
        }
    }

    private func updateUsername() {
        usernameError = nil
        usernameSuccess = nil
        switch userStore.updateUsername(newUsername) {
        case .success:
            usernameSuccess = "Kullanıcı adı güncellendi."
        case .failure(let error):
            usernameError = error.errorDescription
        }
    }
}

#Preview {
    ProfileView().environmentObject(UserStore())
}
