//
//  NewMessageViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 12.02.2023.
//

import UIKit
import JGProgressHUD
import Foundation

class NewMessageViewController: UIViewController {
    
    var completition : ((UserSearchResult) -> Void)?
    let progressIndicator = JGProgressHUD(style: .dark)
    var users = [[String : String]]()
    var results = [UserSearchResult]()
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for users"
        return searchBar
    }()
    
    let tableview: UITableView = {
        let tableview = UITableView()
        tableview.isHidden = true
        tableview.register(NewChatTableViewCell.self, forCellReuseIdentifier: NewChatTableViewCell.id)
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
        view.addSubview(noResultsLabel)
        tableview.delegate = self
        tableview.dataSource = self
        searchBar.delegate = self
        view.backgroundColor = .systemBackground
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSearchBar))
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
    
}

extension NewMessageViewController: UISearchBarDelegate {
    
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

extension NewMessageViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: NewChatTableViewCell.id, for: indexPath) as! NewChatTableViewCell
        cell.configure(model: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableview.deselectRow(at: indexPath, animated: true)
        let userData = results[indexPath.row]
        dismiss(animated: true) {
            self.completition?(userData)
        }
        
        
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
}

struct UserSearchResult {
    let email : String
    let username : String
}
