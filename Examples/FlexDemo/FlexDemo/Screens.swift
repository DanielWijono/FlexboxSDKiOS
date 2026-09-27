//
//  Screens.swift
//  FlexDemo
//

import UIKit
import FlexboxKit

final class ListViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "FlexDemo"
        tableView.register(FlexTableViewCell.self, forCellReuseIdentifier: "row")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Form", primaryAction: UIAction { [unowned self] _ in
                navigationController?.pushViewController(FormViewController(), animated: true)
            }
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        DemoContent.articles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath) as! FlexTableViewCell
        cell.host.update(to: Layouts.row(DemoContent.articles[indexPath.row], index: indexPath.row))
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detail = DetailViewController(article: DemoContent.articles[indexPath.row])
        navigationController?.pushViewController(detail, animated: true)
    }
}

final class DetailViewController: UIViewController {
    private let article: Article

    init(article: Article) {
        self.article = article
        super.init(nibName: nil, bundle: nil)
        title = article.title
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let host = FlexHostView(tree: Layouts.detail(article))
        host.backgroundColor = .systemBackground
        host.safeAreaMode = .padRoot(.all)
        view = host
    }
}
