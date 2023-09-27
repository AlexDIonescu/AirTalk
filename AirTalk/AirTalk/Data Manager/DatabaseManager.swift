//
//  DatabaseManager.swift
//  AirTalk
//
//  Created by Alex Ionescu on 12.02.2023.
//

import Foundation
import FirebaseDatabase
import MessageKit
import UIKit
import AVFoundation
import CoreLocation
import FirebaseAuth
import FirebaseStorage

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    
    //MARK: Create safe email based on user's email (Firebase does not support ".")
    static func safeEmail(email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    //MARK: Get all users
    func getUsers(completition: @escaping(Result<[[String : String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completition(.failure(DatabaseErrors.cannotGetUsers))
                return
            }
            completition(.success(value))
        }
    }
    
}

extension DatabaseManager {
    
    // MARK: Insert user into database based on AppUser struct
    func insertUser(with user : AppUser, completition: @escaping(Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "username":user.username,
            "online": false,
            "is_typing": false ]) { error, databaseReference in
                guard error == nil else {
                    completition(false)
                    return
                }
                
                self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                    
                    if var users = snapshot.value as? [[String: String]] {
                        let newUser = [
                            "username" : user.username,
                            "email" : user.safeEmail
                        ]
                        print(newUser)
                        users.append(newUser)
                        print("existing users")
                        print(users)
                        self.database.child("users").setValue(users) { error, dbRef in
                            guard error == nil else {
                                completition(false)
                                return
                            }
                            completition(true)
                        }
                        
                    } else {
                        let collection: [[String: String]] = [
                            [
                                "username" : user.username,
                                "email" : user.safeEmail
                            ]
                        ]
                        self.database.child("users").setValue(collection) { error, dbRef in
                            guard error == nil else {
                                completition(false)
                                return
                            }
                            completition(true)
                        }
                    }
                    
                }
            }
    }
}

extension DatabaseManager {
    
