//
//  GroupDatabaseManager.swift
//  AirTalk
//
//  Created by Alex Ionescu on 02.04.2023.
//

import Foundation
import FirebaseDatabase
import MessageKit
import UIKit
import AVFoundation
import CoreLocation
import FirebaseAuth
import FirebaseStorage

final class GroupDatabaseManager {
    
    static let shared = GroupDatabaseManager()
    
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



extension GroupDatabaseManager {
    
    func createNewGroupChat(emails: [String], name: String, firstMessage: Message, photo: Data?, completition: @escaping(Bool) -> Void) {
        print("grEmails: \(emails)")
        guard let email = UserDefaults.standard.value(forKey: "email") as? String, let username = UserDefaults.standard.value(forKey: "username") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        let otherEmails = emails.joined(separator: ",") + "," + safeEmail

        let conversationId = "conversation_group_\(firstMessage.messageId)"
        guard let img = photo else {
            return
        }
        StorageManager.shared.uploadProfilePhoto(data: img, filename: conversationId + "_profile_photo.png") { result in
            switch result {
            case .success(_):
                print("success")
                let ref = self.database.child("\(safeEmail)")
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
                            
                            message = url
                            print("message: \(message)")
                            photoCheck = 1
                        }
                        break
                    case .video(let video):
                        print("\n\nVideo kind\n\n")
                        if let url = video.url?.absoluteString {
                            
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
                        audioCheck = 1
                        break
                    case .contact(_):
                        break
                    case .linkPreview(_):
                        break
                    case .custom(_):
                        break
                    }
                    
                    if locationCheck == 1 {
                        message = username + ": Location\u{1F4CD}"
                    } else if videoCheck == 1 {
                        message = username + ": Video\u{1F3A5}"
                    } else if photoCheck == 1 {
                        message = username + ": Photo\u{1F4F7}"
                    } else if audioCheck == 1 {
                        message = username + ": Audio\u{1F3B6}"
                    }
                    
                    let newConversation : [String: Any] = [
                        "id": conversationId,
                        "name" : name,
                        "other_user_email": otherEmails ,
                        "latest_message": [
                            "date" : dateString,
                            "message": message,
                            "is_read": false
                        ],
                        "group_photo" : "\(conversationId)"
                    ]
                    
                    let otherUserNewConversation : [String: Any] = [
                        "id": conversationId,
                        "name" : name,
                        "other_user_email": otherEmails ,
                        "latest_message": [
                            "date" : dateString,
                            "message": message,
                            "is_read": false
                        ],
                        "group_photo" : "\(conversationId)"
                    ]
                    
                    for email in emails {
                        //other user conversation in database
                        self.database.child("\(email)/conversations").observeSingleEvent(of: .value) { snapshot in
                            if var conversations = snapshot.value as? [[String: Any]] {
                                conversations.append(otherUserNewConversation)
                                self.database.child("\(email)/conversations").setValue(conversations)
                                
                            } else {
                                self.database.child("\(email)/conversations").setValue([otherUserNewConversation])
                            }
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
                            self.insertGroupConversationNode(name: name, conversationId: conversationId, firstMessage: firstMessage, completition: completition)
                            
                            
                        }
                        
                    } else {  //create conversations array
                        userObject["conversations"] = [newConversation]
                        
                        ref.setValue(userObject) { error, ref in
                            guard error == nil else {
                                completition(false)
                                return
                            }
                            self.insertGroupConversationNode(name: name, conversationId: conversationId, firstMessage: firstMessage, completition: completition)
                            
                        }
                        
                    }
                    
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        
        
    }
    
    
    
    
    // MARK: Insert conversation in it's own place in database ( conversationId is it's name)
    func insertGroupConversationNode(name : String, conversationId: String, firstMessage: Message, completition: @escaping (Bool) -> Void) {
        print(name)
        print(conversationId)
        print(firstMessage)
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
            ],
            "admin" : safeEmail
        ]
        database.child("\(conversationId)").setValue(value) { error, ref in
            guard error == nil else {
                completition(false)
                return
            }
            completition(true)
        }
    }
    
    
    
    
    
    
    
