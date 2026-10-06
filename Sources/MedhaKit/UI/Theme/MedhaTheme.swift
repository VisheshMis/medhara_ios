import SwiftUI
import AppKit

// MARK: - Color Hex Initializer
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Dynamic color supporting Dark and Light mode
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
    }
}

// MARK: - Medha Theme Design System
public enum MedhaTheme {

    // MARK: - Spacing Scale (4pt grid)
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radii (.continuous)
    public enum Radius {
        public static let micro: CGFloat = 4
        public static let chip: CGFloat = 6
        public static let small: CGFloat = 8
        public static let row: CGFloat = 10
        public static let card: CGFloat = 14
        public static let hero: CGFloat = 20
    }

    // MARK: - Colors
    public enum Colors {
        // Tiered Backgrounds (Cool indigo-slate tinted dark / crisp elevated light)
        public static let bgBase = Color.dynamic(
            light: Color(hex: "#F8FAFC"),
            dark: Color(hex: "#0F1117")
        )
        public static let bgSurface = Color.dynamic(
            light: Color(hex: "#FFFFFF"),
            dark: Color(hex: "#161923")
        )
        public static let bgElevated = Color.dynamic(
            light: Color(hex: "#F1F5F9"),
            dark: Color(hex: "#1E2230")
        )
        public static let bgSidebar = Color.dynamic(
            light: Color(hex: "#F8FAFC").opacity(0.85),
            dark: Color(hex: "#0D0E15").opacity(0.85)
        )

        // Borders & Separators
        public static let borderHairline = Color.dynamic(
            light: Color.black.opacity(0.08),
            dark: Color.white.opacity(0.08)
        )
        public static let borderSubtle = Color.dynamic(
            light: Color.black.opacity(0.12),
            dark: Color.white.opacity(0.12)
        )
        public static let borderHighlight = Color.dynamic(
            light: Color.white.opacity(0.8),
            dark: Color.white.opacity(0.12)
        )

        // Text & Hierarchy
        public static let textPrimary = Color.dynamic(
            light: Color(hex: "#0F172A"),
            dark: Color(hex: "#F8FAFC")
        )
        public static let textSecondary = Color.dynamic(
            light: Color(hex: "#475569"),
            dark: Color(hex: "#94A3B8")
        )
        public static let textTertiary = Color.dynamic(
            light: Color(hex: "#94A3B8"),
            dark: Color(hex: "#64748B")
        )

        // Brand Accent Gradient & Colors (Violet to Blue)
        public static let accentStart = Color(hex: "#7C6CFF")
        public static let accentEnd = Color(hex: "#4C9AFF")
        public static let accent = Color(hex: "#6C6CFF")

        public static let brandGradient = LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Feature Accents (Identity per domain)
        public static let notesAccent = Color(hex: "#3B82F6")      // Vibrant Blue
        public static let graphAccent = Color(hex: "#10B981")      // Teal / Emerald
        public static let flashcardsAccent = Color(hex: "#F59E0B") // Warm Amber
        public static let palaceAccent = Color(hex: "#8B5CF6")     // Royal Violet
        public static let aiAccent = Color(hex: "#EC4899")         // Magenta / Pink

