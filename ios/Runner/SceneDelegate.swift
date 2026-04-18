import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    private let nativeAsrPlugin = NativeAsrPlugin()

    override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        if let windowScene = scene as? UIWindowScene,
           let controller = windowScene.windows.first?.rootViewController as? FlutterViewController {
            nativeAsrPlugin.register(with: controller.engine.binaryMessenger)
        }
    }
}
