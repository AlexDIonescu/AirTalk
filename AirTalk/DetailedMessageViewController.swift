//
//  DetailedMessageViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 12.02.2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import Photos
import FirebaseAuth
import JGProgressHUD
import FirebaseDatabase
import FirebaseStorage
import Network

//MessageKit messageType
struct Message: MessageType {
    
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
    
    
}

// used to upload message kind to firebase ( messageKing it's a enum )
extension MessageKind {
    var messageKindString : String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributedText"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}

// Messagekit media
struct Media: MediaItem {
    
    var url: URL?
    
    var image: UIImage?
    
    var placeholderImage: UIImage
    
    var size: CGSize
    
    
}


struct Audio: AudioItem {
    
    var url: URL
    
    var duration: Float
    
    var size: CGSize
    
}
//Messagekit Sender struct
struct Sender: SenderType {
    
    var photoUrl: String
    var senderId: String
    var displayName: String
    
    
}

//Location Struct
struct Location: LocationItem {
    var location: CLLocation
    
    var size: CGSize
    
    
}


class DetailedMessageViewController: MessagesViewController {
    
    // MARK: create unique identifier for messages and conversations
    static let uniqueDateforId : DateFormatter = {
        let date = DateFormatter()
        date.dateStyle = .medium
        date.timeStyle = .medium
        date.locale = Locale(identifier: "en_US_POSIX") // Set locale to US English (fixed format)
        date.timeZone = TimeZone(identifier: "UTC") // timezone to UTC
        date.dateFormat = "MMM dd, yyyy 'at' h:mm:ss a"   //date format is very important!!! Different timezones will provide different formats so we have to specify one!
        print(date)
        return date
    }()
    
