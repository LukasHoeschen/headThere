import SwiftUI

// MARK: - Single item indicator

struct SingleItemView: View {
    let data: CompassItemData
    let metrics: CompassMetrics

    @AppStorage("useMiles") private var useMiles: Bool = false

    private var rad: Double { data.screenAngle * .pi / 180 }

    private var pos: CGSize {
        CGSize(width: sin(rad) * data.visualRadius, height: -cos(rad) * data.visualRadius)
    }

    private var isRightHalf: Bool { sin(rad) >= 0 }

    private var labelOffset: CGSize {
        let hGap = metrics.arrowSize * 0.7 + 34
        return CGSize(
            width:  pos.width  + (isRightHalf ? hGap : -hGap),
            height: pos.height
        )
    }

    var body: some View {
        ZStack {
            switch data.zone {
            case .tooClose:
                // Dots sit inside the visible scale
                Circle()
                    .fill(data.item.color.opacity(0.5))
                    .frame(width: metrics.dotSize * 0.7, height: metrics.dotSize * 0.7)
                    .overlay(Circle().stroke(data.item.color.opacity(0.8), lineWidth: 0.7))
                    .offset(pos)

            case .middle:
                Image(systemName: "location.north.fill")
                    .font(.system(size: metrics.arrowSize, weight: .semibold))
                    .foregroundStyle(data.item.color)
                    .rotationEffect(.degrees(data.screenAngle))
                    .offset(pos)

                VStack(alignment: isRightHalf ? .leading : .trailing, spacing: 1) {
                    Text(data.item.name)
                        .font(.system(size: metrics.labelFontSize, weight: .semibold))
                        .lineLimit(1)
                    Text(formatDistance(data.distance, useMiles: useMiles))
                        .font(.system(size: metrics.distFontSize))
                        .opacity(0.88)
                    if let countdown = data.item.countdownText {
                        Text(countdown)
                            .font(.system(size: metrics.distFontSize))
                            .opacity(0.88)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(data.item.color, in: RoundedRectangle(cornerRadius: 7))
                .offset(labelOffset)

            case .tooFar:
                // Dots sit outside the visible scale
                Circle()
                    .fill(data.item.color.opacity(0.5))
                    .frame(width: metrics.dotSize * 0.7, height: metrics.dotSize * 0.7)
                    .overlay(Circle().stroke(data.item.color.opacity(0.8), lineWidth: 0.7))
                    .offset(pos)
            }
        }
    }
}
