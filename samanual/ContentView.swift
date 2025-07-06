//
//  ContentView.swift
//  samanual
//
//  Created by Judi Smith on 7/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text("Welcome to samanual!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your new Clean Architecture project is ready.")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
