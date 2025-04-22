/*
 InfinitePagingViewModifier.swift
 InfinitePaging

 Created by Takuto Nakamura on 2023/10/22.
*/

import SwiftUI

struct InfinitePagingViewModifier<T: Pageable>: ViewModifier {
    @Binding var objects: [T]
    @Binding var pageSize: CGFloat
    @State var pagingOffset: CGFloat
    @State var dismissDirectionOffset: CGFloat
    @State var draggingOffset: CGFloat
    private let minimumDistance: CGFloat
    private let pageAlignment: PageAlignment
    private let pagingHandler: (PageDirection) -> Void
    private let closingHandler: (() -> Void)?

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: minimumDistance)
            .onChanged { value in
                draggingOffset = pageAlignment.scalar(value.translation)
            }
            .onEnded { value in
                let oldIndex = Int(floor(0.5 - (pagingOffset / pageSize)))
                pagingOffset += pageAlignment.scalar(value.translation)
                draggingOffset = 0
                let predicatedOffset = pageAlignment.scalar(value.predictedEndTranslation)
                let newIndex = Int(max(0, min(2, round(1 - predicatedOffset / pageSize))))
                if #available(iOS 18.0, *) {
                    // ページングの方向より、ページングと垂直の方向(=閉じる操作の方向)の方が大きければページを閉じる
                    // 18.0以降で.sheetによりInfinitePagingViewを開いた場合にスワイプダウンによる動作が不安定になり、18.4以降でほぼ効かなくなっているためこの処理を追加
                    dismissDirectionOffset += pageAlignment.dismissScalar(value.translation)
                    if abs(predicatedOffset) < abs(dismissDirectionOffset), dismissDirectionOffset > 0 {
                        closingHandler?()
                        return
                    }
                }
                withAnimation(.smooth(duration: 0.1)) {
                    pagingOffset = -pageSize * CGFloat(newIndex)
                } completion: {
                    if newIndex == oldIndex { return }
                    if newIndex == 0 {
                        pagingHandler(.backward)
                    }
                    if newIndex == 2 {
                        pagingHandler(.forward)
                    }
                }
            }
    }

    init(
        objects: Binding<[T]>,
        pageSize: Binding<CGFloat>,
        minimumDistance: CGFloat,
        pageAlignment: PageAlignment,
        pagingHandler: @escaping (PageDirection) -> Void,
        closingHandler: (() -> Void)?
    ) {
        _objects = objects
        _pageSize = pageSize
        _pagingOffset = State(initialValue: -pageSize.wrappedValue)
        _draggingOffset = State(initialValue: 0)
        _dismissDirectionOffset = State(initialValue: -pageSize.wrappedValue)
        self.minimumDistance = minimumDistance
        self.pageAlignment = pageAlignment
        self.pagingHandler = pagingHandler
        self.closingHandler = closingHandler
    }

    func body(content: Content) -> some View {
        content
            .offset(pageAlignment.offset(pagingOffset + draggingOffset))
            .simultaneousGesture(dragGesture)
            .onChange(of: objects) { _, _ in
                pagingOffset = -pageSize
            }
            .onChange(of: pageSize) { _, _ in
                pagingOffset = -pageSize
            }
    }
}
