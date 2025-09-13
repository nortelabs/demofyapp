import SwiftUI

// MARK: - Updated Color Palette
extension Color {
    // New color palette: Black, Oxford Blue, Orange Web, Platinum, White
    static let brandBlack = Color(red: 0.0, green: 0.0, blue: 0.0)                    // #000000
    static let oxfordBlue = Color(red: 0.078, green: 0.129, blue: 0.239)             // #14213D
    static let orangeWeb = Color(red: 0.988, green: 0.639, blue: 0.067)              // #FCA311
    static let platinum = Color(red: 0.898, green: 0.898, blue: 0.898)               // #E5E5E5
    static let brandWhite = Color(red: 1.0, green: 1.0, blue: 1.0)                  // #FFFFFF
    
    // Semantic colors using the new palette
    static let primaryBrand = orangeWeb
    static let secondaryBrand = oxfordBlue
    static let accentBrand = orangeWeb
    
    // System colors using new palette with dark mode support
    static let background = Color(NSColor.controlBackgroundColor)
    static let cardBackground = Color(NSColor.controlBackgroundColor)
    static let previewBackground = Color(NSColor.windowBackgroundColor)
    static let accent = primaryBrand
    static let secondaryText = Color.secondary
    static let border = Color(NSColor.separatorColor)
    static let success = Color.green
    static let warning = orangeWeb
    static let destructive = Color.red
}

// MARK: - Custom View Modifiers
struct CardStyle: ViewModifier {
    let padding: CGFloat
    let useGradient: Bool
    
    init(padding: CGFloat = 20, useGradient: Bool = false) {
        self.padding = padding
        self.useGradient = useGradient
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primaryBrand.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: Color.primaryBrand.opacity(0.1), radius: 8, x: 0, y: 4)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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

extension NSImage {
    /// Trims fully transparent borders and returns a cropped image; returns self on failure.
    func trimmingTransparentPixels() -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return self }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return self }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data?.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel) else { return self }
        var top = height
        var bottom = 0
        var left = width
        var right = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                if data[offset + 3] != 0 { // any non-transparent pixel
                    if x < left { left = x }
                    if x > right { right = x }
                    if y < top { top = y }
                    if y > bottom { bottom = y }
                }
            }
        }
        if left > right || top > bottom { return self }
        let cropRect = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
        guard let cropped = cgImage.cropping(to: cropRect) else { return self }
        return NSImage(cgImage: cropped, size: cropRect.size)
    }
}

extension NSImage {
    /// Returns the bounding rectangle of fully-transparent pixels in pixel coordinates.
    /// The rectangle is slightly inset to avoid edge bleed under the frame border.
    func transparentAreaBoundingRect(alphaThreshold: UInt8 = 1, insetPixels: Int = 1) -> CGRect? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let dataPtr = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0..<height {
            let rowBase = y * width * bytesPerPixel
            for x in 0..<width {
                let a = dataPtr[rowBase + x * bytesPerPixel + 3]
                if a <= alphaThreshold { // transparent
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard minX <= maxX && minY <= maxY else { return nil }
        // Inset by a pixel to avoid border overlap. Clamp to image bounds.
        let ix = max(0, minX + insetPixels)
        let iy = max(0, minY + insetPixels)
        let ax = min(width - 1, maxX - insetPixels)
        let ay = min(height - 1, maxY - insetPixels)
        guard ax >= ix && ay >= iy else { return nil }
        return CGRect(x: ix, y: iy, width: ax - ix + 1, height: ay - iy + 1)
    }
    
    /// Computes a ScreenRect in percentages (0..100) representing the transparent "screen" hole.
    func screenRectFromTransparencyPercent(alphaThreshold: UInt8 = 1, insetPixels: Int = 2) -> ScreenRect? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let pxRect = transparentAreaBoundingRect(alphaThreshold: alphaThreshold, insetPixels: insetPixels) else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let xPct = Double((pxRect.origin.x / w) * 100.0)
        let yPct = Double((pxRect.origin.y / h) * 100.0)
        let wPct = Double((pxRect.size.width / w) * 100.0)
        let hPct = Double((pxRect.size.height / h) * 100.0)
        return ScreenRect(x: xPct, y: yPct, w: wPct, h: hPct)
    }
}

struct ModernButtonStyle: ButtonStyle {
    let variant: Variant
    let size: Size
    
    enum Variant {
        case primary, secondary, destructive, ghost, accent
        
        var backgroundColor: Color {
            switch self {
            case .primary: return Color.primaryBrand
            case .accent: return Color.accentBrand
            case .destructive: return Color.destructive
            case .secondary: return Color(NSColor.controlColor)
            case .ghost: return .clear
            }
        }
        
        
        var foregroundColor: Color {
            switch self {
            case .primary: return Color.brandWhite
            case .accent: return Color.brandBlack
            case .destructive: return Color.brandWhite
            case .secondary: return .primary
            case .ghost: return .primaryBrand
            }
        }
        
        var borderColor: Color {
            switch self {
            case .ghost: return Color.primaryBrand
            case .secondary: return Color.border
            default: return .clear
            }
        }
    }
    
    enum Size {
        case small, medium, large
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium: return EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
            case .large: return EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .caption.weight(.semibold)
            case .medium: return .body.weight(.medium)
            case .large: return .headline.weight(.semibold)
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
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
            .foregroundColor(variant.foregroundColor)
            .padding(size.padding)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(variant.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: size.cornerRadius)
                            .stroke(variant.borderColor, lineWidth: variant == .ghost || variant == .secondary ? 1 : 0)
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
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
// MARK: - Animated Components
struct PulsingAnimation: ViewModifier {
    @State private var isAnimating = false
    let color: Color
    let intensity: Double
    
    init(color: Color = .primaryBrand, intensity: Double = 0.3) {
        self.color = color
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .opacity(isAnimating ? 0 : intensity)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct FloatingAnimation: ViewModifier {
    @State private var isFloating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -2 : 2)
            .animation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear {
                isFloating = true
            }
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle(padding: CGFloat = 20, useGradient: Bool = false) -> some View {
        modifier(CardStyle(padding: padding, useGradient: useGradient))
    }
    
    func modernButton(_ variant: ModernButtonStyle.Variant = .secondary, size: ModernButtonStyle.Size = .medium) -> some View {
        buttonStyle(ModernButtonStyle(variant, size: size))
    }
    
    func pulsingBorder(color: Color = .primaryBrand, intensity: Double = 0.3) -> some View {
        modifier(PulsingAnimation(color: color, intensity: intensity))
    }
    
    func floating() -> some View {
        modifier(FloatingAnimation())
    }
    
    func glassEffect() -> some View {
        background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.linearGradient(
                    colors: [.white.opacity(0.2), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
    
    func modernSectionHeader() -> some View {
        font(.title2)
        .fontWeight(.bold)
        .foregroundColor(Color.primaryBrand)
    }
    
    func subtleShadow() -> some View {
        shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}