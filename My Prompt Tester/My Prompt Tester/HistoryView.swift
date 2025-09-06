//
//  HistoryView.swift
//  My Prompt Tester
//
//  Created by Krystian Kozerawski on 05/09/2025.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    // Fetch newest first
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    @State private var itemPendingDeletion: Item? = nil
    @State private var isShowingDeleteAlert: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("No Saved Prompts",
                                           systemImage: "tray",
                                           description: Text("Submit a prompt and save the response to see it here."))
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                HistoryDetailView(item: item)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Prompt preview (multiline)
                                        Text(item.prompt)
                                            .font(.headline)
                                            .lineLimit(nil) // allow unlimited lines
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        // Answer preview (multiline)
                                        Text(item.aiAnswer)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(nil) // allow unlimited lines
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        // Timestamp
                                        Text(item.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 8)
                                    
                                    Spacer(minLength: 8)
                                    
                                    // Visible copy button in the row
                                    Button {
                                        _ = ClipboardManager.copy(from: item)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .imageScale(.medium)
                                            .accessibilityLabel("Copy")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Copy prompt and answer")

                                    // Visible delete button in the row
                                    Button(role: .destructive) {
                                        itemPendingDeletion = item
                                        isShowingDeleteAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .imageScale(.medium)
                                            .accessibilityLabel("Delete")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete this history item")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            #if os(iOS)
                            // iOS swipe actions for quick copy and delete
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    _ = ClipboardManager.copy(from: item)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    itemPendingDeletion = item
                                    isShowingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            #endif
                        }
                        // Retain existing bulk delete via edit mode if desired
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("History")
            #if os(iOS)
            .toolbar {
                EditButton()
            }
            #endif
            .alert("Delete this item?", isPresented: $isShowingDeleteAlert, presenting: itemPendingDeletion) { item in
                Button("Cancel", role: .cancel) {
                    itemPendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    delete(item: item)
                    itemPendingDeletion = nil
                }
            } message: { item in
                Text("This action cannot be undone.")
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    private func delete(item: Item) {
        withAnimation {
            modelContext.delete(item)
        }
    }
}

private struct HistoryDetailView: View {
    let item: Item
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.timestamp, format: Date.FormatStyle(date: .complete, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(item.prompt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Answer")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(item.aiAnswer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                
                // Copy button in detail as well for convenience
                HStack {
                    Spacer()
                    Button {
                        _ = ClipboardManager.copy(from: item)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    // In-memory preview with sample data
    let container: ModelContainer = {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let samples = [
            Item(timestamp: Date(), prompt: "Sample prompt 1\nwith multiple lines to demonstrate wrapping in the list cell.", aiAnswer: "Sample answer 1 that is also quite long and spans multiple lines to test multiline rendering in the list."),
            Item(timestamp: Date().addingTimeInterval(-3600), prompt: "Another prompt that is longer to show wrapping in the list cell and ensure everything expands properly.", aiAnswer: "Another answer that is longer to show wrapping in the list cell.\nSecond line.\nThird line.")
        ]
        samples.forEach { context.insert($0) }
        return container
    }()
    
    return HistoryView()
        .modelContainer(container)
}
