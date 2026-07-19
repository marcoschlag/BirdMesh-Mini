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
                    print("✅ AVAsset erfolgreich geladen")
                    self.selectedAsset = avAsset

                    // Versuche die lokale URL zu ermitteln
                    if let urlAsset = avAsset as? AVURLAsset {
                        self.videoURL = urlAsset.url
                        print("📁 Video URL: \(urlAsset.url)")
                    }

                    // Lade Metadaten asynchron
                    avAsset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
                        DispatchQueue.main.async {
                            print("📊 Video-Metadaten geladen")
                        }
                    }

                    self.isLoading = false
                } else {
                    self.errorMessage = "Video konnte nicht geladen werden."
                    print("❌ Fehler beim Laden des AVAsset")
                    self.isLoading = false
                }
            }
        }
    }

    /// Gibt Informationen über das geladene Video zurück
    func getVideoInfo() -> (duration: String, dimensions: String)? {
        guard let asset = selectedAsset else { return nil }

        // Prüfe, ob Metadata geladen sind
        var loadError: NSError?
        let durationStatus = asset.statusOfValue(forKey: "duration", error: &loadError)
        let tracksStatus = asset.statusOfValue(forKey: "tracks", error: &loadError)

        if durationStatus == .failed || tracksStatus == .failed {
            print("⚠️ Video-Metadaten konnten nicht geladen werden: \(loadError?.localizedDescription ?? "Unbekannter Fehler")")
            return ("Fehler", "Fehler")
        }

        // Hole Dauer
        let duration = CMTimeGetSeconds(asset.duration)
        var durationString = "Unbekannt"
        if !duration.isNaN && duration > 0 {
            durationString = String(format: "%.1f s", duration)
        } else if duration == 0.0 {
            print("⚠️ Video-Dauer ist 0.0 – Metadaten möglicherweise noch nicht geladen")
        }

        // Hole Auflösung
        var dimensions = "Unbekannt"
        if let track = asset.tracks(withMediaType: .video).first {
            let size = track.naturalSize
            if size.width > 0 && size.height > 0 {
                dimensions = "\(Int(size.width)) × \(Int(size.height))"
            }
        }

        print("✅ Video-Info: Dauer=\(durationString), Auflösung=\(dimensions)")
        return (durationString, dimensions)
    }
}
