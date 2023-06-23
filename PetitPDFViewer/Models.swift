//
//  PdfFile.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/15.
//

import Foundation
import Dependencies

struct BookmarkData: Codable, Equatable {
    let id: String
    let page: Int
    let pdfId: String
    let userId: String
    let isVisible: Bool
    let createdAt: String
}

public struct File: Equatable, Identifiable {
    public let id: UUID
    //pdf URL
    public var url: URL
    //문제집 이름
    public var name: String
    //학습시간
    public var learningTime: Int
    //총 페이지 수
    public var numOfPages: Int
    //북마크된 페이지 넘버들
    public var bookMarkedPages: [Int:String]
    //날짜정보
    public var createdAt: Date
    public var createdDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "yyyy.MM.dd"
        return dateFormatter.string(from: createdAt)
    }
    

    
    public init(
        //UUID 자동생성을 위해 nil
        id: UUID? = nil,
        url: URL,
        name: String,
        learningTime: Int = 0,
        numOfPages: Int,
        boorMarkedPages: [Int:String],
        createdAt: Date
    ) {
        @Dependency(\.uuid) var uuid
        self.id = id ?? UUID()
        self.url = url
        self.name = name
        self.learningTime = learningTime
        self.numOfPages = numOfPages
        self.bookMarkedPages = boorMarkedPages
        self.createdAt = createdAt
    }
}

extension File {
    static let suneungteukgang = Self(url: URL(string: "http://suteuk")!, name: "수능특강", numOfPages: 10, boorMarkedPages: [:], createdAt: Date.now)
}
