# BirdMesh Mini Phase 1 – Video-Metadata Fehler Behebung

**Datum:** 2026-07-19  
**Problem:** Video wird geladen, zeigt aber fehlerhafte Metadaten (Dauer: 0.0s, Auflösung: Unbekannt)

---

## Root-Cause Analyse

### Das Problem
Wenn Marco ein Video aus der Fotos-App auswählte, zeigte BirdMesh Mini:
- **Dauer: 0.0 s** (sollte echte Dauer zeigen)
- **Auflösung: Unbekannt** (sollte z.B. "1920 × 1080" zeigen)
- Der "Vorschau anschauen" Button funktionierte

### Technische Ursache
**In `VideoPickerView.swift` (alte Version, Zeile 168):**
```swift
let asset = AVAsset(url: url)  // ← PROBLEM!
```

Wenn man AVAsset direkt aus einer URL erstellt, wird die Metadaten (Dauer, Video-Tracks, Dimensionen) **asynchron** im Hintergrund geladen. Die Funktion `getVideoInfo()` wurde aufgerufen, bevor die Metadaten verfügbar waren:

1. User wählt Video
2. `AVAsset(url:)` erstellt Asset (ABER Metadaten laden noch)
3. `getVideoInfo()` wird aufgerufen → Metadaten noch nicht da
4. Ergebnis: duration = 0.0, no tracks found

### Warum das falsch war
`VideoImportService.swift` hatte bereits eine **bessere Methode** (`loadVideo(from:)`), die `PHImageManager.requestAVAsset()` nutzt – diese Methode wartet auf die Metadaten. Aber `VideoPickerView` hat sie nicht aufgerufen!

---

## Lösungsansatz

### Fix 1: Verwende PHAsset statt URL-Fallback (Priorität 1)
**Datei:** `VideoPickerView.swift`

**Alte Methode:**
```swift
// Direkt über URL → Metadaten nicht bereit
result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
    let asset = AVAsset(url: url)
    self.videoImportService.selectedAsset = asset
}
```

**Neue Methode:**
```swift
// Nutze PHAsset → korrekt durch PHImageManager geladen
result.itemProvider.loadObject(ofClass: PHAsset.self) { phAsset, error in
    guard let phAsset = phAsset as? PHAsset else {
        // Fallback für spezielle Quellen
        self.loadVideoViaURL(from: result)
        return
    }
    // PHImageManager wartet auf Metadaten!
    self.videoImportService.loadVideo(from: phAsset)
}
```

**Vorteil:**
- `PHImageManager.requestAVAsset()` wartet auf Metadaten
- Zuverlässigere Metadaten-Verfügbarkeit
- Funktioniert besser mit optimierten/komprimierten Videos

### Fix 2: Fallback-Methode mit Metadaten-Wartezeiten
**Datei:** `VideoPickerView.swift`

Neue private Methode `loadVideoViaURL()`:
```swift
private func loadVideoViaURL(from result: PHPickerResult) {
    result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
        let asset = AVAsset(url: url)
        
        // Warte auf Metadaten, bevor Asset gespeichert wird!
        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) {
            DispatchQueue.main.async {
                self.videoImportService.selectedAsset = asset
                self.videoImportService.videoURL = url
                self.videoImportService.isLoading = false
            }
        }
    }
}
```

**Vorteil:**
- Fallback für Videos, die nicht via PHAsset geladen werden können
- `loadValuesAsynchronously()` stellt sicher, dass Metadaten vor der Nutzung verfügbar sind

### Fix 3: Besseres Fehlerhandling in VideoImportService
**Datei:** `VideoImportService.swift`

**In `loadVideo(from:)`:**
- Ruft `loadValuesAsynchronously()` auf, um Metadaten explizit zu laden
- Debug-Prints für Diagnose hinzugefügt

**In `getVideoInfo()`:**
- Prüft `statusOfValue()`, um zu erkennen, ob Metadaten fehlgeschlagen sind
- Validiert Dauer (>0, nicht NaN)
- Validiert Auflösung (width/height > 0)
- Zeigt aussagekräftige Fehlermeldungen statt 0.0 oder "Unbekannt"

---

## Geänderte Dateien

