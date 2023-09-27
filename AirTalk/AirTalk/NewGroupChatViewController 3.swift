//
//  NewGroupChatViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 21.03.2023.
//

import UIKit
import JGProgressHUD
import Photos

class NewGroupChatViewController: UIViewController {

    var completition : (([UserSearchResult], String, Data?) -> Void)?
    let progressIndicator = JGProgressHUD(style: .dark)
    var users = [[String : String]]()
    var results = [UserSearchResult]()
    var userData = [UserSearchResult]()
    var selectedCells = [Int]()
    var chatName = ""
    var chatPhoto = UIImage(systemName: "person.3")?.pngData()
    var image = UIImageView()
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for users"
        return searchBar
    }()
    
    let tableview: UITableView = {
        let tableview = UITableView()
        tableview.isHidden = true
        tableview.register(NewGroupChatTableViewCell.self, forCellReuseIdentifier: NewGroupChatTableViewCell.id)
        return tableview
    }()
    
    let noResultsLabel : UILabel = {
        let noResultsLabel = UILabel()
        noResultsLabel.isHidden = true
        noResultsLabel.text = "No results..."
        noResultsLabel.textAlignment = .center
        noResultsLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        noResultsLabel.textColor = .gray
        return noResultsLabel
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableview)
        tableview.delegate = self
        tableview.dataSource = self
        searchBar.delegate = self
        
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 150))
        header.backgroundColor = .systemYellow
        
        image = UIImageView(frame: CGRect(x: (header.frame.width - 100) / 2, y: 5, width: 100, height: 100))
        image.image = UIImage(systemName: "person.3")
        image.isUserInteractionEnabled = true
        image.contentMode = .scaleAspectFill
        image.layer.cornerRadius = self.image.frame.size.width / 2
        image.clipsToBounds = true
        image.layer.borderColor = UIColor.black.cgColor
        image.layer.borderWidth = 2.5
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(addImage))
        image.addGestureRecognizer(imageTapGesture)
        
        let textInput = UITextField(frame: CGRect(x: (header.frame.width - 200) / 2, y: 110, width: 200, height: 30))
        textInput.placeholder = "Enter group name.."
        textInput.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textInput.frame.height))
        textInput.leftViewMode = .always
        textInput.layer.borderWidth = 1
        textInput.layer.borderColor = UIColor.black.cgColor
        textInput.delegate = self
        
        header.addSubview(image)
        header.addSubview(textInput)
        tableview.tableHeaderView =  header
        
        view.backgroundColor = .systemBackground
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSearchBar))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(createChat))
        searchBar.becomeFirstResponder()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableview.frame = view.bounds
        noResultsLabel.frame = CGRect(x: (view.frame.width)/4, y: (view.frame.width - 200)/2, width:  view.frame.width/2, height: 200)
    }
    
    @objc func dismissSearchBar() {
        dismiss(animated: true)
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
    
    
    @objc func createChat() {
        if self.userData.count > 1 {
            if self.chatName == "" {
                self.chatName = "Group Chat"
            }
            dismiss(animated: true) {
                self.completition?(self.userData, self.chatName, self.chatPhoto)
            }
        } else {
            let alert = UIAlertController(title: "Error", message: "You cannot create a group with only one person!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }


    
}

extension NewGroupChatViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        results.removeAll()
        self.progressIndicator.show(in: view)
        self.searchUser(string: text)
    }
    
    func searchUser(string: String) {

        DatabaseManager.shared.getUsers { result in
            switch result {
            case .success(let usersCollection):
                self.users = usersCollection
                self.filterResults(text: string)
            case .failure(let error):
                print("error: \(error)")
            }
        }
    }
    
    func filterResults(text: String) {
       
        self.progressIndicator.dismiss(animated: true)
        var results = [UserSearchResult]()
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let selfUser = DatabaseManager.safeEmail(email: email)
        for user in users {
            // user cannot message himself
            if user["email"]!.contains(text.lowercased()) && user["email"] != selfUser || user["username"]!.lowercased().contains(text.lowercased()) && user["email"] != selfUser {
                guard let email = user["email"] , let username = user["username"] else {
                    return
                }
                results.append(UserSearchResult(email: email, username: username))
            }
        }
        self.results = results
        updateTableView()
    }
    
    func updateTableView() {
        if results.isEmpty {
            self.noResultsLabel.isHidden = false
            self.tableview.isHidden = true
        } else {
            self.noResultsLabel.isHidden = true
            self.tableview.isHidden = false
            self.tableview.reloadData()
        }
    }
}

extension NewGroupChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewGroupChatTableViewCell.id, for: indexPath) as! NewGroupChatTableViewCell
        cell.configure(model: model)
        cell.accessoryType = self.selectedCells.contains(indexPath.row) ? .checkmark : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if self.selectedCells.contains(indexPath.row) {
            tableView.deselectRow(at: indexPath, animated: false)
            if let index = self.selectedCells.firstIndex(of: indexPath.row) {
                
                self.selectedCells.remove(at: index)
            }
            
            var index = 0
            let currentUser = tableView.cellForRow(at: indexPath) as! NewGroupChatTableViewCell
            
            for data in self.userData {
                let range = data.email.range(of: "-")
                var email = data.email.replacingOccurrences(of: "-", with: "@", range: range)
                email = email.replacingOccurrences(of: "-", with: ".")
                if email == currentUser.emailLabel.text {
                    break
                }
                index += 1
            }
            self.userData.remove(at: index)
            
        } else {
            self.selectedCells.append(indexPath.row)
            userData.append(results[indexPath.row])
            print("results: \(userData)")
        }
        
        tableView.reloadData()
           
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    
}

extension NewGroupChatViewController : UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            self.chatName = text
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
            self.chatName = text
        }
        textField.resignFirstResponder()
        return true
    }
}

extension NewGroupChatViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        self.chatPhoto = image.pngData()
        DispatchQueue.main.async {
            self.image.image = image
        }
        
    }
}