    func sendGroupMessage(conversation: String, emails: [String],  name: String, newMessage: Message, completition: @escaping(Bool) -> Void) {
        print("send emails:::")
        print(emails)
        
        guard let email =  UserDefaults.standard.value(forKey: "email") as? String, let username = UserDefaults.standard.value(forKey: "username") as? String else {
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
                
                if locationCheck == 1 {
                    message = "Location\u{1F4CD}"
                } else if videoCheck == 1 {
                    message = "Video\u{1F3A5}"
                } else if photoCheck == 1 {
                    message = "Photo\u{1F4F7}"
                } else if audioCheck == 1 {
                    message = "Audio\u{1F3B6}"
                }
                
                
                // Update latest message for the user sending the message
                self.database.child("\(selfEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    var dbConversations = [[String: Any]]()
                    
                    let newLatestMessage : [String: Any]  = [
                        "date": dateString,
                        "is_read": false,
                        "message": "Me: " + message
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
                            let otherEmails = emails.joined(separator: ",")
                            let newConversation : [String: Any] = [
                                "id": conversation,
                                "name" : name,
                                "other_user_email": DatabaseManager.safeEmail(email: otherEmails) ,
                                "latest_message": newLatestMessage
                            ]
                            conversations.append(newConversation)
                            dbConversations = conversations
                            
                        }
                        
                    } else {
                        let otherEmails = emails.joined(separator: ",")
                        let newConversation : [String: Any] = [
                            "id": conversation,
                            "name" : name,
                            "other_user_email": DatabaseManager.safeEmail(email: otherEmails) ,
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
                var otherEmails = emails
                otherEmails.removeAll { user in
                    return user == safeEmail
                }
                // Update latest message for the user that receives the message
                for otherUserEmail in otherEmails {
                    self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                        var dbConversations = [[String: Any]]()
                        
                        let newLatestMessage : [String: Any]  = [
                            "date": dateString,
                            "is_read": false,
                            "message":  username + ": " + message
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
                                let otherEmails = emails.joined(separator: ",")
                                let newConversation : [String: Any] = [
                                    "id": conversation,
                                    "name" : name,
                                    "other_user_email": DatabaseManager.safeEmail(email: otherEmails) ,
                                    "latest_message": newLatestMessage
                                ]
                                conversations.append(newConversation)
                                dbConversations = conversations
                            }
                            
                        } else {
                            //the collection of messages does not exist
                            let otherEmails = emails.joined(separator: ",")
                            let newConversation : [String: Any] = [
                                "id": conversation,
                                "name" : name,
                                "other_user_email": DatabaseManager.safeEmail(email: otherEmails) ,
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
                }
                
                completition(true)
            }
        }
    }
    
    
    
    // MARK:
    func deleteGroupConversation(otherUsers: [String], id: String, completition : @escaping(Bool)-> Void) {
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
                    completition(true)
                }
            }
        }
               
