//
//  AppDelegate.swift
//  AirTalk
//
//  Created by Alex Ionescu on 09.02.2023.
//

import UIKit
import FirebaseCore
import FirebaseStorage
import FirebaseDatabase
import AVFAudio
@main
class AppDelegate: UIResponder, UIApplicationDelegate {


   
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        FirebaseApp.configure()
        //Database.database().isPersistenceEnabled = true
        
        if let email = UserDefaults.standard.value(forKey: "email") as? String {
            let safeEmail = DatabaseManager.safeEmail(email: email)
            print(safeEmail)
            let ref = Database.database().reference().child("\(safeEmail)").child("online")
            ref.setValue(true)
            
            ref.onDisconnectSetValue(false)
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch(let error) {
            print(error.localizedDescription)
        }
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

