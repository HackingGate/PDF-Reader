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
import CloudKit

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
    var pageIndex: Int64 = 0
    var currentEntity: DocumentEntity? = nil
    var currentCKRecords: [CKRecord]? = nil
    
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
        if let currentEntity = currentEntity {
            pageIndex = currentEntity.pageIndex
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
    
    // call after moveToLastReadingProsess()
    func checkForNewerRecords() {
        if let record = currentCKRecords?.first, let modificationDate = record["modificationDate"] as? Date, let cloudPageIndex = record["pageIndex"] as? NSNumber {
            if let currentModificationDate = currentEntity?.modificationDate {
                if currentModificationDate > modificationDate { return }
            }
            if cloudPageIndex.int64Value != pageIndex {
                var message = modificationDate.description(with: Locale.current)
                if let modifiedByDevice = record["modifiedByDevice"] as? String {
                    message += "\n\(NSLocalizedString("Device:", comment: "")) \(modifiedByDevice)"
                }
                message += "\n\(NSLocalizedString("Last Viewed Page:", comment: "")) \(cloudPageIndex)"
                
                let alertController: UIAlertController = UIAlertController(title: NSLocalizedString("Found iCloud Data", comment: ""), message: message, preferredStyle: .alert)
                
                let defaultAction: UIAlertAction = UIAlertAction(title: NSLocalizedString("Move", comment: ""), style: .default, handler: { (action: UIAlertAction?) in
                    self.pageIndex = cloudPageIndex.int64Value
                    if let pdfPage = self.pdfView.document?.page(at: Int(self.pageIndex)) {
                        self.pdfView.go(to: pdfPage)
                    }
                })
                
                let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: UIAlertActionStyle.cancel, handler: nil)
                
                alertController.addAction(cancelAction)
                alertController.addAction(defaultAction)
                
                present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Save Data
    
    @objc
    func insertNewObject(_ bookmark: Data, pageIndex: Int64) {
        if let context = self.managedObjectContext {
            let newDocument = DocumentEntity(context: context)
            
            // If appropriate, configure the new managed object.
            newDocument.uuid = UUID()
            newDocument.creationDate = Date()
            newDocument.modificationDate = Date()
            newDocument.bookmarkData = bookmark
            newDocument.pageIndex = pageIndex
            newDocument.isVerticalWriting = self.isVerticalWriting
            newDocument.isRightToLeft = self.isRightToLeft
            
            print("saving: \(newDocument)")
            
            self.saveContext(context)
        } else {
            print("context not exist")
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
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
    
    @objc func saveAndClose() {
        guard let pdfDocument = pdfView.document else { return }
        if let currentPage = pdfView.currentPage {
            var currentIndex = pdfDocument.index(for: currentPage)
            if isRightToLeft {
                currentIndex = pdfDocument.pageCount - currentIndex - 1
            }
            if let documentEntity = currentEntity {
                documentEntity.modificationDate = Date()
                documentEntity.pageIndex = Int64(currentIndex)
                print("updating entity: \(documentEntity)")
                if let context = self.managedObjectContext {
                    self.saveContext(context)
                }
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
