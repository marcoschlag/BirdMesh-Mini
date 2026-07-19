import Foundation
import AVFoundation
import Photos

/// Service für Videoauswahl und -verwaltung
class VideoImportService: NSObject, ObservableObject {
    @Published var selectedAsset: AVAsset?
    @Published var videoURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Lädt ein PHAsset (Video aus Fotos-App) und erstellt ein AVAsset
    func loadVideo(from asset: PHAsset) {
        isLoading = true
        errorMessage = nil

        // Prüfe, ob es ein Video ist
        guard asset.mediaType == .video else {
            errorMessage = "Das ausgewählte Element ist kein Video."
            isLoading = false
            return
        }

        // Lade das Video mit PHImageManager
        let requestOptions = PHVideoRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.deliveryMode = .automatic

        PHImageManager.default().requestAVAsset(forVideo: asset, options: requestOptions) { avAsset, audioMix, info in
            DispatchQueue.main.async {
                if let avAsset = avAsset {
                    self.selectedAsset = avAsset

                    // Versuche die lokale URL zu ermitteln
                    if let urlAsset = avAsset as? AVURLAsset {
                        self.videoURL = urlAsset.url
                    }

                    self.isLoading = false
                } else {
                    self.errorMessage = "Video konnte nicht geladen werden."
                    self.isLoading = false
                }
            }
        }
    }

    /// Gibt Informationen über das geladene Video zurück
    func getVideoInfo() -> (duration: String, dimensions: String)? {
        guard let asset = selectedAsset else { return nil }

        let duration = CMTimeGetSeconds(asset.duration)
        let durationString = String(format: "%.1f s", duration)

        var dimensions = "Unbekannt"
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize
            dimensions = "\(Int(size.width)) × \(Int(size.height))"
        }

        return (durationString, dimensions)
    }
}
