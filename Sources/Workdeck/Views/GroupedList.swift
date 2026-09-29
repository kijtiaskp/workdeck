import SwiftUI

struct GroupedList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let groupName: (Item) -> String
    var onSelect: ((Item) -> Void)?
    var emptyTitle = "Nothing found"
    var emptySystemImage = "magnifyingglass"
    var emptyDescription: String?
    @ViewBuilder let row: (Item) -> Row

    private var sections: [(name: String, items: [Item])] {
        Dictionary(grouping: items, by: groupName)
            .map { (name: $0.key, items: $0.value) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: emptySystemImage, description: emptyDescription.map { Text($0) })
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(sections, id: \.name) { section in
                    Section(section.name) {
                        ForEach(section.items) { item in
                            if let onSelect {
                                row(item)
                                    .onTapGesture { onSelect(item) }
                            } else {
                                row(item)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}
