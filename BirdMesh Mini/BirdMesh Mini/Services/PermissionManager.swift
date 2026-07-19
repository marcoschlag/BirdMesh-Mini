import Foundation
import Photos

/// Verwaltet Berechtigungen für Photobibliothek und andere Ressourcen
class PermissionManager: NSObject, ObservableObject {
    @Published var hasPhotoLibraryAccess = false

    override init() {
        super.init()
        checkPhotoLibraryPermission()
    }

    /// Prüft und fordert Zugriff auf die Photobibliothek an
    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            hasPhotoLibraryAccess = true
        case .denied, .restricted:
            hasPhotoLibraryAccess = false
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    self.hasPhotoLibraryAccess = (newStatus == .authorized || newStatus == .limited)
                }
            }
        @unknown default:
            hasPhotoLibraryAccess = false
        }
    }
}
