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
        var sections: [(name: String, items: [Item])] = []
        for item in items {
            let name = groupName(item)
            if let index = sections.firstIndex(where: { $0.name == name }) {
                sections[index].items.append(item)
            } else {
                sections.append((name: name, items: [item]))
            }
        }
        return sections
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
