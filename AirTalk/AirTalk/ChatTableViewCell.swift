//
//  ChatTableViewCell.swift
//  AirTalk
//
//  Created by Alex Ionescu on 14.02.2023.
//

import UIKit
import SDWebImage
import FirebaseStorage

class ChatTableViewCell: UITableViewCell {
    
    static let id = "ChatTableViewCell"
    let userImageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 35
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    let userNamelabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.numberOfLines = 0
        return label
    }()
    
    let messagelabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.numberOfLines = 2
        return label
    }()
    let newMessagesCount : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.layer.borderWidth = 1
        label.layer.cornerRadius = 12
        label.layer.borderColor = UIColor.link.cgColor
        return label
    }()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNamelabel)
        contentView.addSubview(messagelabel)
        //contentView.addSubview(newMessagesCount)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 10, y: 10, width: 70, height: 70)
        userNamelabel.frame = CGRect(x: userImageView.frame.maxX + 15, y: 5, width: contentView.frame.width - userImageView.frame.width - 20, height: (contentView.frame.height - 40)/2)
        messagelabel.frame = CGRect(x: userImageView.frame.maxX + 15, y: userNamelabel.frame.maxY + 5, width: contentView.frame.width - userImageView.frame.width - 60, height: (contentView.frame.height - 20)/2)
        newMessagesCount.frame = CGRect(x: messagelabel.frame.maxX + 8, y: messagelabel.frame.maxY - 39 , width: 25, height: (contentView.frame.height - 40)/2)
        
    }
    
    func configure(model: Conversation) {
        print(model)
        self.messagelabel.text = model.latestMessage.text
        self.userNamelabel.text = model.name
        self.newMessagesCount.text = "22"
        if model.groupPhoto == "" {
            let path = "profileImages/\(model.otherUserEmail)_profile_photo.png"
            StorageManager.shared.downloadUrl(path: path) { result in
                switch result {
                    
                case .success(let url):
                    
                    DispatchQueue.main.async {
                        self.userImageView.sd_setImage(with: url)
                        
                    }
                case .failure(let error):
                    print("error: \(error)")
                }
            }
        } else {
            let path = "profileImages/\(model.groupPhoto)_profile_photo.png"
            let ref = Storage.storage().reference().child(path)
            
        
            StorageManager.shared.downloadUrl(path: path) { result in
                switch result {
                    
                case .success(let url):
                    
                    DispatchQueue.main.async {
                        self.userImageView.sd_setImage(with: url)
                        
                    }
                case .failure(let error):
                    print("error: \(error)")
                }
            }
        }
    }
}
