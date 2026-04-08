import SwiftUI

@main
struct CoreAudioInterruptionBugApp: App {
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}
