//
//  PaddingLabel.swift
//  PDFReader
//
//  Created by ERU on H29/12/25.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit

class PaddingLabel: UILabel {
    
    @IBInspectable var top: CGFloat = 0.0
    @IBInspectable var left: CGFloat = 0.0
    @IBInspectable var bottom: CGFloat = 0.0
    @IBInspectable var right: CGFloat = 0.0
    
    override func drawText(in rect: CGRect) {
        let newRect = rect.inset(by: UIEdgeInsets(top: top, left: left, bottom: bottom, right: right))
        super.drawText(in: newRect)
    }
    
    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height += top + bottom
        contentSize.width += left + right
        return contentSize
    }
    
}