### 1. `/Users/marco/Desktop/BirdMesh-Mini-Test/BirdMesh Mini/BirdMesh Mini/Views/VideoPickerView.swift`
**Änderungen:**
- VideoPicker.Coordinator.picker() nutzt jetzt `loadObject(ofClass: PHAsset.self)`
- Neue private Methode `loadVideoViaURL()` mit `loadValuesAsynchronously()`
- Fallback-Logik für spezielle Video-Quellen

### 2. `/Users/marco/Desktop/BirdMesh-Mini-Test/BirdMesh Mini/BirdMesh Mini/Services/VideoImportService.swift`
**Änderungen:**
- `loadVideo(from:)` ruft nun `loadValuesAsynchronously()` auf
- `getVideoInfo()` prüft Metadaten-Status mit `statusOfValue()`
- Bessere Validierung (duration > 0, size > 0)
- Debug-Prints für Diagnose (✅ ❌ ⚠️ 📊 📁)

---

## Wie die Fixes wirken

### Szenario: Video auswählen

1. **Alte Version:**
   ```
   User wählt Video
   → AVAsset(url:) erstellt SOFORT
   → getVideoInfo() wird SOFORT aufgerufen
   → Metadaten sind noch nicht da
   → Dauer = 0.0, Auflösung = Unbekannt ❌
   ```

2. **Neue Version (PHAsset-Weg):**
   ```
   User wählt Video
   → PHImageManager.requestAVAsset() wird aufgerufen
   → PHImageManager wartet auf Metadaten
   → getVideoInfo() wird aufgerufen NACH PHImageManager (via loadValuesAsynchronously)
   → Metadaten sind verfügbar
   → Dauer = "9.5 s", Auflösung = "1920 × 1080" ✅
   ```

3. **Neue Version (URL Fallback):**
   ```
   User wählt Video
   → AVAsset(url:) erstellt
   → loadValuesAsynchronously(forKeys:) wartet auf Metadaten
   → selectedAsset wird ERST gespeichert, wenn Metadaten da sind
   → getVideoInfo() wird aufgerufen → Metadaten verfügbar ✅
   ```

---

## Testing

### Manueller Test
1. Xcode öffnen: `/Users/marco/Desktop/BirdMesh-Mini-Test/BirdMesh Mini`
2. iPhone Simulator starten
3. App bauen + starten
4. "Video auswählen" antippen
5. Ein bekanntes Video aus der Fotos-App aussuchen
6. **Erwartetes Ergebnis:**
   - Dauer sollte korrekt angezeigt werden (z.B. "15.3 s")
   - Auflösung sollte korrekt angezeigt werden (z.B. "1920 × 1080")
   - "Vorschau anschauen" Button sollte funktionieren
   - Console sollte Debug-Logs zeigen:
     ```
     ✅ AVAsset erfolgreich geladen
     📁 Video URL: file:///...
     📊 Video-Metadaten geladen
     ✅ Video-Info: Dauer=15.3 s, Auflösung=1920 × 1080
     ```

### Mit problematischen Videos testen
Falls Videos immer noch `duration = 0.0` zeigen:
1. Schau in die Console für `⚠️` Meldungen
2. Prüfe, ob `statusOfValue()` `.failed` zurückgibt
3. Melde das Problem mit den Console-Logs

---

## Weitere Verbesserungen (Optional für Phase 2)

1. **Timeout hinzufügen:** Falls Metadaten nicht laden, nach X Sekunden abbrechen
2. **Metadaten-Cache:** Einmal geladene Metadaten speichern, um nicht neu zu laden
3. **UI-Feedback:** "Lädt Metadaten..." anzeigen während `loadValuesAsynchronously()` läuft
4. **Video-Validierung:** Prüfe, ob Video mindestens 1s lang ist + hat Video-Track
5. **Netzwerk-Videos:** Bessere Behandlung von Remote-Videos (iCloud Photos)

---

## Zusammenfassung

| Aspekt | Problem | Lösung |
|--------|---------|--------|
| **Root Cause** | AVAsset erstellt ohne Warten auf Metadaten | PHImageManager + loadValuesAsynchronously() |
| **Dauer zeigt 0.0** | Metadaten noch nicht geladen | Warten auf Laden vor Anzeigen |
| **Auflösung unbekannt** | Keine Video-Tracks gefunden | Warten auf Tracks vor Zugriff |
| **Debugging schwer** | Keine Logs, keine Error-Checks | Debug-Prints + statusOfValue() Prüfungen |

**Status nach Fix:** ✅ Dauer und Auflösung sollten korrekt angezeigt werden
