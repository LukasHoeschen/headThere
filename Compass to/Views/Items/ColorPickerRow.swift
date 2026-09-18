import SwiftUI

// MARK: - Color picker row

struct ColorPickerRow: View {
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(itemColorPalette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: selected == hex ? 2.5 : 0)
                                .padding(2)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: hex), lineWidth: selected == hex ? 1.5 : 0)
                        )
                        .onTapGesture { selected = hex }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
