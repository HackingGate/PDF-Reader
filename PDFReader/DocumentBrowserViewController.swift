//
//  DocumentBrowserViewController.swift
//  PDFReader
//
//  Created by Eru on H29/09/28.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import CoreData

class DocumentBrowserViewController: UIDocumentBrowserViewController, UIDocumentBrowserViewControllerDelegate, NSFetchedResultsControllerDelegate {
    
    let browserUserInterfaceStyleKey = "browserUserInterfaceStyle"
    let defaultBrowserUserInterfaceStyle: UIDocumentBrowserViewController.BrowserUserInterfaceStyle = .white
    var managedObjectContext: NSManagedObjectContext? = nil
    var fetchedResults: [DocumentEntity]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let sectionInfo = fetchedResultsController.sections?.first{
            fetchedResults = sectionInfo.objects as? [DocumentEntity]
        }

        delegate = self
        
        allowsDocumentCreation = false
        allowsPickingMultipleItems = false
        
        // get Settings.bundle
        var appDefaults = Dictionary<String, AnyObject>()
        appDefaults[browserUserInterfaceStyleKey] = defaultBrowserUserInterfaceStyle.rawValue as NSNumber
        
        UserDefaults.standard.register(defaults: appDefaults)
        updateInterface()
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateInterface),
                           name: .UIApplicationWillEnterForeground,
                           object: nil)

        // Specify the allowed content types of your application via the Info.plist.
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @objc func updateInterface() {
        UserDefaults.standard.synchronize()
        browserUserInterfaceStyle = UIDocumentBrowserViewController.BrowserUserInterfaceStyle(rawValue: UInt(UserDefaults.standard.integer(forKey: browserUserInterfaceStyleKey))) ?? defaultBrowserUserInterfaceStyle
        if browserUserInterfaceStyle == .white {
            view.tintColor = UIButton(type: .system).titleColor(for: .normal)
        } else if browserUserInterfaceStyle == .light {
            view.tintColor = .darkGray
        } else if browserUserInterfaceStyle == .dark {
            view.tintColor = .orange
        }
    }
    
    // MARK: UIDocumentBrowserViewControllerDelegate
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didRequestDocumentCreationWithHandler importHandler: @escaping (URL?, UIDocumentBrowserViewController.ImportMode) -> Void) {
        let newDocumentURL: URL? = nil
        
        // Set the URL for the new document here. Optionally, you can present a template chooser before calling the importHandler.
        // Make sure the importHandler is always called, even if the user cancels the creation request.
        if newDocumentURL != nil {
            importHandler(newDocumentURL, .move)
        } else {
            importHandler(nil, .none)
        }
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentURLs documentURLs: [URL]) {
        guard let sourceURL = documentURLs.first else { return }
        
        // Present the Document View Controller for the first document that was picked.
        // If you support picking multiple items, make sure you handle them all.
        presentDocument(at: sourceURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didImportDocumentAt sourceURL: URL, toDestinationURL destinationURL: URL) {
        // Present the Document View Controller for the new newly created document
        presentDocument(at: destinationURL)
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, failedToImportDocumentAt documentURL: URL, error: Error?) {
        // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
    }
    
    // MARK: Document Presentation
    
    func presentDocument(at documentURL: URL) {
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        
        let navigationController = storyBoard.instantiateViewController(withIdentifier: "NavigationController") as! UINavigationController
        
        let documentViewController = navigationController.viewControllers.first as! DocumentViewController
        documentViewController.document = Document(fileURL: documentURL)
        documentViewController.managedObjectContext = self.fetchedResultsController.managedObjectContext
        if let documentEntity = self.currentEntityFor(documentURL) {
            documentViewController.currentEntity = documentEntity
        }
        
        navigationController.modalTransitionStyle = .crossDissolve
        present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: - Fetch Data
    
    func currentEntityFor(_ documentURL: URL) -> DocumentEntity? {
        guard let objects = fetchedResults else { return nil }
        for documentEntity in objects {
            if let bookmarkData = documentEntity.bookmark {
                do {
                    var isStale = false
                    if let bookmarkURL = try URL.init(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) {
                        print("resolved url: \(bookmarkURL)")
                        if bookmarkURL == documentURL {
                            return documentEntity
                        }
                        if isStale {
                            print("bookmark is stale")
                            // create a new bookmark using the returned URL
                            // https://developer.apple.com/documentation/foundation/nsurl/1572035-urlbyresolvingbookmarkdata
                            do {
                                documentEntity.timestamp = Date()
                                try documentEntity.bookmark = bookmarkURL.bookmarkData()
                            } catch let error as NSError {
                                print("Bookmark Creation Fails: \(error.description)")
                            }
                        }
                    }
                } catch let error as NSError {
                    print("Bookmark Access Fails: \(error.description)")
                    if error.code == -1005 {
                        // file not exists
                        let context = fetchedResultsController.managedObjectContext
                        print("deleting: \(documentEntity)")
                        context.delete(documentEntity)
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Fetched results controller
    
    var fetchedResultsController: NSFetchedResultsController<DocumentEntity> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<DocumentEntity> = DocumentEntity.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        // workaround: use random string as cacheName to prevent 0 numberOfObjects
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Document")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }
    var _fetchedResultsController: NSFetchedResultsController<DocumentEntity>? = nil
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            fetchedResults?.insert(anObject as! DocumentEntity, at: newIndexPath!.row)
        case .delete:
            fetchedResults?.remove(at: indexPath!.row)
        case .update:
            fetchedResults?[indexPath!.row] = anObject as! DocumentEntity
        case .move:
            fetchedResults?.remove(at: indexPath!.row)
            fetchedResults?.insert(anObject as! DocumentEntity, at: newIndexPath!.row)
        }
    }
    
}

