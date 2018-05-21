//
//  SearchViewController.swift
//  PDFReader
//
//  Created by ERU on 2018/05/07.
//  Copyright © 2018 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

class SearchViewController: UITableViewController {
    
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet var footerView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var searchWeb: UIBarButtonItem!
    @IBOutlet weak var searchWikipedia: UIBarButtonItem!
    var searchBar = UISearchBar()

    var delegate: SettingsDelegate!
    var pdfDocument: PDFDocument?
    var displayBox: PDFDisplayBox = .cropBox
    var searchResults = [PDFSelection]()
    var currentSearchText = ""
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchBar.becomeFirstResponder()
        
        if let string = searchResults.first?.string {
            currentSearchText = string
            searchBar.text = string
            searchWeb.isEnabled = true
            searchWikipedia.isEnabled = true
        } else {
            searchWeb.isEnabled = false
            searchWikipedia.isEnabled = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        searchBar.delegate = self
        searchBar.showsCancelButton = true
        navigationItem.titleView = searchBar
        
        self.tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        tableView.removeObserver(self, forKeyPath: "contentSize")
    }
    
    func updateStatusLabel() {
        if searchResults.count > 1 {
            statusLabel.text = String(format: NSLocalizedString("%d matches found", comment: "matches found"), searchResults.count)
        } else if searchResults.count == 1 {
            statusLabel.text = NSLocalizedString("1 match found", comment: "1 match")
        } else {
            statusLabel.text = NSLocalizedString("No matches found", comment: "no match")
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
        
        if let imageView = cell.viewWithTag(1) as? UIImageView {
            let width: CGFloat = imageView.frame.width // must be same as IB width
            let height = width / aspectRatio
            imageView.image = page.thumbnail(of: CGSize(width: width, height: height), for: displayBox)
        }
        
        // title text
        if let textLabel = cell.viewWithTag(2) as? UILabel {
            // no workaround found for iOS 11.2 and later, comment out
            /*
            textLabel.text = ""
            if let outlineLabel = pdfDocument?.outlineItem(for: selection)?.label {
                textLabel.text = "\(outlineLabel) "
            }
            if let pageLabel = page.label {
                textLabel.text?.append(contentsOf: String(format: NSLocalizedString("Page %@", comment: "page index"), pageLabel))
            }
             */
            if let currentIndex = pdfDocument?.index(for: page) {
                textLabel.text = String(currentIndex+1)
                print(textLabel.constraints.debugDescription)
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
        
        if let detailTextLabel = cell.viewWithTag(3) as? UILabel {
            detailTextLabel.attributedText = attrstr
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = searchResults[indexPath.row]
        
        delegate.goToSelection(selection)

        if UIDevice.current.userInterfaceIdiom != .pad {
            self.dismiss(animated: true) {
                self.delegate.setCurrentSelection(selection, animate: true)
            }
        } else {
            delegate.setCurrentSelection(selection, animate: true)
        }
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        navigationController?.preferredContentSize = tableView.contentSize
    }

    // MARK: - IB Actions
    
    @IBAction func searchWeb(_ sender: UIBarButtonItem) {
        if let text = searchBar.text,
            let searchURLString: String = "x-web-search://?\(text)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let searchURL = URL(string: searchURLString) {
            UIApplication.shared.open(searchURL, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func searchWikipedia(_ sender: UIBarButtonItem) {
        if let text = searchBar.text,
            let wikiURLString = "https://wikipedia.org/wiki/\(text)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let wikiURL = URL(string: wikiURLString){
            UIApplication.shared.open(wikiURL, options: [:], completionHandler: nil)
        }
    }

}

extension SearchViewController: PDFDocumentDelegate {
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
        statusLabel.text = NSLocalizedString("Searching...", comment: "searching")
        if let userInfo = notification.userInfo, let index = userInfo["PDFDocumentPageIndex"] as? Int, let pageCount = pdfDocument?.pageCount {
            progressView.progress = Float(index+1) / Float(pageCount)
        }
    }
    
    func documentDidEndDocumentFind(_ notification: Notification) {
        updateStatusLabel()
    }
    
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let cancelButton = searchBar.value(forKey: "cancelButton") as? UIButton {
            cancelButton.isEnabled = true
        }
        if searchBar.text == currentSearchText {
            return
        }
        pdfDocument?.cancelFindString()
        searchResults.removeAll()
        tableView.reloadData()
        if let searchText = searchBar.text {
            currentSearchText = searchText
            delegate.fullTextSearch(string: currentSearchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        pdfDocument?.cancelFindString()
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text.contains(" ") {
            // fix crash
            return false
        }
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 {
            searchWeb.isEnabled = true
            searchWikipedia.isEnabled = true
        } else {
            searchWeb.isEnabled = false
            searchWikipedia.isEnabled = false
        }
        if searchText == currentSearchText {
            return
        }
        currentSearchText = ""
        pdfDocument?.cancelFindString()
        searchResults.removeAll()
        tableView.reloadData()
        statusLabel.text = nil
        progressView.progress = 0.0
    }
    
}
