import Foundation

/// Souřadnice plánu: X doprava, Y směrem k publiku (0 = zadní stěna), Z nahoru. Jednotky: metry.
typealias V3 = SIMD3<Double>

@inline(__always) func dot3(_ a: V3, _ b: V3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
@inline(__always) func len3(_ a: V3) -> Double { dot3(a, a).squareRoot() }
func norm3(_ a: V3) -> V3 { let l = len3(a); return l > 1e-12 ? a / l : V3(0, 0, 1) }
func cross3(_ a: V3, _ b: V3) -> V3 {
    V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }
func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = clamp((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)
}
func rad(_ d: Double) -> Double { d * .pi / 180 }
func deg(_ r: Double) -> Double { r * 180 / .pi }
func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
