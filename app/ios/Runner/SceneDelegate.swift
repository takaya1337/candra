import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // A tap on the Dynamic Island, or on its banner, opens the app with
  // the practice's address: the app is told, and shows the practice.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if connectionOptions.urlContexts.contains(where: { $0.url == CandraShared.practiceURL }) {
      AppDelegate.launchedByIsland = true
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if URLContexts.contains(where: { $0.url == CandraShared.practiceURL }) {
      AppDelegate.islandTapped()
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
