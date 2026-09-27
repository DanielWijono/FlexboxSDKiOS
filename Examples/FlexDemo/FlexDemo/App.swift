//
//  App.swift
//  FlexDemo
//
//  Manual test bed for the Artefak 3 "done when" check: a list of self-sizing
//  flex cells that pushes a scrolling flex detail screen. Push/pop it repeatedly
//  under Instruments to look for abandoned memory.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: ListViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
