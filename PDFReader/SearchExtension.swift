//
//  SearchExtension.swift
//  PDFReader
//
//  Created by ERU on 2018/05/09.
//  Copyright © 2018 Hacking Gate. All rights reserved.
//

import UIKit

extension DocumentViewController: UISearchBarDelegate, UISearchControllerDelegate {
    // full text search
    func fullTextSearch(string: String) {
        pdfView.document?.cancelFindString()
        pdfView.document?.beginFindString(string, withOptions: [.regularExpression, .caseInsensitive])
    }
    
    // on page search
    func createSearchController() -> UISearchController {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false
        navigationItem.hidesSearchBarWhenScrolling = false
        return searchController
    }
    
    func updateSearchController() {
        if let navigationController = navigationController, let searchController = navigationItem.searchController {
            searchController.searchBar.superview?.isHidden = navigationController.isNavigationBarHidden || !isFindOnPageEnabled
            
            if navigationController.isNavigationBarHidden && isFindOnPageEnabled {
                self.additionalSafeAreaInsets.top = -64 // fixed by a magic num
            } else {
                self.additionalSafeAreaInsets.top = 0
            }
        }
    }
    
    func setSearchEnabled(_ enable: Bool) {
        if let navigationController = navigationController, !navigationController.isNavigationBarHidden {
            // interact when nav is not hidden
            if enable {
                navigationItem.searchController = searchController
            } else {
                navigationItem.searchController = nil
                // workaround to update UI
                navigationController.setNavigationBarHidden(true, animated: false)
                navigationController.setNavigationBarHidden(false, animated: false)
            }
        }
    }
    
    func searchText(withOptions options: NSString.CompareOptions) {
        if let text = searchBarText {
            if pdfView.currentSelection == nil, let currentPage = pdfView.currentPage {
                // a workaround to search text from current page
                let selection = currentPage.selection(for: currentPage.bounds(for: pdfView.displayBox))
                pdfView.setCurrentSelection(selection, animate: false)
            }
            if let newSelection = pdfView.document?.findString(text, fromSelection: pdfView.currentSelection, withOptions: options) {
                self.goToSelection(newSelection)
                self.setCurrentSelection(newSelection, animate: true)
            } else {
                // for workaround: clear selected if no real search results returned
                pdfView.clearSelection()
            }
        }
    }
    
    // UISearchBarDelegate
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBarText = searchBar.text
        searchText(withOptions: [.regularExpression])
    }
    
    // UISearchControllerDelegate
    
    func willPresentSearchController(_ searchController: UISearchController) {
        if let pdfThumbnailView = navigationController?.toolbar.viewWithTag(1) {
            pdfThumbnailView.isHidden = true
        }
        if let items = navigationController?.toolbar.items {
            for item in items {
                item.isEnabled = true
                item.tintColor = view.tintColor
            }
        }
        navigationController?.hidesBarsOnTap = false
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        if let pdfThumbnailView = navigationController?.toolbar.viewWithTag(1) {
            pdfThumbnailView.isHidden = false
        }
        if let items = navigationController?.toolbar.items {
            for item in items {
                item.isEnabled = false
                item.tintColor = .clear
            }
        }
        navigationController?.hidesBarsOnTap = true
    }
    
}