    // MARK: Create new chat with other user's email and using Message struct
    func createNewChat(otherUserEmail: String, name: String, firstMessage: Message, completition: @escaping(Bool) -> Void) {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String, let username = UserDefaults.standard.value(forKey: "username") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value) { snapshot in
            guard var userObject = snapshot.value as? [String: Any] else {
                completition(false)
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = DetailedMessageViewController.uniqueDateforId.string(from: messageDate)
            var videoCheck = 0
            var photoCheck = 0
            var locationCheck = 0
            var audioCheck = 0
            var message = ""
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
                print("text!")
                break
            case .attributedText(_):
                break
            case .photo(let photo):
                if let url = photo.url?.absoluteString {
                    
                    print("message: \(message)")
                    photoCheck = 1
                }
                break
            case .video(let video):
                print("\n\nVideo kind\n\n")
                if let url = video.url?.absoluteString {
                    
                    videoCheck = 1
                }
                break
            case .location(_):
                locationCheck = 1
                break
            case .emoji(_):
                break
            case .audio(_):
                
                audioCheck = 1
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationId = "conversation_\(firstMessage.messageId)"
            if locationCheck == 1 {
                message = "Location\u{1F4CD}"
            } else if videoCheck == 1 {
                message = "Video\u{1F3A5}"
            } else if photoCheck == 1 {
                message = "Photo\u{1F4F7}"
            } else if audioCheck == 1 {
                message = "Audio\u{1F3B6}"
            }
            
            let newConversation : [String: Any] = [
                "id": conversationId,
                "name" : name,
                "other_user_email": otherUserEmail ,
                "latest_message": [
                    "date" : dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let otherUserNewConversation : [String: Any] = [
                "id": conversationId,
                "name" : username,
                "other_user_email": safeEmail ,
                "latest_message": [
                    "date" : dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            //other user conversation in database
            self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    conversations.append(otherUserNewConversation)
                    self.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                    
                } else {
                    self.database.child("\(otherUserEmail)/conversations").setValue([otherUserNewConversation])
                }
            }
            
            //current user conversation in database
            if var conversations = userObject["conversations"] as? [[String: Any]] {    //append conversations(array already exists)
                
                conversations.append(newConversation)
                userObject["conversations"] = conversations
                ref.setValue(userObject) { error, ref in
                    guard error == nil else {
                        completition(false)
                        return
                    }
                    self.insertConversationNode(name: name, conversationId: conversationId, firstMessage: firstMessage, otherUser: otherUserEmail, completition: completition)
                    
                }
                
            } else {  //create conversations array
                userObject["conversations"] = [newConversation]
                
                ref.setValue(userObject) { error, ref in
                    guard error == nil else {
                        completition(false)
                        return
                    }
                    self.insertConversationNode(name: name, conversationId: conversationId, firstMessage: firstMessage, otherUser: otherUserEmail, completition: completition)
                    
                }
            }
            
            
        }
    }
    
    
    
    // MARK: Insert conversation in it's own place in database ( conversationId is it's name)
    func insertConversationNode(name : String, conversationId: String, firstMessage: Message, otherUser: String, completition: @escaping (Bool) -> Void) {
        
        var message = ""
        var audioDuration = ""
        var videoPlaceholder = ""
        switch firstMessage.kind {
            
        case .text(let messageText):
            message = messageText
            break
        case .attributedText(_):
            break
        case .photo(let photo):
            if let url = photo.url?.absoluteString {
                
                message = url
            }
            break
        case .video(let video):

            if let url = video.url?.absoluteString, let imageUrl = video.url {
                StorageManager.shared.imageFromVideo(url: imageUrl) { image in
                    if let image = image, let data = image.pngData() {
                        let date = DetailedMessageViewController.uniqueDateforId.string(from: Date())
                        let filename = "video_placeholder_\(date).png"
                        StorageManager.shared.uploadMessagePhoto(data: data, filename: filename) { result in
                            switch result {
                            case .success(let url):
                                videoPlaceholder = url
                            case .failure(let error):
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
                message = url
            }
            break
        case .location(let data):
            let location = data.location
            message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
            break
        case .emoji(_):
            break
        case .audio(let audio):
                audioDuration = "\(AVURLAsset(url: audio.url).duration.seconds.rounded())"
                message = audio.url.absoluteString
            
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        let messageDate = firstMessage.sentDate
        let dateString = DetailedMessageViewController.uniqueDateforId.string(from: messageDate)
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            completition(false)
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let collMessage : [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content" : message,
            "date" : dateString,
            "sender_email" : safeEmail,
            "is_read" : false,
            "name" : name,
            "audio_duration" : audioDuration,
            "video_placeholder" : videoPlaceholder
        ]
        let value : [String: Any] = [
            "messages" : [
                collMessage
            ]
        ]
        database.child("\(conversationId)").setValue(value) { error, ref in
            guard error == nil else {
                completition(false)
                return
            }
            completition(true)
        }
    }
    
    
    
    
    
    
    // MARK: Get all conversations based on an email parameter
    func getAllChats(email: String, completition: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value) { snapshot in
            print(email)
            print(snapshot)
            
            guard let value = snapshot.value as? [[String: Any]] else {
                completition(.failure(DatabaseErrors.failedToDownload))
                print("get all chats error")
                return
            }
            
            let conversations: [Conversation] = value.compactMap { dictionary in
                guard let conversationId = dictionary["id"] as? String, let name = dictionary["name"] as? String, let otherUserEmail = dictionary["other_user_email"] as? String, let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String, let isRead = latestMessage["is_read"] as? Bool, let message = latestMessage["message"] as? String else {
                    return nil
                }
                var groupPhoto = ""
                if let photo = dictionary["group_photo"] as? String {
                    groupPhoto = photo
                }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject, groupPhoto: groupPhoto)
            }

            completition(.success(conversations))
            
        }
    }
    
    // MARK: Get all messages from a chat based on it's id
    func getMessagesForChat(id: String, completition: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completition(.failure(DatabaseErrors.failedToDownload))
                print("get messages error")
                return
            }
            
            let messages: [Message] = value.compactMap { dictionary in
                guard let name = dictionary["name"] as? String, let _ = dictionary["is_read"] as? Bool, let messageId = dictionary["id"] as? String, let content = dictionary["content"] as? String, let senderEmail = dictionary["sender_email"] as? String, let dateString = dictionary["date"] as? String, let type = dictionary["type"] as? String  else {
                    completition(.failure(DatabaseErrors.failedToDownload))
                    return nil
                }
                guard let date = DetailedMessageViewController.uniqueDateforId.date(from: dateString) else {
                    print("date again...")
                    print(dateString)
                    print(DetailedMessageViewController.uniqueDateforId.date(from: dateString))
                    return nil
                }
                var messageType : MessageKind?
                
                if type == "photo" {
                    guard let url = URL(string: content) else {
                        return nil
                    }
                    guard let placeholderImage = UIImage(systemName: "photo") else {
                        return nil
                    }
                    
                    let media = Media(url: url, image: nil, placeholderImage: placeholderImage, size: CGSize(width: 200, height: 120))
                    messageType = .photo(media)
                    
                } else if type == "video" {
                    guard let url = URL(string: content), let image = UIImage(systemName: "network")?.withTintColor(.black, renderingMode: .alwaysTemplate) else {
                        return nil
                    }

                    let media = Media(url: url, image: nil, placeholderImage: image, size: CGSize(width: 200, height: 120))

                    messageType = .video(media)
                    

                    
                } else if type == "audio" {
                    guard let url = URL(string: content) else {
                        return nil
                    }
                    
                    guard let duration = dictionary["audio_duration"] as? String else {
                        return nil
                    }
                    let audio = Audio(url: url, duration: Float(duration) ?? 0.0, size: CGSize(width: 200, height: 50))
       
                            messageType = .audio(audio)

                    
                } else if type == "location" {
                    let coordinates = content.components(separatedBy: ",")
                    guard let longitude = Double(coordinates[0]),let latitude = Double(coordinates[1]) else {
                        return nil
                    }
                    let cllocation = CLLocation(latitude: latitude, longitude: longitude)
                    let location = Location(location: cllocation, size: CGSize(width: 200, height: 120))
                    messageType = .location(location)
                } else {
                    messageType = .text(content)
                }
                guard let finalType = messageType else {
                    return nil
                }
                
                let sender = Sender(photoUrl: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageId, sentDate: date, kind: finalType)
            }
            completition(.success(messages))
            
        }
    }
    
    // MARK: Send a message( if a conversation already exists)
    func sendMessage(conversation: String, otherUserEmail: String,  name: String, newMessage: Message, completition: @escaping(Bool) -> Void) {
        
        
        guard let email =  UserDefaults.standard.value(forKey: "email") as? String else {
            completition(false)
            return
        }
        let selfEmail = DatabaseManager.safeEmail(email: email)
        self.database.child("\(conversation)/messages").observeSingleEvent(of: .value) { snapshot in
            guard var messages = snapshot.value as? [[String: Any]] else {
                completition(false)
                return
            }
            var message = ""
            var audioDuration = ""
            var videoPlaceholder = ""
            var videoCheck = 0
            var photoCheck = 0
            var locationCheck = 0
            var audioCheck = 0

            switch newMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let photo):
                if let url = photo.url?.absoluteString {
                    
                    message = url
                    photoCheck = 1
                }
                break
            case .video(let video):
                print("\n\nVideo kind\n\n")
                if let url = video.url?.absoluteString, let imageUrl = video.url {
                    StorageManager.shared.imageFromVideo(url: imageUrl) { image in
                        if let image = image, let data = image.pngData() {
                            let date = DetailedMessageViewController.uniqueDateforId.string(from: Date())
                            let filename = "video_placeholder_\(date).png"
                            StorageManager.shared.uploadMessagePhoto(data: data, filename: filename) { result in
                                switch result {
                                case .success(let url):
                                    videoPlaceholder = url
                                case .failure(let error):
                                    print(error.localizedDescription)
                                }
                            }
                        }
                    }
                    message = url
                    videoCheck = 1
                }
                break
            case .location(let data):
                let location = data.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                locationCheck = 1
                break
            case .emoji(_):
                break
            case .audio(let audio):
                message = audio.url.absoluteString
                audioDuration = "\(AVURLAsset(url: audio.url).duration.seconds.rounded())"

                audioCheck = 1
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let messageDate = newMessage.sentDate
            let dateString = DetailedMessageViewController.uniqueDateforId.string(from: messageDate)
            guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                completition(false)
                return
            }
            let safeEmail = DatabaseManager.safeEmail(email: email)
            let newMessage : [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content" : message,
                "date" : dateString,
                "sender_email" : safeEmail,
                "is_read" : false,
                "name" : name,
                "audio_duration" : audioDuration,
                "video_placeholder" : videoPlaceholder
            ]
            messages.append(newMessage)
            print("\n\nbefore set value\n\n")
            self.database.child("\(conversation)/messages").setValue(messages) { error, ref in
                guard error == nil else {
                    completition(false)
                    
                    return
                }
                print("\n\nafter set value\n\n")
                
                // Update latest message for the user sending the message
                self.database.child("\(selfEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var dbConversations = [[String: Any]]()
                    if locationCheck == 1 {
                        message = "Location\u{1F4CD}"
                    } else if videoCheck == 1 {
                        message = "Video\u{1F3A5}"
                    } else if photoCheck == 1 {
                        message = "Photo\u{1F4F7}"
                    } else if audioCheck == 1 {
                        message = "Audio\u{1F3B6}"
                    }
                    let newLatestMessage : [String: Any]  = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    if var conversations = snapshot.value as? [[String: Any]]{
                        var index = 0
                        
                        var conversationToUpdate : [String: Any]?
                        for conv in conversations {
                            if let id = conv["id"] as? String, id == conversation {
                                conversationToUpdate = conv
                                break
                            }
                            index += 1
                        }
                        
                        if var conversationToUpdate = conversationToUpdate {
                            conversationToUpdate["latest_message"] = newLatestMessage
                            conversations[index] = conversationToUpdate
                            dbConversations = conversations
                        } else {
                            let newConversation : [String: Any] = [
                                "id": conversation,
                                "name" : name,
                                "other_user_email": DatabaseManager.safeEmail(email: otherUserEmail) ,
                                "latest_message": newLatestMessage
                            ]
                            conversations.append(newConversation)
                            dbConversations = conversations
                            
                        }
                        
                    } else {
                        let newConversation : [String: Any] = [
                            "id": conversation,
                            "name" : name,
                            "other_user_email": DatabaseManager.safeEmail(email: otherUserEmail) ,
                            "latest_message": newLatestMessage
                        ]
                        
                        dbConversations = [
                            newConversation
                        ]
                    }
                    
                    self.database.child("\(selfEmail)/conversations").setValue(dbConversations) { error, _ in
                        guard error == nil else {
                            completition(false)
                            return
                        }
                    }
                }
                
                // Update latest message for the user that receives the message
                self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var dbConversations = [[String: Any]]()
                    guard let username = UserDefaults.standard.value(forKey: "username") as? String else {
                        return
                    }
                    if locationCheck == 1 {
                        message = "Location\u{1F4CD}"
                    } else if videoCheck == 1 {
                        message = "Video\u{1F3A5}"
                    } else if photoCheck == 1 {
                        message = "Photo\u{1F4F7}"
                    } else if audioCheck == 1 {
                        message = "Audio\u{1F3B6}"
                    }
                    let newLatestMessage : [String: Any]  = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    if var conversations = snapshot.value as? [[String: Any]] {
                        var index = 0
                        
                        var conversationToUpdate : [String: Any]?
                        for conv in conversations {
                            if let id = conv["id"] as? String, id == conversation {
                                conversationToUpdate = conv
                                break
                            }
                            index += 1
                        }
                        if var conversationToUpdate = conversationToUpdate {
                            
                            conversationToUpdate["latest_message"] = newLatestMessage
                            conversations[index] = conversationToUpdate
                            dbConversations = conversations
                            
                        } else {
                            //cannot find the collection of messages
                            
                            let newConversation : [String: Any] = [
                                "id": conversation,
                                "name" : username,
                                "other_user_email": DatabaseManager.safeEmail(email: email) ,
                                "latest_message": newLatestMessage
                            ]
                            conversations.append(newConversation)
                            dbConversations = conversations
                        }
                        
                    } else {
                        //the collection of messages does not exist
                        let newConversation : [String: Any] = [
                            "id": conversation,
                            "name" : username,
                            "other_user_email": DatabaseManager.safeEmail(email: email) ,
                            "latest_message": newLatestMessage
                        ]
                        
                        dbConversations = [
                            newConversation
                        ]
                    }
                    
                    
                    self.database.child("\(otherUserEmail )/conversations").setValue(dbConversations) { error, _ in
                        guard error == nil else {
                            completition(false)
                            return
                        }
                    }
                }
                completition(true)
            }
        }
    }
    
