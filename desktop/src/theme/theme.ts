// Medha Theme Tokens — Direct 1:1 Port of Sources/MedhaKit/UI/Theme/MedhaTheme.swift
export const MedhaTheme = {
  spacing: {
    xxs: '2px',
    xs: '4px',
    s: '8px',
    m: '12px',
    l: '16px',
    xl: '20px',
    xxl: '24px',
    xxxl: '32px',
  },
  radius: {
    micro: '4px',
    chip: '6px',
    small: '8px',
    row: '10px',
    card: '14px',
    hero: '20px',
    full: '9999px',
  },
  colors: {
    // Dark mode Tiered Backgrounds (Matches MedhaTheme.swift)
    bgBase: '#0F1117',
    bgSurface: '#161923',
    bgElevated: '#1E2230',
    bgSubtle: '#262B3D',
    bgOverlay: 'rgba(15, 17, 23, 0.85)',

    // Accents & Gradients
    accentBlue: '#3B82F6',
    accentPurple: '#8B5CF6',
    accentIndigo: '#6366F1',
    accentPink: '#EC4899',
    accentTeal: '#14B8A6',
    accentAmber: '#F59E0B',
    accentEmerald: '#10B981',

    // Borders & Hairlines
    borderHairline: 'rgba(255, 255, 255, 0.06)',
    borderSubtle: 'rgba(255, 255, 255, 0.10)',
    borderStrong: 'rgba(255, 255, 255, 0.18)',

    // Text hierarchy
    textPrimary: '#F8FAFC',
    textSecondary: '#94A3B8',
    textTertiary: '#64748B',
    textMuted: '#475569',

    // Semantic status
    success: '#22C55E',
    warning: '#F59E0B',
    danger: '#EF4444',
    info: '#3B82F6',
  },
  typography: {
    fontSans: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
    fontMono: '"SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace',
    measure: '740px', // Strict typographic measure from BlockEditorView.swift
  }
};
