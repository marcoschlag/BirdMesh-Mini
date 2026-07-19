import SwiftUI
import AVFoundation
import AVKit

/// View für Video-Vorschau und Analyse-Start
struct VideoPreviewView: View {
    @ObservedObject var videoImportService: VideoImportService
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // Video Player
            if let asset = videoImportService.selectedAsset {
                VideoPlayerContainer(asset: asset)
                    .ignoresSafeArea()
            }

            // Controls Overlay
            VStack {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Zurück")
                        }
                        .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Vorschau")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                        .opacity(0)
                }
                .padding(16)
                .background(Color.black.opacity(0.4))

                Spacer()

                // Bottom Controls
                VStack(spacing: 12) {
                    // Info
                    if let info = videoImportService.getVideoInfo() {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video-Info")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("Dauer: \(info.duration) | Auflösung: \(info.dimensions)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    }

                    // Analyze Button (für Phase 2)
                    Button(action: {
                        // Später: Audioanalyse starten
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.circle.fill")
                            Text("Analysieren (Phase 2)")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.4))
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - AVPlayer Container (UIViewControllerRepresentable)

/// SwiftUI Wrapper für AVPlayerViewController
struct VideoPlayerContainer: UIViewControllerRepresentable {
    let asset: AVAsset

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Keine Updates nötig
    }
}

#Preview {
    @State var mockService = VideoImportService()

    return VStack {
        Text("Preview würde Video anzeigen")
            .foregroundColor(.gray)
    }
}
