//
//  AppDelegate.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import UserNotifications

import ClipKit
import Roxas

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        // Override point for customization after application launch.
        
        print(RoxasVersionNumber)
        
        func printError<T>(from result: Result<T, Error>, title: String)
        {
            guard let error = result.error else { return }
            print(title, error)
        }
        
        DatabaseManager.shared.prepare() { printError(from: $0, title: "Database Error:") }
        PasteboardMonitor.shared.start() { printError(from: $0, title: "PasteboardMonitor Error:") }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (success, error) in
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication)
    {
        DatabaseManager.shared.refresh()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
