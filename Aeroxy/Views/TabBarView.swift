import SwiftUI

struct TabBarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.tabs) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: model.selectedTabID == tab.id,
                            select: {
                                model.selectedTabID = tab.id
                            },
                            close: {
                                model.closeTab(tab)
                            }
                        )
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)

            Button {
                model.showOpenPanel()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.aeroxyGlass)
            .help("Open HTML")
            .padding(.trailing, 10)
        }
        .frame(height: 48)
        .background(.thinMaterial.opacity(0.65))
    }
}

private struct TabButton: View {
    @ObservedObject var tab: HTMLTab
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 7) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(tab.title.isEmpty ? tab.displayName : tab.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 190, alignment: .leading)

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close Tab")
            }
            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, 7)
            .frame(height: 31)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(isSelected ? 0.12 : 0.05))
        )
        .help(tab.fileURL.path)
    }
}

