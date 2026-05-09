import SwiftUI

// MARK: - PinDot

struct PinDot: View {
    enum Kind {
        case certified, friendly, photo, cultural, saved

        var color: Color {
            switch self {
            case .certified: return Theme.pinCertified
            case .friendly:  return Theme.pinFriendly
            case .photo:     return Theme.pinPhoto
            case .cultural:  return Theme.pinCultural
            case .saved:     return Theme.pinSaved
            }
        }

        var glyph: String {
            switch self {
            case .certified, .friendly: return "fork.knife"
            case .photo:    return "camera.fill"
            case .cultural: return "building.columns.fill"
            case .saved:    return "heart.fill"
            }
        }
    }

    let kind: Kind
    var size: CGFloat = 36
    var label: String?
    var selected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(kind.color)
            if let label {
                Text(label)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: kind.glyph)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: Theme.fg1.opacity(0.20), radius: 4, y: 2)
        .shadow(color: Theme.fg1.opacity(0.18), radius: 12, y: 4)
        .scaleEffect(selected ? 1.15 : 1.0)
        .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.86), value: selected)
    }

    init(_ kind: Kind, size: CGFloat = 36, label: String? = nil, selected: Bool = false) {
        self.kind = kind
        self.size = size
        self.label = label
        self.selected = selected
    }
}

// MARK: - CertBadge

struct CertBadge: View {
    let status: ZabihahHalalStatus
    var compact: Bool = false

    private var color: Color {
        switch status {
        case .zabiha, .fullyHalal: return Theme.pinCertified
        case .partiallyHalal: return Theme.pinFriendly
        }
    }

    private var label: String {
        switch status {
        case .zabiha: return "Halal"
        case .fullyHalal: return "Halal"
        case .partiallyHalal: return "Partially-Halal"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: compact ? 11 : 13))
            Text(label)
                .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
                .tracking(0.3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 3 : 4)
        .background(color, in: Capsule())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let eyebrow: String?
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    Text(eyebrow)
                        .eyebrowStyle()
                }
                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.fg1)
            }
            Spacer()
            if let action {
                Button {
                    onAction?()
                } label: {
                    HStack(spacing: 2) {
                        Text(action)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.fg1)
                }
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.bottom, Theme.s3)
    }
}

// MARK: - Filter Chip

struct SafaFilterChip: View {
    let label: String
    var dotColor: Color?
    var hasDropdown: Bool = false
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                        .overlay {
                            if isSelected {
                                Circle().stroke(.white, lineWidth: 1.5)
                            }
                        }
                }
                Text(label)
                    .font(.system(size: 12.5, weight: .semibold))
                if hasDropdown {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Theme.fg2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : Theme.fg1)
            .background(isSelected ? Theme.fg1 : .white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? .clear : Theme.fg1.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Column (for detail views)

struct StatColumn: View {
    let label: String
    let value: String
    let sub: String
    var icon: String?
    var positive: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .eyebrowStyle()
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(positive ? Theme.pinCertified : Theme.fg1)
                }
                Text(value)
                    .font(.mono(17, weight: .bold))
                    .foregroundStyle(positive ? Theme.pinCertified : Theme.fg1)
            }
            Text(sub)
                .font(.mono(11))
                .foregroundStyle(Theme.fg3)
        }
        .frame(maxWidth: .infinity)
    }
}
