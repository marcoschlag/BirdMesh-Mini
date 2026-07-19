//
//  ContentView.swift
//  BirdMesh Mini
//
//  Created by Marco Schlag on 18.07.26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var videoImportService = VideoImportService()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // DEBUG: Zeige Permission Status
                Text("BirdMesh Mini – MVP")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Permission: \(permissionManager.hasPhotoLibraryAccess ? "✅ Granted" : "❌ Denied")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if permissionManager.hasPhotoLibraryAccess {
                    // Hauptzustand: Video Picker
                    VideoPickerView(videoImportService: videoImportService)
                } else {
                    // Kein Zugriff: Bitte fragen
                    VStack(spacing: 20) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("Fotobibliothek-Zugriff erforderlich")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Um Videos zu analysieren, benötigen wir Zugriff auf deine Fotobibliothek.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            permissionManager.checkPhotoLibraryPermission()
                        }) {
                            Text("Berechtigung erteilen")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding(20)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
