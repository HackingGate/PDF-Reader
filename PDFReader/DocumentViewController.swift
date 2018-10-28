//
//  DocumentViewController.swift
//  PDFReader
//
//  Created by Eru on H29/09/28.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit
import HGPDFKit
import CoreData
import CloudKit

protocol SettingsDelegate {
    var isHorizontalScroll: Bool { get set }
    var isRightToLeft: Bool { get set }
    var isEncrypted: Bool { get }
    var allowsDocumentAssembly: Bool { get }
    var prefersTwoUpInLandscapeForPad: Bool { get }
    var displayMode: PDFDisplayMode { get }
    var isFindOnPageEnabled: Bool { get set }
    func updateScrollDirection() -> Void
    func pageIndex(page: PDFPage) -> Int?
    func goToPage(page: PDFPage) -> Void
    func goToSelection(_ selection: PDFSelection) -> Void
    func setCurrentSelection(_ selection: PDFSelection, animate: Bool) -> Void
    func fullTextSearch(string: String) -> Void
    func selectOutline(outline: PDFOutline) -> Void
    func setPreferredDisplayMode(_ twoUpInLandscapeForPad: Bool) -> Void
    func share() -> Void
}

extension DocumentViewController: SettingsDelegate {
    var allowsDocumentAssembly: Bool {
        get {
            if let document = pdfView.document {
                return document.allowsDocumentAssembly
            } else {
                return false
            }
        }
    }
    
    var displayMode: PDFDisplayMode {
        get {
            return pdfView.displayMode
        }
    }
    
    func pageIndex(page: PDFPage) -> Int? {
        guard let pdfDocument = pdfView.document else { return nil }
        return pdfDocument.index(for: page)
    }
    
    func goToPage(page: PDFPage) {
        pdfView.go(to: page)
    }
    
