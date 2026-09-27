//
//  CellSelfSizingTests.swift
//  FlexboxKitTests
//
//  `FlexTableViewCell` / `FlexCollectionViewCell` inside a real table and
//  collection view drive the cell's height from their flex content
//  (spec Artefak 3 §"Self-sizing sel"). Rows follow their text length, match the
//  host's own measure-only answer, and re-size when a reused cell is updated.
//
//  iOS Simulator only.
//

#if canImport(UIKit)
import XCTest
import UIKit
import FlexboxCore
@testable import FlexboxKit

@MainActor
final class CellSelfSizingTests: XCTestCase {

    // MARK: Fixtures

    static let short = "Short."
    static let long = String(repeating: "A long line of text that wraps onto many rows. ", count: 8)

    static func card(_ text: String) -> LayoutTree {
        LayoutTree(
            id: "card", content: .container,
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(12))),
            children: [
                LayoutTree(id: "title", content: .text, props: ["text": .string(text)]),
            ]
        )
    }

    /// The height the host itself reports for `text` at `width`.
    static func expectedHeight(_ text: String, width: CGFloat) -> CGFloat {
        FlexHostView(tree: card(text))
            .sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    private func makeWindow(_ root: UIView) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 2000))
        window.addSubview(root)
        window.makeKeyAndVisible()
        addTeardownBlock { @MainActor in window.isHidden = true }
        return window
    }

    // MARK: UITableView

    final class TableSource: NSObject, UITableViewDataSource {
        var texts: [String]
        init(_ texts: [String]) { self.texts = texts }
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { texts.count }
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "c", for: indexPath) as! FlexTableViewCell
            cell.host.update(to: CellSelfSizingTests.card(texts[indexPath.row]))
            return cell
        }
    }

    private func makeTable(_ source: TableSource) -> UITableView {
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 2000), style: .plain)
        table.separatorStyle = .none
        table.register(FlexTableViewCell.self, forCellReuseIdentifier: "c")
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 44
        table.dataSource = source
        _ = makeWindow(table)
        table.reloadData()
        table.layoutIfNeeded()
        return table
    }

    func testTableRowsSizeToTheirFlexContent() {
        let source = TableSource([Self.short, Self.long])
        let table = makeTable(source)

        let shortRow = table.rectForRow(at: IndexPath(row: 0, section: 0)).height
        let longRow = table.rectForRow(at: IndexPath(row: 1, section: 0)).height

        XCTAssertGreaterThan(longRow, shortRow * 2, "wrapped text makes a taller row")
        XCTAssertEqual(shortRow, Self.expectedHeight(Self.short, width: 320), accuracy: 1)
        XCTAssertEqual(longRow, Self.expectedHeight(Self.long, width: 320), accuracy: 1)
    }

    func testTableRowResizesWhenReusedCellIsUpdated() {
        let source = TableSource([Self.short])
        let table = makeTable(source)
        let before = table.rectForRow(at: IndexPath(row: 0, section: 0)).height

        source.texts = [Self.long]
        table.reloadData()
        table.layoutIfNeeded()
        let after = table.rectForRow(at: IndexPath(row: 0, section: 0)).height

        XCTAssertGreaterThan(after, before)
        XCTAssertEqual(after, Self.expectedHeight(Self.long, width: 320), accuracy: 1)
    }

    // MARK: UICollectionView

    final class CollectionSource: NSObject, UICollectionViewDataSource {
        let texts: [String]
        init(_ texts: [String]) { self.texts = texts }
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { texts.count }
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath) as! FlexCollectionViewCell
            cell.host.update(to: CellSelfSizingTests.card(texts[indexPath.item]))
            return cell
        }
    }

    func testCollectionItemsSizeToTheirFlexContent() {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = CGSize(width: 320, height: 44)   // layout owns the width
        layout.minimumLineSpacing = 0
        let collection = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 2000),
                                          collectionViewLayout: layout)
        collection.register(FlexCollectionViewCell.self, forCellWithReuseIdentifier: "c")
        let source = CollectionSource([Self.short, Self.long])
        collection.dataSource = source
        _ = makeWindow(collection)
        collection.reloadData()
        collection.layoutIfNeeded()

        let shortItem = collection.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))!.size
        let longItem = collection.layoutAttributesForItem(at: IndexPath(item: 1, section: 0))!.size

        XCTAssertEqual(shortItem.width, 320, accuracy: 1)
        XCTAssertGreaterThan(longItem.height, shortItem.height * 2)
        XCTAssertEqual(shortItem.height, Self.expectedHeight(Self.short, width: 320), accuracy: 1)
        XCTAssertEqual(longItem.height, Self.expectedHeight(Self.long, width: 320), accuracy: 1)
    }
}
#endif
