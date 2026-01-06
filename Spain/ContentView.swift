//
//  ContentView.swift
//  Spain
//
//  Created by Max on 1/6/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            VocabularyListView()
                .tabItem {
                    Label("词汇", systemImage: "list.bullet")
                }

            StudyView()
                .tabItem {
                    Label("背诵", systemImage: "brain.head.profile")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(StudyStore())
}
