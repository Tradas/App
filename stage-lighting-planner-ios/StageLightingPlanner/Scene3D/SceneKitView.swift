import SwiftUI
import SceneKit

/// Interaktivní 3D pohled: tažením otáčíte kameru, štípnutím zoomujete, klepnutím vyberete světlo/objekt.
struct SceneKitView: UIViewRepresentable {
    @EnvironmentObject var store: PlannerStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        let c = context.coordinator
        v.scene = c.scene
        v.backgroundColor = UIColor(white: 0.04, alpha: 1)
        v.antialiasingMode = .multisampling4X
        v.allowsCameraControl = true
        v.pointOfView = c.camera
        v.defaultCameraController.interactionMode = .orbitTurntable
        v.addGestureRecognizer(UITapGestureRecognizer(target: c, action: #selector(Coordinator.tap(_:))))
        c.view = v
        c.applyCamera(.persp, plan: store.plan)
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        let c = context.coordinator
        c.store = store
        SceneBuilder.rebuild(content: c.content, plan: store.plan, geometry: store.geometry, showCones: store.showCones)
        if c.token != store.cameraToken {
            c.token = store.cameraToken
            c.applyCamera(store.cameraPreset, plan: store.plan)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        let scene = SCNScene()
        let content = SCNNode()
        let camera = SCNNode()
        var store: PlannerStore
        var token = 0
        weak var view: SCNView?

        init(store: PlannerStore) {
            self.store = store
            super.init()
            scene.rootNode.addChildNode(content)
            let cam = SCNCamera()
            cam.zNear = 0.1
            cam.zFar = 300
            cam.projectionDirection = .horizontal   // na výšku (iPhone) se vždy vejde celá šířka místnosti
            cam.fieldOfView = 60
            camera.camera = cam
            scene.rootNode.addChildNode(camera)
            let amb = SCNNode()
            amb.light = SCNLight()
            amb.light?.type = .ambient
            amb.light?.intensity = 60
            amb.light?.color = UIColor(white: 0.5, alpha: 1)
            scene.rootNode.addChildNode(amb)
        }

        func applyCamera(_ p: CameraPreset, plan: Plan) {
            let t = V3(plan.stage.x, plan.stage.y + plan.stage.d / 2, 1.5)
            let dist = max(plan.room.w, plan.room.d) * 1.1
            var pos = t
            var up = SCNVector3(0, 1, 0)
            switch p {
            case .front: pos = t + V3(0, dist, 2)
            case .side: pos = t + V3(dist, 0, 2)
            case .top: pos = t + V3(0, 0.01, dist * 1.4); up = SCNVector3(0, 0, -1)
            case .persp: pos = t + V3(dist * 0.5, dist * 0.9, dist * 0.45)
            }
            camera.position = SceneBuilder.vec(pos)
            camera.look(at: SceneBuilder.vec(t), up: up, localFront: SCNVector3(0, 0, -1))
            view?.defaultCameraController.target = SceneBuilder.vec(t)
        }

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let v = g.view as? SCNView else { return }
            let hits = v.hitTest(g.location(in: v), options: [.categoryBitMask: 1])
            for h in hits {
                var n: SCNNode? = h.node
                while let node = n {
                    if let name = node.name {
                        if name.hasPrefix("light-"), let id = UUID(uuidString: String(name.dropFirst(6))) { store.selection = .light(id); return }
                        if name.hasPrefix("obj-"), let id = UUID(uuidString: String(name.dropFirst(4))) { store.selection = .object(id); return }
                    }
                    n = node.parent
                }
            }
            store.selection = nil
        }
    }
}
