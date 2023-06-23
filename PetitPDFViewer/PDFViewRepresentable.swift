//
//  PDFViewRepresentable.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/17.
//

import Foundation
import PDFKit
import SwiftUI

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @Binding var currentPageIndex: Int
    
    func makeUIView(context: UIViewRepresentableContext<PDFKitView>) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage // displayMode 설정
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: UIViewRepresentableContext<PDFKitView>) {
        uiView.autoScales = true
        uiView.displayMode = .singlePage // displayMode 업데이트
        if let page = uiView.document?.page(at: currentPageIndex) {
             uiView.go(to: page)
         } //페이지 변경
    }
    
}

//썸네일 UIImage 생성
struct PDFKitThumbnailView: View {
    let url: URL
    let pageNum: Int

    var body: some View {
        Image(uiImage: self.image ?? UIImage())
            .resizable()
            .scaledToFit()
            .frame(width: 150, height: 200)
    }

    var image: UIImage? {
        guard let document = PDFDocument(url: url),
              let firstPage = document.page(at: pageNum) else {
            return nil
        }

        return firstPage.thumbnail(of: CGSize(width: 100, height: 100), for: .mediaBox)
    }
}

