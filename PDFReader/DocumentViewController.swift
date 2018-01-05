//
//  DocumentViewController.swift
//  PDFReader
//
//  Created by Eru on H29/09/28.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit
import CoreData

protocol SettingsDelegate {
    var isVerticalWriting: Bool { get }
    var isRightToLeft: Bool { get }
    var isEncrypted: Bool { get }
    var allowsDocumentAssembly: Bool { get }
    func writing(vertically: Bool, rightToLeft: Bool) -> Void
    func goToPage(page: PDFPage) -> Void
    func selectOutline(outline: PDFOutline) -> Void
}

extension DocumentViewController: SettingsDelegate {
    func goToPage(page: PDFPage) {
        pdfView.go(to: page)
    }
    
    func selectOutline(outline: PDFOutline) {
        if let action = outline.action as? PDFActionGoTo {
            pdfView.go(to: action.destination)
        }
    }
}

class DocumentViewController: UIViewController {
    
    @IBOutlet weak var pdfView: PDFView!
    
    var document: Document?
    
    // data
    var managedObjectContext: NSManagedObjectContext? = nil
    var _fetchedResultsController: NSFetchedResultsController<DocumentEntity>? = nil
    var isBookmarkExists = false
    var pageIndex: Int64 = 0
    var currentEntity: DocumentEntity? = nil
    
    // scale
    var portraitScaleFactorForSizeToFit: CGFloat = 0.0
    var landscapeScaleFactorForSizeToFit: CGFloat = 0.0
    
    // delegate properties
    var isVerticalWriting = false
    var isRightToLeft = false
    var isEncrypted = false
    var allowsDocumentAssembly = false
    
