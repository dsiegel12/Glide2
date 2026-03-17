//
//  Glide2App.swift
//  Glide2
//
//  Created by DonSiegel on 3/13/26.
//

import SwiftUI

@main
struct Glide2App: App {
    @StateObject private var store = AircraftStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var store: AircraftStore
    @State private var selectedAircraft: Aircraft? = nil

    var body: some View {
        if let ac = selectedAircraft {
            ContentView(aircraft: ac, onChangeAircraft: { selectedAircraft = nil })
        } else {
            AircraftSelectionView(selectedAircraft: $selectedAircraft)
                .environmentObject(store)
        }
    }
}