    let button : UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "chevron.down.circle.fill"), for: .normal)
        button.backgroundColor = .gray
        button.tintColor = .systemYellow
        button.layer.borderColor = UIColor.gray.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 10
        button.layer.transform = CATransform3DMakeScale(2, 2, 2)
        button.isHidden = true
        return button
    }()
    
    var scrollToBottom = true
    var audioRecorder: AVAudioRecorder!
    let mic = InputBarButtonItem()
    var messages = [Message]()
    var isNew = false
    let otherUserEmail : String
    var conversationId : String?
    var currentUserPhotoUrl : URL?
    var otherUserPhotoUrl : URL?
    var otherUserUsername = ""
    var inputText = ""
    var audioInput : URL?
    var audioPlayer : AVAudioPlayer?
    var audioTimer : Timer?
    var audiosPlaying : [IndexPath] = []
    let networkMonitor = NWPathMonitor()
    var selfSender : Sender?  {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        guard let username = UserDefaults.standard.value(forKey: "username") as? String else {
            print("username...")
            return nil
        }
        guard let url = UserDefaults.standard.value(forKey: "profilePhotoUrl") as? String  else {
            print("url...")
            
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        return Sender(photoUrl: url, senderId: safeEmail , displayName: username)
    }
    
    
    
    init(email: String, id: String?, username: String, isNew: Bool) {
        self.conversationId = id
        self.otherUserEmail = email
        self.otherUserUsername = username
        self.isNew = isNew
        super.init(nibName: nil, bundle: nil)
        
        
        if let conversationId = conversationId {
            
            listenForMessages(id: conversationId)
            
            
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        networkChanges()
        
        hidesBottomBarWhenPushed = true
        navigationItem.largeTitleDisplayMode = .never
        let safeOtherEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        Database.database().reference().child("\(safeOtherEmail)").child("online").observe(.value, with: { snapshot in
            if let online = snapshot.value as? Bool {
                if online {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: " 🟢 online", style: .done, target: nil, action: nil)
                } else {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: " 🔴 offline", style: .done, target: nil, action: nil)
                    
                }
            }
        })
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messagesCollectionView.alwaysBounceVertical = true
        messageInputBar.delegate = self
        self.scrollsToLastItemOnKeyboardBeginsEditing = true
        self.showMessageTimestampOnSwipeLeft = true
        configureInputButton()
        button.addTarget(self, action: #selector(scrollMessagesToBottom), for: .touchUpInside)
        view.addSubview(button)
        
        Database.database().reference().child("\(safeOtherEmail)").child("is_typing").observe(.value, with: { snapshot in
            if let typing = snapshot.value as? Bool {
                if typing {
                    self.title = "typing..."
                } else {
                    print(self.otherUserUsername)
                    self.title = self.otherUserUsername
                }
            }
        })
        
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        button.frame = CGRect(x: view.frame.size.width - 40, y: view.frame.size.height - 130, width: 20, height: 20)
        
    }
    override func scrollViewDidEndDecelerating(_: UIScrollView) {
        button.isHidden = true
    }
    func networkChanges() {
        
        let queue = DispatchQueue(label: "network")
        networkMonitor.start(queue: queue)
        
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
        
        
    }
    
    func listenForMessages(id: String) {
        let indicator = JGProgressHUD(style: .light)
        guard let id = self.conversationId else {
            return
        }
        let cached = UserDefaults.standard.value(forKey: "\(id)") as? String
        if cached == nil && self.isNew == false {
            
            indicator.textLabel.text = "Loading conversations..."
            indicator.show(in: self.view, animated: true)
        }
        
        //MARK: Get messages for chat
        
        print(id)
        UserDefaults.standard.set(id, forKey: id)
        DatabaseManager.shared.getMessagesForChat(id: id) { result in
            print("before switch")
            
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    print("\nempty\n")
                    
                    return
                }
                print("\n\nsuccess\n")
                
                if messages.count > self.messages.count {
                    self.scrollToBottom = true
                }
                
                self.messages = messages
                
                DispatchQueue.main.async {
                    self.additionalBottomInset = 15
                    self.messagesCollectionView.reloadData()
                    if self.scrollToBottom {
                        
                        self.messagesCollectionView.scrollToLastItem(at: .bottom, animated: false)
                        self.scrollToBottom = false
                    }
                    indicator.dismiss(afterDelay: 2.0, animated: true)
                    
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    indicator.dismiss(animated: true)
                    
                }
                print("error listening: \(error)")
            }
        }
    }
    @objc func scrollMessagesToBottom() {
        DispatchQueue.main.async {
            self.messagesCollectionView.scrollToLastItem(at: .bottom, animated: true)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt index: IndexPath) {
        
        if index.section + 1 >= messages.count - 1 {
            self.button.isHidden = true
        } else if index.section + 1 < messages.count - 1 {
            self.button.isHidden = false
        }
        
        
    }
    
    func configureInputButton() {
        let plusButton = InputBarButtonItem()
        plusButton.setSize(CGSize(width: 45, height: 45), animated: true)
        plusButton.setImage(UIImage(systemName: "plus"), for: .normal)
        plusButton.imageView?.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
        plusButton.onTouchUpInside { button in
            self.presentInputOptions()
        }
        
        mic.setSize(CGSize(width: 45, height: 45), animated: true)
        mic.setImage(UIImage(systemName: "mic"), for: .normal)
        mic.imageView?.layer.transform = CATransform3DMakeScale(1.5, 1.5, 1.5)
        
        mic.onTouchUpInside { button in
            self.micButtonTapped()
        }
        
        messageInputBar.inputTextView.textContainerInset.top = 4
        messageInputBar.inputTextView.textContainerInset.bottom = 7
        messageInputBar.maxTextViewHeight = 30
        messageInputBar.padding.top = 10
        messageInputBar.padding.bottom = 10
        messageInputBar.setLeftStackViewWidthConstant(to: 92, animated: true)
        messageInputBar.sendButton.image = UIImage(systemName: "paperplane.fill")
        messageInputBar.sendButton.tintColor = .systemGreen
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.imageView?.layer.transform = CATransform3DMakeScale(1.6, 1.6, 1.6)
        messageInputBar.setStackViewItems([plusButton, mic], forStack: .left, animated: true)
        
        
    }
    func presentInputOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { action in
            self.openPhotos()
        }))
        alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { action in
            self.openCamera()
        }))
        alert.addAction(UIAlertAction(title: "Location", style: .default, handler: { action in
            self.presentLocationOption()
        }))
        alert.addAction(UIAlertAction(title: "Play Connect Four 🕹️", style: .default, handler: { action in
            
            guard let id = self.conversationId else {
                return
            }
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "game") as! ConnectFourViewController
            vc.convId = id
            vc.otherUserEmail = self.otherUserEmail
           
            self.navigationController?.pushViewController(vc, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true)
    }
    func presentLocationOption () {
        let vc = LocationViewController(coordinates: nil)
        vc.title = "Pick a location"
        
        vc.completition = { coordinates in
            
            let longitude: Double = coordinates.longitude
            let latitude: Double = coordinates.latitude
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            
            guard let uniqueId = self.createMessageId(), let id = self.conversationId, let selfSender = self.selfSender else {
                return
            }
            let progressIndicator = JGProgressHUD(style: .light)
            progressIndicator.textLabel.text = "Sending location..."
            progressIndicator.show(in: self.view)
            
            let message = Message(sender: selfSender, messageId: uniqueId, sentDate: Date(), kind: .location(location))
            
            //MARK: Send location messages
            if self.isNew {
                
                DatabaseManager.shared.createNewChat(otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, firstMessage: message) { success in
                    if success {
                        progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                        progressIndicator.textLabel.text = ""
                        progressIndicator.dismiss(afterDelay: 2, animated: true)
                        print("location message sent!")
                        let conversationId = "conversation_\(message.messageId)"
                        self.conversationId = conversationId
                        self.listenForMessages(id: conversationId)
                        
                    } else {
                        progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                        progressIndicator.dismiss(afterDelay: 2, animated: true)
                    }
                }
            } else {
                DatabaseManager.shared.sendMessage(conversation: id, otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, newMessage: message) { success in
                    
                    if success {
                        progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                        progressIndicator.textLabel.text = ""
                        progressIndicator.dismiss(afterDelay: 2, animated: true)
                        print("location message sent!")
                        
                    } else {
                        progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                        progressIndicator.dismiss(afterDelay: 2, animated: true)
                    }
                }
            }
            progressIndicator.dismiss(afterDelay: 2, animated: true)
            
            
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    func micButtonTapped() {
        if mic.image == UIImage(systemName: "mic") {
            mic.setImage(UIImage(systemName: "stop.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal), for: .normal)
            self.messageInputBar.inputTextView.placeholder = "recording audio..."
            self.messageInputBar.inputTextView.placeholderLabel.textColor = .red
            self.recordAudio()
        } else {
            mic.setImage(UIImage(systemName: "mic"), for: .normal)
            self.messageInputBar.inputTextView.placeholder = "Aa"
            self.messageInputBar.inputTextView.placeholderLabel.textColor = .lightGray
            audioRecorder.stop()
            audioRecorder = nil
            print("success recording audio!")
            guard let id = self.conversationId else {
                return
            }
            guard let selfSender = self.selfSender, let messageId = createMessageId() else {
                return
            }
            let filename = "conversation_"+messageId+"_audio".replacingOccurrences(of: " ", with: "-")+".m4a"
            
            guard let url = audioInput else {
                return
            }
            let progressIndicator = JGProgressHUD(style: .light)
            progressIndicator.textLabel.text = "Sending audio..."
            progressIndicator.show(in: view)
            StorageManager.shared.uploadAudioMessage(url: url, filename: filename) { result in
                switch result {
                case .success(let url):
                    guard let url = URL(string: url) else {
                        return
                    }
                    
                    let duration = AVURLAsset(url: url).duration
                    print("\n\nduration\n\n")
                    print(duration.value)
                    let audioItem = Audio(url: url, duration: Float(duration.value), size: CGSize(width: 200, height: 100))
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .audio(audioItem))
                    if self.isNew {
                        DatabaseManager.shared.createNewChat(otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, firstMessage: message) { success in
                            if success {
                                print("audio message sent!")
                                progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                                progressIndicator.textLabel.text = ""
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                                let conversationId = "conversation_\(message.messageId)"
                                self.conversationId = conversationId
                                self.listenForMessages(id: conversationId)
                            } else {
                                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                progressIndicator.textLabel.text = "Error sending audio"
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            }
                        }
                    } else {
                        DatabaseManager.shared.sendMessage(conversation: id, otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, newMessage: message) { success in
                            if success {
                                print("audio message sent!")
                                progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                                progressIndicator.textLabel.text = ""
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            } else {
                                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                progressIndicator.textLabel.text = "Error sending audio"
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            }
                            
                        }
                    }
                case .failure(let error):
                    print("error: \(error.localizedDescription)")
                    progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                    progressIndicator.textLabel.text = "Error sending audio"
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                }
            }
            
        }
    }
    
    func recordAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("error starting audio session...")
            self.messageInputBar.inputTextView.placeholderLabel.textColor = .lightGray
            self.messageInputBar.inputTextView.placeholder = "Aa"
        }
        session.requestRecordPermission { success in
            if success {
                self.startRecordingAudio()
            }
        }
    }
    
    func startRecordingAudio() {
        let filename = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = filename.appendingPathComponent("audio.m4a", conformingTo: .audio)
        self.audioInput = path
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),   //audio format
            AVSampleRateKey: 12000,                     //recording rate
            AVNumberOfChannelsKey: 1,                    //one channel recording
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue      //highest quality possible
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: path, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
        } catch {
            self.messageInputBar.inputTextView.placeholder = "Aa"
            self.messageInputBar.inputTextView.placeholderLabel.textColor = .lightGray
            print(error.localizedDescription)
            print("error recording audio...")
        }
    }
    
    func presentPhotoOptions() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { action in
                self.openPhotos()
            }))
            alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { action in
                self.openCamera()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        } else {
            requestMediaAccess()
        }
    }
    func openCamera() {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.videoQuality = .typeHigh
                if let types = UIImagePickerController.availableMediaTypes(for: .camera) {
                    picker.mediaTypes = types
                }
                picker.sourceType = UIImagePickerController.SourceType.camera
                picker.allowsEditing = true
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
                picker.videoQuality = .typeHigh
                if let types = UIImagePickerController.availableMediaTypes(for: .photoLibrary) {
                    picker.mediaTypes = types
                }
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
    
    
    
    //MARK: Handle image saving error/success
    
    @objc func imageSavingError(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if error != nil {
            let indicator = JGProgressHUD(style: .light)
            indicator.indicatorView = JGProgressHUDErrorIndicatorView()
            indicator.textLabel.text = "Error saving the image..."
            indicator.show(in: view, animated: true)
            indicator.dismiss(afterDelay: 2, animated: true)
        } else {
            let indicator = JGProgressHUD(style: .light)
            indicator.indicatorView = JGProgressHUDSuccessIndicatorView()
            indicator.textLabel.text = "Image saved succesfully!"
            indicator.show(in: view, animated: true)
            indicator.dismiss(afterDelay: 2, animated: true)
        }
    }
    
    
    
}