    // MARK: Check if a conversation exists to determine whether we start a new conversation or continue an existing one
    func conversationAlreadyExists(otherUserEmail: String, completition: @escaping(Result<String, Error>)-> Void) {
        let safeOtherUserEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSelfEmail = DatabaseManager.safeEmail(email: email)
        database.child("\(safeOtherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            guard let conversations = snapshot.value as? [[String: Any]] else {
                completition(.failure(DatabaseErrors.failedToDownload))
                return
            }
            
            if let conv = conversations.first(where: {
                guard let sender = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSelfEmail == sender
            }){
                guard let id = conv["id"] as? String else {
                    completition(.failure(DatabaseErrors.failedToDownload))
                    return
                }
                completition(.success(id))
                return
            }
            completition(.failure(DatabaseErrors.failedToDownload))
            return
        }
    }
    
    // MARK: Delete an conversation( from user's node); the conversation will be permanently deleted if no user holds a refference to it's id
    func deleteConversation(otherUser: String, id: String, completition : @escaping(Bool)-> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        
        
        database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var index = 0
                for conv in conversations {
                    if let targetId = conv["id"] as? String, targetId == id {
                        break
                    }
                    index += 1
                }
                conversations.remove(at: index)
                self.database.child("\(safeEmail)/conversations").setValue(conversations) { error, ref in
                    guard error == nil else {
                        completition(false)
                        return
                    }
                    
                }
            }
        }
        
        //check if other user holds a refference to conversation's id
        if id.contains("_group_") {
            
            var users = otherUser.components(separatedBy: ",")
            if let index = users.firstIndex(of: safeEmail) {
                users.remove(at: index)
            }
            
            var newUsers = users.joined(separator: ",")
            
            if !otherUser.contains(",") {
                self.database.child("\(id)").removeValue()
            }
            
            print(users)
            print(newUsers)
            for user in users {
                let otherUserSafeEmail = DatabaseManager.safeEmail(email: user)
                database.child("\(otherUserSafeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    if var conversations = snapshot.value as? [[String: Any]] {
                        var index = 0
                        for conv in conversations {
                            if let targetId = conv["id"] as? String, targetId == id {
                                if let data = conversations[index]["other_user_email"] as? String {
                                    
                                    conversations[index]["other_user_email"] = newUsers
                                    self.database.child("\(otherUserSafeEmail)/conversations").setValue(conversations)
                                }
                                return
                            }
                            index += 1
                        }
                        
                    } else if snapshot.value == nil {
                        self.database.child("\(id)").removeValue()
                    }
                }
            }
            
            
        } else {
            let otherUserSafeEmail = DatabaseManager.safeEmail(email: otherUser)
            database.child("\(otherUserSafeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                if let conversations = snapshot.value as? [[String: Any]] {
                    for conv in conversations {
                        if let targetId = conv["id"] as? String, targetId == id {
                            return
                        }
                    }
                    self.database.child("\(id)").removeValue()
                } else if snapshot.value == nil {
                    self.database.child("\(id)").removeValue()
                }
            }
        }
        completition(true)
    }
    

    // MARK: Delete a message from a conversation and replace it's content with: "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶"
    func deleteMessage(id: String, email: String, otherUserEmail: String, index: Int, completition: @escaping(Bool)->Void) {
        var finalData = [[String: Any]]()
        print(id)
        print("index: \(index)")
        var dataCount = 0
        var messageDate = ""
        database.child("\(id)/messages").observeSingleEvent(of: .value) { snapshot in
            
            if var data = snapshot.value as? [[String: Any]] {
                let old = data[index]
                guard let id = old["id"] as? String, let date = old["date"] as? String, let email = old["sender_email"] as? String, let name = old["name"] as? String else {
                    return
                }
                messageDate = date
                let deleted : [String: Any] = [
                    "id": id,
                    "type": "text",
                    "content" : "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶",
                    "date" : date,
                    "sender_email" : email,
                    "is_read" : true,
                    "name" : name
                ]
                data[index] = deleted
                finalData = data
                
            }
            self.database.child("\(id)/messages").setValue(finalData)
            dataCount = Int(snapshot.childrenCount)
            let selfSafeEmail = DatabaseManager.safeEmail(email: email)
            let otherSafeEmail = DatabaseManager.safeEmail(email: otherUserEmail)
            if index == dataCount-1 {
                print("\n\nindex:\n\n\n")

                print(index)
                self.database.child("\(selfSafeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    if var data = snapshot.value as? [[String: Any]] {
                        print("\n\n\ndata:\n\n\n")
                        var i = 0
                        for conversation in data {
                            if let convId = conversation["id"] as? String {
                                if convId == id {
                                    break
                                }
                                i+=1
                            }
                        }
                        data[i]["latest_message"] = ["date": messageDate,
                                                         "is_read": false,
                                                         "message": "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶"
                        ]
                        self.database.child("\(selfSafeEmail)/conversations").setValue(data)
                    }
                }
                
                self.database.child("\(otherSafeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    if var data = snapshot.value as? [[String: Any]] {
                        var i = 0
                        for conversation in data {
                            if let convId = conversation["id"] as? String {
                                if convId == id {
                                    break
                                }
                                i+=1
                            }
                        }
                        data[i]["latest_message"] = ["date": messageDate,
                                                         "is_read": false,
                                                         "message": "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶"
                        ]
                        self.database.child("\(otherSafeEmail)/conversations").setValue(data)
                    }
                }
            }
        }
       
        
    }
    
    
    
    // MARK: get data from a specified path 
    func getData(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseErrors.failedToDownload))
                return
            }
            completion(.success(value))
        }
    }
    
    
    func createNewConnectFourGame(id: String, otherUserEmail: String) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let otherSafeEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        database.child("\(id)/connect_four_game").observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? [String:Any] {
                self.resetGame(id: id, otherUserEmail: otherUserEmail)
            } else {
                self.database.child("\(id)/connect_four_game").setValue([
                    "yellow" : "\(safeEmail)",
                    "red" : "\(otherSafeEmail)",
                    "playerTurn" : "\(safeEmail),yellow",
                    "turns_number": 0,
                    "\(safeEmail)_wins" : 0,
                    "\(otherSafeEmail)_wins" : 0,
                    "rematch" : 0,
                    "in_progress" : true,
                    "game_matrix" : "-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1",
                    "winner": "none"
                ])
            }
        }
        
    }
    func gameDataExists(id: String, completition: @escaping(Bool)->Void) {
        database.child("\(id)/connect_four_game").observe(.value) { snapshot in
            if let data = snapshot.value as? [String:Any] {
                completition(true)
            } else {
                completition(false)
            }
        }
    }
    
    func checkIfGameInProgress(id: String, completition: @escaping(Bool)->Void) {
        database.child("\(id)/connect_four_game/in_progress").observe(.value) { snapshot in
            if let inProgress = snapshot.value as? Bool {
                if inProgress == true {
                    completition(true)
                } else if inProgress == false {
                    completition(false)
                }
            } else {
                completition(false)
            }
        }
    }
    func checkIfGameInProgressOnce(id: String, completition: @escaping(Bool)->Void) {
        database.child("\(id)/connect_four_game/in_progress").observeSingleEvent(of: .value) { snapshot in
            if let inProgress = snapshot.value as? Bool {
                if inProgress == true {
                    completition(true)
                } else if inProgress == false {
                    completition(false)
                }
            } else {
                completition(false)
            }
        }
    }
    
    func listenForGameChanges(id: String, completition: @escaping(String)->Void) {
        database.child("\(id)/connect_four_game/game_matrix").observe(.value) { snapshot in
            if let matrix = snapshot.value as? String {
                
                completition(matrix)
            }
        }
    }
    
    func checkforPlayerTurn(id: String, completition: @escaping(String)->Void) {
        database.child("\(id)/connect_four_game/playerTurn").observe(.value) { snapshot in
            if let value = snapshot.value as? String {
                
                completition(value)
            }
        }
    }
    func changePlayerTurn(id: String, player: String) {
        database.child("\(id)/connect_four_game/playerTurn").setValue(player)
    }
    
    func resetGame(id: String, otherUserEmail: String) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let otherSafeEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        database.child("\(id)/connect_four_game/yellow").setValue(safeEmail)
        database.child("\(id)/connect_four_game/red").setValue(otherSafeEmail)
        database.child("\(id)/connect_four_game/playerTurn").setValue("\(safeEmail),yellow")
        database.child("\(id)/connect_four_game/in_progress").setValue(true)
        database.child("\(id)/connect_four_game/winner").setValue("none")
        database.child("\(id)/connect_four_game/turns_number").setValue(0)
        let matrix = "-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1"
        database.child("\(id)/connect_four_game/game_matrix").setValue(matrix)
    }
    
    func addDataToGame(id: String, matrix: String, turnsNumber: Int) {
        database.child("\(id)/connect_four_game/game_matrix").setValue(matrix)
        database.child("\(id)/connect_four_game/turns_number").setValue(turnsNumber)
    }
   
    func getTurns(id: String, completition: @escaping(Int)->Void) {
        database.child("\(id)/connect_four_game/turns_number").observe(.value) { snapshot in
            if var data = snapshot.value as? Int {
                
                completition(data)
            }
        }
    }
    
    func checkForWins(id: String, completition: @escaping(String)->Void) {
        database.child("\(id)/connect_four_game/winner").observe(.value) { snapshot in
            if let winner = snapshot.value as? String {
                
                completition(winner)
            }
        }
    }
    
    func checkForWinsOnce(id: String, completition: @escaping(String)->Void) {
        database.child("\(id)/connect_four_game/winner").observeSingleEvent(of: .value) { snapshot in
            if let winner = snapshot.value as? String {
                
                completition(winner)
            }
        }
    }
    
    func addWinner(id: String, winner: String) {
        if winner == "rematch" {
            database.child("\(id)/connect_four_game/winner").setValue(winner)
            database.child("\(id)/connect_four_game/rematch").observeSingleEvent(of: .value) { snapshot in
                if let data = snapshot.value as? Int {
                    let newData = data + 1
                    self.database.child("\(id)/connect_four_game/rematch").setValue(newData)
                }
            }
        } else {
            guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                return
            }
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            database.child("\(id)/connect_four_game/winner").setValue(winner)
            database.child("\(id)/connect_four_game/\(safeEmail)_wins").observeSingleEvent(of: .value) { snapshot in
                if let data = snapshot.value as? Int {
                    let newData = data + 1
                    self.database.child("\(id)/connect_four_game/\(safeEmail)_wins").setValue(newData)
                }
            }
            database.child("\(id)/connect_four_game/in_progress").setValue(false)
        }
    }
    
    func getPlayerColor(id: String, completition: @escaping(String)->Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        database.child("\(id)/connect_four_game/yellow").observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? String {
                if data == safeEmail {
                    completition("yellow")
                } else {
                    completition("red")
                }
            }
        }

        
    }
    func getRematchData(id: String, completition: @escaping(Int)->Void) {
        database.child("\(id)/connect_four_game/rematch").observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? Int {
                completition(value)
                
            }
        }
    }
    
    func getWinsData(id: String, otherUserEmail: String, completition: @escaping([String:String])->Void) {
        var data = [String:String]()
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let otherSafeEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        
        database.child("\(id)/connect_four_game/\(safeEmail)_wins").observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? Int {
                
                let range = safeEmail.range(of: "-")
                var email = safeEmail.replacingOccurrences(of: "-", with: "@", range: range)
                email = email.replacingOccurrences(of: "-", with: ".")
                    data[safeEmail] = "\(email): \(value)"
                self.database.child("\(id)/connect_four_game/\(otherSafeEmail)_wins").observeSingleEvent(of: .value) { snapshot in
                    if let value = snapshot.value as? Int {
                        
                        let range = otherSafeEmail.range(of: "-")
                        var email = otherSafeEmail.replacingOccurrences(of: "-", with: "@", range: range)
                        email = email.replacingOccurrences(of: "-", with: ".")
                            data[otherSafeEmail] = "\(email): \(value)"

                        print(data)
                        completition(data)
                    }
                }
                
            }
        }
        
    }
}



// MARK: User data struct
struct AppUser {
    let username : String
    let email: String
    var safeEmail : String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePhotoName: String {
        return "\(safeEmail)_profile_photo.png"
    }
}

// MARK: custom errors in database
enum DatabaseErrors: Error {
    
    case cannotGetUsers
    case failedToDownload
}
