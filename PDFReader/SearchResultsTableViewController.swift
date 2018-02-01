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
    
    var delegate: SettingsDelegate!
    var pdfDocument: PDFDocument?
    var displayBox: PDFDisplayBox = .cropBox
    var searchResults = [PDFSelection]()
    
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
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
        delegate.goToSelection(selection)
        delegate.setCurrentSelection(selection, animate: true)
    }

}

extension SearchResultsTableViewController: PDFDocumentDelegate {
    func didMatchString(_ instance: PDFSelection) {
        if instance.string != nil && instance.pages.count != 0 {
            searchResults.append(instance)
            tableView.reloadData()
        }
    }
}

extension SearchResultsTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        delegate.fullTextSearch(string: searchText)
    }
}

extension SearchResultsTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchResults.removeAll()
        tableView.reloadData()
    }
}
