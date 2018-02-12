//
//  SearchResultsTableViewController.swift
//  PDFReader
//
//  Created by ERU on 2018/01/31.
//  Copyright © 2018年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

class SearchResultsTableViewController: UITableViewController {
    
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet var footerView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    
    var delegate: SettingsDelegate!
    var pdfDocument: PDFDocument?
    var displayBox: PDFDisplayBox = .cropBox
    var searchResults = [PDFSelection]()
    var currentSearchText = ""
    
    override func viewWillAppear(_ animated: Bool) {
        if let presentingViewController = presentingViewController as? PopoverTableViewController {
            presentingViewController.preferredContentSize = CGSize(width: presentingViewController.preferredContentSize.width, height: presentingViewController.preferredContentSize.height + 300)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if let presentingViewController = presentingViewController as? PopoverTableViewController {
            presentingViewController.preferredContentSize = CGSize(width: presentingViewController.preferredContentSize.width, height: presentingViewController.preferredContentSize.height - 300)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        pdfDocument?.delegate = self
        updateStatusLabel(showResult: false)
    }
    
    func updateStatusLabel(showResult: Bool) {
        if showResult {
            if searchResults.count > 1 {
                statusLabel.text = "\(searchResults.count) matches found"
            } else if searchResults.count == 1 {
                statusLabel.text = "1 match found"
            } else {
                statusLabel.text = "No matches found"
            }
        } else {
            statusLabel.text = "Tap Search to start"
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            return footerView.bounds.height
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return footerView
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)

        let selection = searchResults[indexPath.row]
        let page = selection.pages[0]
        
        // image
        let rect = page.bounds(for: displayBox)
        let aspectRatio = rect.width / rect.height
        
        let width: CGFloat = 50.0
        let height = width / aspectRatio
        
        cell.imageView?.image = page.thumbnail(of: CGSize(width: width, height: height), for: displayBox)
        
        // title text
        if let textLabel = cell.textLabel {
            textLabel.text = ""
            if let outlineLabel = pdfDocument?.outlineItem(for: selection)?.label {
                textLabel.text = "\(outlineLabel) "
            }
            if let pageLabel = page.label {
                textLabel.text?.append(contentsOf: "Page \(pageLabel)")
            }
        }
        
        // detail text
        let extendSelection = selection.copy() as! PDFSelection
        extendSelection.extend(atStart: 10)
        extendSelection.extend(atEnd: 90)
        extendSelection.extendForLineBoundaries()
        
        let range = (extendSelection.string! as NSString).range(of: selection.string!, options: .caseInsensitive)
        let attrstr = NSMutableAttributedString(string: extendSelection.string!)
        attrstr.addAttribute(.backgroundColor, value: UIColor.yellow, range: range)
        
        cell.detailTextLabel?.attributedText = attrstr

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = searchResults[indexPath.row]
        
        if UIDevice.current.userInterfaceIdiom != .pad {
            self.dismiss(animated: false, completion: nil)
            self.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        delegate.goToSelection(selection)
        delegate.setCurrentSelection(selection, animate: true)
    }

}

extension SearchResultsTableViewController: PDFDocumentDelegate {
    func didMatchString(_ instance: PDFSelection) {
        if instance.string != nil && instance.pages.count != 0 {
            searchResults.append(instance)
            if tableView.dataSource != nil {
                tableView.beginUpdates()
                let indexPath = IndexPath(row: searchResults.count-1, section: 0)
                tableView.insertRows(at: [indexPath], with: .none)
                tableView.endUpdates()
            }
        }
    }
    
    func documentDidBeginPageFind(_ notification: Notification) {
        statusLabel.text = "Searching..."
        if let userInfo = notification.userInfo, let index = userInfo["PDFDocumentPageIndex"] as? Int, let pageCount = pdfDocument?.pageCount {
            progressView.progress = Float(index+1) / Float(pageCount)
        }
    }
    
    func documentDidEndDocumentFind(_ notification: Notification) {
        updateStatusLabel(showResult: true)
    }
    
}

extension SearchResultsTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == currentSearchText {
            tableView.dataSource = self
            tableView.reloadData()
            updateStatusLabel(showResult: true)
        } else {
            tableView.dataSource = nil
            tableView.reloadData()
            updateStatusLabel(showResult: false)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchBar.text == currentSearchText {
            return
        }
        tableView.dataSource = self
        searchResults.removeAll()
        tableView.reloadData()
        if let searchText = searchBar.text {
            currentSearchText = searchText
            delegate.fullTextSearch(string: currentSearchText)
        }
    }
}