extension DetailedMessageViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        Database.database().reference().child("\(safeEmail)").child("is_typing").setValue(true)
        //        Database.database().reference().child("\(safeEmail)").child("online").observeSingleEvent(of: .value) { snapshot in
        //            guard let data = snapshot.value as? Bool else {
        //                return
        //            }
        //            if !data {
        //                Database.database().reference().child("\(safeEmail)").child("online").setValue(true)
        //
        //            }
        //        }
        self.inputText = text
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { timer in
            if self.inputText == text {
                
                Database.database().reference().child("\(safeEmail)").child("is_typing").setValue(false)
                
            }
        }
        
    }
    
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        print("clicked")
        self.messageInputBar.sendButton.isEnabled = false
        guard !text.isEmpty , let selfSender = self.selfSender, let messageId = createMessageId() else {
            return
        }
        print("after guard")
        
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        
        //MARK: Create new conversation based on isNew variable
        if isNew {
            
            DatabaseManager.shared.createNewChat(otherUserEmail: otherUserEmail, name: self.otherUserUsername , firstMessage: message) { success in
                if success {
                    print("Message sent")
                    self.isNew = false
                    let conversationId = "conversation_\(message.messageId)"
                    self.conversationId = conversationId
                    self.listenForMessages(id: conversationId)
                    self.messageInputBar.inputTextView.text = nil
                    self.messageInputBar.sendButton.isEnabled = true
                    self.messageInputBar.sendButton.stopAnimating()
                    self.messageInputBar.inputTextView.placeholder = "Aa"
                    self.messageInputBar.inputTextView.placeholderLabel.textColor = .lightGray
                    
                } else {
                    self.messageInputBar.sendButton.isEnabled = true
                    
                    print("failed to send the message0")
                }
            }
            //MARK: Append to existing conversation
        } else {
            guard let conversationId = conversationId else {
                return
            }
            self.messageInputBar.inputTextView.text = nil
            DatabaseManager.shared.sendMessage(conversation: conversationId, otherUserEmail: self.otherUserEmail, name: otherUserUsername ,newMessage: message) { success in
                if success {
                    print("message sent")
                    self.messageInputBar.sendButton.isEnabled = true
                    self.messageInputBar.sendButton.stopAnimating()
                    self.messageInputBar.inputTextView.placeholder = "Aa"
                    self.messageInputBar.inputTextView.placeholderLabel.textColor = .lightGray
                } else {
                    self.messageInputBar.sendButton.isEnabled = true
                    print("failed to send the message...")
                }
            }
            
        }
        
    }
    
    func createMessageId() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        var date = DetailedMessageViewController.uniqueDateforId.string(from: Date())
        date = date.replacingOccurrences(of: " ", with: "_")
        date = date.replacingOccurrences(of: ".", with: "_")
        let identifier = "\(otherUserEmail)_\(safeEmail)_\(date)"
        print(identifier)
        return identifier
    }
}