    func goToSelection(_ selection: PDFSelection) {
        pdfView.go(to: selection) // stops scrolling
        if let page = selection.pages.first {
            
            let selectionBounds = selection.bounds(for: page)
            let selectionBoundsInView = pdfView.convert(selectionBounds, from: page)
            
            if let scrollView = pdfView.scrollView {
                let inset: CGFloat = 10
                
                if selectionBoundsInView.origin.y - inset < pdfView.safeAreaInsets.top {
                    let offsetNeedToFix = pdfView.safeAreaInsets.top - selectionBoundsInView.origin.y + inset
                    scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y - offsetNeedToFix)
                } else if selectionBoundsInView.origin.y + inset + selectionBoundsInView.height > pdfView.frame.size.height - pdfView.safeAreaInsets.bottom {
                    var offsetNeedToFix = (selectionBoundsInView.origin.y + selectionBoundsInView.height) - (pdfView.frame.size.height - pdfView.safeAreaInsets.bottom) + inset
                    if pdfView.isViewTransformedForRTL { offsetNeedToFix = -offsetNeedToFix}
                    scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: scrollView.contentOffset.y + offsetNeedToFix)
                }
                if selectionBoundsInView.origin.x - inset < pdfView.safeAreaInsets.left {
                    var offsetNeedToFix = pdfView.safeAreaInsets.left - selectionBoundsInView.origin.x + inset
                    if pdfView.isViewTransformedForRTL { offsetNeedToFix = -offsetNeedToFix}
                    scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x - offsetNeedToFix, y: scrollView.contentOffset.y)
                } else if selectionBoundsInView.origin.x + inset + selectionBoundsInView.width > pdfView.frame.size.width - pdfView.safeAreaInsets.right {
                    let offsetNeedToFix = (selectionBoundsInView.origin.x + selectionBoundsInView.width) - (pdfView.frame.size.width - pdfView.safeAreaInsets.right) + inset
                    scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x - offsetNeedToFix, y: scrollView.contentOffset.y)
                }
            }
        }
    }
    
    func setCurrentSelection(_ selection: PDFSelection, animate: Bool) {
        pdfView.setCurrentSelection(selection, animate: true)
    }
    
    func selectOutline(outline: PDFOutline) {
        if let action = outline.action as? PDFActionGoTo {
            pdfView.go(to: action.destination)
        }
    }
    
    func share() {
        let activityVC = UIActivityViewController(activityItems: [document?.fileURL as Any], applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    
}

class DocumentViewController: UIViewController {
    
    @IBOutlet weak var pdfView: PDFView!
    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var pageLabel: UILabel!
    var blurDismissTimer = Timer()
    
    var document: Document?
    
    // search
    var searchBarText: String?
    var isFindOnPageEnabled = false {
        willSet {
            self.setSearchEnabled(newValue)
        }
    }
    var searchController: UISearchController {
        get {
            return createSearchController()
        }
    }
    var searchNavigationController: UINavigationController?
    
    // data
    var managedObjectContext: NSManagedObjectContext? = nil
    var pageIndex: Int64 = 0
    var currentEntity: DocumentEntity? = nil
    var currentCKRecords: [CKRecord]? {
        didSet {
            if didMoveToLastViewedPage {
                checkForNewerRecords()
            }
        }
    }
    var didMoveToLastViewedPage = false
    
    
    // offset
    var offsetPortrait: CGPoint?
    var offsetLandscape: CGPoint?
    
    // delegate properties
    var isHorizontalScroll = false
    var isRightToLeft = false
    var isEncrypted = false
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
                
                self.isEncrypted = document.isEncrypted
                
                self.pdfView.document = document
                
                self.moveToLastViewedPage()
                self.getScaleFactorForSizeToFitAndOffset()
                self.pdfView.setMinScaleFactorForSizeToFit()
                self.pdfView.setScaleFactorForUser()
                
                self.setPDFThumbnailView()
                
                if let documentEntity = self.currentEntity {
                    self.isHorizontalScroll = documentEntity.isHorizontalScroll
                    self.isRightToLeft = documentEntity.isRightToLeft
                    self.updateScrollDirection()
                }
                self.moveToLastViewedOffset()
                
                self.checkForNewerRecords()
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    override func viewDidLoad() {
        enableCustomMenus()
        blurEffectView.layer.masksToBounds = true
        blurEffectView.layer.cornerRadius = 6
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapGestureRecognizerHandler(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        pdfView.addGestureRecognizer(doubleTapGesture)
        navigationController?.barHideOnTapGestureRecognizer.require(toFail: doubleTapGesture)
        navigationController?.barHideOnTapGestureRecognizer.addTarget(self, action: #selector(barHideOnTapGestureRecognizerHandler))
        
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.displayBox = .cropBox
        if let documentEntity = self.currentEntity {
            prefersTwoUpInLandscapeForPad = documentEntity.prefersTwoUpInLandscapeForPad
            isFindOnPageEnabled = documentEntity.isFindOnPage
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
                           name: .UIApplicationWillChangeStatusBarOrientation,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(didChangeOrientationHandler),
                           name: .UIApplicationDidChangeStatusBarOrientation,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(didChangePageHandler),
                           name: .PDFViewPageChanged,
                           object: nil)
    }
    
    @objc func updateInterface() {
        if presentingViewController != nil, let navigationController = navigationController {
            // use same UI style as DocumentBrowserViewController
            view.backgroundColor = presentingViewController?.view.backgroundColor
            view.tintColor = presentingViewController?.view.tintColor
            navigationController.navigationBar.tintColor = presentingViewController?.view.tintColor
            navigationController.toolbar.tintColor = presentingViewController?.view.tintColor
            navigationItem.searchController?.searchBar.tintColor = presentingViewController?.view.tintColor
            if UserDefaults.standard.integer(forKey: DocumentBrowserViewController.browserUserInterfaceStyleKey) == UIDocumentBrowserViewController.BrowserUserInterfaceStyle.dark.rawValue {
                navigationController.navigationBar.barStyle = .black
                navigationController.toolbar.barStyle = .black
                // use true black background to protect OLED screen
                view.backgroundColor = .black
            } else {
                navigationController.navigationBar.barStyle = .default
                navigationController.toolbar.barStyle = .default
            }
            
            if navigationItem.searchController?.isActive == true, let items = navigationController.toolbar.items {
                for item in items {
                    item.isEnabled = true
                    item.tintColor = view.tintColor
                }
            }
            
            // for search
            guard let searchNC = searchNavigationController else { return }
            guard let searchVC = searchNC.topViewController as? SearchViewController else { return }
            searchNC.navigationBar.tintColor = view.tintColor
            searchNC.toolbar.tintColor = view.tintColor
            if navigationController.navigationBar.barStyle != .black {
                searchNC.navigationBar.barStyle = navigationController.navigationBar.barStyle
                searchNC.toolbar.barStyle = navigationController.toolbar.barStyle
                searchVC.view.backgroundColor = view.backgroundColor
                searchVC.searchBar.barStyle = searchNC.navigationBar.barStyle
            }
            searchVC.searchBar.tintColor = view.tintColor
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
            pdfView.setMinScaleFactorForSizeToFit()
            pdfView.go(to: page) // workaround to fix
            pdfView.setScaleFactorForUser()
        }
        
    }
    
    func updateScrollDirection() {
        updateUserScaleFactorAndOffset(changeOrientation: false)
        
        let thumbnailView = navigationController?.toolbar.viewWithTag(1) as? PDFThumbnailView
        
        if let currentPage = pdfView.currentPage {
            if pdfView.displayMode == .singlePageContinuous && allowsDocumentAssembly {
                if isRightToLeft != pdfView.isViewTransformedForRTL {
                    if pdfView.displaysRTL {
                        pdfView.displaysRTL = false
                    }
                    pdfView.transformViewForRTL(isRightToLeft, thumbnailView)
                }
                if isRightToLeft {
                    // single page RTL use horizontal scroll
                    if isRightToLeft {
                        isHorizontalScroll = true
                    }
                }
            } else if pdfView.displayMode == .twoUpContinuous {
                if isRightToLeft != pdfView.displaysRTL  {
                    if pdfView.isViewTransformedForRTL {
                        pdfView.transformViewForRTL(false, thumbnailView)
                    }
                    pdfView.displaysRTL = isRightToLeft
                }
                if isRightToLeft {
                    // two up RTL use vertical scroll
                    if isRightToLeft {
                        isHorizontalScroll = false
                    }
                }
            }
            
            if isHorizontalScroll != (pdfView.displayDirection == .horizontal) {
                if isHorizontalScroll {
                    pdfView.displayDirection = .horizontal
                } else {
                    if pdfView.isViewTransformedForRTL {
                        pdfView.transformViewForRTL(false, thumbnailView)
                    }
                    pdfView.displayDirection = .vertical
                }
                pdfView.scrollView?.showsHorizontalScrollIndicator = pdfView.displayDirection == .horizontal
                pdfView.scrollView?.showsVerticalScrollIndicator = pdfView.displayDirection == .vertical
            }
            
            pdfView.layoutDocumentView()
            pdfView.go(to: currentPage)
        }
        
        pdfView.setMinScaleFactorForSizeToFit()
        pdfView.setScaleFactorForUser()
    }
    
    func setPDFThumbnailView() {
        if let margins = navigationController?.toolbar.safeAreaLayoutGuide {
            let pdfThumbnailView = PDFThumbnailView()
            pdfThumbnailView.tag = 1
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if let navigationController = navigationController {
            for constraint in navigationController.navigationBar.constraints {
                if constraint.firstAttribute == NSLayoutAttribute.height {
                    if navigationController.navigationBar.frame.origin.y == -constraint.constant {
                        // system will return UIStatusBarStyle.default even when navigation bar style is .black
                        // a workaround to fix this
                        return navigationController.navigationBar.barStyle == .black ? .lightContent : .default
                    }
                }
            }
        }
        return super.preferredStatusBarStyle
    }
    
    override var prefersStatusBarHidden: Bool {
        if isFindOnPageEnabled {
            return navigationController?.isNavigationBarHidden == true && navigationItem.searchController?.isActive == false && navigationItem.searchController?.isBeingDismissed == false || super.prefersStatusBarHidden
        } else {
            return navigationController?.isNavigationBarHidden == true || super.prefersStatusBarHidden
        }
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return navigationController?.isToolbarHidden == true
    }
    
    @objc func doubleTapGestureRecognizerHandler(_ sender: UITapGestureRecognizer) {
        print(sender.location(in: pdfView))
        
        if !pdfView.isZoomedIn {
            updateUserScaleFactorAndOffset(changeOrientation: false)
        }
        
        pdfView.autoZoomInOrOut(location: sender.location(in: pdfView), animated: true)
    }
    
    @objc func barHideOnTapGestureRecognizerHandler() {
        navigationController?.setToolbarHidden(navigationController?.isNavigationBarHidden == true, animated: true)
        updateSearchController()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    func getScaleFactorForSizeToFitAndOffset() {
        // make sure to init
        if let verticalPortrait = currentEntity?.scaleFactorVerticalPortrait, let verticalLandscape = currentEntity?.scaleFactorVerticalLandscape {
            self.pdfView.hgScaleFactorVertical = HGPDFScaleFactor(portrait: CGFloat(verticalPortrait), landscape: CGFloat(verticalLandscape))
        }
        if let horizontalPortrait = currentEntity?.scaleFactorHorizontalPortrait, let horizontalLandscape = currentEntity?.scaleFactorVerticalLandscape {
            self.pdfView.hgScaleFactorHorizontal = HGPDFScaleFactor(portrait: CGFloat(horizontalPortrait), landscape: CGFloat(horizontalLandscape))
        }
        
        pdfView.getScaleFactorForSizeToFit()
        
        // offset
        offsetPortrait = currentEntity?.offsetLandscape as? CGPoint
        offsetLandscape = currentEntity?.offsetLandscape as? CGPoint
    }
    
    func updateUserScaleFactorAndOffset(changeOrientation: Bool) {
        // for save
        // XOR operator for bool (!=)
        if UIApplication.shared.statusBarOrientation.isPortrait != changeOrientation {
            if pdfView.displayDirection == .vertical {
                self.pdfView.hgScaleFactorVertical.portrait = pdfView.scaleFactor
            } else if pdfView.displayDirection == .horizontal {
                self.pdfView.hgScaleFactorHorizontal.portrait = pdfView.scaleFactor
            }
            
            offsetPortrait = pdfView.scrollView?.contentOffset
        } else if UIApplication.shared.statusBarOrientation.isLandscape != changeOrientation {
            if pdfView.displayDirection == .vertical {
                self.pdfView.hgScaleFactorVertical.landscape = pdfView.scaleFactor
            } else if pdfView.displayDirection == .horizontal {
                self.pdfView.hgScaleFactorHorizontal.landscape = pdfView.scaleFactor
            }
            
            offsetLandscape = pdfView.scrollView?.contentOffset
        }
    }
    
    func moveToLastViewedPage() {
        if let currentEntity = currentEntity {
            pageIndex = currentEntity.pageIndex
        } else if isHorizontalScroll {
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
    
    func moveToLastViewedOffset() {
        if let currentPage = pdfView.currentPage, let currentOffset = pdfView.scrollView?.contentOffset {
            if UIApplication.shared.statusBarOrientation.isPortrait, let offsetPortrait = currentEntity?.offsetPortrait as? CGPoint {
                pdfView.scrollView?.contentOffset = offsetPortrait
            } else if UIApplication.shared.statusBarOrientation.isLandscape, let offsetLandscape = currentEntity?.offsetLandscape as? CGPoint {
                pdfView.scrollView?.contentOffset = offsetLandscape
            }
            if pdfView.currentPage != currentPage {
                print("in case something wrong \nOld: \(currentPage) \nNew: \(String(describing: pdfView.currentPage)) \nmove to previous offset")
                pdfView.scrollView?.contentOffset = currentOffset
            }
        }
        didMoveToLastViewedPage = true
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
                message += "\n\(NSLocalizedString("Last Viewed Page:", comment: "")) \(cloudPageIndex.intValue + 1)"
                
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
                
                // fix crash 'NSInternalInconsistencyException', reason: 'accessing _cachedSystemAnimationFence requires the main thread'
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc func willChangeOrientationHandler() {
        updateUserScaleFactorAndOffset(changeOrientation: true)
    }
    
    @objc func didChangeOrientationHandler() {
        // detect if user enabled and update scale factor
        setPreferredDisplayMode(prefersTwoUpInLandscapeForPad)
        updateScrollDirection()
    }
    
    @objc func didChangePageHandler() {
        guard let pdfDocument = pdfView.document else { return }
        guard let currentPage = pdfView.currentPage else { return }
        let currentIndex = pdfDocument.index(for: currentPage)
        // currentIndex starts from 0
        pageLabel.text = "\(currentIndex+1) / \(pdfDocument.pageCount)"
        
        blurEffectView.alpha = 1.0
        blurEffectView.isHidden = false
        blurDismissTimer.invalidate()
        blurDismissTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(hidePageLabel), userInfo: nil, repeats: false)
    }
    
    @objc func hidePageLabel() {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseOut], animations: {
            self.blurEffectView.alpha = 0.0
        }) { (completed) in
            self.blurEffectView.isHidden = true
        }
    }
    
    // MARK: - IBAction
    
    @IBAction func searchLeft(_ sender: UIBarButtonItem) {
        if isRightToLeft {
            searchText(withOptions: [.regularExpression])
        } else {
            searchText(withOptions: [.regularExpression, .backwards])
        }
    }
    
    @IBAction func searchRight(_ sender: UIBarButtonItem) {
        if isRightToLeft {
            searchText(withOptions: [.regularExpression, .backwards])
        } else {
            searchText(withOptions: [.regularExpression])
        }
    }
    
    /*
     @IBAction func shareAction() {
     let activityVC = UIActivityViewController(activityItems: [document?.fileURL as Any], applicationActivities: nil)
     self.present(activityVC, animated: true, completion: nil)
     }
     */
    
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.saveAndClose()
        }
    }
    
    @objc func saveAndClose() {
        guard let pdfDocument = pdfView.document else { return }
        if let currentPage = pdfView.currentPage {
            let currentIndex = pdfDocument.index(for: currentPage)
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
        entity.isHorizontalScroll = self.isHorizontalScroll
        entity.isRightToLeft = self.isRightToLeft
        entity.prefersTwoUpInLandscapeForPad = self.prefersTwoUpInLandscapeForPad
        entity.isFindOnPage = isFindOnPageEnabled
        
        // store user scale factor
        updateUserScaleFactorAndOffset(changeOrientation: false)
        // Vertical
        entity.scaleFactorVerticalPortrait = Float(self.pdfView.hgScaleFactorVertical.portrait)
        entity.scaleFactorVerticalLandscape = Float(self.pdfView.hgScaleFactorVertical.landscape)
        // Horizontal
        entity.scaleFactorHorizontalPortrait = Float(self.pdfView.hgScaleFactorHorizontal.portrait)
        entity.scaleFactorHorizontalLandscape = Float(self.pdfView.hgScaleFactorHorizontal.landscape)
        
        if let offsetPortrait = offsetPortrait {
            entity.offsetPortrait = offsetPortrait as NSObject
        }
        if let offsetLandscape = offsetLandscape {
            entity.offsetLandscape = offsetLandscape as NSObject
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

extension DocumentViewController {
    // MARK: - Custom Menus
    
    func enableCustomMenus() {
        let define = UIMenuItem(title: NSLocalizedString("Define", comment: "define"), action: #selector(define(_:)))
        UIMenuController.shared.menuItems = [define]
    }
    
    @objc func define(_ sender: UIMenuController) {
        if let term = pdfView.currentSelection?.string {
            if let searchController = navigationItem.searchController, searchController.isActive {
                searchController.isActive = false
            }
            let referenceLibraryVC = UIReferenceLibraryViewController(term: term)
            self.present(referenceLibraryVC, animated: true, completion: nil)
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
                let width = popopverVC.preferredContentSize.width
                var height = popopverVC.preferredContentSize.height
                if !isEncrypted {
                    height -= 44
                }
                if UIDevice.current.userInterfaceIdiom != .pad {
                    height -= 44
                }
                // temporary disable Find on Page
                height -= 44
                
                popopverVC.preferredContentSize = CGSize(width: width, height: height)
                
            }
        } else if (segue.identifier == "Container") {
            if let containerVC: ContainerViewController = segue.destination as? ContainerViewController {
                containerVC.pdfDocument = pdfView.document
                containerVC.displayBox = pdfView.displayBox
                containerVC.transformForRTL = pdfView.isViewTransformedForRTL
                if let currentPage = pdfView.currentPage, let document: PDFDocument = pdfView.document {
                    containerVC.currentIndex = document.index(for: currentPage)
                }
                containerVC.delegate = self
            }
        } else if (segue.identifier == "SearchViewController") {
            if let searchNC = segue.destination as? UINavigationController,
                let searchVC = searchNC.topViewController as? SearchViewController,
                let navigationController = navigationController {
                searchNC.navigationBar.tintColor = presentingViewController?.view.tintColor
                searchNC.toolbar.tintColor = presentingViewController?.view.tintColor
                if navigationController.navigationBar.barStyle != .black {
                    searchNC.navigationBar.barStyle = navigationController.navigationBar.barStyle
                    searchNC.toolbar.barStyle = navigationController.toolbar.barStyle
                    searchVC.view.backgroundColor = presentingViewController?.view.backgroundColor
                    searchVC.searchBar.barStyle = searchNC.navigationBar.barStyle
                }
                searchVC.searchBar.tintColor = presentingViewController?.view.tintColor
                searchNavigationController = searchNC
                
                // because searchVC is in a navigationController, viewDidLoad() will proceeded before here.
                searchVC.delegate = self
                searchVC.pdfDocument = pdfView.document
                searchVC.pdfDocument?.delegate = searchVC
                searchVC.displayBox = pdfView.displayBox
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    searchNC.modalPresentationStyle = .popover
                    searchNC.popoverPresentationController?.delegate = self
                }
            }
        }
    }
    
    // fix for iPhone Plus
    // https://stackoverflow.com/q/36349303/4063462
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
}

