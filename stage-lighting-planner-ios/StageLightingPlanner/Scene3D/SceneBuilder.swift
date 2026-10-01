import SceneKit
import UIKit

/// Převádí plán na SceneKit scénu. Souřadnice plánu (x, y, z) → SceneKit (x, z, y), tj. Y nahoru.
enum SceneBuilder {
    static func vec(_ v: V3) -> SCNVector3 { SCNVector3(Float(v.x), Float(v.z), Float(v.y)) }

    private static func material(_ color: UIColor, alpha: CGFloat = 1, constant: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = constant ? .constant : .lambert
        m.transparency = alpha
        return m
    }

    @discardableResult
    private static func addBox(_ parent: SCNNode, size: V3, center: V3, material m: SCNMaterial, name: String? = nil) -> SCNNode {
        let g = SCNBox(width: CGFloat(size.x), height: CGFloat(size.z), length: CGFloat(size.y), chamferRadius: 0)
        g.materials = [m]
        let n = SCNNode(geometry: g)
        n.position = vec(center)
        n.name = name
        parent.addChildNode(n)
        return n
    }

    static func rebuild(content: SCNNode, plan: Plan, geometry: [LightGeometry], showCones: Bool) {
        content.childNodes.forEach { $0.removeFromParentNode() }
        let r = plan.room, st = plan.stage

        // podlaha a stěny
        addBox(content, size: V3(r.w, r.d, 0.04), center: V3(r.w / 2, r.d / 2, -0.02), material: material(UIColor(white: 0.12, alpha: 1)))
        let wallM = material(UIColor(white: 0.55, alpha: 1), alpha: 0.45)
        addBox(content, size: V3(r.w, 0.05, r.h), center: V3(r.w / 2, -0.025, r.h / 2), material: wallM)
        let sideM = material(UIColor(white: 0.55, alpha: 1), alpha: 0.18)
        addBox(content, size: V3(0.05, r.d, r.h), center: V3(-0.025, r.d / 2, r.h / 2), material: sideM)
        addBox(content, size: V3(0.05, r.d, r.h), center: V3(r.w + 0.025, r.d / 2, r.h / 2), material: sideM)

        // dveře a okna
        for o in plan.openings {
            let col = o.type == .door ? UIColor(red: 0.85, green: 0.6, blue: 0.32, alpha: 1) : UIColor(red: 0.35, green: 0.66, blue: 1, alpha: 1)
            let m = material(col, alpha: 0.55, constant: true)
            let mid = o.pos + o.w / 2, zc = o.sill + o.h / 2
            switch o.wall {
            case .back: addBox(content, size: V3(o.w, 0.04, o.h), center: V3(mid, 0.03, zc), material: m)
            case .front: addBox(content, size: V3(o.w, 0.04, o.h), center: V3(mid, r.d - 0.03, zc), material: m)
            case .left: addBox(content, size: V3(0.04, o.w, o.h), center: V3(0.03, mid, zc), material: m)
            case .right: addBox(content, size: V3(0.04, o.w, o.h), center: V3(r.w - 0.03, mid, zc), material: m)
            }
        }

        // pódium
        addBox(content, size: V3(st.w, st.d, st.h), center: V3(st.x, st.y + st.d / 2, st.h / 2), material: material(UIColor(white: 0.22, alpha: 1)))

        // truss (rám + nohy)
        let tm = material(UIColor(white: 0.7, alpha: 1))
        let x0 = st.x - st.w / 2 - 0.4, x1 = st.x + st.w / 2 + 0.4, yb = plan.trussBackY, yf = plan.trussFrontY, tz = plan.truss.h
        addBox(content, size: V3(x1 - x0, 0.12, 0.12), center: V3((x0 + x1) / 2, yb, tz), material: tm)
        addBox(content, size: V3(x1 - x0, 0.12, 0.12), center: V3((x0 + x1) / 2, yf, tz), material: tm)
        addBox(content, size: V3(0.12, abs(yf - yb), 0.12), center: V3(x0, (yb + yf) / 2, tz), material: tm)
        addBox(content, size: V3(0.12, abs(yf - yb), 0.12), center: V3(x1, (yb + yf) / 2, tz), material: tm)
        for x in [x0, x1] {
            for y in [yb, yf] { addBox(content, size: V3(0.1, 0.1, tz), center: V3(x, y, tz / 2), material: material(UIColor(white: 0.4, alpha: 1))) }
        }

        // objekty na pódiu (kostka = reproduktor, válec = hudebník…)
        for o in plan.objects {
            let base = plan.surfaceZ(x: o.x, y: o.y) + o.lift
            let m = material(o.color.uiColor)
            let node: SCNNode
            if o.kind == .box {
                node = addBox(content, size: V3(o.w, o.d, o.h), center: V3(o.x, o.y, base + o.h / 2), material: m)
            } else {
                let g = SCNCylinder(radius: CGFloat(o.r), height: CGFloat(o.h))
                g.materials = [m]
                node = SCNNode(geometry: g)
                node.position = vec(V3(o.x, o.y, base + o.h / 2))
                content.addChildNode(node)
                if o.hasHead {
                    let head = SCNNode(geometry: SCNSphere(radius: 0.12))
                    head.geometry?.materials = [m]
                    head.position = SCNVector3(0, Float(o.h / 2 + 0.12), 0)
                    node.addChildNode(head)
                }
            }
            node.name = "obj-\(o.id.uuidString)"
        }

        // světla: skutečný SceneKit spot + viditelný kužel
        for (idx, g) in geometry.enumerated() {
            let node = SCNNode()
            node.name = "light-\(g.light.id.uuidString)"
            node.position = vec(g.origin)
            content.addChildNode(node)

            let l = SCNLight()
            l.type = .spot
            l.color = g.light.color.uiColor
            l.intensity = CGFloat(min(4000, g.fixture.lumens * g.light.intensity / 100 / 5))
            l.spotOuterAngle = CGFloat(g.light.angle)
            l.spotInnerAngle = CGFloat(g.light.angle * 0.6)
            l.attenuationStartDistance = 3
            l.attenuationEndDistance = 60
            l.attenuationFalloffExponent = 1
            l.castsShadow = idx < 6
            l.shadowRadius = 4
            l.shadowSampleCount = 8
            l.shadowColor = UIColor(white: 0, alpha: 0.6)
            node.light = l

            let dirUp = abs(g.direction.z) > 0.99 ? SCNVector3(0, 0, 1) : SCNVector3(0, 1, 0)
            node.look(at: vec(g.origin + g.direction), up: dirUp, localFront: SCNVector3(0, 0, -1))

            // tělo svítidla (světlo míří do -Z)
            let body = SCNNode(geometry: SCNBox(width: 0.25, height: 0.25, length: 0.35, chamferRadius: 0.03))
            body.geometry?.materials = [material(UIColor(white: 0.1, alpha: 1))]
            body.position = SCNVector3(0, 0, 0.15)
            node.addChildNode(body)
            let lens = SCNNode(geometry: SCNSphere(radius: 0.08))
            lens.geometry?.materials = [material(g.light.color.uiColor, constant: true)]
            lens.position = SCNVector3(0, 0, -0.03)
            node.addChildNode(lens)

            // viditelný kužel (nad haze je výraznější)
            if showCones {
                let len = min(max(g.axis.t, 0.5), 40)
                let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat(len * tan(g.halfAngle)), height: CGFloat(len))
                let m = material(g.light.color.uiColor, alpha: CGFloat(plan.hazeOn ? 0.07 + 0.12 * plan.hazeDensity : 0.025), constant: true)
                m.blendMode = .add
                m.writesToDepthBuffer = false
                m.isDoubleSided = true
                cone.materials = [m]
                let c = SCNNode(geometry: cone)
                c.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)       // hrot kuželu do počátku, osa podél -Z
                c.position = SCNVector3(0, 0, Float(-len / 2))
                c.categoryBitMask = 2                                // nezachytávat klepnutí
                node.addChildNode(c)
            }
        }
    }
}