        // AI Sparkle Gradient
        public static let aiGradient = LinearGradient(
            colors: [Color(hex: "#EC4899"), Color(hex: "#8B5CF6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Semantic Colors
        public static let success = Color(hex: "#10B981")
        public static let warning = Color(hex: "#F59E0B")
        public static let danger = Color(hex: "#EF4444")
        public static let info = Color(hex: "#3B82F6")

        // Anki/FSRS Study Status Colors (Softened & refined)
        public static let cardNew = Color(hex: "#3B82F6")     // Soft Blue
        public static let cardLearn = Color(hex: "#F97316")   // Soft Orange
        public static let cardDue = Color(hex: "#10B981")     // Soft Emerald Green

        // Rating Answer Buttons
        public static let ratingAgain = Color(hex: "#EF4444") // Red
        public static let ratingHard = Color(hex: "#F59E0B")  // Amber
        public static let ratingGood = Color(hex: "#3B82F6")  // Blue
        public static let ratingEasy = Color(hex: "#10B981")  // Green
    }

    // MARK: - Typography
    public enum Typography {
        public static let largeTitle = Font.system(size: 28, weight: .bold)
        public static let title = Font.system(size: 20, weight: .bold)
        public static let headline = Font.system(size: 15, weight: .semibold)
        public static let body = Font.system(size: 14, weight: .regular)
        public static let subheadline = Font.system(size: 13, weight: .regular)
        public static let caption = Font.system(size: 12, weight: .regular)
        public static let micro = Font.system(size: 10, weight: .medium)

        // Rounded for Stats, Badges, Timers
        public static let roundedStatsLarge = Font.system(size: 28, weight: .bold, design: .rounded)
        public static let roundedStatsMedium = Font.system(size: 20, weight: .bold, design: .rounded)
        public static let roundedBadge = Font.system(size: 11, weight: .semibold, design: .rounded)
        public static let roundedTimer = Font.system(size: 13, weight: .bold, design: .rounded).monospacedDigit()

        // Serif (New York) for Note Titles & Flashcard Questions
        public static let serifNoteTitle = Font.system(size: 28, weight: .bold, design: .serif)
        public static let serifHeading1 = Font.system(size: 24, weight: .bold, design: .serif)
        public static let serifCardQuestion = Font.system(size: 22, weight: .medium, design: .serif)
        public static let serifCardAnswer = Font.system(size: 16, weight: .regular, design: .serif)

        // SF Mono for Code, References, Monospaced counts
        public static let codeBlock = Font.system(size: 13, weight: .regular, design: .monospaced)
        public static let monoBadge = Font.system(size: 10, weight: .semibold, design: .monospaced)
        public static let monoCounter = Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    // MARK: - Shadows
    public enum Shadows {
        public static let softLow = Color.black.opacity(0.12)
        public static let softMedium = Color.black.opacity(0.20)
        public static let glowAccent = MedhaTheme.Colors.accentStart.opacity(0.25)
    }
}

// MARK: - Reusable View Modifiers

/// Polished Card Container with subtle background, hairline border, soft shadow, and inner highlight
public struct MedhaCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var elevation: Int
    var isInteractive: Bool
    @State private var isHovered: Bool = false

    public init(cornerRadius: CGFloat = MedhaTheme.Radius.card, elevation: Int = 1, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(elevation > 1 ? MedhaTheme.Colors.bgElevated : MedhaTheme.Colors.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isInteractive && isHovered
                            ? MedhaTheme.Colors.accent.opacity(0.35)
                            : MedhaTheme.Colors.borderHairline,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: elevation > 1
                    ? MedhaTheme.Shadows.softMedium
                    : MedhaTheme.Shadows.softLow,
                radius: (isInteractive && isHovered) ? 12 : (elevation > 1 ? 8 : 4),
                x: 0,
                y: (isInteractive && isHovered) ? 4 : (elevation > 1 ? 4 : 2)
            )
            .offset(y: (isInteractive && isHovered) ? -1 : 0)
            .onHover { hovering in
                if isInteractive {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isHovered = hovering
                    }
                }
            }
    }
}

/// Compact Capsule Chip with tinted fill, hairline border, and rounded typography
public struct MedhaChipModifier: ViewModifier {
    var color: Color
    var isMuted: Bool

    public init(color: Color, isMuted: Bool = false) {
        self.color = color
        self.isMuted = isMuted
    }

    public func body(content: Content) -> some View {
        content
            .font(MedhaTheme.Typography.roundedBadge)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(isMuted ? 0.08 : 0.15))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(isMuted ? 0.18 : 0.3), lineWidth: 1)
            )
    }
}

/// Row Container with smooth hover/selection pill effect and left indicator
public struct MedhaRowModifier: ViewModifier {
    var isSelected: Bool
    var tint: Color
    @State private var isHovered: Bool = false

    public init(isSelected: Bool, tint: Color = MedhaTheme.Colors.accent) {
        self.isSelected = isSelected
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: MedhaTheme.Radius.row, style: .continuous)
                    .fill(
                        isSelected
                            ? tint.opacity(0.16)
                            : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                    )
            )
            .overlay(
                HStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(tint)
                            .frame(width: 3)
                            .padding(.vertical, 4)
                            .padding(.leading, 2)
                    }
                    Spacer()
                }
            )
            .contentShape(RoundedRectangle(cornerRadius: MedhaTheme.Radius.row, style: .continuous))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

/// Brand Gradient Primary Button
public struct MedhaPrimaryButtonModifier: ViewModifier {
    var gradient: LinearGradient
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    public init(gradient: LinearGradient = MedhaTheme.Colors.brandGradient) {
        self.gradient = gradient
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: MedhaTheme.Radius.small, style: .continuous)
                    .fill(gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MedhaTheme.Radius.small, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: MedhaTheme.Shadows.glowAccent, radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 3 : 1)
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.01 : 1.0))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Convenient View Extensions
public extension View {
    func medhaCard(cornerRadius: CGFloat = MedhaTheme.Radius.card, elevation: Int = 1, isInteractive: Bool = false) -> some View {
        modifier(MedhaCardModifier(cornerRadius: cornerRadius, elevation: elevation, isInteractive: isInteractive))
    }

    func medhaChip(color: Color = MedhaTheme.Colors.accent, isMuted: Bool = false) -> some View {
        modifier(MedhaChipModifier(color: color, isMuted: isMuted))
    }

    func medhaRow(isSelected: Bool, tint: Color = MedhaTheme.Colors.accent) -> some View {
        modifier(MedhaRowModifier(isSelected: isSelected, tint: tint))
    }

    func medhaPrimaryButton(gradient: LinearGradient = MedhaTheme.Colors.brandGradient) -> some View {
        modifier(MedhaPrimaryButtonModifier(gradient: gradient))
    }
}
