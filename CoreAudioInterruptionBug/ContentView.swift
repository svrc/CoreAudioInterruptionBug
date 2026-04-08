//
//  ContentView.swift
//  CoreAudioInterruptionBug
//
//  Created by Stuart Charlton on 2026-04-08.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    var body: some View {
        VStack {
            ToggleImmersiveSpaceButton()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
