import SwiftUI

struct GroupedList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let groupName: (Item) -> String
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    private var sections: [(name: String, items: [Item])] {
        Dictionary(grouping: items, by: groupName)
            .map { (name: $0.key, items: $0.value) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView("Nothing found", systemImage: "magnifyingglass")
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(sections, id: \.name) { section in
                    Section(section.name) {
                        ForEach(section.items) { item in
                            row(item)
                                .onTapGesture { onSelect(item) }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}
