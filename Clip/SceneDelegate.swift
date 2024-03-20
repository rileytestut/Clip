//
//  SceneDelegate.swift
//  Clip
//
//  Created by Riley Testut on 10/30/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import ClipKit

import Roxas

class SceneDelegate: UIResponder, UIWindowSceneDelegate
{
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions)
    {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        if let context = connectionOptions.urlContexts.first
        {
            self.open(context)
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene)
    {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        guard DatabaseManager.shared.isStarted else { return }
        
        DatabaseManager.shared.refresh()
        
        guard !UIPasteboard.general.hasImages else {
            // Our duplicate detection does not work for images,
            // so don't automatically save images upon returning to foreground.
            return
        }
        
        let location = ApplicationMonitor.shared.locationManager.location
        DatabaseManager.shared.savePasteboard(location: location) { (result) in
            do
            {
                try result.get()
                print("Saved clipboard upon returning to foreground!")
            }
            catch PasteboardError.noItem, PasteboardError.duplicateItem
            {
                // Ignore
            }
            catch
            {
                print("Failed to save clipboard upon returning to app.")
            }
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene)
    {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        
        #if targetEnvironment(simulator)
        // Audio extension hack to access pasteboard doesn't work in simulator, so for testing just start background task.
        RSTBeginBackgroundTask("com.rileytestut.Clip.simulatorBackgroundTask")
        #endif
        
        DatabaseManager.shared.purge()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)
    {
        guard let context = URLContexts.first else { return }
        self.open(context)
    }
}

private extension SceneDelegate
{
    func open(_ context: UIOpenURLContext)
    {
        guard context.url.scheme?.lowercased() == "clip" && context.url.host?.lowercased() == "settings" else { return }
        
        let openURL = URL(string: UIApplication.openSettingsURLString)!
        UIApplication.shared.open(openURL, options: [:], completionHandler: nil)
    }
}

