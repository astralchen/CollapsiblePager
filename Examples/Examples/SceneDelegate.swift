import CollapsiblePager
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let demoDataSource = DemoPagerDataSource()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let pagerViewController = DemoPagerFactory.makePager(dataSource: demoDataSource)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = pagerViewController
        window.makeKeyAndVisible()
        self.window = window

        pagerViewController.reloadData()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
