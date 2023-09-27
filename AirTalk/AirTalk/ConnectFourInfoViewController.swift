//
//  ConnectFourInfoViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 23.07.2023.
//

import UIKit

class ConnectFourInfoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print(otherUserEmail)
        self.title = "Wins"
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        DatabaseManager.shared.getWinsData(id: id, otherUserEmail: otherUserEmail) { users in
            self.player1Label.text = users[safeEmail]
            self.player1Label.textColor = .white
            self.player2Label.text = users[self.otherUserEmail]
            self.player2Label.textColor = .white

        }
        DatabaseManager.shared.getRematchData(id: id) { value in
            self.rematchesLabel.text = "Rematches: \(value)"
            self.rematchesLabel.textColor = .white
        }
       
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBar.tintColor = nil
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.tintColor = .white
    }
    
    var id = ""
    var otherUserEmail = ""
    
    @IBOutlet weak var player1Label: UILabel!
    
    
    @IBOutlet weak var player2Label: UILabel!
    
    @IBOutlet weak var rematchesLabel: UILabel!
    
}
