//
//  AddToGroupViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 23.04.2023.
//

import UIKit
import JGProgressHUD

class AddToGroupViewController: UIViewController {
    
    var completition : (([String]) -> Void)?
    let progressIndicator = JGProgressHUD(style: .dark)
    var users = [[String : String]]()
    var results = [UserSearchResult]()
    var userData = [String]()
    var selectedCells = [Int]()
    var id = ""
    var usersInGroup = [String]()
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
        
        
        view.backgroundColor = .systemBackground
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSearchBar))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(addUser))
        searchBar.becomeFirstResponder()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableview.frame = view.bounds
        noResultsLabel.frame = CGRect(x: (view.frame.width)/4, y: (view.frame.width - 200)/2, width:  view.frame.width/2, height: 200)
    }
    
    
    init(users: [String], id: String) {
        self.usersInGroup = users
        self.id = id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func dismissSearchBar() {
        dismiss(animated: true)
    }
    
    
    
    
    @objc func addUser() {
        
        GroupDatabaseManager.shared.addUsers(emails: userData, currentUsers: usersInGroup, id: self.id) { success in
            if success {
               
                self.dismiss(animated: true) {
                    
                    self.completition?(self.userData)
                }
            } else {
                let progressIndicator = JGProgressHUD(style: .light)
                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                progressIndicator.show(in: self.view)
                progressIndicator.dismiss(afterDelay: 2, animated: true)
            }
        }
        
        
    }
    
    
    
}

extension AddToGroupViewController: UISearchBarDelegate {
    
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
            if user["email"]!.contains(text.lowercased()) && !usersInGroup.contains(user["email"]!) || user["username"]!.lowercased().contains(text.lowercased()) && !usersInGroup.contains(user["email"]!) {
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

extension AddToGroupViewController: UITableViewDelegate, UITableViewDataSource {
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
                let range = data.range(of: "-")
                var email = data.replacingOccurrences(of: "-", with: "@", range: range)
                email = email.replacingOccurrences(of: "-", with: ".")
                if email == currentUser.emailLabel.text {
                    break
                }
                index += 1
            }
            self.userData.remove(at: index)
            
        } else {
            self.selectedCells.append(indexPath.row)
            userData.append(results[indexPath.row].email)
            print("results: \(userData)")
        }
        
        tableView.reloadData()
        
    }
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    
}




