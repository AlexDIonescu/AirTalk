//
//  SignUpViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 09.02.2023.
//

import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import JGProgressHUD
import Photos

class SignUpViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emailInput.delegate = self
        usernameInput.delegate = self
        passwordInput.delegate = self
        emailInput.spellCheckingType = .no
        emailInput.autocorrectionType = .no
        passwordInput.spellCheckingType = .no
        passwordInput.autocorrectionType = .no
        usernameInput.spellCheckingType = .no
        usernameInput.autocorrectionType = .no
        
        imagePicker.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(addImage))
        imagePicker.addGestureRecognizer(tapGesture)
        imagePicker.layer.cornerRadius = 66
    }
    
    let progressIndicator = JGProgressHUD(style: .dark)
    
    let storage = Storage.storage().reference()
    var profileImage = Data()
    
    @IBOutlet weak var imagePicker: UIImageView!
    
    @IBOutlet weak var usernameInput: UITextField!
    
    @IBOutlet weak var emailInput: UITextField!
    
    @IBOutlet weak var passwordInput: UITextField!
    
    @IBAction func signUpButtonTap(_ sender: UIButton) {
        signUp()
    }
    
    @objc func addImage() {
        let alert = UIAlertController(title: "Choose Image", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.openCamera()
        }))
        
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.openPhotos()
        }))
        
        alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func openCamera() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.sourceType = UIImagePickerController.SourceType.camera
                picker.allowsEditing = false
                self.present(picker, animated: true, completion: nil)
            }
        } else {
            requestMediaAccess()
        }
    }
    
    func openPhotos() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = true
                picker.sourceType = .photoLibrary
                self.present(picker, animated: true, completion: nil)
            }
        } else {
            requestMediaAccess()
        }
    }
    
    func requestMediaAccess() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized {
                    print("authorised!")
                }
            }
        } else if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .denied {
            
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized {
                    print("authorised!")
                }
            }
        } else if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .restricted {
            
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized {
                    print("authorised!")
                }
            }
        } else if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized {
                    print("authorised!")
                }
            }
        }
    }
    
    
    func signUp() {
        if emailInput.text == "" || passwordInput.text == "" || usernameInput.text == "" || imagePicker.image == UIImage(systemName: "person.fill") {
            
            let alert = UIAlertController(title: "Error", message: "Cannot sign up with empty credentials!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
        } else {
            
            let safeName = usernameInput.text!
            let safeEmail = emailInput.text!.trimmingCharacters(in: .whitespaces)
            let safePassword = passwordInput.text!.trimmingCharacters(in: .whitespaces)
            
            progressIndicator.show(in: view)
            
            Auth.auth().createUser(withEmail: safeEmail, password: safePassword) { authResult, error in
                
                if error != nil {
                    self.progressIndicator.dismiss(animated: true)
                    let alert = UIAlertController(title: nil, message: error?.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                } else {
                    
                    UserDefaults.standard.set(self.usernameInput.text, forKey: "username")
                    UserDefaults.standard.set(self.emailInput.text, forKey: "email")
                    
                    self.usernameInput.text = ""
                    self.emailInput.text = ""
                    self.passwordInput.text = ""
                    let loggedIn = UserDefaults.standard
                    loggedIn.set(true, forKey: "logged")
                    
                    //insert user based on AppUser struct
                    let appUser = AppUser(username: safeName, email: safeEmail)
                    DatabaseManager.shared.insertUser(with: appUser) { success in
                        if success {
                            guard let image = self.imagePicker.image, let data = image.pngData() else {
                                return
                            }
                            let filename = appUser.profilePhotoName
                            StorageManager.shared.uploadProfilePhoto(data: data, filename: filename) {  result in
                                switch result {
                                case .success(let downloadUrl):
                                    UserDefaults.standard.set(downloadUrl, forKey: "profilePhotoUrl")
                                    
                                    print(downloadUrl)
                                case .failure(let error):
                                    self.progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                    print("error : \(error)")
                                }
                            }
                        }
                    }
                    self.progressIndicator.dismiss(afterDelay: 1, animated: true)
                    let nav = self.storyboard?.instantiateViewController(withIdentifier: "mainNav") as! UITabBarController
                    self.present(nav, animated: false, completion: nil)
                }
            }
            
            
            
            
            
            
            
            
        }
        
        
    }
    
    
}

extension SignUpViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        guard let imgData = image.pngData() else {
            return
        }
        imagePicker.image = image
        profileImage = imgData
        
    }
}


extension SignUpViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameInput {
            emailInput.becomeFirstResponder()
        } else if textField == emailInput {
            passwordInput.becomeFirstResponder()
        } else if textField == passwordInput {
            view.endEditing(true)
            signUp()
        }
        return true
    }
}
