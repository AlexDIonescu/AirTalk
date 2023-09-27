//
//  GroupInfoViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 06.04.2023.
//

import UIKit
import Photos
import SDWebImage
import JGProgressHUD
import FirebaseDatabase

class GroupInfoViewController: UIViewController {

    
    var users : [String]
    var image = UIImageView()
    var name : String
    var photo : UIImage?
    var id : String
    var header = UIView()
    var groupName  = UILabel()
    var completition : ((String, [String])->())?
    var admin = 0
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        tableview.delegate = self
        tableview.dataSource = self
        
    
        header = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 150))
        header.backgroundColor = #colorLiteral(red: 0.8374180198, green: 0.8374378085, blue: 0.8374271393, alpha: 1)
        
        image = UIImageView(frame: CGRect(x: (header.frame.width - 100) / 2, y: 5, width: 100, height: 100))
        image.image = photo
        image.isUserInteractionEnabled = true
        image.contentMode = .scaleAspectFill
        image.layer.cornerRadius = self.image.frame.size.width / 2
        image.clipsToBounds = true
        image.layer.borderColor = UIColor.black.cgColor
        image.layer.borderWidth = 2.5
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(changeImage))
        image.addGestureRecognizer(imageTapGesture)
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        Database.database().reference().child("\(id)/admin").observeSingleEvent(of: .value) { snapshot in
            if let admin = snapshot.value as? String {
                if admin == safeEmail {
                    self.admin = 1
                    
                    let addButton = UIButton(frame: CGRect(x: 15, y: 105, width: 40, height: 40))
                    addButton.setImage(UIImage(systemName: "person.fill.badge.plus"), for: .normal)
                    addButton.imageView?.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
                    addButton.imageView?.tintColor = .white
                    addButton.backgroundColor = .systemGreen
                    addButton.layer.cornerRadius = 20
                    addButton.layer.borderColor =  UIColor.black.cgColor
                    addButton.layer.borderWidth = 1.5
                    addButton.layer.masksToBounds = true
                    addButton.addTarget(self, action: #selector(self.addUsers), for: .touchUpInside)
                    self.header.addSubview(addButton)
                }
            }
        }
        
    
        
        groupName = UILabel(frame: CGRect(x: (header.frame.width - 200) / 2, y: 110, width: 200, height: 30))
        groupName.textAlignment = .center
        groupName.text = self.name
        groupName.backgroundColor = .systemYellow
        groupName.isUserInteractionEnabled = true
        let groupNameTapGesture = UITapGestureRecognizer(target: self, action: #selector(changeGroupName))
        groupName.addGestureRecognizer(groupNameTapGesture)
        
        header.addSubview(image)
        
        header.addSubview(groupName)
        tableview.tableHeaderView =  header
        view.addSubview(tableview)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableview.frame = view.bounds
    }

    
    init(users: [String], name: String, photo: UIImage?, id: String) {
        self.users = users
        self.name = name
        self.photo = photo
        self.id = id
        
        super.init(nibName: nil, bundle: nil)
        
        DispatchQueue.main.async {
            self.tableview.reloadData()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    let tableview: UITableView = {
        let tableview = UITableView()
        tableview.register(GroupInfoTableViewCell.self, forCellReuseIdentifier: GroupInfoTableViewCell.id)
        return tableview
    }()

    @objc func changeImage() {
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
    
    @objc func addUsers() {
        let vc = AddToGroupViewController(users: self.users, id: id)
        vc.completition = { result in
            print(result.count)
            for user in result {
                self.users.append(user)

            }
            print(self.users.count)
            DispatchQueue.main.async {
                self.tableview.reloadData()
        
            }
        }
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    @objc func changeGroupName() {
        let alert = UIAlertController(title: "Change group name", message: "", preferredStyle: .alert)
        alert.addTextField()
        
        alert.textFields?[0].text = self.name
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { _ in
            guard let cleanName = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return
            }
            let progressIndicator = JGProgressHUD(style: .light)
            progressIndicator.textLabel.text = "Changing group name..."
            progressIndicator.show(in: self.view, animated: true)
            
            GroupDatabaseManager.shared.changeGroupName(id: self.id, emails: self.users, name: cleanName) { success in
                if success {
                    DispatchQueue.main.async {
                        self.groupName.text = cleanName
                        self.completition?(cleanName, self.users)
                    }
                    progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                    progressIndicator.textLabel.text = ""
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                } else {
                    progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                }
            }
        }))
        present(alert, animated: true)
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
    
}

extension GroupInfoViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = users[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: GroupInfoTableViewCell.id, for: indexPath) as! GroupInfoTableViewCell
        cell.configure(model: model)
        
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return .none
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        if self.users[indexPath.row] == safeEmail {
            return .none

        }
        
        if self.admin == 1 {
            return.delete
        }
        return .none
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        
        if editingStyle == .delete {
            tableView.beginUpdates()
            let email = users[indexPath.row]
            
            let progressIndicator = JGProgressHUD(style: .light)
            progressIndicator.textLabel.text = "Deleting user..."
            progressIndicator.show(in: self.view, animated: true)
            GroupDatabaseManager.shared.removeUser(email: email, currentUsers: self.users, id: self.id) { success in
                if success {
                    
                    self.users.remove(at: indexPath.row)
                    self.tableview.deleteRows(at: [indexPath], with: .automatic)
                    progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                    progressIndicator.textLabel.text = ""
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                    self.completition?("", self.users)
                    
                } else {
                    progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                }
            }
            Database.database().reference().child("\(email)/deleted").setValue(true)
            
            tableView.endUpdates()
        }
    }
    
}

extension GroupInfoViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        
        guard let data = image.pngData(), let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let filename = "\(self.id)_profile_photo.png"
        StorageManager.shared.uploadProfilePhoto(data: data, filename: filename) {  result in
            switch result {
            case .success(let downloadUrl):
                UserDefaults.standard.set(downloadUrl, forKey: "profilePhotoUrl")
                guard let url = URL(string: downloadUrl) else {
                    return
                }
                self.image.sd_imageIndicator = SDWebImageActivityIndicator.gray
                self.image.sd_setImage(with: url)
                print(downloadUrl)
            case .failure(let error):
                print("error : \(error)")
            }
        }
        
    }
}
