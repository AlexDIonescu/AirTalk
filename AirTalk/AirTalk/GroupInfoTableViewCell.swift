//
//  GroupDetailsTableViewCell.swift
//  AirTalk
//
//  Created by Alex Ionescu on 06.04.2023.
//



import UIKit
import SDWebImage
import FirebaseDatabase

class GroupInfoTableViewCell: UITableViewCell {
    
    //id used for dequeque reusable cells - memory efficient
    static let id = "GroupInfoTableViewCell"
    
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
    let selfLabel : UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .systemGray
        label.numberOfLines = 0
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNamelabel)
        contentView.addSubview(emailLabel)
        contentView.addSubview(selfLabel)
        
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
        userNamelabel.frame = CGRect(x: userImageView.frame.maxX + 15, y: 5, width: contentView.frame.width / 2, height: contentView.frame.height - 40)
        emailLabel.frame = CGRect(x: userImageView.frame.maxX + 15, y: userNamelabel.frame.maxY + 5, width: contentView.frame.width / 2, height: (contentView.frame.height - 20)/2)
        selfLabel.frame = CGRect(x: emailLabel.frame.maxX + 50, y: 12, width: 50, height: 30)

    }
    
    func configure(model: String) {
        
        //make the email more user-friendly( "@" and "." were deleted in order to be stored in Firebase Database)
        let range = model.range(of: "-")
        var email = model.replacingOccurrences(of: "-", with: "@", range: range)
        email = email.replacingOccurrences(of: "-", with: ".")
        self.emailLabel.text = email
        guard let selfEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        if selfEmail == email {
            print(selfEmail)
            print(email)
            print("me")
            self.selfLabel.text = "~Me"
        }
        
        GroupDatabaseManager.shared.getUsername(email: model) { result in
            switch result {
            case .success(let username):
                self.userNamelabel.text = username
                
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

        
        
        
        //get the profile picture for the given email
        let path = "profileImages/\(model)_profile_photo.png"
        
        
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


