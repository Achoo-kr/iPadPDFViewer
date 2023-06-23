//
//  ContentView.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/15.
//

import SwiftUI
import ComposableArchitecture
import PDFKit

struct AppFeature: Reducer {
    struct State: Equatable {
        var files: IdentifiedArrayOf<File> = []
        var alert: AlertState<Action.Alert>?
        //NavLink로 넘어갈 State
        var pdfDetail: PDFDetailFeature.State?
        var isOnDeleteMode: Bool = false
        var isImporterOpen: Bool = false
    }
    
    enum Action: Equatable {
        case openFileImporter
        case addPDF(File)
        case toggleDeleteMode
        case alert(PresentationAction<Alert>)
        case deleteButtonTapped(id: File.ID)
        case pdfTapped(id: File.ID)
        case editPDFInfo(PresentationAction<PDFDetailFeature.Action>)
        
        enum Alert: Equatable {
            case confirmDeletion(id: File.ID)
        }
    }
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                //파일 임포터 오픈
            case .openFileImporter:
                state.isImporterOpen.toggle()
                return .none
                
                //PDF 추가
            case let .addPDF(file):
                state.files.append(file)
                return .none
                
                //PDF 삭제
            case .toggleDeleteMode:
                state.isOnDeleteMode.toggle()
                return .none
                
            case .alert(.dismiss):
                state.alert = nil
                return .none
                
            case let .alert(.presented(.confirmDeletion(id))):
                state.files.remove(id: id)
                return .none
                
            case .alert:
                return .none
                
            case let .deleteButtonTapped(id):
                guard let file = state.files[id: id]
                else { return .none }
                
                state.alert = .delete(file: file)
                return .none
                
                //PDF 뷰어에서 나왔을때 총 학습시간 변경
            case .editPDFInfo(.dismiss):
                guard let file = state.pdfDetail?.file
                else { return .none }
                state.files[id: file.id] = file
                return .none
            case .editPDFInfo:
                return .none
                
                //PDF 뷰어로 넘어가기
            case let .pdfTapped(id: fileID):
                guard let file = state.files[id: fileID]
                else { return .none }
                state.pdfDetail = PDFDetailFeature.State(file: file, currentPageIndex: 0)
                return .none
            }
        }
        .ifLet(\.pdfDetail, action: /Action.editPDFInfo) {
            PDFDetailFeature()
        }
    }
}

extension AlertState where Action == AppFeature.Action.Alert {
    static func delete(file: File) -> Self {
        AlertState {
            TextState(#""\#(file.name)"을 삭제"#)
        } actions: {
            ButtonState(role: .destructive, action: .send(.confirmDeletion(id: file.id), animation: .default)) {
                TextState("삭제")
            }
        } message: {
            TextState("삭제된 파일은 복구되지 않으며, 다시 불러와야 합니다")
        }
    }
}


struct ContentView: View {
    let store: StoreOf<AppFeature>
    
    struct ViewState: Equatable {
        let pdfDetail: File.ID?
        let files: IdentifiedArrayOf<File>
        let isOnDeleteMode: Bool
        let isImporterOpen: Bool
        
