//
//  EntirePageView.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/17.
//

import SwiftUI
import ComposableArchitecture

struct EntirePageFeature: Reducer {
    struct State: Equatable, Identifiable {
        @BindingState var file: File
        @BindingState var currentPageIndex: Int
        var id: File.ID { self.file.id }
        //북마크만
        var showBookmarksOnly: Bool = false
    }
    enum Action: Equatable {
        case changePage(Int)
        case toggleBookmarks
    }
    @Dependency(\.dismiss) var dismiss
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .changePage(page):
                state.currentPageIndex = page
                return .none
            case .toggleBookmarks:
                state.showBookmarksOnly.toggle()
                return .none
            }
        }
    }
}

struct EntirePageView: View {
    @Environment(\.dismiss) var dismiss
    let store: StoreOf<EntirePageFeature>
    
    struct ViewState: Equatable {
        let file: File
        let currentPageIndex: Int
        let showBookmarksOnly: Bool
        init(state: EntirePageFeature.State) {
            self.file = state.file
            self.currentPageIndex = state.currentPageIndex
            self.showBookmarksOnly = state.showBookmarksOnly
        }
    }
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { (viewStore: ViewStore<ViewState, EntirePageFeature.Action>) in
            HStack{
                Button {
                    viewStore.send(.toggleBookmarks)
                } label: {
                    if viewStore.state.showBookmarksOnly {
                        Text("전체보기")
                    } else {
                        Text("북마크만")
                    }
                }
                Spacer()
                Text("탐색")
                Spacer()
            }
            .padding()
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5)) {
                    //토글 상태에 따라 뷰 변경 (타입 맞추기 위해 Set 만들고 정렬)
                    ForEach(viewStore.showBookmarksOnly ? Array(viewStore.file.bookMarkedPages.keys).sorted() : Array(0..<viewStore.file.numOfPages), id: \.self) { pageNum in
                        Button {
                            viewStore.send(.changePage(pageNum))
                            self.dismiss()
                        } label: {
                            VStack{
                                PDFKitThumbnailView(url: viewStore.file.url, pageNum: pageNum)
                                HStack{
                                    Text("\(pageNum+1)")
                                    if viewStore.file.bookMarkedPages.keys.contains(pageNum) {
                                        Text("(북마크됨)")
                                    }
                                }.foregroundColor(.primary)
                                
                            }.padding()
                        }
                        
                    }
                }
            }
        }
    }
}

struct EntirePageView_Previews: PreviewProvider {
    static var previews: some View {
        EntirePageView(
            store: Store(
                initialState:
                    EntirePageFeature.State(
                        file: .suneungteukgang, currentPageIndex: 0
                    ),
                reducer: EntirePageFeature()
            )
        )
    }
}
