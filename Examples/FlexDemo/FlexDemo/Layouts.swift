//
//  Layouts.swift
//  FlexDemo
//
//  The demo's layouts, as values. No `font` props: the built-in text factory
//  only scales the default preferred font with Dynamic Type.
//

import FlexboxCore

struct Article {
    let title: String
    let summary: String
    let body: [String]
}

enum DemoContent {
    static let sentence = "Layout is data: a value tree that is diffed, serialized and tested without views. "

    static let articles: [Article] = (1...40).map { i in
        Article(
            title: "Article \(i)",
            summary: String(repeating: sentence, count: 1 + i % 4),
            body: (1...12).map { p in String(repeating: sentence, count: 1 + (i + p) % 5) }
        )
    }
}

enum Layouts {

    /// A list row: title over a wrapping summary, with a badge to the right.
    static func row(_ article: Article, index: Int) -> LayoutTree {
        LayoutTree(
            id: "row", content: .container,
            style: FlexStyle(flexDirection: .row, alignItems: .flexStart,
                             padding: Edges(.points(12)), gap: .points(12)),
            children: [
                LayoutTree(
                    id: "badge", content: .image,
                    style: FlexStyle(width: .points(32), height: .points(32)),
                    props: ["systemImage": .string("doc.text"), "tintColor": .string("#3478F6")]
                ),
                LayoutTree(
                    id: "texts", content: .container,
                    style: FlexStyle(flexDirection: .column, flexGrow: 1, flexShrink: 1, gap: .points(4)),
                    children: [
                        LayoutTree(id: "title", content: .text, props: ["text": .string(article.title)]),
                        LayoutTree(id: "summary", content: .text,
                                   props: ["text": .string(article.summary), "textColor": .string("#6B6B6B")]),
                    ]
                ),
            ]
        )
    }

    /// The detail screen: a scrolling column of a header and paragraphs.
    static func detail(_ article: Article) -> LayoutTree {
        let paragraphs = article.body.enumerated().map { i, text in
            LayoutTree(id: "p\(i)", content: .text, props: ["text": .string(text)])
        }
        return LayoutTree(
            id: "detail", content: .container,
            style: FlexStyle(flexDirection: .column, overflow: .scroll),
            children: [
                LayoutTree(
                    id: "content", content: .container,
                    style: FlexStyle(flexDirection: .column, padding: Edges(.points(20)), gap: .points(16)),
                    children: [
                        LayoutTree(
                            id: "hero", content: .image,
                            style: FlexStyle(height: .points(160)),
                            props: ["systemImage": .string("photo"), "contentMode": .string("scaleAspectFit"),
                                    "tintColor": .string("#8E8E93")]
                        ),
                        LayoutTree(id: "title", content: .text, props: ["text": .string(article.title)]),
                    ] + paragraphs
                ),
            ]
        )
    }
}
