//
//  APIClient.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/15.
//

import Foundation
import ComposableArchitecture
import Combine

struct ApiClient {
    var fetchBookmarks: (_ pdfId: String) -> AnyPublisher<[BookmarkData], Failure>
    var addBookmark: (_ pdfId: String, _ page: Int) -> AnyPublisher<[String:String], Failure>
    var removeBookmark: (_ bookmarkId: String) -> AnyPublisher<EquatableVoid, Failure>
    
    struct Failure: Error, Equatable {
        let message: String
        
        init(message: String) {
            self.message = message
        }
    }
}

enum EquatableVoid: Error {
    case void
}


//의존성
private enum ApiClientKey: DependencyKey {
    static let liveValue = ApiClient.live
    
}

extension DependencyValues {
    var apiClient: ApiClient {
        get { self[ApiClientKey.self] }
        set { self[ApiClientKey.self] = newValue }
    }
}

extension ApiClient {
    static let live = Self(
        fetchBookmarks: { pdfId in
            let url = URL(string: "https://asia-northeast3-dev-giyoung.cloudfunctions.net/petitPDFViewer-getBookmarks?userId=no3yd1f0pd&pdfId=\(pdfId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            return URLSession.shared
            //비동기 처리
                .dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: [BookmarkData].self, decoder: JSONDecoder())
                .mapError { error -> Failure in
                    // 에러처리
                    return Failure(message: error.localizedDescription)
                }
                .eraseToAnyPublisher()
        },
        addBookmark: { pdfId, page in
            let url = URL(string: "https://asia-northeast3-dev-giyoung.cloudfunctions.net/petitPDFViewer-createBookmark")!
            let body: [String : Any] = ["userId": "no3yd1f0pd", "pdfId": pdfId, "page": page]
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            return URLSession.shared
                .dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: [String:String].self, decoder: JSONDecoder())
                .mapError { error -> Failure in
                    return Failure(message: error.localizedDescription)
                }
                .eraseToAnyPublisher()
        },
        removeBookmark: { bookmarkId in
            let url = URL(string: "https://asia-northeast3-dev-giyoung.cloudfunctions.net/petitPDFViewer-deleteBookmark")!
            let body = ["bookmarkId": bookmarkId]
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            return URLSession.shared
                .dataTaskPublisher(for: request)
                .tryMap { data, response -> EquatableVoid in
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                    return EquatableVoid.void
                }
                .mapError { error -> Failure in
                    // Handle any specific error here if needed
                    return Failure(message: error.localizedDescription)
                }
                .eraseToAnyPublisher()
        }
    )
}