extension DetailedMessageViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, MessageCellDelegate {
    
    
    
    var currentSender: MessageKit.SenderType {
        if let sender = selfSender {
            return sender
        }
        
        return Sender(photoUrl: "", senderId: "11138", displayName: "UNKNOWN")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        
        let dateBuilder = DateFormatter()
        dateBuilder.dateFormat = "MM-dd-yyyy HH:mm"
        let date = dateBuilder.string(from: message.sentDate)
        
        guard let font = UIFont(name: "Helvetica", size: 10) else {
            return nil
        }
        
        return NSAttributedString(string: date, attributes: [.font: font, .foregroundColor: UIColor.gray])
    }
    
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 18
    }
    
    
    //MARK: Context menu configuration for messages
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
        guard let location = messagesCollectionView.indexPathForItem(at: point) else {
            return nil
        }
        let message = messages[location.section]
        switch message.kind {
            
        case .text(let text):
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { menu in
                guard let image = UIImage(systemName: "doc.on.doc") else {
                    return nil
                }
                guard let deleteImage = UIImage(systemName: "trash") else {
                    return nil
                }
                let copyText = UIAction(title: "Copy Text", image: image) { action in
                    if text == "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶" {
                        UIPasteboard.general.string = "deleted message"
                    } else {
                        UIPasteboard.general.string = text
                    }
                    print(text)
                }
                guard let convId = self.conversationId, let id = self.selfSender?.senderId, let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return nil
                }
                
                if message.sender.senderId == id {
                    let deleteMessage = UIAction(title: "Delete Message", image: deleteImage) { action in
                        DatabaseManager.shared.deleteMessage(id: convId, email: email, otherUserEmail: self.otherUserEmail, index: location.section) { success in
                            if success {
                                print("message deleted succesfully!")
                            }
                        }
                    }
                    return UIMenu(title: "", children: [copyText, deleteMessage])
                }
                return UIMenu(title: "", children: [copyText])
            }
        case .attributedText(_):
            break
        case .photo(let photo):
            return UIContextMenuConfiguration(identifier: indexPaths as NSCopying, previewProvider: nil) { menu in
                guard let saveImage = UIImage(systemName: "square.and.arrow.down") else {
                    return nil
                }
                guard let convId = self.conversationId, let id = self.selfSender?.senderId, let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return nil
                }
                guard let deleteImage = UIImage(systemName: "trash") else {
                    return nil
                }
                guard let url = photo.url else {
                    return nil
                }
                let saveMedia = UIAction(title: "Save image", image: saveImage) { action in
                    let path = FileManager.default.temporaryDirectory.appendingPathComponent("photo.png")
                    URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
                        if error == nil {
                            guard let data = data else {
                                return
                            }
                            do {
                                try data.write(to: path)
                                DispatchQueue.main.async {
                                    let activity = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                                    self.present(activity, animated: true)
                                }
                                print("saved!")
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }).resume()
                    
                }
                
                
                if message.sender.senderId == id {
                    let deleteMessage = UIAction(title: "Delete Message", image: deleteImage) { action in
                        DatabaseManager.shared.deleteMessage(id: convId, email: email, otherUserEmail: self.otherUserEmail, index: location.section) { success in
                            if success {
                                print("message deleted succesfully!")
                            }
                        }
                    }
                    return UIMenu(title: "", children: [saveMedia, deleteMessage])
                }
                
                return UIMenu(title: "", children: [saveMedia])
            }
        case .video(let video):
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { menu in
                
                guard let convId = self.conversationId, let id = self.selfSender?.senderId, let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return nil
                }
                guard let url = video.url else {
                    return nil
                }
                guard let deleteImage = UIImage(systemName: "trash") else {
                    return nil
                }
                guard let saveImage = UIImage(systemName: "square.and.arrow.down") else {
                    return nil
                }
                
                
                let saveMedia = UIAction(title: "Save video", image: saveImage) { action in
                    let path = FileManager.default.temporaryDirectory.appendingPathComponent("video.mov")
                    URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
                        if error == nil {
                            guard let data = data else {
                                return
                            }
                            do {
                                try data.write(to: path)
                                DispatchQueue.main.async {
                                    let activity = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                                    self.present(activity, animated: true)
                                }
                                print("saved!")
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }).resume()
                    
                }
                if message.sender.senderId == id {
                    let deleteMessage = UIAction(title: "Delete Message", image: deleteImage) { action in
                        DatabaseManager.shared.deleteMessage(id: convId, email: email, otherUserEmail: self.otherUserEmail, index: location.section) { success in
                            if success {
                                print("message deleted succesfully!")
                            }
                        }
                    }
                    return UIMenu(title: "", children: [saveMedia, deleteMessage])
                }
                
                
                return UIMenu(title: "", children: [saveMedia])
            }
            
        case .location(let info):
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { menu in
                guard let convId = self.conversationId, let id = self.selfSender?.senderId, let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return nil
                }
                guard let deleteImage = UIImage(systemName: "trash") else {
                    return nil
                }
                guard let image = UIImage(systemName: "location") else {
                    return nil
                }
                let coordinates = "\(info.location.coordinate.latitude),\(info.location.coordinate.longitude)"
                
                let copyLocationCoordinates = UIAction(title: "Copy location coordinates", image: image) { action in
                    UIPasteboard.general.string = coordinates
                }
                let deleteMessage = UIAction(title: "Delete Message", image: deleteImage) { action in
                    DatabaseManager.shared.deleteMessage(id: convId, email: email, otherUserEmail: self.otherUserEmail, index: location.section) { success in
                        if success {
                            print("message deleted succesfully!")
                        }
                    }
                }
                if message.sender.senderId == id {
                    
                    return UIMenu(title: "", children: [copyLocationCoordinates, deleteMessage])
                }
                return UIMenu(title: "", children: [copyLocationCoordinates])
            }
        case .emoji(_):
            break
        case .audio(let audio):
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { menu in
                guard let deleteImage = UIImage(systemName: "trash") else {
                    return nil
                }
                guard let saveImage = UIImage(systemName: "square.and.arrow.down") else {
                    return nil
                }
                
                guard let convId = self.conversationId, let id = self.selfSender?.senderId, let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return nil
                }
                let deleteMessage = UIAction(title: "Delete Message", image: deleteImage) { action in
                    DatabaseManager.shared.deleteMessage(id: convId, email: email, otherUserEmail: self.otherUserEmail, index: location.section) { success in
                        if success {
                            print("message deleted succesfully!")
                        }
                    }
                }
                let saveMedia = UIAction(title: "Save audio to Files", image: saveImage) { action in
                    let path = FileManager.default.temporaryDirectory.appendingPathComponent("audio.m4a")
                    URLSession.shared.dataTask(with: audio.url, completionHandler: { data, response, error in
                        if error == nil {
                            guard let data = data else {
                                return
                            }
                            do {
                                try data.write(to: path)
                                DispatchQueue.main.async {
                                    let activity = UIActivityViewController(activityItems: [path], applicationActivities: nil)
                                    self.present(activity, animated: true)
                                }
                                print("saved!")
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }).resume()
                    
                }
                if message.sender.senderId == id {
                    
                    return UIMenu(title: "", children: [saveMedia,deleteMessage])
                }
                return UIMenu(title: "", children: [saveMedia])
            }
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
            
        }
        return nil
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        switch message.kind {
        case .text(_):
            break
        case .attributedText(_):
            break
        case .photo(let photo):
            guard let url = photo.url else {
                return
            }
            imageView.sd_imageIndicator = SDWebImageActivityIndicator.gray
            imageView.sd_setImage(with: url)
            
            break
        case .video(let video):
            guard let url = video.url else {
                return
            }
            if let img = UserDefaults.standard.value(forKey: "\(url)") as? Data {
                imageView.sd_imageIndicator = SDWebImageActivityIndicator.gray
                imageView.sd_setImage(with: nil, placeholderImage: UIImage(data: img))
                
            } else {
                DispatchQueue.global(qos: .background).async {
                    StorageManager.shared.imageFromVideo(url: url) { image in
                        if let image = image {
                            DispatchQueue.main.async {
                                imageView.sd_imageIndicator = SDWebImageActivityIndicator.gray
                                imageView.sd_setImage(with: nil, placeholderImage: image)
                                UserDefaults.standard.set(image.pngData(), forKey: "\(url)")
                            }
                        }
                    }
                }
                
            }
            
            break
        case .location(_):
            
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
    }
    
    
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let photo):
            guard let url = photo.url else {
                return
            }
            
            let vc = ImageViewerViewController(url: url)
            
            navigationController?.pushViewController(vc, animated: true)
        case .video(let video):
            guard let url = video.url else {
                return
            }
            let vc = AVPlayerViewController()
            vc.tabBarController?.tabBar.isHidden = true
            
            print(url)
            vc.player = AVPlayer(url: url)
            
            present(vc, animated: true) {
                vc.player?.play()
            }
        default:
            break
        }
        
        
    }
    
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .location(let data):
            
            let locationCoordinates = data.location.coordinate
            let vc = LocationViewController(coordinates: locationCoordinates)
            vc.title = "Location"
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
        
    }
    
    func clearAudios() {
        if audiosPlaying.count > 0 {
            
            for i in audiosPlaying {
                let cell = messagesCollectionView.cellForItem(at: i) as! AudioMessageCell
                cell.progressView.setProgress(0.0, animated: false)
                cell.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                self.audioTimer?.invalidate()
            }
            self.audiosPlaying.removeAll()
            
        }
    }
    
    func didTapPlayButton(in cell: AudioMessageCell) {
        print("tapped")
        
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .audio(let audio):
            
            print(audio.duration)
            do {
                try audioPlayer = AVAudioPlayer(contentsOf: audio.url)
            } catch {
                print(error.localizedDescription)
                
            }
            if cell.playButton.currentImage == UIImage(systemName: "play.fill") {
                if self.networkMonitor.currentPath.status == .unsatisfied || self.networkMonitor.currentPath.status == .requiresConnection {
                    
                    let alert = UIAlertController(title: "Error playing the audio file!", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    return
                    
                }
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print(error.localizedDescription)
                    
                }
                
                print("count: \(audiosPlaying.count)")
                clearAudios()
                audioPlayer?.play()
                
                audiosPlaying.append(indexPath)
                print(self.audiosPlaying)
                cell.playButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
                var progress : Float = 0.0
                let duration = audio.duration.rounded()
                let time = 1.0 / duration
                
                audioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                    if self.networkMonitor.currentPath.status == .requiresConnection || self.networkMonitor.currentPath.status == .unsatisfied {
                        print("here")
                        let alert = UIAlertController(title: "Error playing the audio file!", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                        cell.progressView.setProgress(0.0, animated: false)
                        cell.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                        timer.invalidate()
                        self.clearAudios()
                        return
                        
                    }
                    cell.progressView.setProgress(progress, animated: true)
                    print("progress: \(progress)")
                    print("duration: \(duration)")
                    
                    if progress >= 1.0 {
                        cell.progressView.setProgress(0.0, animated: false)
                        cell.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                        timer.invalidate()
                        self.clearAudios()
                        print("count: \(self.audiosPlaying.count)")
                    }
                    progress += time
                }
                
                
            } else if cell.playButton.currentImage == UIImage(systemName: "stop.fill") {
                audioTimer?.invalidate()
                audioPlayer?.pause()
                self.audiosPlaying.removeAll { index in
                    index == indexPath
                }
                clearAudios()
                print("count: \(audiosPlaying.count)")
                
                cell.progressView.setProgress(0.0, animated: false)
                cell.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            }
            
            break
            
        default:
            break
        }
    }
    
    
    func audioProgressTextFormat(_ duration: Float, for audioCell: AudioMessageCell, in messageCollectionView: MessagesCollectionView) -> String {
        audioCell.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        let finalDuration = round((duration * 100)/100.0)
        if finalDuration > 60 {
            return "\(round(finalDuration / 60 * 100) / 100.0) m"
        }
        return "\(finalDuration) s"
    }
    //MARK: set message background depending on who is sending the message
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        let mess = messages[indexPath.section]
        switch mess.kind {
        case .text(let text):
            if text == "̶d̶e̶l̶e̶t̶e̶d̶ ̶m̶e̶s̶s̶a̶g̶e̶" {
                return .gray
            }
        default:
            break
        }
        if sender.senderId == self.selfSender?.senderId {  // I sent the message
            return .systemGreen
        } else {  //the other user sent the message
            return .link
        }
        
    }
    
    func audioTintColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return .white
    }
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        
        return .white
        
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        let sender = message.sender
        
        //current sender
        if sender.senderId == selfSender?.senderId {
            if let url = currentUserPhotoUrl {
                
                avatarView.sd_setImage(with: url)
                
            } else {
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(email: email)
                let path = "profileImages/\(safeEmail)_profile_photo.png"
                StorageManager.shared.downloadUrl(path: path) { result in
                    switch result {
                    case .success(let url):
                        UserDefaults.standard.set(url, forKey: "\(safeEmail)")
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print("error: \(error)")
                    }
                }
            }
            
            
            
            
            //message receiver
        } else {
            if let url = otherUserPhotoUrl {
                avatarView.sd_setImage(with: url)
            } else {
                
                let email = self.otherUserEmail
                let safeEmail = DatabaseManager.safeEmail(email: email)
                let path = "profileImages/\(safeEmail)_profile_photo.png"
                StorageManager.shared.downloadUrl(path: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)
                        }
                    case .failure(let error):
                        print("error: \(error)")
                    }
                }
                
                
            }
        }
    }
    
}

