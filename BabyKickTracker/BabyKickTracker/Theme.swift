import SwiftUI

// Soft pastel color scheme
struct Theme {
    // Primary colors - soft pastel pink
    static let primary = Color(red: 1.0, green: 0.71, blue: 0.82) // #FFB5D1 - Soft pink
    static let primaryLight = Color(red: 1.0, green: 0.93, blue: 0.95) // #FFECF2 - Very light pink
    static let primaryDark = Color(red: 0.98, green: 0.56, blue: 0.73) // #FA8FB8 - Medium pink

    // Secondary - soft lavender
    static let secondary = Color(red: 0.82, green: 0.76, blue: 0.98) // #D1C2FA - Soft lavender
    static let secondaryLight = Color(red: 0.95, green: 0.93, blue: 0.99) // #F2EDFE - Very light lavender

    // Success - soft mint green
    static let success = Color(red: 0.64, green: 0.91, blue: 0.80) // #A4E8CC - Soft mint
    static let successLight = Color(red: 0.92, green: 0.98, blue: 0.95) // #EBF9F2 - Very light mint

    // Accent - soft peach
    static let accent = Color(red: 1.0, green: 0.85, blue: 0.78) // #FFD9C7 - Soft peach
    static let accentLight = Color(red: 1.0, green: 0.95, blue: 0.93) // #FFF2ED - Very light peach

    // Backgrounds
    static let background = Color(red: 0.99, green: 0.98, blue: 0.99) // #FCFAFC - Very soft pink-tinted white
    static let cardBackground = Color.white

    // Text
    static let textPrimary = Color(red: 0.20, green: 0.18, blue: 0.22) // #332D38 - Soft black
    static let textSecondary = Color(red: 0.55, green: 0.52, blue: 0.58) // #8C8594 - Medium gray
    static let textTertiary = Color(red: 0.72, green: 0.69, blue: 0.75) // #B8B0BF - Light gray

    // Shadows and borders
    static func cardShadow() -> some View {
        return Color.black.opacity(0.03)
    }
}

// Modern card style
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
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
