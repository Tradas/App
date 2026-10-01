import Foundation

/// Výchozí knihovna = seznam svítidel od uživatele; `stock` je počet kusů ve skladu.
/// Úhly kuželů a příkony jsou orientační – upravte je podle datasheetů.
enum FixtureLibrary {
    private static func f(_ name: String, _ type: FixtureType, _ watt: Double, _ angle: Double,
                          _ minA: Double, _ maxA: Double, _ stock: Int, _ tech: LampTech) -> Fixture {
        Fixture(id: name, name: name, type: type, watt: watt, angle: angle, minAngle: minA, maxAngle: maxA, stock: stock, tech: tech)
    }

    static let builtIn: [Fixture] = [
        f("LED Wall Wash 72×12W RGBW IP64", .wash, 864, 40, 20, 80, 2, .led),
        f("LED Can RGBWA+UV Wireless (P-163B)", .par, 60, 30, 15, 45, 12, .led),
        f("LED TMH-20 Wash", .wash, 200, 25, 10, 45, 4, .led),
        f("LED Rotating Wash RGBW 36×10W", .wash, 360, 25, 10, 50, 10, .led),
        f("LED Beam BAR RGBW 8×10W", .beam, 80, 4, 3, 10, 4, .led),
        f("LED Lightmaxx Vector 280W 10R", .beam, 280, 3, 2, 4, 10, .discharge),
        f("LED Spider Light", .beam, 80, 12, 8, 25, 2, .led),
        f("ROBE Color Spot 575W", .spot, 575, 20, 11, 38, 2, .discharge),
        f("ROBE Color Wash 575W", .wash, 575, 30, 12, 60, 2, .discharge),
        f("MAC 550 Profile", .spot, 550, 20, 12, 32, 4, .discharge),
        f("FHR 500/650W", .fresnel, 650, 35, 10, 60, 2, .tungsten),
        f("FHR 1000W", .fresnel, 1000, 40, 12, 65, 2, .tungsten),
        f("ARRI 650W Plus Man", .fresnel, 650, 40, 10, 60, 4, .tungsten),
        f("ARRI Junior 1000W", .fresnel, 1000, 40, 10, 60, 4, .tungsten),
        f("ARRI TRUE BLUE T1 1000W", .fresnel, 1000, 40, 12, 60, 4, .tungsten),
        f("ARRI TRUE BLUE T1 1000W MAN", .fresnel, 1000, 40, 12, 60, 4, .tungsten),
        f("Eurolite LED THA-250F", .fresnel, 250, 40, 20, 60, 4, .led),
        f("Profile FS-600 26° 600W", .spot, 600, 26, 26, 26, 4, .tungsten),
        f("ETC Source Four JR 25°–50° 600W", .spot, 600, 36, 25, 50, 2, .tungsten),
        f("AHR 500W asymetrický", .flood, 500, 95, 80, 110, 2, .tungsten),
        f("HHR 1000W Follow Spot", .follow, 1000, 8, 4, 16, 1, .tungsten),
        f("ADB DN204 2000W Follow Spot", .follow, 2000, 6, 3, 12, 1, .tungsten),
        f("LED PAR 32 ML-30 QCL RGBW", .par, 30, 30, 30, 30, 22, .led),
        f("LED PAR 64 Cameo QCL RGBW", .par, 180, 25, 25, 25, 16, .led),
        f("LED PAR 64 RGBWA+UV 6in1", .par, 150, 25, 25, 25, 20, .led),
        f("LED PAR Varytec 64 RGBWA+UV 6in1", .par, 150, 25, 25, 25, 34, .led),
        f("LED Punch CLS-18 QCL RGBW", .par, 180, 30, 30, 30, 20, .led),
        f("LED BAR Starline 6in1", .bar, 120, 35, 20, 60, 10, .led),
        f("Tri LED Show BAR 18×3W", .bar, 54, 30, 25, 40, 8, .led),
        f("LED eBAR r24×15W RGBWA 5in1", .bar, 360, 25, 15, 40, 20, .led),
    ]
}
