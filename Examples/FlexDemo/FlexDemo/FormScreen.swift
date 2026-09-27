//
//  FormScreen.swift
//  FlexDemo
//
//  Custom content types: text fields stacked in a column, with a button pinned
//  to the bottom by a flexGrow spacer. The views are plain UIKit, registered
//  under `.custom("textField")` and `.custom("button")`.
//

import UIKit
import FlexboxCore
import FlexboxKit

final class FormViewController: UIViewController {
    /// The live text fields, keyed by node id, so `submit()` can read them.
    private var fields: [String: UITextField] = [:]

    override func loadView() {
        title = "Form"

        var registry = FlexViewRegistry.default
        registry.register(.custom("textField")) { [unowned self] tree in
            let field = UITextField()
            field.borderStyle = .roundedRect
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
            if case .string(let placeholder)? = tree.props?["placeholder"] {
                field.placeholder = placeholder
            }
            field.isSecureTextEntry = tree.props?["secure"] == .bool(true)
            self.fields[tree.id] = field
            return field
        }
        registry.register(.custom("button")) { [unowned self] tree in
            var config = UIButton.Configuration.filled()
            if case .string(let title)? = tree.props?["title"] { config.title = title }
            return UIButton(configuration: config, primaryAction: UIAction { _ in self.submit() })
        }

        let host = FlexHostView(tree: Self.form, registry: registry)
        host.backgroundColor = .systemBackground
        host.safeAreaMode = .padRoot(.all)
        view = host

        // Tapping outside a field dismisses the keyboard.
        let tap = UITapGestureRecognizer(target: host, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        host.addGestureRecognizer(tap)
    }

    static let form = LayoutTree(
        id: "form", content: .container,
        style: FlexStyle(flexDirection: .column, padding: Edges(.points(20)), gap: .points(12)),
        children: [
            field("name", "Name"),
            field("email", "Email"),
            field("password", "Password", secure: true),
            LayoutTree(id: "spacer", content: .container, style: FlexStyle(flexGrow: 1)),
            LayoutTree(
                id: "submit", content: .custom("button"),
                style: FlexStyle(height: .points(50)),
                props: ["title": .string("Sign up")]
            ),
        ]
    )

    static func field(_ id: String, _ placeholder: String, secure: Bool = false) -> LayoutTree {
        LayoutTree(
            id: id, content: .custom("textField"),
            style: FlexStyle(height: .points(44)),
            props: ["placeholder": .string(placeholder), "secure": .bool(secure)]
        )
    }

    private func submit() {
        view.endEditing(true)
        let summary = ["name", "email"]
            .map { "\($0): \(fields[$0]?.text ?? "")" }
            .joined(separator: "\n")
        let alert = UIAlertController(title: "Submitted", message: summary, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