extension DetailedMessageViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true)
        guard let uniqueId = createMessageId(), let selfSender = selfSender else {
            return
        }
        // Media type is image
        if let image = info[ .editedImage] as? UIImage , let imgData = image.pngData()  {
            
            let progressIndicator = JGProgressHUD(style: .light)
            progressIndicator.textLabel.text = "Sending photo..."
            progressIndicator.show(in: view)
            let filename = "conversation_"+uniqueId+"_photos".replacingOccurrences(of: " ", with: "-")+".png"
            StorageManager.shared.uploadMessagePhoto(data: imgData, filename: filename) { result in
                switch result {
                case .success(let urlString):
                    guard let url = URL(string: urlString), let imagePlaceholder = UIImage(systemName: "video.fill") else {
                        return
                    }
                    let media = Media(url: url,image: image ,placeholderImage: imagePlaceholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: uniqueId, sentDate: Date(), kind: .photo(media))
                    
                    self.messagesCollectionView.reloadDataAndKeepOffset()
                    if self.isNew {
                        DatabaseManager.shared.createNewChat(otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, firstMessage: message) { success in
                            if success {
                                progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                                progressIndicator.textLabel.text = ""
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                                print("photo message sent!")
                                let conversationId = "conversation_\(message.messageId)"
                                self.conversationId = conversationId
                                self.listenForMessages(id: conversationId)
                                
                            } else {
                                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            }
                        }
                    } else {
                        guard let id = self.conversationId else {
                            return
                        }
                        DatabaseManager.shared.sendMessage(conversation: id, otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, newMessage: message) { success in
                            
                            if success {
                                progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                                progressIndicator.textLabel.text = ""
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                                print("photo message sent!")
                                
                            } else {
                                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            }
                        }
                    }
                case .failure(let error):
                    progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                    progressIndicator.textLabel.text = "Error sending photo!\nNo internet connection!"
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                    print("error: \(error)")
                }
            }
            if networkMonitor.currentPath.status == .requiresConnection || networkMonitor.currentPath.status == .unsatisfied {
                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                progressIndicator.textLabel.text = "Error sending photo!\nNo internet connection!"
                progressIndicator.dismiss(afterDelay: 2, animated: true)
            }
            // Media type is video
        } else if let videoUrl = info[.mediaURL] as? URL {
            
            let progressIndicator = JGProgressHUD(style: .light)
            progressIndicator.textLabel.text = "Sending video..."
            progressIndicator.show(in: view)
            var filename = "conversation_"+uniqueId+"_video.mov"
            filename = filename.replacingOccurrences(of: " ", with: "-")
            StorageManager.shared.uploadMessageVideo(url: videoUrl, filename: filename) { result in
                switch result {
                case .success(let urlString):
                    guard let url = URL(string: urlString), let imagePlaceholder = UIImage(systemName: "video.fill") else {
                        return
                    }
                    
                    let media = Media(url: url,image: imagePlaceholder ,placeholderImage: imagePlaceholder, size: .zero)
                    
                    let message = Message(sender: selfSender, messageId: uniqueId, sentDate: Date(), kind: .video(media))
                    
                    if self.isNew {
                        DatabaseManager.shared.createNewChat(otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, firstMessage: message) { success in
                            if success {
                                progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                                progressIndicator.textLabel.text = ""
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                                print("video message sent!")
                                let conversationId = "conversation_\(message.messageId)"
                                self.conversationId = conversationId
                                self.listenForMessages(id: conversationId)
                                
                            } else {
                                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            }
                        }
                    } else {
                        guard let id = self.conversationId else {
                            return
                        }
                        DatabaseManager.shared.sendMessage(conversation: id, otherUserEmail: self.otherUserEmail, name: self.otherUserUsername, newMessage: message) { success in
                            
                            if success {
                                progressIndicator.indicatorView = JGProgressHUDSuccessIndicatorView()
                                progressIndicator.textLabel.text = ""
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                                print("video message sent!")
                                
                            } else {
                                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                                progressIndicator.dismiss(afterDelay: 2, animated: true)
                            }
                        }
                    }
                    
                case .failure(let error):
                    progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                    progressIndicator.textLabel.text = "Error sending video!\nNo internet connection!"
                    progressIndicator.dismiss(afterDelay: 2, animated: true)
                    print("error: \(error)")
                }
            }
            if networkMonitor.currentPath.status == .requiresConnection || networkMonitor.currentPath.status == .unsatisfied {
                progressIndicator.indicatorView = JGProgressHUDErrorIndicatorView()
                progressIndicator.textLabel.text = "Error sending video!\nNo internet connection!"
                progressIndicator.dismiss(afterDelay: 2, animated: true)
            }
        }
        
    }
}


extension DetailedMessageViewController: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            audioRecorder.stop()
            audioRecorder = nil
            mic.setImage(UIImage(systemName: "mic"), for: .normal)
            print("error in recording audio")
        }
    }
}







