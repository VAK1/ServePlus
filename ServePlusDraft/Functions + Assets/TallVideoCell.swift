//
//  TallVideoCell.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 8/24/21.
//
//  Class for dequeuing a cell for a portrait video


import UIKit

class TallVideoCell: UITableViewCell {
    
    @IBOutlet weak var VideoPlayer: UIImageView!
    @IBOutlet weak var serveCountLabel: UILabel!
    @IBOutlet weak var vidDurationLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var scoresButton: UIButton!
    var index: Int!
    var pSegue: ((Int) -> Void)?
    
    @IBAction func getFeedback(_ sender: UIButton) {
        self.pSegue!(self.index)
    }


    override func awakeFromNib() {
        super.awakeFromNib()
        self.scoresButton.backgroundColor = UIColor.systemBlue
        
        self.scoresButton.layer.cornerRadius = 15.0
        self.scoresButton.layer.shadowColor   = UIColor.systemTeal.cgColor
        self.scoresButton.layer.shadowOffset  = CGSize(width: 0.0, height: 0.0)
        self.scoresButton.layer.shadowRadius  = 8
        self.scoresButton.layer.shadowOpacity       = 0.5


        // Initialization code
    }
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {

        // Configure the view for the selected state
    }
    
}
