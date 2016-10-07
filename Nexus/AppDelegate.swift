//
//  AppDelegate.swift
//  Nexus
//
//  Created by Jade Mulholland on 18/02/2016.
//  Copyright © 2016 Nexus Social Network Pty Ptd. All rights reserved.
//

import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    var mainView = ViewController()
    var isLoadedWithShortcuts = false
    var keychain: Keychain!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        //Actions to do on first run of app
        if (UserDefaults.standard.object(forKey: "FirstRun") == nil) {
            //Setting the NSUserDefaults 'FirstRun' value
            UserDefaults.standard.setValue(false, forKey: "FirstRun")
            UserDefaults.standard.synchronize()
            
            //Setting the Keychain service and removing all on first run
            keychain = Keychain(service: "social.nexus.nexus")
            do {
                try keychain.removeAll()
            } catch let error {
                print("error: \(error)")
            }
        }
        
        
        // Register for remote notifications
        let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
        
        
        //If launched with shortcuts
        let launchedByShortcut = launchOptions?[UIApplicationLaunchOptionsKey.shortcutItem] != nil
            
        if (launchedByShortcut) {
            isLoadedWithShortcuts = true
        }
        
        //Loads saved user cookies - TC
        loadCookies()
        
        //Receive and Open Push Notifications - TC
        
        return true
    }
    
    
    // Successful registration of remote notifications.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        print(deviceTokenString)
        
        mainView.setDeviceTokenId(newToken: deviceTokenString);
    }
        
        
    /*private func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        // display the userInfo
        if let notification = userInfo["aps"] as? NSDictionary?,
            let alert = notification["alert"] as? String {
            let alertCtrl = UIAlertController(title: "Time Entry", message: alert as String, preferredStyle: UIAlertControllerStyle.Alert)
            alertCtrl.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            // Find the presented VC...
            var presentedVC = self.window?.rootViewController
            while (presentedVC!.presentedViewController != nil)  {
                presentedVC = presentedVC!.presentedViewController
            }
            presentedVC!.presentViewController(alertCtrl, animated: true, completion: nil)
            
            // call the completion handler
            // -- pass in NoData, since no new data was fetched from the server.
            completionHandler(UIBackgroundFetchResult.noData)
        }
    }*/
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    //This is called if we fail to register for remote notifications. - TC
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
    
    

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        saveCookies()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        loadCookies()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        saveCookies()
    }

    enum ShortcutIdentifier: String {
        case search
        case newpost
        case messages
        
        init?(fullIdentifier: String) {
            guard let shortIdentifier = fullIdentifier.components(separatedBy: ".").last else {
                return nil
            }
            self.init(rawValue: shortIdentifier)
        }
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcut(shortcutItem: shortcutItem))
    }
    
    @available(iOS 9.0, *)
    private func handleShortcut(shortcutItem: UIApplicationShortcutItem) -> Bool {
        let shortcutType = shortcutItem.type
        guard let ShortcutIdentifier = ShortcutIdentifier(fullIdentifier: shortcutType) else {
            return false
        }
        return selectLinkForIdentifier(identifier: ShortcutIdentifier)
    }
    
    private func selectLinkForIdentifier(identifier: ShortcutIdentifier) -> Bool {
        guard let mainView = self.window?.rootViewController as? ViewController else {
            return false
        }
        
        switch identifier {
            case .search:
                mainView.urlPath = mainView.urlPathConst + "#/search"
                mainView.loadWebView(loadUrl: mainView.urlPath)
                return true
            
            case.newpost:
                mainView.urlPath = mainView.urlPathConst + "#/post"
                mainView.loadWebView(loadUrl: mainView.urlPath)
                return true
            
            case.messages:
                mainView.urlPath = mainView.urlPathConst + "#/mm"
                mainView.loadWebView(loadUrl: mainView.urlPath)
                return true
        }
    }
    
    //Save and load Cookies. - TC
    //Do not change from var to let, this throws a compiler error.
    
    func loadCookies() {
        
        let cookieDict : NSMutableArray? = UserDefaults.standard.value(forKey: "cookieArray") as? NSMutableArray
        
        if cookieDict != nil {
            
            for var c in cookieDict! {
                
                let cookies = UserDefaults.standard.value(forKey: c as! String) as! NSDictionary
                let cookie = HTTPCookie(properties: cookies as! [HTTPCookiePropertyKey : AnyObject] )
                
                HTTPCookieStorage.shared.setCookie(cookie!)
            }
        }
    }
    
    func saveCookies() {
        
        let cookieArray = NSMutableArray()
        let savedC = HTTPCookieStorage.shared.cookies
        
        for var c : HTTPCookie in savedC! {
            
            let cookieProps = NSMutableDictionary()
            cookieArray.add(c.name)
            cookieProps.setValue(c.name, forKey: HTTPCookiePropertyKey.name.rawValue)
            cookieProps.setValue(c.value, forKey: HTTPCookiePropertyKey.value.rawValue)
            cookieProps.setValue(c.domain, forKey: HTTPCookiePropertyKey.domain.rawValue)
            cookieProps.setValue(c.path, forKey: HTTPCookiePropertyKey.path.rawValue)
            cookieProps.setValue(c.version, forKey: HTTPCookiePropertyKey.version.rawValue)
            cookieProps.setValue(NSDate().addingTimeInterval(2629743), forKey: HTTPCookiePropertyKey.expires.rawValue)
            
            UserDefaults.standard.setValue(cookieProps, forKey: c.name)
            UserDefaults.standard.synchronize()
            
        }
        
        UserDefaults.standard.setValue(cookieArray, forKey: "cookieArray")
    }
    
}

