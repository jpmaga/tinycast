import SwiftUI

struct EmptyResults: View {
    @Environment(\.metrics) private var metrics
    let text: String
    var detail: String?
    var systemImage = "magnifyingglass"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.largeTitle)
                .symbolRenderingMode(.hierarchical).foregroundStyle(.tertiary)
            Text(text).font(metrics.typography.rowTitle).foregroundStyle(.secondary)
            if let detail {
                Text(detail)
                    .font(metrics.typography.rowTrailing)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