        init(state: AppFeature.State) {
            self.pdfDetail = state.pdfDetail?.file.id
            self.files = state.files
            self.isOnDeleteMode = state.isOnDeleteMode
            self.isImporterOpen = state.isImporterOpen
        }
    }
    
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { (viewStore: ViewStore<ViewState, AppFeature.Action>) in
            NavigationView{
                VStack{
                    HStack(spacing: 12) {
                        Text("Petit PDF Viewer")
                            .font(.system(size: 28, weight: .bold))
                        Spacer()
                        Button {
                            viewStore.send(.toggleDeleteMode)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 10)
                        }
                        Button {
                            viewStore.send(.openFileImporter)
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.leading, 14)
                    .padding(.top, 30)
                    
                    List {
                        ForEach(viewStore.files.reversed()) { file in
                                NavigationLink(
                                    isActive: Binding(
                                        get: { viewStore.pdfDetail == file.id},
                                        set: { isActive in
                                            if isActive {
                                                viewStore.send(.pdfTapped(id: file.id))
                                            } else {
                                                viewStore.send(.editPDFInfo(.dismiss))
                                            }
                                        }
                                    ),
                                    destination: {
                                        IfLetStore(
                                            self.store.scope(
                                                state: \.pdfDetail,
                                                action: { .editPDFInfo(.presented($0)) }
                                            ),
                                            then: { store in
                                                PDFDetailView(store: store)
                                            }
                                        )
                                    },
                                    label: {
                                        HStack{
                                            PDFKitThumbnailView(url: file.url, pageNum: 0)
                                            VStack(alignment: .leading) {
                                                Text(file.name)
                                                    .bold()
                                                    .lineLimit(1)
                                                
                                                if file.learningTime == 0 {
                                                    Text("학습 전")
                                                } else if file.learningTime < 60 {
                                                    // 시, 분 단위가 아닌 경우 초 나타내기
                                                    Text("\(file.learningTime)초 학습 중")
                                                } else {
                                                    let hours = file.learningTime / 3600 // 시간 계산
                                                    let minutes = (file.learningTime % 3600) / 60 // 분 계산
                                                    
                                                    if hours == 0 {
                                                        // 시간이 0인 경우 분만 나타내기
                                                        Text("\(minutes)분 학습 중")
                                                    } else {
                                                        // 시간과 분 함께 나타내기
                                                        Text("\(hours)시간 \(minutes)분 학습 중")
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                Text("\(file.numOfPages)쪽, 북마크 \(file.bookMarkedPages.count)개")
                                            }
                                            Spacer()
                                            VStack{
                                                Spacer()
                                                Text("\(file.createdDate)")
                                            }
                                            
                                            if viewStore.state.isOnDeleteMode {
                                                Button {
                                                    viewStore.send(.deleteButtonTapped(id: file.id))
                                                } label: {
                                                    Image(systemName: "trash.fill")
                                                        .foregroundColor(.red)
                                                        .frame(width: 36, height: 36)
                                                        .background(Color.white)
                                                        .clipShape(Circle())
                                                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 10)
                                                }
                                                .padding(.leading)
                                            }
                                        }
                                    }
                                )
                                .buttonStyle(.plain)
                            
                        }
                    }
                    .alert(
                        store: self.store.scope(state: \.alert, action: AppFeature.Action.alert)
                    )
                    .fileImporter(
                        isPresented: viewStore.binding(
                            get: \.isImporterOpen,
                            send: AppFeature.Action.openFileImporter
                        ),
                        allowedContentTypes: [.pdf],
                        allowsMultipleSelection: false
                    ) { result in
                        do{
                            if case .success = result {
                                do {
                                    //pdf url
                                    guard let selectedFile: URL = try result.get().first else { return }
                                    if selectedFile.startAccessingSecurityScopedResource() {
                                        //pdf 이름
                                        let fileName = selectedFile.lastPathComponent
                                        //실제 pdf파일
                                        let pdfDocument = PDFDocument(url: selectedFile)
                                        // pdf 파일 페이지 수
                                        let pageCount = pdfDocument?.pageCount ?? 0
                                        // pdf를 files에 append
                                        let newFile = File(url: selectedFile, name: fileName, numOfPages: pageCount, boorMarkedPages: [:], createdAt: .now)
                                        viewStore.send(.addPDF(newFile))
                                    }
                                } catch {
                                    print("pdf 파일 불러오기 실패: \(error)")

                                }
                            } else {
                                print("pdf 파일 불러오기 실패")
                            }
                        }
                        
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: Store(
                initialState: AppFeature.State(
                    files: [
                        .suneungteukgang,
                    ]
                ),
                reducer: AppFeature()
            )
        )
    }
}

