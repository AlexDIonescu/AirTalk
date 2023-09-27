//
//  NewGroupChatTableViewCell.swift
//  AirTalk
//
//  Created by Alex Ionescu on 21.03.2023.
//

import UIKit
import SDWebImage

class NewGroupChatTableViewCell: UITableViewCell {
    
    //id used for dequeque reusable cells - memory efficient
    static let id = "NewGroupChatTableViewCell"
    
    //user's profile picture
    let userImageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        return imageView
    }()
    //user's username
    let userNamelabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 0
        return label
    }()
    
    //user's email
    let emailLabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNamelabel)
        contentView.addSubview(emailLabel)
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        userImageView.frame = CGRect(x: 10, y: 10, width: 40, height: 40)
        userNamelabel.frame = CGRect(x: userImageView.frame.maxX + 15, y: 5, width: contentView.frame.width - userImageView.frame.width - 20, height: contentView.frame.height - 40)
        emailLabel.frame = CGRect(x: userImageView.frame.maxX + 15, y: userNamelabel.frame.maxY + 5, width: contentView.frame.width - userImageView.frame.width - 20, height: (contentView.frame.height - 20)/2)
        
    }
    
    func configure(model: UserSearchResult) {
        self.userNamelabel.text = model.username
        
        //make the email more user-friendly( "@" and "." were deleted in order to be stored in Firebase Database
        let range = model.email.range(of: "-")
        var email = model.email.replacingOccurrences(of: "-", with: "@", range: range)
        email = email.replacingOccurrences(of: "-", with: ".")
        self.emailLabel.text = email
        
        //get the profile picture for the given email
        let path = "profileImages/\(model.email)_profile_photo.png"
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

