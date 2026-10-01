# Plánovač pódiového osvětlení – nativní iOS/iPadOS aplikace

SwiftUI + SceneKit, iOS 17+, bez externích závislostí. Funkčně odpovídá webové verzi ve `../stage-lighting-planner/`.

## Spuštění (potřebujete Mac s Xcode 15+)

**A) XcodeGen** – `brew install xcodegen && xcodegen generate && open StageLightingPlanner.xcodeproj`

**B) Ručně** – v Xcode: File ▸ New ▸ Project ▸ iOS App (SwiftUI, název `StageLightingPlanner`, deployment target iOS 17),
smažte vygenerovaný `ContentView.swift` a `…App.swift`, přetáhněte do projektu složku `StageLightingPlanner/` (Create groups).

## Co aplikace umí

- **Scéna:** rozměry místnosti, pódia (vč. výšky), výška trussu, dveře a okna, výška očí publika, haze.
- **Plán (záložka 1):** 2D shora s drag-and-drop světel a zaměřovačem; čelní a boční elevace; plně interaktivní 3D (SceneKit – skutečné spot světla, stíny, kužely, haze).
- **Světla:** pozice X/Y/Z, pan/tilt (nebo „zaměřit na střed“), úhel kuželu v rozsahu svítidla, intenzita, RGB barva (`ColorPicker`), role.
- **Knihovna:** 30 svítidel ze zadání (počet = sklad), vlastní svítidla přes „+“.
- **Objekty na pódiu:** reproduktor/kostka, válec, hudebník, riser – SceneKit je osvítí a vrhají stíny.
- **Analýza:** skóre hloubky, kontrastu a bezpečnosti; varování před oslněním publika, nízkým úhlem, přepalem front zóny a paprsky mimo pódium; režimy trojbodové, backlight, side, kontra, pozadí, haze a ⭐ doporučené rozmístění.
- Plán se ukládá automaticky; export/import JSON v záložce Scéna.

## iPhone

Aplikace je navržená primárně pro iPhone (na výšku i na šířku; iPad funguje také):
- spodní `TabView` s 5 záložkami, inspektor světla jako spodní panel (40 % výšky / celá obrazovka), plátno zůstává ovladatelné i při otevřeném panelu,
- 2D plán: **pinch = zoom, tažení prázdné plochy = posun**, tlačítko pro návrat pohledu, velké dotykové plochy světel a haptická odezva při výběru,
- 3D: kamera s horizontálním FOV, aby se na výšku vešla celá šířka místnosti,
- číselná pole mají nad klávesnicí tlačítko „Hotovo“ a formuláře se posunem zavírají klávesnici.

## Struktura

| Složka | Obsah |
|---|---|
| `Core/` | modely, knihovna, fyzika paprsků (`traceRay`, osvětlenost), analýza, presety – bez závislosti na UI |
| `Store/` | `PlannerStore` (jediný zdroj pravdy, ukládání), `PlanDocument` |
| `Scene3D/` | `SceneBuilder` (plán → SceneKit), `SceneKitView` |
| `Views/` | SwiftUI obrazovky a 2D `Canvas` editor |

## Poznámky

- Kód byl napsán bez možnosti kompilace (psáno na Linuxu bez Xcode) – při prvním buildu mohou vyskočit drobné chyby. Pošlete výpis a opravím.
- Osvětlenost [lx] je orientační (příkon × účinnost technologie); SceneKit jas se kalibruje v `SceneBuilder` (`l.intensity`). Úhly kuželů u většiny svítidel jsou odhad – upravte je podle datasheetů.
- SceneKit vykreslí nejvýše ~8 spotů na objekt najednou; stíny mají prvních 6 světel.
