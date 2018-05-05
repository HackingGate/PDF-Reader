//
//  OutlineTableViewController.swift
//  PDFReader
//
//  Created by ERU on H29/12/29.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

class OutlineTableViewController: UITableViewController {
    
    var delegate: SettingsDelegate!
    var outlineRoot: PDFOutline?
    var outlineArray: NSMutableArray = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        if let outline = outlineRoot {
            addChild(outline: outline)
        }
    }
    
    func addChild(outline: PDFOutline) {
        for i in 0..<outline.numberOfChildren {
            if let outlineChild = outline.child(at: i) {
                outlineArray.add(outlineChild)
                if outlineChild.numberOfChildren > 0 {
                    addChild(outline: outlineChild)
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return outlineArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OutlineCell", for: indexPath) as! OutlineTableViewCell
        if let outline = outlineArray[indexPath.row] as? PDFOutline {
            cell.titleLabel.text = outline.label
            
            if let page = outline.destination?.page, let index = delegate.pageIndex(page: page) {
                cell.pageLabel.text = String(index + 1)
            }
            cell.titleTrailing.constant = cell.pageLabel.intrinsicContentSize.width + cell.pageLabel.layoutMargins.right + 16
            
            var leadingConstant: CGFloat = 0
            var parent = outline.parent
            while parent != nil && parent != outlineRoot {
                leadingConstant += 16
                parent = parent?.parent
            }
            cell.titleLeading.constant = leadingConstant
            if leadingConstant > 0 {
                cell.titleLabel.font = UIFont.systemFont(ofSize: 14)
            } else {
                cell.titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let outline = outlineArray[indexPath.row] as? PDFOutline {
            if let page = outline.destination?.page {
                delegate.goToPage(page: page)
                navigationController?.popViewController(animated: true)
            }
        }
    }
}
