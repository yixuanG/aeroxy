import SwiftUI

struct EmptyStateView: View {
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 56, weight: .light))
                .symbolRenderingMode(.hierarchical)

            Button {
                openAction()
            } label: {
                Label("Open HTML", systemImage: "plus")
            }
            .buttonStyle(.aeroxyGlassProminent)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

