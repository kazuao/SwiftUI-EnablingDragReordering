//
//  ContentView.swift
//  EnablingDragReordering
//
//  Created by kazunori.aoki on 2023/09/13.
//

import SwiftUI

// https://danielsaidi.com/blog/2023/08/30/enabling-drag-reordering-in-swiftui-lazy-grids-and-stacks?utm_source=swiftlee&utm_medium=swiftlee_weekly&utm_campaign=issue_183

typealias Reorderable = Identifiable & Equatable

struct GridData: Reorderable {
    let id: Int
}

struct ReorderableForEach<Item: Reorderable, Content: View, Preview: View>: View {
    @Binding var active: Item?
    @State private var hasChangedLocation: Bool = false

    private let items: [Item]
    private let content: (Item) -> Content
    private let preview: ((Item) -> Preview)?
    private let moveAction: (IndexSet, Int) -> Void

    init(
        _ items: [Item],
        active: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ViewBuilder preview: @escaping (Item) -> Preview,
        moveAction: @escaping (IndexSet, Int) -> Void
    ) {
        self.items = items
        self._active = active
        self.content = content
        self.preview = preview
        self.moveAction = moveAction
    }

    init(
        _ items: [Item],
        active: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content,
        moveAction: @escaping (IndexSet, Int) -> Void
    ) where Preview == EmptyView {
        self.items = items
        self._active = active
        self.content = content
        self.preview = nil
        self.moveAction = moveAction
    }

    var body: some View {
        ForEach(items) { item in
            if let preview {
                contentView(for: item)
                    .onDrag {
                        dragData(for: item)
                    } preview: {
                        preview(item)
                    }
            } else {
                contentView(for: item)
                    .onDrag {
                        dragData(for: item)
                    }
            }
        }
    }

    private func contentView(for item: Item) -> some View {
        content(item)
            .opacity(active == item && hasChangedLocation ? 0.5 : 1)
            .onDrop(
                of: [.text],
                delegate: ReorderableDragRelocateDelegate(
                    item: item,
                    items: items,
                    active: $active,
                    hasChangedLocation: $hasChangedLocation
                ) { from, to in
                    withAnimation {
                        moveAction(from, to)
                    }
                })
    }

    private func dragData(for item: Item) -> NSItemProvider {
        active = item
        return .init(object: "\(item.id)" as NSString)
    }
}

struct ReorderableDragRelocateDelegate<Item: Reorderable>: DropDelegate {
    let item: Item
    var items: [Item]

    @Binding var active: Item?
    @Binding var hasChangedLocation: Bool

    var moveAction: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard item != active,
              let current = active,
              let from = items.firstIndex(of: current),
              let to = items.firstIndex(of: item)
        else { return }

        hasChangedLocation = true

        if items[to] != current {
            moveAction(IndexSet(integer: from), to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        hasChangedLocation = false
        active = nil
        return true
    }
}

struct ReorderableDropOutsideDelegate<Item: Reorderable>: DropDelegate {
    @Binding var active: Item?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        active = nil
        return true
    }
}

extension View {
    func reorderableForEachContainer<Item: Reorderable>(
        active: Binding<Item?>
    ) -> some View {
        onDrop(of: [.text], delegate: ReorderableDropOutsideDelegate(active: active))
    }
}

struct ContentView: View {

    @State private var items = (1...100).map { GridData(id: $0) }
    @State private var active: GridData?

    var shape: some Shape {
        RoundedRectangle(cornerRadius: 20)
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 200))]) {

                ReorderableForEach(items, active: $active) { item in
                    shape
                        .fill(.white.opacity(0.5))
                        .frame(height: 100)
                        .overlay(Text("\(item.id)"))
                        .contentShape(.dragPreview, shape)
                } preview: { item in
                    Color.white
                        .frame(height: 150)
                        .frame(minWidth: 250)
                        .overlay(Text("\(item.id)"))
                        .contentShape(.dragPreview, shape)
                } moveAction: { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                }
            }
            .padding()
        }
        .background(Color.blue.gradient)
        .scrollContentBackground(.hidden)
        .reorderableForEachContainer(active: $active)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
