//
//  PetitPDFViewerApp.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/15.
//

import SwiftUI
import ComposableArchitecture

@main
struct PetitPDFViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: Store(
                    initialState: AppFeature.State(
                        files: [
                            .suneungteukgang
                        ]
                    ),
                    reducer: AppFeature()
                )
            )
        }
    }
}
