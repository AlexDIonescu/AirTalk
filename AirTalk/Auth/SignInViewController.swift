//
//  SignInViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 09.02.2023.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class SignInViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    let progressIndicator = JGProgressHUD(style: .dark)
    
    @IBOutlet weak var emailInput: UITextField!
    
    @IBOutlet weak var passwordInput: UITextField!
    
    @IBAction func signInButtonTap(_ sender: UIButton) {
        
        signIn()
    }
    
    
    func signIn(){
        
        if emailInput.text == "" || passwordInput.text == "" || emailInput.text == "" && passwordInput.text == "" {
            let alert = UIAlertController(title: "Error", message: "Cannot sign in with empty credentials!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } else {
            let safeEmail = emailInput.text!.trimmingCharacters(in: .whitespaces)
            let safePassword = passwordInput.text!.trimmingCharacters(in: .whitespaces)
            
            //Firebase signIn
            Auth.auth().signIn(withEmail: safeEmail, password: safePassword) { authResult, error in
                
                if error != nil {
                    
                    let alert = UIAlertController(title: nil, message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                } else {
                    self.progressIndicator.show(in: self.view)
                    
                    let currentUser = UserDefaults.standard
                    
                    //store the email and the username to device's memory; also, set true to key "logged" which means the user is logged in
                    currentUser.set(true, forKey: "logged")
                    currentUser.set(self.emailInput.text, forKey: "email")
                    guard let email = self.emailInput.text else {
                        return
                    }
                    let safeEmail = DatabaseManager.safeEmail(email: email)
                    self.emailInput.text = ""
                    self.passwordInput.text = ""
                    
                    //after the user is signed in, we retreive he's username and store it in device's memory
                    DatabaseManager.shared.getData(path: safeEmail) { result in
                        switch result {
                        case .success(let data):
                            guard let userData = data as? [String: Any],
                                  let username = userData["username"] as? String else {
                                return
                            }
                            UserDefaults.standard.set("\(username)", forKey: "username")
                            
                        case .failure(let error):
                            print("Error \(error)")
                        }
                    }
                    //store user's profile photo url to device's memory
                    StorageManager.shared.downloadUrl(path: "profileImages/\(safeEmail)_profile_photo.png") { result in
                        switch result {
                        case .success(let url):
                            UserDefaults.standard.set(url.absoluteString, forKey: "profilePhotoUrl")
                            print(url.absoluteString)
                        case .failure(let error):
                            print(error)
                        }
                    }
                    
                    
                    print("Email: \(safeEmail)")
                    self.progressIndicator.dismiss(animated: true)
                    let nav = self.storyboard?.instantiateViewController(withIdentifier: "mainNav") as! UITabBarController
                    self.present(nav, animated: false, completion: nil)
                    
                }
            }
        }
    }
}
