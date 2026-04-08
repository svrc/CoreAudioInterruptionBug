import SwiftUI
import RealityKit

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
            // Minimal immersive content — a small sphere so the space is visible
            let sphere = MeshResource.generateSphere(radius: 0.1)
            let material = SimpleMaterial(color: .blue, isMetallic: false)
            let entity = ModelEntity(mesh: sphere, materials: [material])
            entity.position = [0, 1.5, -1]
            content.add(entity)
        }
    }
}
