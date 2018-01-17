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
    var prefersTwoUpInLandscapeForPad: Bool { get }
    func writing(vertically: Bool, rightToLeft: Bool) -> Void
    func goToPage(page: PDFPage) -> Void
    func selectOutline(outline: PDFOutline) -> Void
    func setPreferredDisplayMode(_ twoUpInLandscapeForPad: Bool) -> Void
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
    
    // scaleFactor
    struct ScaleFactor {
        // store factor for single mode
        var portrait: CGFloat
        var landscape: CGFloat
        // devide by 2 for two up mode
    }
    var scaleFactorForSizeToFit: ScaleFactor?
    var scaleFactorVertical: ScaleFactor?
    var scaleFactorHorizontal: ScaleFactor?
    
    // delegate properties
    var isVerticalWriting = false
    var isRightToLeft = false
    var isEncrypted = false
    var allowsDocumentAssembly = false
    var prefersTwoUpInLandscapeForPad = false // default value
    
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
                
                self.moveToLastViewedPage()
                self.getScaleFactorForSizeToFit()
                self.setMinScaleFactorForSizeToFit()
                self.setScaleFactorForUser()
                
                if let documentEntity = self.currentEntity {
                    self.writing(vertically: documentEntity.isVerticalWriting, rightToLeft: documentEntity.isRightToLeft)
                }
                self.moveToLastViewedPageRect()

                self.setPDFThumbnailView()
                
                self.checkForNewerRecords()
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
        if let documentEntity = self.currentEntity {
            prefersTwoUpInLandscapeForPad = documentEntity.prefersTwoUpInLandscapeForPad
        }
        if prefersTwoUpInLandscapeForPad && UIDevice.current.userInterfaceIdiom == .pad && UIApplication.shared.statusBarOrientation.isLandscape {
            pdfView.displayMode = .twoUpContinuous
        } else {
            pdfView.displayMode = .singlePageContinuous
        }

        pdfView.scrollView?.scrollsToTop = false
        pdfView.scrollView?.contentInsetAdjustmentBehavior = .scrollableAxes
        
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
                           selector: #selector(willChangeOrientationHandler),
                           name: .UIApplicationDidChangeStatusBarOrientation,
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
            view.tintColor = presentingViewController?.view.tintColor
            navigationController?.navigationBar.tintColor = presentingViewController?.view.tintColor
        }
    }
    
    func setPreferredDisplayMode(_ twoUpInLandscapeForPad: Bool) {
        prefersTwoUpInLandscapeForPad = twoUpInLandscapeForPad
        if let page = pdfView.currentPage {
            if twoUpInLandscapeForPad && UIDevice.current.userInterfaceIdiom == .pad && UIApplication.shared.statusBarOrientation.isLandscape {
                pdfView.displayMode = .twoUpContinuous
            } else {
                pdfView.displayMode = .singlePageContinuous
            }
            pdfView.go(to: page) // workaround to fix
        }
        setMinScaleFactorForSizeToFit()
        setScaleFactorForUser()
    }
    
    func writing(vertically: Bool, rightToLeft: Bool) {
        updateUserScaleFactor(changeOrientation: false)
        
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
        
        setMinScaleFactorForSizeToFit()
        setScaleFactorForUser()
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
        // do not hide status bar in portrait if height is not 20 (detect if iPhone X)
        return navigationController?.isNavigationBarHidden == true && UIApplication.shared.statusBarFrame.height == 20 || super.prefersStatusBarHidden
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if navigationController?.isNavigationBarHidden == true && navigationController?.navigationBar.barStyle == .black {
            return .lightContent
        } else {
            return super.preferredStatusBarStyle
        }
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
        // make sure to init
        if let verticalPortrait = currentEntity?.scaleFactorVerticalPortrait, let verticalLandscape = currentEntity?.scaleFactorVerticalLandscape {
            scaleFactorVertical = ScaleFactor(portrait: CGFloat(verticalPortrait), landscape: CGFloat(verticalLandscape))
        } else {
            scaleFactorVertical = ScaleFactor(portrait: 0.25, landscape: 0.25)
        }
        if let horizontalPortrait = currentEntity?.scaleFactorHorizontalPortrait, let horizontalLandscape = currentEntity?.scaleFactorVerticalLandscape {
            scaleFactorHorizontal = ScaleFactor(portrait: CGFloat(horizontalPortrait), landscape: CGFloat(horizontalLandscape))
        } else {
            scaleFactorHorizontal = ScaleFactor(portrait: 0.25, landscape: 0.25)
        }

        if pdfView.displayDirection == .vertical {
            let frame = view.frame
            let aspectRatio = frame.size.width / frame.size.height
            var scaleFactor = pdfView.scaleFactorForSizeToFit
            if pdfView.displayMode == .twoUpContinuous {
                scaleFactor *= 2
            }
            if UIApplication.shared.statusBarOrientation.isPortrait {
                scaleFactorForSizeToFit = ScaleFactor(portrait: scaleFactor,
                                                      landscape: scaleFactor / aspectRatio)
            } else if UIApplication.shared.statusBarOrientation.isLandscape {
                scaleFactorForSizeToFit = ScaleFactor(portrait: scaleFactor / aspectRatio,
                                                      landscape: scaleFactor)
            }
        }
        
    }
    
    // SizeToFit currentlly only works for vertical display direction
    func setMinScaleFactorForSizeToFit() {
        if pdfView.displayDirection == .vertical, let scaleFactorForSizeToFit = scaleFactorForSizeToFit {
            if UIApplication.shared.statusBarOrientation.isPortrait {
                if pdfView.displayMode == .singlePageContinuous {
                    pdfView.minScaleFactor = scaleFactorForSizeToFit.portrait
                } else if pdfView.displayMode == .twoUpContinuous {
                    pdfView.minScaleFactor = scaleFactorForSizeToFit.portrait / 2
                }
            } else if UIApplication.shared.statusBarOrientation.isLandscape {
                // set minScaleFactor to safe area for iPhone X and later
                let multiplier = (pdfView.frame.width - pdfView.safeAreaInsets.left - pdfView.safeAreaInsets.right) / pdfView.frame.width
                if pdfView.displayMode == .singlePageContinuous {
                    pdfView.minScaleFactor = scaleFactorForSizeToFit.landscape * multiplier
                } else if pdfView.displayMode == .twoUpContinuous {
                    pdfView.minScaleFactor = scaleFactorForSizeToFit.landscape / 2 * multiplier
                }
            }
        }
    }
    
    func setScaleFactorForUser() {
        var scaleFactor: ScaleFactor?
        if pdfView.displayDirection == .vertical {
            scaleFactor = scaleFactorVertical
        } else if pdfView.displayDirection == .horizontal {
            scaleFactor = scaleFactorHorizontal
        }
        
        if let scaleFactor = scaleFactor {
            print("set scale factor: \(scaleFactor)")
            if UIApplication.shared.statusBarOrientation.isPortrait {
                if pdfView.displayMode == .singlePageContinuous {
                    pdfView.scaleFactor = scaleFactor.portrait
                } else if pdfView.displayMode == .twoUpContinuous {
                    pdfView.scaleFactor = scaleFactor.portrait / 2
                }
            } else if UIApplication.shared.statusBarOrientation.isLandscape {
                // set scaleFactor to safe area for iPhone X and later
                let multiplier = (pdfView.frame.width - pdfView.safeAreaInsets.left - pdfView.safeAreaInsets.right) / pdfView.frame.width
                if pdfView.displayMode == .singlePageContinuous {
                    pdfView.scaleFactor = scaleFactor.landscape * multiplier
                } else if pdfView.displayMode == .twoUpContinuous {
                    pdfView.scaleFactor = scaleFactor.landscape / 2 * multiplier
                }
            }
        }
    }
    
    func updateUserScaleFactor(changeOrientation: Bool) {
        // for save
        // XOR operator for bool (!=)
        if UIApplication.shared.statusBarOrientation.isPortrait != changeOrientation {
            if pdfView.displayDirection == .vertical {
                scaleFactorVertical?.portrait = pdfView.scaleFactor
            } else if pdfView.displayDirection == .horizontal {
                scaleFactorHorizontal?.portrait = pdfView.scaleFactor
            }
        } else if UIApplication.shared.statusBarOrientation.isLandscape != changeOrientation {
            if pdfView.displayDirection == .vertical {
                scaleFactorVertical?.landscape = pdfView.scaleFactor
            } else if pdfView.displayDirection == .horizontal {
                scaleFactorHorizontal?.landscape = pdfView.scaleFactor
            }
        }
    }
    
    func moveToLastViewedPage() {
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
    
    func moveToLastViewedPageRect() {
        if let currentEntity = currentEntity, let currentPage = pdfView.currentPage, let pageRect = currentEntity.pageRect as? CGRect {
            pdfView.go(to: pageRect, on: currentPage)
        }
    }
    
    // call after moveToLastViewedPage()
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
                
                alertController.view.tintColor = view.tintColor
                
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
    
    @objc func willChangeOrientationHandler() {
        updateUserScaleFactor(changeOrientation: true)
    }
    
    @objc func didChangeOrientationHandler() {
        // detect if user enabled and update scale factor
        setPreferredDisplayMode(prefersTwoUpInLandscapeForPad)
    }
    
    @IBAction func shareAction() {
        let activityVC = UIActivityViewController(activityItems: [document?.fileURL as Any], applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.saveAndClose()
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
                if let record = currentCKRecords?.first {
                    // if another device have the same bookmark but different recordID
                    documentEntity.uuid = UUID(uuidString: record.recordID.recordName)
                }
                documentEntity.pageIndex = Int64(currentIndex)
                update(entity: documentEntity)
                
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
    
    // MARK: - Save Data
    
    @objc
    func insertNewObject(_ bookmark: Data, pageIndex: Int64) {
        if let context = self.managedObjectContext {
            let newDocument = DocumentEntity(context: context)
            
            if let record = currentCKRecords?.first {
                // if the record exists in iCloud but not in CoreData
                newDocument.uuid = UUID(uuidString: record.recordID.recordName)
            } else {
                newDocument.uuid = UUID()
            }
            newDocument.creationDate = Date()
            newDocument.bookmarkData = bookmark
            newDocument.pageIndex = pageIndex
            update(entity: newDocument)
            
            print("saving: \(newDocument)")
            
            self.saveContext(context)
        } else {
            print("context not exist")
        }
    }

    func update(entity: DocumentEntity) {
        entity.modificationDate = Date()
        entity.isVerticalWriting = self.isVerticalWriting
        entity.isRightToLeft = self.isRightToLeft
        entity.prefersTwoUpInLandscapeForPad = self.prefersTwoUpInLandscapeForPad
        
        // store user scale factor
        updateUserScaleFactor(changeOrientation: false)
        if let scaleFactorVertical = scaleFactorVertical {
            entity.scaleFactorVerticalPortrait = Float(scaleFactorVertical.portrait)
            entity.scaleFactorVerticalLandscape = Float(scaleFactorVertical.landscape)
        }
        if let scaleFactorHorizontal = scaleFactorHorizontal {
            entity.scaleFactorHorizontalPortrait = Float(scaleFactorHorizontal.portrait)
            entity.scaleFactorHorizontalLandscape = Float(scaleFactorHorizontal.landscape)
        }
        
        if let currentPage = pdfView.currentPage {
            let pageRect = pdfView.convert(view.frame, to: currentPage)
            entity.pageRect = pageRect as NSObject
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
                var height = 245
                if !isEncrypted {
                    // 245 - 44 = 201
                    height -= 44
                }
                if UIDevice.current.userInterfaceIdiom != .pad {
                    height -= 44
                }
                
                popopverVC.preferredContentSize = CGSize(width: 300, height: height)

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

extension PDFView {
    var scrollView: UIScrollView? {
        for view in self.subviews {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
        }
        return nil
    }
}
