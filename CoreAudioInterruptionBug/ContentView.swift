import SwiftUI

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var audioManager = AudioManager()
    @State private var immersiveSpaceOpen = false

    var body: some View {
        VStack(spacing: 20) {
            Text("CoreAudio Interruption Bug")
                .font(.title)

            Text("""
                Steps to reproduce:
                1. Tap "Start Audio" (a 440Hz tone plays)
                2. Tap "Open Immersive Space"
                3. Double-tap Digital Crown to dismiss
                4. Observe: render callback count stops, no error reported
                5. Re-enter immersive space — audio does NOT resume
                """)
                .font(.caption)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            // Controls
            HStack(spacing: 16) {
                Button(audioManager.isPlaying ? "Stop Audio" : "Start Audio") {
                    if audioManager.isPlaying {
                        audioManager.stopAudio()
                    } else {
                        audioManager.startAudio()
                    }
                }

                Button(immersiveSpaceOpen ? "Close Space" : "Open Space") {
                    Task {
                        if immersiveSpaceOpen {
                            await dismissImmersiveSpace()
                            immersiveSpaceOpen = false
                        } else {
                            let result = await openImmersiveSpace(id: "ImmersiveSpace")
                            immersiveSpaceOpen = result == .opened
                        }
                    }
                }

                Button("Reset") {
                    audioManager.resetFlags()
                }
            }

            // Status indicators
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Render callbacks:")
                    Text("\(audioManager.renderCallbackCount)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Callback active:")
                    StatusIndicator(
                        active: audioManager.isPlaying && !audioManager.callbackStoppedDetected,
                        label: audioManager.callbackStoppedDetected ? "STOPPED" : "Running"
                    )
                }
                GridRow {
                    Text("Interruption began:")
                    StatusIndicator(
                        active: audioManager.interruptionBegan,
                        label: audioManager.interruptionBegan ? "Yes" : "No"
                    )
                }
                GridRow {
                    Text("Interruption ended (shouldResume):")
                    StatusIndicator(
                        active: audioManager.interruptionEndedWithResume,
                        label: audioManager.interruptionEndedWithResume ? "Yes" : "No"
                    )
                }
                GridRow {
                    Text("Error callback fired:")
                    StatusIndicator(
                        active: audioManager.errorCallbackFired,
                        label: audioManager.errorCallbackFired ? "Yes" : "No"
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

            // Log
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(audioManager.statusLog, id: \.self) { entry in
                        Text(entry)
                            .font(.caption2)
                            .monospaced()
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }
}

struct StatusIndicator: View {
    let active: Bool
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }
}
