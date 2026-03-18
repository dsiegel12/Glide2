import SwiftUI

struct AircraftSelectionView: View {
    @EnvironmentObject var store: AircraftStore
    @Binding var selectedAircraft: Aircraft?

    @State private var showAddSheet = false
    @State private var aircraftToEdit: Aircraft?
    @State private var aircraftToDelete: Aircraft?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.aircraft) { ac in
                    aircraftRow(ac)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if ac.isUserDefined {
                                Button(role: .destructive) {
                                    aircraftToDelete = ac
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    aircraftToEdit = ac
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .background(Color(red: 0.055, green: 0.068, blue: 0.085))
            .scrollContentBackground(.hidden)
            .navigationTitle("Select Aircraft")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditAircraftView(existingAircraft: nil)
                    .environmentObject(store)
            }
            .sheet(item: $aircraftToEdit) { ac in
                AddEditAircraftView(existingAircraft: ac)
                    .environmentObject(store)
            }
            .confirmationDialog(
                "Delete \(aircraftToDelete?.fullName ?? "")?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let ac = aircraftToDelete {
                        store.delete(ac)
                    }
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    func aircraftRow(_ ac: Aircraft) -> some View {
        Button {
            selectedAircraft = ac
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(ac.accentColor)
                    .frame(width: 4, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ac.id)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(ac.accentColor)
                    Text(ac.fullName)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white)
                    HStack(spacing: 10) {
                        Text("MTOW \(Int(ac.mtow)) lb")
                        Text("L/D \(String(format: "%.1f", ac.glideRatio)):1")
                        Text("Vbg \(Int(ac.refGlideSpeed)) kts / \(Int((ac.refGlideSpeed * 1.15078).rounded())) mph")
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                if ac.isUserDefined {
                    Button {
                        aircraftToEdit = ac
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(ac.accentColor.opacity(0.85))
                            Text("EDIT")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(ac.accentColor.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.25))
                    .font(.system(size: 13))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(red: 0.055, green: 0.068, blue: 0.085))
        .listRowSeparatorTint(Color.white.opacity(0.08))
    }
}
