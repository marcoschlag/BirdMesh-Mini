import SwiftUI
import PhotosUI
import AVFoundation

/// SwiftUI View für Videoauswahl aus der Fotos-App
struct VideoPickerView: View {
    @ObservedObject var videoImportService: VideoImportService
    @State private var showingPicker = false

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Titel
                Text("BirdMesh Mini – MVP")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                // Video auswählen Button
                if videoImportService.selectedAsset == nil {
                    Button(action: { showingPicker = true }) {
                        VStack(spacing: 12) {
                            Image(systemName: "film.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)

                            Text("Video auswählen")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Wähle ein Video aus deiner Mediathek")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                                .foregroundColor(.blue)
                        )
                    }
                    .sheet(isPresented: $showingPicker) {
                        VideoPicker(videoImportService: videoImportService, isPresented: $showingPicker)
                    }
                }

                // Loading Indicator
                if videoImportService.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }

                // Error Message
                if let error = videoImportService.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }

                // Video Info (falls geladen)
                if let asset = videoImportService.selectedAsset,
                   let info = videoImportService.getVideoInfo() {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Video geladen")
                                .fontWeight(.semibold)
                        }

                        Text("Dauer: \(info.duration)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Auflösung: \(info.dimensions)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()

                // Weiter Button (nur wenn Video geladen)
                if videoImportService.selectedAsset != nil {
                    NavigationLink(destination: VideoPreviewView(videoImportService: videoImportService)) {
                        Text("Vorschau anschauen")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - PHPickerViewController Wrapper

/// SwiftUI Wrapper für PHPickerViewController (Video-Auswahl)
struct VideoPicker: UIViewControllerRepresentable {
    @ObservedObject var videoImportService: VideoImportService
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .videos

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(videoImportService: videoImportService, isPresented: $isPresented)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let videoImportService: VideoImportService
        @Binding var isPresented: Bool

        init(videoImportService: VideoImportService, isPresented: Binding<Bool>) {
            self.videoImportService = videoImportService
            self._isPresented = isPresented
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            isPresented = false

            guard let result = results.first else { return }

            // Lade Video direkt über URL – einfach, zuverlässig, MVP-ready
            self.loadVideoViaURL(from: result)
        }

        /// Fallback-Methode: Lade Video direkt über URL
        /// (weniger zuverlässig, aber nötig für bestimmte Video-Quellen)
        private func loadVideoViaURL(from result: PHPickerResult) {
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.videoImportService.errorMessage = "Fehler: \(error.localizedDescription)"
                        return
                    }

                    guard let url = url else {
                        self.videoImportService.errorMessage = "Video konnte nicht geladen werden."
                        return
                    }

                    // Erstelle AVAsset und warte auf Metadata
                    let asset = AVAsset(url: url)

                    // Warte auf Video-Metadaten (Timeout 5 Sekunden)
                    asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
                        DispatchQueue.main.async {
                            self.videoImportService.selectedAsset = asset
                            self.videoImportService.videoURL = url
                            self.videoImportService.isLoading = false
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VideoPickerView(videoImportService: VideoImportService())
    }
}
