import SwiftUI

// MARK: - Color Extensions
extension Color {
    static let background = Color(NSColor.controlBackgroundColor)
    static let cardBackground = Color(NSColor.controlBackgroundColor)
    static let accent = Color.accentColor
    static let secondaryText = Color.secondary
    static let border = Color(NSColor.separatorColor)
    static let success = Color.green
    static let warning = Color.orange
    static let destructive = Color.red
    
    // Modern gradient colors
    static let primaryGradient = LinearGradient(
        colors: [Color.accent, Color.accent.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color(.systemGray6), Color(.systemGray5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Custom View Modifiers
struct CardStyle: ViewModifier {
    let padding: CGFloat
    
    init(padding: CGFloat = 16) {
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct ModernGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.subheadline)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
            
            configuration.content
        }
        .modifier(CardStyle())
    }
}

struct ModernButtonStyle: ButtonStyle {
    let variant: Variant
    let size: Size
    
    enum Variant {
        case primary, secondary, destructive, ghost
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .accent
            case .secondary: return Color(NSColor.controlColor)
            case .destructive: return .destructive
            case .ghost: return .clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .white
            case .ghost: return .accent
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary, .destructive: return .clear
            case .secondary: return .border
            case .ghost: return .accent
            }
        }
    }
    
    enum Size {
        case small, medium, large
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            case .medium: return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            case .large: return EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .caption
            case .medium: return .body
            case .large: return .headline
            }
        }
    }
    
    init(_ variant: Variant = .secondary, size: Size = .medium) {
        self.variant = variant
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .fontWeight(.medium)
            .foregroundColor(variant.foregroundColor)
            .padding(size.padding)
            .background(
                Group {
                    if variant == .primary {
                        LinearGradient(
                            colors: [Color.accent, Color.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        variant.backgroundColor
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(variant.borderColor, lineWidth: variant == .secondary || variant == .ghost ? 1 : 0)
            )
            .cornerRadius(10)
            .shadow(
                color: variant == .primary ? Color.accent.opacity(0.3) : Color.black.opacity(0.1),
                radius: variant == .primary ? 4 : 2,
                x: 0,
                y: variant == .primary ? 2 : 1
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernSliderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(.accent)
    }
}

// MARK: - Custom Components
struct StatusIndicator: View {
    let state: RecordingState
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
    
    private var indicatorColor: Color {
        switch state {
        case .idle: return .secondary
        case .recording: return .destructive
        case .recorded: return .success
        }
    }
    
    private var statusText: String {
        switch state {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .recorded: return "Recorded"
        }
    }
}

struct LabeledControl<Content: View>: View {
    let label: String
    let content: () -> Content
    
    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            content()
        }
    }
}

struct SliderWithValue: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let unit: String
    let onEditingChanged: ((Bool) -> Void)?
    
    init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        format: String = "%.1f",
        unit: String = "",
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.format = format
        self.unit = unit
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(String(format: format, value))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accent)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged ?? { _ in })
                .modifier(ModernSliderStyle())
        }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle(padding: CGFloat = 20) -> some View {
        modifier(CardStyle(padding: padding))
    }
    
    func modernButton(_ variant: ModernButtonStyle.Variant = .secondary, size: ModernButtonStyle.Size = .medium) -> some View {
        buttonStyle(ModernButtonStyle(variant, size: size))
    }
}