import SwiftUI
import PhotosUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = "My Profile"
    @AppStorage("profileCity") private var profileCity = ""
    @AppStorage("profileImageData") private var profileImageData: Data?

    @State private var editName = ""
    @State private var editCity = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 8) {
                                if let profileImage {
                                    profileImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundStyle(.teal)
                                }
                                Text("Change Photo")
                                    .font(.caption)
                                    .foregroundStyle(.teal)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Your name", text: $editName)
                }

                Section("Home City") {
                    TextField("e.g. Chandler, AZ", text: $editCity)
                        .textContentType(.addressCity)
                }

                if profileImage != nil {
                    Section {
                        Button(role: .destructive) {
                            profileImage = nil
                            profileImageData = nil
                            selectedPhoto = nil
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profileName = editName.isEmpty ? "My Profile" : editName
                        profileCity = editCity
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                editName = profileName
                editCity = profileCity
                loadSavedImage()
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await loadPhoto(from: newItem) }
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        profileImageData = data
        if let uiImage = UIImage(data: data) {
            await MainActor.run {
                profileImage = Image(uiImage: uiImage)
            }
        }
    }

    private func loadSavedImage() {
        guard let data = profileImageData, let uiImage = UIImage(data: data) else { return }
        profileImage = Image(uiImage: uiImage)
    }
}
