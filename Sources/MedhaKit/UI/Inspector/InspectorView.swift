import SwiftUI

public struct InspectorView: View {
    @ObservedObject public var store: BlockStore

    public var body: some View {
        VStack(spacing: 0) {
            // Inspector Segmented Tab Header
            HStack {
                Picker("Inspector Tab", selection: $store.selectedInspectorTab) {
                    ForEach(InspectorTab.allCases) { tab in
                        Image(systemName: tab.icon)
                            .tag(tab)
                            .help(tab.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Active Tab Content
            switch store.selectedInspectorTab {
            case .outline:
                OutlineView(store: store)
            case .backlinks:
                BacklinksView(store: store)
            case .graph:
                LocalGraphView(store: store)
            case .info:
                DocInfoView(store: store)
            }
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
