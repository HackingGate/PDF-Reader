//
//  OutlineTableViewCell.swift
//  PDFReader
//
//  Created by ERU on H30/01/02.
//  Copyright © 平成30年 Hacking Gate. All rights reserved.
//

import UIKit

class OutlineTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pageLabel: UILabel!
    @IBOutlet weak var titleTrailing: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
