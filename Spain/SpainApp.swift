//
//  SpainApp.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import SwiftUI

@main
struct SpainApp: App {
    @StateObject private var store = StudyStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
