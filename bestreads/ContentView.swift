//
//  ContentView.swift
//  bestreads
//
//  Created by Angela Kwon on 3/16/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = BookStore()
    @State private var showingAdd = false

    var body: some View {
        NavigationView {
            List {
                if store.books.isEmpty {
                    Text("No books yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.books) { book in
                        NavigationLink(destination: BookDetailView(book: book, store: store)) {
                            BookRowView(book: book)
                        }
                    }
                    .onDelete { idx in
                        for i in idx {
                            let id = store.books[i].id
                            store.delete(id: id)
                        }
                    }
                    .onMove { from, to in
                        store.move(fromOffsets: from, toOffset: to)
                    }
                }
            }
            .navigationTitle("Best Reads")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditBookView(store: store, mode: .add) {
                    showingAdd = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