    override func viewWillAppear(_ animated: Bool) {
        updateInterface()
        super.viewWillAppear(animated)
        navigationController?.hidesBarsOnTap = true
        
        if (pdfView.document != nil) { return }
        
        // Access the document
        document?.open(completionHandler: { (success) in
            if success {
                // Display the content of the document, e.g.:
                self.navigationItem.title = self.document?.localizedName
                
                guard let pdfURL: URL = (self.document?.fileURL) else { return }
                guard let document = PDFDocument(url: pdfURL) else { return }
                
                self.allowsDocumentAssembly = document.allowsDocumentAssembly
                self.isEncrypted = document.isEncrypted
                
                self.pdfView.document = document
                
                self.moveToLastReadingProsess()
                if self.pdfView.displayDirection == .vertical {
                    self.getScaleFactorForSizeToFit()
                }
                
                self.writing(vertically: self.isVerticalWriting, rightToLeft: self.isRightToLeft)
                
                self.setPDFThumbnailView()
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    override func viewDidLoad() {
        self.fetchAllObjects()
        
        navigationController?.barHideOnTapGestureRecognizer.addTarget(self, action: #selector(barHideOnTapGestureRecognizerHandler))
        
        
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = false
        pdfView.displayBox = .cropBox
        pdfView.displayMode = .singlePageContinuous
        for view in pdfView.subviews {
            if view.isKind(of: UIScrollView.self) {
                (view as? UIScrollView)?.scrollsToTop = false
                (view as? UIScrollView)?.contentInsetAdjustmentBehavior = .scrollableAxes
            }
        }
        
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateInterface),
                           name: .UIApplicationWillEnterForeground,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(saveAndClose),
                           name: .UIApplicationDidEnterBackground,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(didChangeOrientationHandler),
                           name: .UIApplicationDidChangeStatusBarOrientation,
                           object: nil)
    }
    
    @objc func updateInterface() {
        if presentingViewController != nil {
            // use same UI style as DocumentBrowserViewController
            if UserDefaults.standard.integer(forKey: (presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey) == UIDocumentBrowserViewController.BrowserUserInterfaceStyle.dark.rawValue {
                navigationController?.navigationBar.barStyle = .black
                navigationController?.toolbar.barStyle = .black
            } else {
                navigationController?.navigationBar.barStyle = .default
                navigationController?.toolbar.barStyle = .default
            }
            view.backgroundColor = presentingViewController?.view.backgroundColor
            navigationController?.navigationBar.tintColor = presentingViewController?.view.tintColor
        }
    }
    
    func writing(vertically: Bool, rightToLeft: Bool) {
        // experimental feature
        if let currentPage = pdfView.currentPage {
            if let document: PDFDocument = pdfView.document {
                let currentIndex: Int = document.index(for: currentPage)
                
                print("currentIndex: \(currentIndex)")
                
                if rightToLeft != isRightToLeft {
                    if !allowsDocumentAssembly {
                        return
                    }
                    // ページ交換ファンクションを利用して、降順ソートして置き換える。
                    let pageCount: Int = document.pageCount
                    
                    print("pageCount: \(pageCount)")
                    for i in 0..<pageCount/2 {
                        print("exchangePage at: \(i), withPageAt: \(pageCount-i-1)")
                        document.exchangePage(at: i, withPageAt: pageCount-i-1)
                    }
                    if currentIndex != pageCount - currentIndex - 1 {
                        if let pdfPage = document.page(at: pageCount - currentIndex - 1) {
                            print("go to: \(pageCount - currentIndex - 1)")
                            pdfView.go(to: pdfPage)
                        }
                    }
                    isRightToLeft = rightToLeft
                }
                
                if vertically != isVerticalWriting {
                    if vertically {
                        pdfView.displayDirection = .horizontal
                    } else {
                        pdfView.displayDirection = .vertical
                    }
                    isVerticalWriting = vertically
                }
                
                // reset document to update interface
                pdfView.document = nil
                pdfView.document = document
                pdfView.go(to: currentPage)
            }
        }
        
        setScaleFactorForSizeToFit()
    }
    
    func setPDFThumbnailView() {
        if let margins = navigationController?.toolbar.safeAreaLayoutGuide {
            let pdfThumbnailView = PDFThumbnailView.init()
            pdfThumbnailView.pdfView = pdfView
            pdfThumbnailView.layoutMode = .horizontal
            pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
            navigationController?.toolbar.addSubview(pdfThumbnailView)
            pdfThumbnailView.leadingAnchor.constraint(equalTo: margins.leadingAnchor).isActive = true
            pdfThumbnailView.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
            pdfThumbnailView.topAnchor.constraint(equalTo: margins.topAnchor).isActive = true
            pdfThumbnailView.bottomAnchor.constraint(equalTo: margins.bottomAnchor).isActive = true
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden == true || super.prefersStatusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return navigationController?.isToolbarHidden == true
    }
    
    @objc func barHideOnTapGestureRecognizerHandler() {
        navigationController?.setToolbarHidden(navigationController?.isNavigationBarHidden == true, animated: true)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    func getScaleFactorForSizeToFit() {
        let frame = pdfView.frame
        let aspectRatio = frame.size.width / frame.size.height
        if UIApplication.shared.statusBarOrientation.isPortrait {
            portraitScaleFactorForSizeToFit = pdfView.scaleFactorForSizeToFit 
            landscapeScaleFactorForSizeToFit = portraitScaleFactorForSizeToFit / aspectRatio
        } else if UIApplication.shared.statusBarOrientation.isLandscape {
            landscapeScaleFactorForSizeToFit = pdfView.scaleFactorForSizeToFit
            portraitScaleFactorForSizeToFit = landscapeScaleFactorForSizeToFit / aspectRatio
        }
    }
    
    func setScaleFactorForSizeToFit() {
        if pdfView.displayDirection == .vertical {
            // currentlly only works for vertical display direction
            if portraitScaleFactorForSizeToFit != 0.0 && UIApplication.shared.statusBarOrientation.isPortrait {
                pdfView.minScaleFactor = portraitScaleFactorForSizeToFit
                pdfView.scaleFactor = portraitScaleFactorForSizeToFit
            } else if landscapeScaleFactorForSizeToFit != 0.0 && UIApplication.shared.statusBarOrientation.isLandscape {
                let multiplier = (pdfView.frame.width - pdfView.safeAreaInsets.left - pdfView.safeAreaInsets.right) / pdfView.frame.width
                // set minScaleFactor to safe area for iPhone X and later
                pdfView.minScaleFactor = landscapeScaleFactorForSizeToFit * multiplier
                pdfView.scaleFactor = landscapeScaleFactorForSizeToFit
            }
        }
    }
    
    func moveToLastReadingProsess() {
        if isBookmarkExists {
            // key exists
        } else if isVerticalWriting {
            // 初めて読む　且つ　縦書き
            if let pageCount: Int = pdfView.document?.pageCount {
                pageIndex = Int64(pageCount - 1)
            }
        }
        // TODO: if pageIndex == pageCount - 1, then go to last CGRect
        if let pdfPage = pdfView.document?.page(at: Int(pageIndex)) {
            pdfView.go(to: pdfPage)
        }
    }
    
    @objc func saveAndClose() {
        guard let pdfDocument = pdfView.document else { return }
        if let currentPage = pdfView.currentPage {
            var currentIndex = pdfDocument.index(for: currentPage)
            if isRightToLeft {
                currentIndex = pdfDocument.pageCount - currentIndex - 1
            }
            if isBookmarkExists, let documentEntity = currentEntity {
                documentEntity.timestamp = Date()
                documentEntity.pageIndex = Int64(currentIndex)
                print("updating entity: \(documentEntity)")
                self.saveContext()
            } else {
                do {
                    if let bookmark = try document?.fileURL.bookmarkData() {
                        self.insertNewObject(bookmark, pageIndex: Int64(currentIndex))
                    }
                } catch let error as NSError {
                    print("Set Bookmark Fails: \(error.description)")
                }
            }
        }

        self.document?.close(completionHandler: nil)
    }
    
    @objc func didChangeOrientationHandler() {
        setScaleFactorForSizeToFit()
    }
    
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.saveAndClose()
        }
    }
    
    @IBAction func shareAction() {
        let activityVC = UIActivityViewController(activityItems: [document?.fileURL as Any], applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
}

extension DocumentViewController: NSFetchedResultsControllerDelegate {
    // MARK: - CoreData
    
    func fetchAllObjects() {
        if let sectionInfo = fetchedResultsController.sections?.first {
            print("numberOfObjects: \(sectionInfo.numberOfObjects)")
            guard let objects = sectionInfo.objects else { return }
            for object in objects {
                if let documentEntity = object as? DocumentEntity {
                    if let bookmarkData = documentEntity.bookmark {
                        do {
                            var isStale = false
                            if let bookmarkURL = try URL.init(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) {
                                print("resolved url: \(bookmarkURL)")
                                if !isBookmarkExists && bookmarkURL == document?.fileURL {
                                    isBookmarkExists = true
                                    pageIndex = documentEntity.pageIndex
                                    currentEntity = documentEntity
                                    self.saveContext()
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
            }
        }
    }
    
    @objc
    func insertNewObject(_ bookmark: Data, pageIndex: Int64) {
        let context = self.fetchedResultsController.managedObjectContext
        
        let newDocument = DocumentEntity(context: context)
        
        // If appropriate, configure the new managed object.
        newDocument.timestamp = Date()
        newDocument.bookmark = bookmark
        newDocument.pageIndex = pageIndex
        
        print("saving: \(newDocument)")
        
        self.saveContext()
    }
    
    func saveContext() {
        let context = self.fetchedResultsController.managedObjectContext

        // Save the context.
        do {
            try context.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
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

}

extension DocumentViewController: UIPopoverPresentationControllerDelegate {
    // MARK: - PopoverTableViewController Presentation

    // iOS Popover presentation Segue
    // http://sunnycyk.com/2015/08/ios-popover-presentation-segue/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "PopoverSettings") {
            if let popopverVC: PopoverTableViewController = segue.destination as? PopoverTableViewController {
                popopverVC.modalPresentationStyle = .popover
                popopverVC.popoverPresentationController?.delegate = self
                popopverVC.delegate = self
                if !isEncrypted {
                    // 201 - 44 = 157
                    popopverVC.preferredContentSize = CGSize(width: 300, height: 157)
                }
            }
        } else if (segue.identifier == "Container") {
            if let containerVC: ContainerViewController = segue.destination as? ContainerViewController {
                containerVC.pdfDocument = pdfView.document
                containerVC.displayBox = pdfView.displayBox
                if let currentPage = pdfView.currentPage, let document: PDFDocument = pdfView.document {
                    containerVC.currentIndex = document.index(for: currentPage)
                }
                containerVC.delegate = self
            }
        }
    }
    
    // fix for iPhone Plus
    // https://stackoverflow.com/q/36349303/4063462
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
}
