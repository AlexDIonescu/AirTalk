//
//  ViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 09.02.2023.
//

import UIKit

class LaunchViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // if user is not logged in, this page will be presented as default
        let currentUser = UserDefaults.standard.bool(forKey: "logged")
        if currentUser == true {
            let nav = storyboard?.instantiateViewController(withIdentifier: "mainNav") as! UITabBarController
            self.present(nav, animated: false, completion: nil)
                }
    }

    @IBAction func returnToLaunch(sender: UIStoryboardSegue){}

}

