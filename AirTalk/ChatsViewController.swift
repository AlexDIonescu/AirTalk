//
//  MessagesViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 09.02.2023.
//

import UIKit
import JGProgressHUD
import FirebaseDatabase
import FirebaseStorage
import Network

// MARK: conversations model for user nodes
struct Conversation {
    let id: String       // refference to conversation id
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
    let groupPhoto : String
}

// MARK: latest message model
struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
class ChatsViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let simpleChat = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(composeMessage))
        let groupChat = UIBarButtonItem(image: UIImage(systemName: "person.3"), style: .done, target: self, action: #selector(composeGroupMessage))

        navigationItem.rightBarButtonItems = [simpleChat, groupChat]
        
        view.addSubview(tableview)
        view.addSubview(noMessages)
        tableview.delegate = self
        tableview.dataSource = self
        conversationsListener()
        
        
        networkChanges()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let email = UserDefaults.standard.value(forKey: "email") as? String {
            let safeEmail = DatabaseManager.safeEmail(email: email)
            let ref = Database.database().reference().child("\(safeEmail)").child("online")
            ref.setValue(true)
            ref.onDisconnectSetValue(false)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableview.frame = view.bounds
        noMessages.frame = CGRect(x: (view.frame.width)/4, y: (view.frame.width - 100)/2, width:  view.frame.width/2, height: 200)
    }
    
    func networkChanges() {
        let networkMonitor = NWPathMonitor()
        networkMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("network connection!")
            } else {
                let alert = UIAlertController(title: "No internet connection!", message: "You cannot send or receive messages!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                DispatchQueue.main.async {
                    self.present(alert, animated: true)
                    
                }
                
                
            }
        }
        let queue = DispatchQueue(label: "network")
        networkMonitor.start(queue: queue)
    }
    
    let progressIndicator = JGProgressHUD(style: .dark)
    
    var conversations = [Conversation]()
    let tableview : UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ChatTableViewCell.self, forCellReuseIdentifier: ChatTableViewCell.id)
        return table
    }()
    
    let noMessages : UILabel = {
        let noResultsLabel = UILabel()
        noResultsLabel.isHidden = true
        noResultsLabel.text = "No conversations..."
        noResultsLabel.textAlignment = .center
        noResultsLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        noResultsLabel.textColor = .gray
        return noResultsLabel
    }()
    
    // MARK: listens for new conversations or updates in existing ones
    func conversationsListener() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        print("listening for conversations")
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        // MARK: get all chats based on an email
        DatabaseManager.shared.getAllChats(email: safeEmail) { result in
            switch result {
                
            case .success(let conversations):
                guard !conversations.isEmpty else {
                    self.tableview.isHidden = true
                    self.noMessages.isHidden = false
                    return
                }
                self.noMessages.isHidden = true
                self.tableview.isHidden = false
                let finalConversation = conversations.sorted { conv1, conv2 in
                    
                    return conv1.latestMessage.date > conv2.latestMessage.date // sort conversations by date( returning latest conversations first)
                }
                self.conversations = finalConversation
                
                DispatchQueue.main.async {
                    self.tableview.reloadData()
                }
            case .failure(let error):
                self.tableview.isHidden = true
                self.noMessages.isHidden = false
                print("Error: \(error)")
                
            }
        }
    }
    @objc func composeGroupMessage() {
        let vc = NewGroupChatViewController()
        vc.completition = { result, name, photo in
            print("\(result)")
            
            //create new conversation
            self.createNewGroupChat(result: result, name: name, photo: photo)
            
        }
        
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    @objc func composeMessage() {
        let vc = NewMessageViewController()
        vc.completition = { result in
            print("\(result)")
            
            let currentConversations = self.conversations
            
            // if user already has a conversation with searched user, the existing conversation will be presented
            if let conversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager.safeEmail(email: result.email)
                
            }) {
                
                let vc = DetailedMessageViewController(email: conversation.otherUserEmail, id: conversation.id, username: conversation.name, isNew: false)
                vc.title = conversation.name
                self.navigationController?.pushViewController(vc, animated: true)
            } else {
                //create new conversation
                self.createNewChat(result: result)
            }
        }
        
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    func createNewChat(result: UserSearchResult) {
        let username = result.username
        let email = result.email
        
        DatabaseManager.shared.conversationAlreadyExists(otherUserEmail: email) { result in
            switch result {
            case .success(let id):
                
                let vc = DetailedMessageViewController(email: email, id: id, username: username, isNew: false)
                vc.title = username
                self.navigationController?.pushViewController(vc, animated: true)
                
            case .failure(_):
                let vc = DetailedMessageViewController(email: email, id: nil, username: username, isNew: true)
                vc.title = username
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
        
    }
    func createNewGroupChat(result: [UserSearchResult], name: String, photo: Data?) {
        
        var emails = [String]()
        for user in result {
            emails.append(user.email)
        }
        print("emails:: \(emails)")
        guard let data = photo else {
            return
        }
        let image = UIImage(data: data)
        
        let vc = DetailedGroupMessageViewController(email: emails, id: nil, name: name, isNew: true, firstGroupImage: photo, rightBarImage: image)
        vc.title = name
        self.navigationController?.pushViewController(vc, animated: true)
        
        
    }
    
    
    func openChat(model: Conversation, index: IndexPath) {
        print("model_email: \(model.otherUserEmail)")
        print(model)
        if model.id.contains("_group_") {
            print("opening group chat...")
            let emails = model.otherUserEmail.components(separatedBy: ",")
            print("emails:: \(emails)")
            let cell = tableview.cellForRow(at: index) as! ChatTableViewCell
            let image = cell.userImageView.image
            let vc = DetailedGroupMessageViewController(email: emails, id: model.id, name: model.name, isNew: false, firstGroupImage: nil, rightBarImage: image)
            vc.title = model.name
            let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
            
            
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
            
        } else {
            let vc = DetailedMessageViewController(email: model.otherUserEmail, id: model.id, username: model.name, isNew: false)
            vc.title = model.name
            
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}

extension ChatsViewController : UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableview.dequeueReusableCell(withIdentifier: ChatTableViewCell.id, for: indexPath) as! ChatTableViewCell
        cell.accessoryType = .disclosureIndicator
        cell.configure(model: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableview.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openChat(model: model, index: indexPath)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            
            let id = conversations[indexPath.row].id
            let otherUser = conversations[indexPath.row].otherUserEmail
            
        
                DatabaseManager.shared.deleteConversation(otherUser: otherUser, id: id) { success in
                    if success {
                        print("conversation deleted succesfully!")
                        
                    }
                }
                
                tableView.endUpdates()
        }
    }
}
