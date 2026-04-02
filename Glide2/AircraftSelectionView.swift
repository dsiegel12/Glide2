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
            VStack(spacing: 0) {
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

            // Aviation Safety Disclaimer
            VStack(alignment: .leading, spacing: 6) {
                Text("Aviation Safety Disclaimer")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                Text("This application is for informational and educational purposes only. It does not constitute flight instruction, operational guidance, or real-time decision-making advice. Always follow certified training, official flight manuals, and FAA guidance. The \"impossible turn\" and similar maneuvers can be extremely hazardous and should only be attempted by trained pilots under appropriate conditions and at their own risk. The user is solely responsible for all flight decisions.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.055, green: 0.068, blue: 0.085))

            } // end VStack
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
