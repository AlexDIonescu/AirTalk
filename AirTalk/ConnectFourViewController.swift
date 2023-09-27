//
//  ConnectFourViewController.swift
//  AirTalk
//
//  Created by Alex Ionescu on 04.07.2023.
//

import UIKit


class ConnectFourViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBlue
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "info.circle"), style: .done, target: self, action: #selector(showInfo))
        DatabaseManager.shared.gameDataExists(id: convId) { exists in
            if !exists {
                let alert = UIAlertController(title: "Start a new game", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Start", style: .default, handler: { action in
                    DatabaseManager.shared.checkIfGameInProgressOnce(id: self.convId) { progress in
                        if progress {
                            alert.dismiss(animated: false)
                            let range = self.otherUserEmail.range(of: "-")
                            var email = self.otherUserEmail.replacingOccurrences(of: "-", with: "@", range: range)
                            email = email.replacingOccurrences(of: "-", with: ".")
                            let alert1 = UIAlertController(title: "Game already started by \(email)", message: nil, preferredStyle: .alert)
                            alert1.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                                alert1.dismiss(animated: true)
                            }))
                            self.present(alert1, animated: true)
                            
                        } else {
                            
                            DatabaseManager.shared.createNewConnectFourGame(id: self.convId, otherUserEmail: self.otherUserEmail)
                            
                            
                        }
                    }
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                    alert.dismiss(animated: true)
                }))
                self.present(alert, animated: true)
                
            }
            
        }
        DatabaseManager.shared.checkIfGameInProgress(id: self.convId) { progress in
            if progress {
                self.resetArrowButtons()
            }
        }
        DatabaseManager.shared.getPlayerColor(id: self.convId) { color in
            self.myColor = color
        }
        DatabaseManager.shared.getTurns(id: self.convId) { data in
            self.numberOfTurns = data
        }
        self.listenForChanges()
        self.checkPlayerTurn()
        self.checkForWins()
        self.combinationsCheck()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBar.tintColor = nil
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.tintColor = .white
    }
    
    var convId = ""
    var otherUserEmail = ""
    var playerTurn = 0
    var playerTurnEmail = ""
    var myColor = ""
    var buttonNumbersArray = Array(repeating: -1, count: 42)
    var fullBoard = [0,1,2,3,4,5,6]
    var column1 = [0,7,14,21,28,35]
    var column2 = [1,8,15,22,29,36]
    var column3 = [2,9,16,23,30,37]
    var column4 = [3,10,17,24,31,38]
    var column5 = [4,11,18,25,32,39]
    var column6 = [5,12,19,21,33,40]
    var column7 = [6,13,10,21,34,41]
    var columns = [[-1,7,14,21,28,35],[1,8,15,22,29,36], [2,9,16,23,30,37], [3,10,17,24,31,38],
                   [4,11,18,25,32,39], [5,12,19,21,33,40], [6,13,10,21,34,41]]
    var numberOfTurns = 0
    var winningCombinations = [
        // Horizontal combinations
        [0, 1, 2, 3], [1, 2, 3, 4], [2, 3, 4, 5], [3, 4, 5, 6],
        [7, 8, 9, 10], [8, 9, 10, 11], [9, 10, 11, 12], [10, 11, 12, 13],
        [14, 15, 16, 17], [15, 16, 17, 18], [16, 17, 18, 19], [17, 18, 19, 20],
        [21, 22, 23, 24], [22, 23, 24, 25], [23, 24, 25, 26], [24, 25, 26, 27],
        [28, 29, 30, 31], [29, 30, 31, 32], [30, 31, 32, 33], [31, 32, 33, 34],
        [35, 36, 37, 38], [36, 37, 38, 39], [37, 38, 39, 40], [38, 39, 40, 41],
        
        // Vertical combinations
        [0, 7, 14, 21], [1, 8, 15, 22], [2, 9, 16, 23], [3, 10, 17, 24],
        [4, 11, 18, 25], [5, 12, 19, 26], [6, 13, 20, 27],
        
        // Diagonal combinations (top-left to bottom-right)
        [7, 14, 21, 28], [8, 15, 22, 29], [9, 16, 23, 30], [10, 17, 24, 31],
        [11, 18, 25, 32], [12, 19, 26, 33], [13, 20, 27, 34],
        
        // Diagonal combinations (top-right to bottom-left)
        [14, 21, 28, 35], [15, 22, 29, 36], [16, 23, 30, 37], [17, 24, 31, 38],
        [18, 25, 32, 39], [19, 26, 33, 40], [20, 27, 34, 41],
        
        // Additional combinations
        [0, 8, 16, 24], [1, 9, 17, 25], [2, 10, 18, 26], [3, 11, 19, 27],
        [7, 15, 23, 31], [8, 16, 24, 32], [9, 17, 25, 33], [10, 18, 26, 34],
        [14, 22, 30, 38], [15, 23, 31, 39], [16, 24, 32, 40], [17, 25, 33, 41],
        [35, 29, 23, 17], [6, 12, 18, 24], [37, 31, 25, 19], [38, 32, 26, 20], [29, 23, 17, 11]
    ]
    
    
    @objc func showInfo() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "gameInfo") as! ConnectFourInfoViewController
        vc.id = self.convId
        vc.otherUserEmail = self.otherUserEmail
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func checkPlayerTurn() {
        DatabaseManager.shared.checkforPlayerTurn(id: self.convId) { value in
            let values = value.components(separatedBy: ",")
            guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                return
            }
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            self.playerTurnEmail = values[0]
            
            if values[1] == "yellow" {
                self.playerTurn = 0
                if safeEmail == self.playerTurnEmail {
                    self.playerTurnLabel.text = "You(🟡)"
                } else {
                    let range = self.playerTurnEmail.range(of: "-")
                    var email = self.playerTurnEmail.replacingOccurrences(of: "-", with: "@", range: range)
                    email = email.replacingOccurrences(of: "-", with: ".")
                    self.playerTurnLabel.text = "\(email)(🟡)"
                }
                
            } else if values[1] == "red" {
                self.playerTurn = 1
                if safeEmail == self.playerTurnEmail {
                    self.playerTurnLabel.text = "You(🔴)"
                } else {
                    let range = self.playerTurnEmail.range(of: "-")
                    var email = self.playerTurnEmail.replacingOccurrences(of: "-", with: "@", range: range)
                    email = email.replacingOccurrences(of: "-", with: ".")
                    self.playerTurnLabel.text = "\(email)(🔴)"
                }
            }
            
        }
    }
    
    func checkForWins() {
        DatabaseManager.shared.checkForWins(id: convId) { winner in
            if winner == self.myColor {
                for button in self.arrowButtons {
                    button.isEnabled = false
                }
                for button in self.GameButtons {
                    button.isUserInteractionEnabled = false
                }
                self.resetButton.isEnabled = true
                let alert = UIAlertController(title: "Congratulations!", message: "You win!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            } else if winner == "rematch" {
                for button in self.arrowButtons {
                    button.isEnabled = false
                }
                for button in self.GameButtons {
                    button.isUserInteractionEnabled = false
                }
                self.resetButton.isEnabled = true
                let alert = UIAlertController(title: "Rematch", message: "You are too good!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                self.resetButton.isEnabled = true
            } else if winner != self.myColor && winner != "none" {
                for button in self.arrowButtons {
                    button.isEnabled = false
                }
                for button in self.GameButtons {
                    button.isUserInteractionEnabled = false
                }
                self.resetButton.isEnabled = true
                let alert = UIAlertController(title: "Not good!", message: "You lose!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
            else if winner == "none" {
                for button in self.arrowButtons {
                    button.isEnabled = true
                }
                for button in self.GameButtons {
                    button.isUserInteractionEnabled = true
                }
                self.resetButton.isEnabled = false
            }
        }
    }
    
    func changePlayerTurn() {
        var player = ""
        
        
        if self.playerTurn == 0 {
            player = "\(otherUserEmail)" + ",red"
        } else {
            player = "\(otherUserEmail)" + ",yellow"
            
        }
        DatabaseManager.shared.changePlayerTurn(id: self.convId, player: player)
        
    }
    
    func listenForChanges() {
        
        DatabaseManager.shared.listenForGameChanges(id: self.convId) { stringMatrix in
            let matrix = stringMatrix.components(separatedBy: ",")
            
            for i in 0..<self.buttonNumbersArray.count {
                if let num = Int(matrix[i]) {
                    self.buttonNumbersArray[i] = num
                }
            }
            print("numbers: \(self.buttonNumbersArray)")
            
            for i in 0..<self.buttonNumbersArray.count {
                
                if self.buttonNumbersArray[i] == -1 {
                    
                    self.GameButtons[i].tintColor = .black
                    self.GameButtons[i].layer.cornerRadius = self.GameButtons[i].frame.size.width/2
                    self.GameButtons[i].clipsToBounds = true
                    self.GameButtons[i].layer.borderWidth = 2
                    self.GameButtons[i].layer.borderColor = UIColor.gray.cgColor
                    
                } else if self.buttonNumbersArray[i] == 0 {
                    var tag = self.GameButtons[i].tag
                    if tag == -1 {
                        tag = 0
                    }
                    if self.fullBoard.contains(tag) {
                        if let button = self.view.viewWithTag(self.columnCheck(tag: tag)) as? UIButton {
                            button.isEnabled = false
                        }
                    }
                    self.GameButtons[i].tintColor = .systemYellow
                    self.GameButtons[i].layer.cornerRadius = self.GameButtons[i].frame.size.width/2
                    self.GameButtons[i].clipsToBounds = true
                    self.GameButtons[i].layer.borderWidth = 2
                    self.GameButtons[i].layer.borderColor = UIColor.gray.cgColor
                } else if self.buttonNumbersArray[i] == 1 {
                    var tag = self.GameButtons[i].tag
                    if tag == -1 {
                        tag = 0
                    }
                    if self.fullBoard.contains(tag) {
                        if let button = self.view.viewWithTag(self.columnCheck(tag: tag)) as? UIButton {
                            button.isEnabled = false
                        }
                    }
                    self.GameButtons[i].tintColor = .systemRed
                    self.GameButtons[i].layer.cornerRadius = self.GameButtons[i].frame.size.width/2
                    self.GameButtons[i].clipsToBounds = true
                    self.GameButtons[i].layer.borderWidth = 2
                    self.GameButtons[i].layer.borderColor = UIColor.gray.cgColor
                }
            }
            
        }
        
    }
    
    func columnCheck(tag: Int) -> Int{
        if column1.contains(tag) {
            return 100
        } else if column2.contains(tag) {
            return 101
        } else if column3.contains(tag) {
            return 102
        } else if column4.contains(tag) {
            return 103
        } else if column5.contains(tag) {
            return 104
        } else if column6.contains(tag) {
            return 105
        } else if column7.contains(tag) {
            return 106
        }
        return 1000
    }
    
    @IBAction func column1Tapped(_ sender: UIButton) {
        colorCheck(tag: 35, arrowTag: 100)
    }
    
    @IBAction func column2Tapped(_ sender: UIButton) {
        colorCheck(tag: 36, arrowTag: 101)
    }
    
    @IBAction func column3Tapped(_ sender: UIButton) {
        colorCheck(tag: 37, arrowTag: 102)
    }
    @IBAction func column4Tapped(_ sender: UIButton) {
        colorCheck(tag: 38, arrowTag: 103)
    }
    @IBAction func column5Tapped(_ sender: UIButton) {
        colorCheck(tag: 39, arrowTag: 104)
    }
    @IBAction func column6Tapped(_ sender: UIButton) {
        colorCheck(tag: 40, arrowTag: 105)
    }
    @IBAction func column7Tapped(_ sender: UIButton) {
        colorCheck(tag: 41, arrowTag: 106)
    }

    @IBOutlet weak var playerTurnLabel: UILabel!
    
    @IBOutlet var GameButtons: [UIButton]!
    
    
    @IBOutlet weak var resetButton: UIButton!
    
    @IBOutlet var arrowButtons: [UIButton]!
    
    
    @IBAction func resetButtonTapped(_ sender: UIButton) {
        DatabaseManager.shared.resetGame(id: self.convId, otherUserEmail: self.otherUserEmail)
        numberOfTurns = 0
        playerTurn = 0
        resetArrowButtons()
    }
    
    
    @IBAction func buttonTapped(_ sender: UIButton) {
        
        
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        if self.playerTurnEmail == safeEmail {
            if sender.tag == 100 {
                
                
                colorCheck(tag: 35, arrowTag: 100)
                
            } else if sender.tag == 101 {
                colorCheck(tag: 36, arrowTag: 101)
            } else if sender.tag == 102 {
                colorCheck(tag: 37, arrowTag: 102)
            } else if sender.tag == 103 {
                colorCheck(tag: 38, arrowTag: 103)
            } else if sender.tag == 104 {
                colorCheck(tag: 39, arrowTag: 104)
            } else if sender.tag == 105 {
                colorCheck(tag: 40, arrowTag: 105)
            } else if sender.tag == 106 {
                colorCheck(tag: 41, arrowTag: 106)
            }
        } else {
            let alert = UIAlertController(title: "Not your turn!", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    func resetArrowButtons() {
        for button in arrowButtons {
            button.isEnabled = true
        }
        for button in self.GameButtons {
            button.isUserInteractionEnabled = true
        }
    }
    
    func colorCheck(tag: Int, arrowTag: Int) {
        var nTag = tag
        if nTag == 0 {
            nTag = -1
        }
        if let button = self.view.viewWithTag(nTag) as? UIButton {
            
            if button.tintColor != .black {
                colorCheck(tag: nTag - 7, arrowTag: arrowTag)
            } else {
                if self.fullBoard.contains(tag) {
                    if let button = self.view.viewWithTag(arrowTag) as? UIButton {
                        button.isEnabled = false
                    }
                    for arr in self.columns {
                        if let lastElement = arr.last {
                            if arrowTag - lastElement == 65 {
                                for tag in arr {
                                    if let button = self.view.viewWithTag(tag) as? UIButton {
                                        button.isUserInteractionEnabled = false
                                    }
                                }
                                break
                            }
                        }
                        
                    }
                   
                    
                }
                if self.playerTurn == 0 {
                    self.numberOfTurns += 1
                    
                    button.tintColor = .systemYellow
                    self.buttonNumbersArray[tag] = 0
                    let data = self.buttonNumbersArray.map { String($0) }.joined(separator: ",")
                    DatabaseManager.shared.addDataToGame(id: self.convId, matrix: data, turnsNumber: self.numberOfTurns)
                    changePlayerTurn()
                    self.playerTurn = 1
                    
                    combinationsCheck()
                } else {
                    self.numberOfTurns += 1
                    
                    button.tintColor = .systemRed
                    self.buttonNumbersArray[tag] = 1
                    let data = self.buttonNumbersArray.map { String($0) }.joined(separator: ",")
                    DatabaseManager.shared.addDataToGame(id: self.convId, matrix: data, turnsNumber: self.numberOfTurns)
                    
                    changePlayerTurn()
                    self.playerTurn = 0
                    combinationsCheck()
                }
                
            }
        }
        
    }
    
    func combinationsCheck() {
        DatabaseManager.shared.checkForWinsOnce(id: self.convId) { winner in
            if winner == "none" {
                var rematch = 0
                for combination in self.winningCombinations {
                    var win1 = 0
                    var win0 = 0
                    for index in combination {
                        if self.buttonNumbersArray[index] == 1 {
                            win1 += 1
                        } else if self.buttonNumbersArray[index] == 0 {
                            win0 += 1
                        }
                    }
                    if win1 == 4 {
                        DatabaseManager.shared.addWinner(id: self.convId, winner: "red")
                        
                        rematch = 1
                        break
                        
                    } else if win0 == 4 {
                        
                        DatabaseManager.shared.addWinner(id: self.convId, winner: "yellow")
                        
                        rematch = 1
                        break
                    }
                    
                }
                if rematch == 0 && self.numberOfTurns == 42 {
                    DatabaseManager.shared.addWinner(id: self.convId, winner: "rematch")
                    
                }
            }
        }
        

}
    
}