        for email in otherUsers {
            let otherUserSafeEmail = DatabaseManager.safeEmail(email: email)
            
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
    }
    
    
    // MARK: Delete a message from a conversation and replace it's content with: "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶"
    func deleteGroupMessage(id: String, email: String, emails: [String], index: Int, completition: @escaping(Bool)->Void) {
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
                for email in emails {
                    let otherSafeEmail = DatabaseManager.safeEmail(email: email)
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
                completition(true)
            }
        }
        
    }
    
    
    func changeGroupName(id: String, emails: [String], name: String, completition: @escaping(Bool)->Void) {
        
        for email in emails {
            let safeEmail = DatabaseManager.safeEmail(email: email)
            self.database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                if var data = snapshot.value as? [[String: Any]] {
                    var i = 0
                    var exists = false
                    for conversation in data {
                        if let convId = conversation["id"] as? String {
                            if convId == id {
                                exists = true
                                break
                            }
                            i+=1
                        }
                    }
                    if exists {
                        data[i]["name"] = name
                        self.database.child("\(safeEmail)/conversations").setValue(data)
                    }
                }
            }
        }
        completition(true)
    }
    func addUsers(emails: [String], currentUsers: [String], id: String, completition: @escaping(Bool)->Void) {
        print("emails...")
        print(emails)
        guard let selfEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: selfEmail)
        
        
        
        for email in currentUsers {
            database.child("\(email)/conversations").observeSingleEvent(of: .value) { snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    var index = 0
                    for conv in conversations {
                        if let targetId = conv["id"] as? String, targetId == id {
                            break
                        }
                        index += 1
                    }
                    if let data = conversations[index]["other_user_email"] as? String {
                        let newUsers = emails.joined(separator: ",")
                        conversations[index]["other_user_email"] = data + "," + newUsers
                    }
                    self.database.child("\(email)/conversations").setValue(conversations)
   
                }
                
            }

        }
        
        database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var index = 0
                for conv in conversations {
                    if let targetId = conv["id"] as? String, targetId == id {
                        break
                    }
                    index += 1
                }
                
                for email in emails {
                    self.database.child("\(email)/conversations").observeSingleEvent(of: .value) { snapshot in
                        if var data = snapshot.value as? [[String: Any]] {
                            data.append(conversations[index])
                            self.database.child("\(email)/conversations").setValue(data)
                        } else {
                            self.database.child("\(email)/conversations").setValue([conversations[index]])
                        }
                    }
                }
            }
            
        }
        
        database.child("\(id)/deleted").observeSingleEvent(of: .value) { snapshot in
            if var data = snapshot.value as? String {
                for email in emails {
                    data = data.replacingOccurrences(of: email, with: "")
                }
                if data == "" {
                    Database.database().reference().child("\(id)").child("deleted").removeValue()
                } else {
                    Database.database().reference().child("\(id)").child("deleted").setValue(data)
                }
            }
        }
        
        completition(true)

        
    }
    
    func removeUser(email: String, currentUsers: [String], id: String, completition: @escaping(Bool)->Void) {
        print("emails...")
        print(email)
        
        var users = currentUsers
        users.removeAll { $0 == email}
        var newUsers = users.joined(separator: ",")
        for user in currentUsers {
            database.child("\(user)/conversations").observeSingleEvent(of: .value) { snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    var index = 0
                    for conv in conversations {
                        if let targetId = conv["id"] as? String, targetId == id {
                            break
                        }
                        index += 1
                    }
                    if user == email {
                        conversations.remove(at: index)
                    } else {
                        if let data = conversations[index]["other_user_email"] as? String {
                            conversations[index]["other_user_email"] = newUsers
                        }
                    }
                    self.database.child("\(user)/conversations").setValue(conversations)
   
                }
                
            }

        }
        database.child("\(id)/deleted").observeSingleEvent(of: .value) { snapshot in
            if var data = snapshot.value as? String {
                data += ","
                data += email
                Database.database().reference().child("\(id)").child("deleted").setValue(data)
            } else {
                Database.database().reference().child("\(id)").child("deleted").setValue(email)
            }
        }
        
        completition(true)

        
    }
    
    // MARK: Delete an conversation( from user's node); the conversation will be permanently deleted if no user holds a refference to it's id
    func deleteGroupConversation(otherUser: String, id: String, completition : @escaping(Bool)-> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        var users = otherUser.components(separatedBy: ",")
        users.removeAll { user in
            user == email
        }
        print(users)
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
                self.database.child("\(safeEmail)/conversations").setValue(conversations)
            }
        }
        //check if other user holds a refference to conversation's id
        for user in users {
            let otherUserSafeEmail = DatabaseManager.safeEmail(email: user)
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
    
    func getUsername(email: String, completition: @escaping(Result<String, Error>) -> Void) {
        
        
        Database.database().reference().child("\(email)").child("username").observeSingleEvent(of: .value) { snapshot in
            if let data = snapshot.value as? String {
                completition(.success(data))
                
            } else {
                completition(.failure(DatabaseErrors.failedToDownload))
            }
        }
        
        
    }
    func checkIfDeleted(id: String, completition: @escaping(Bool) -> Void) {
        guard let selfEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: selfEmail)
        
        database.child("\(id)/deleted").observe(.value) { snapshot in
            if let data = snapshot.value as? String {
                if data.contains(safeEmail) {
                    completition(true)
                } else {
                    completition(false)
                }
                
                
            } else {
                completition(false)
            }
        }
    }
    func getEmails(id: String, completition: @escaping(String) -> Void) {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        database.child("\(safeEmail)/conversations").observe(.value) { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var index = 0
                for conv in conversations {
                    if let targetId = conv["id"] as? String, targetId == id {
                        break
                    }
                    index += 1
                }
                if index < conversations.count {
                    if let users = conversations[index]["other_user_email"] as? String {
                        completition(users)
                    }
                }

            }
        }
    }
    
}




