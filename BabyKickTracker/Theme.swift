import SwiftUI

// Soft pastel color scheme with dark mode support
struct Theme {
    // Primary colors - soft pastel pink (same in both modes)
    static let primary = Color(red: 1.0, green: 0.71, blue: 0.82) // #FFB5D1 - Soft pink
    static let primaryLight = Color(red: 1.0, green: 0.93, blue: 0.95) // #FFECF2 - Very light pink
    static let primaryDark = Color(red: 0.98, green: 0.56, blue: 0.73) // #FA8FB8 - Medium pink

    // Secondary - soft lavender
    static let secondary = Color(red: 0.82, green: 0.76, blue: 0.98) // #D1C2FA - Soft lavender
    static let secondaryLight = Color(red: 0.95, green: 0.93, blue: 0.99) // #F2EDFE - Very light lavender

    // Success - soft mint green
    static let success = Color(red: 0.64, green: 0.91, blue: 0.80) // #A4E8CC - Soft mint
    static let successLight = Color(light: Color(red: 0.92, green: 0.98, blue: 0.95), dark: Color(red: 0.2, green: 0.35, blue: 0.3))

    // Accent - soft peach
    static let accent = Color(red: 1.0, green: 0.85, blue: 0.78) // #FFD9C7 - Soft peach
    static let accentLight = Color(red: 1.0, green: 0.95, blue: 0.93) // #FFF2ED - Very light peach

    // Backgrounds - adaptive for dark mode with glass effect
    static let background = Color(light: Color(red: 0.99, green: 0.98, blue: 0.99), dark: Color(red: 0.12, green: 0.11, blue: 0.13))
    // Note: cardBackground is now replaced by Materials in the CardModifier

    // Text - adaptive for dark mode
    static let textPrimary = Color(light: Color(red: 0.20, green: 0.18, blue: 0.22), dark: Color(red: 0.95, green: 0.94, blue: 0.96))
    static let textSecondary = Color(light: Color(red: 0.55, green: 0.52, blue: 0.58), dark: Color(red: 0.70, green: 0.68, blue: 0.72))
    static let textTertiary = Color(light: Color(red: 0.72, green: 0.69, blue: 0.75), dark: Color(red: 0.50, green: 0.48, blue: 0.52))

    // Shadows and borders
    static func cardShadow() -> some View {
        return Color.black.opacity(0.03)
    }
}

// Helper extension for light/dark mode colors
extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor(dynamicProvider: { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        }))
    }
}

// Modern card style with frosted glass effect
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
