//
//  PDFListView.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/15.
//

import SwiftUI
import SwiftUINavigation
import ComposableArchitecture

struct PDFDetailFeature: Reducer {
    struct State: Equatable, Identifiable {
        @BindingState var file: File
        //현재 페이지 인덱스
        @BindingState var currentPageIndex: Int
        var exploreFile: EntirePageFeature.State?
        //해당 뷰 OnAppear OnDisappear 때 시간 찍고 차이 구해줌
        var startTime: Date?
        var endTime: Date?
        var timeDifference: Double = 0
        
        var id: File.ID { self.file.id }
    }
    enum Action: Equatable, BindableAction {
        //페이지 이동
        case binding(BindingAction<State>)
        case nextPage
        case formerPage
        //뷰에 머무른 시간 계산
        case viewAppeared
        case viewDisappeared
        //탐색 모달 띄우기
        case exploreFile(PresentationAction<EntirePageFeature.Action>)
        case exploreButtonTapped
        case cancelExploreButtonTapped
        //api 호출
        case fetchBookmarks
        case bookmarksResponse(Result<[BookmarkData], ApiClient.Failure>)
        case addBookmark
        case bookmarkAdded(Result<[String:String], ApiClient.Failure>)
        case removeBookmark
        case bookmarkRemoved(Result<EquatableVoid, ApiClient.Failure>)
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.apiClient) var apiClient
    @Dependency(\.mainQueue) var mainQueue
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .nextPage:
                if state.currentPageIndex < state.file.numOfPages - 1 {
                    state.currentPageIndex += 1
                    print(state.currentPageIndex)
                }
                return .none
            case .formerPage:
                if state.currentPageIndex > 0 {
                    state.currentPageIndex -= 1
                    print(state.currentPageIndex)
                }
                return .none
            case .viewAppeared:
                //공부 시작
                state.startTime = Date()
                return .none
            case .viewDisappeared:
                //공부 끝
                state.endTime = Date()
                // 시간 차이 계산 후에 learningTime 변수에 저장
                if let startTime = state.startTime, let endTime = state.endTime {
                    state.timeDifference = endTime.timeIntervalSince(startTime)
                    //누적 공부시간
                    state.file.learningTime += Int(state.timeDifference)
                    print("공부시간: \(state.file.learningTime)")
                }
                return .none
            case .exploreFile:
                return .none
            case .exploreButtonTapped:
                let file = state.file
                
                state.exploreFile = EntirePageFeature.State(file: file, currentPageIndex: 0)
                return .none
            case .cancelExploreButtonTapped:
                state.exploreFile = nil
                return .none
            
            // -TODO: run 쓰는 법 찾아서 옛날 코드 수정하기
            case .fetchBookmarks:
                return apiClient.fetchBookmarks(state.file.id.uuidString)
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map(PDFDetailFeature.Action.bookmarksResponse)

            case .bookmarksResponse(.success(let bookmarks)):
                print("불러오기 성공:\(bookmarks)")
                return .none

            case .bookmarksResponse(.failure(let error)):
                print("에러:\(error)")
                return .none
                
            case .addBookmark:
                return apiClient.addBookmark(state.file.id.uuidString, state.currentPageIndex)
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map(PDFDetailFeature.Action.bookmarkAdded)
                
            case .bookmarkAdded(.success(let bookmark)):
                state.file.bookMarkedPages[state.currentPageIndex] = bookmark["bookmarkId"]
                print("북마크 성공: \(bookmark)")
                return .none

            case .bookmarkAdded(.failure(let error)):
                print("에러:\(error)")
                return .none
                
            case .removeBookmark:
                return apiClient.removeBookmark(state.file.bookMarkedPages[state.currentPageIndex] ?? "")
                    .receive(on: mainQueue)
                    .catchToEffect()
                    .map(PDFDetailFeature.Action.bookmarkRemoved)
                
            case .bookmarkRemoved(.success):
                state.file.bookMarkedPages.removeValue(forKey: state.currentPageIndex)
                print("삭제 성공")
                return .none

            case .bookmarkRemoved(.failure(let error)):
                print("에러:\(error)")
                return .none
                
            }
        }
        .ifLet(\.exploreFile, action: /Action.exploreFile) {
            EntirePageFeature()
        }
    }
}

struct PDFDetailView: View {
    @Environment(\.dismiss) var dismiss
    let store: StoreOf<PDFDetailFeature>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack{
                HStack(spacing: 12) {
                    Button {
                        viewStore.send(.exploreButtonTapped)
                    } label: {
                        HStack{
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.primary)
                            Text("탐색")
                                .foregroundColor(.primary)
                        }
                        
                    }
                    Spacer()
                    
                    Button(action: {
                        if viewStore.file.bookMarkedPages.keys.contains(viewStore.currentPageIndex) {
                            viewStore.send(.removeBookmark)
                        } else {
                            viewStore.send(.addBookmark)
                        }
                        print(viewStore.file.bookMarkedPages)
                    }) {
                        if viewStore.file.bookMarkedPages.keys.contains(viewStore.currentPageIndex) {
                            Text("북마크삭제")
                                .foregroundColor(.primary)
                        } else {
                            Text("북마크하기")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.leading, 14)
                .padding(.top, 30)
                
                PDFKitView(
                    url: viewStore.file.url,
                    currentPageIndex: viewStore.binding(\.$currentPageIndex)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    DragGesture()
                        .onEnded { gesture in
                            let dragDistance = gesture.translation.width
                            let threshold: CGFloat = 200
                            
                            if dragDistance > threshold {
                                viewStore.send(.formerPage)
                            } else if dragDistance < -threshold {
                                viewStore.send(.nextPage)
                            }
                        }
                )
                
                HStack {
                    Button(action: {
                        viewStore.send(.formerPage)
                    }, label: {
                        Text("이전 페이지")
                            .foregroundColor(.primary)
                    })
                    
                    Spacer()
                    
                    Button(action: {
                        viewStore.send(.nextPage)
                    }, label: {
                        Text("다음 페이지")
                            .foregroundColor(.primary)
                    })
                }
                .padding()
                
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: {
                    viewStore.send(.viewDisappeared)
                    self.dismiss()
                }, label: {
                    HStack{
                        Image(systemName: "chevron.backward.square")
                            .foregroundColor(.primary)
                        Text("뒤로가기")
                            .foregroundColor(.primary)
                    }
                    .padding(.top)
                })
            )
            .onAppear {
                viewStore.send(.viewAppeared)
                viewStore.send(.fetchBookmarks)
            }
            .sheet(store: self.store.scope(state: \.exploreFile, action: PDFDetailFeature.Action.exploreFile)
            ) { store in
                EntirePageView(store: store)
            }
            
            
        }
    }
}

struct PDFDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PDFDetailView(
            store: Store(
                initialState:
                    PDFDetailFeature.State(
                        file: .suneungteukgang,
                        currentPageIndex: 0,
                        timeDifference: 0
                    ),
                reducer: PDFDetailFeature()
            )
        )
    }
}

