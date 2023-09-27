//
//  SettingsViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 09.02.2023.
//

import UIKit
import FirebaseAuth
import SDWebImage
import FirebaseDatabase
import JGProgressHUD
import FirebaseStorage
import Photos

class SettingsViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
            setupProfileImage()

        
        setupData()
        profileImage.isUserInteractionEnabled = true
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(addImage))
        profileImage.addGestureRecognizer(imageTapGesture)
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        profileImage.contentMode = .scaleAspectFill
        profileImage.layer.cornerRadius = self.profileImage.frame.size.width / 2
        profileImage.clipsToBounds = true
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
    
    func setupData() {
        guard let username = UserDefaults.standard.value(forKey: "username") as? String else {
            return
        }
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        self.usernameLabel.text = username
        self.emailLabel.text = email
    }
    func setupProfileImage() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        print(safeEmail)
        StorageManager.shared.downloadUrl(path: "profileImages/\(safeEmail)_profile_photo.png") { result in
            switch result {
            case .success(let url):
                self.profileImage.sd_imageIndicator = SDWebImageActivityIndicator.gray
                self.profileImage.sd_setImage(with: url)
            case .failure(let error):
                print(error)
            }
        }
    }
    
    
    
    let progressIndicator = JGProgressHUD(style: .dark)
    
    @IBOutlet weak var profileImage: UIImageView!
    
    @IBOutlet weak var usernameLabel: UILabel!
    
    @IBOutlet weak var emailLabel: UILabel!
    
    //user signOut - user data is removed from memory
    @IBAction func signOutButtonTap(_ sender: UIBarButtonItem) {
        
        let mainAlert = UIAlertController(title: nil, message: "Sign Out ?", preferredStyle: .alert)
        mainAlert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
            do{
                try Auth.auth().signOut()
                if let email = UserDefaults.standard.value(forKey: "email") as? String {
                    let safeEmail = DatabaseManager.safeEmail(email: email)
                    let ref = Database.database().reference().child("\(safeEmail)").child("online")
                    ref.setValue(false)
                }
                let currentUser = UserDefaults.standard
                currentUser.dictionaryRepresentation().keys.forEach(currentUser.removeObject(forKey:)) //deletes all user's data stored in memory
                UserDefaults.standard.synchronize()
                
//                currentUser.removeObject(forKey: "logged")
//                currentUser.removeObject(forKey: "profilePhotoUrl")
//                currentUser.removeObject(forKey: "username")
//                currentUser.removeObject(forKey: "email")
                self.performSegue(withIdentifier: "toLaunch", sender: self)
            } catch {
                let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }))
        mainAlert.addAction(UIAlertAction(title: "No", style: .cancel))
        present(mainAlert, animated: true)
    }
    
    
}

extension SettingsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        
        guard let data = image.pngData(), let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let filename = "\(safeEmail)_profile_photo.png"
        StorageManager.shared.uploadProfilePhoto(data: data, filename: filename) {  result in
            switch result {
            case .success(let downloadUrl):
                UserDefaults.standard.set(downloadUrl, forKey: "profilePhotoUrl")
                guard let url = URL(string: downloadUrl) else {
                    return
                }
                self.profileImage.sd_imageIndicator = SDWebImageActivityIndicator.gray
                self.profileImage.sd_setImage(with: url)
                print(downloadUrl)
            case .failure(let error):
                print("error : \(error)")
            }
        }
        
    }
}


