import SwiftUI
import UIKit

extension Color {
    /// Multiplies brightness (f < 1 darker, f > 1 lighter).
    func shade(_ f: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s),
                     brightness: Double(min(max(b * f, 0), 1)), opacity: Double(a))
    }
}

enum Accent: String, CaseIterable, Identifiable {
    case cyan, violet, lime, orange, pink, gold
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .cyan:   return Color(red: 0.15, green: 0.80, blue: 1.00)
        case .violet: return Color(red: 0.62, green: 0.42, blue: 1.00)
        case .lime:   return Color(red: 0.60, green: 0.95, blue: 0.25)
        case .orange: return Color(red: 1.00, green: 0.55, blue: 0.15)
        case .pink:   return Color(red: 1.00, green: 0.32, blue: 0.62)
        case .gold:   return Color(red: 1.00, green: 0.80, blue: 0.20)
        }
    }
}

let restColor = Color(red: 0.20, green: 0.90, blue: 0.60)
let keyFace = Color(red: 0.16, green: 0.16, blue: 0.19)

enum Brand {
    static var logo: UIImage? {
        guard let p = Bundle.main.path(forResource: "logo", ofType: "png") else { return nil }
        return UIImage(contentsOfFile: p)
    }
}

/// Chunky, physical-looking key: glossy face, dark edge underneath, presses down.
struct Raised3DStyle: ButtonStyle {
    var face: Color
    var radius: CGFloat = 18
    var depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                shape.fill(LinearGradient(colors: [face.shade(1.18), face.shade(0.86)],
                                          startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.04)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .offset(y: down ? depth : 0)
            .background(shape.fill(face.shade(0.40)).offset(y: depth))
            .shadow(color: face.opacity(0.35), radius: down ? 3 : 14, x: 0, y: down ? 2 : 8)
            .padding(.bottom, depth)
            .animation(.easeOut(duration: 0.08), value: down)
    }
}
