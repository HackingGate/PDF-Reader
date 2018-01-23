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
    var isHorizontalScroll: Bool { get set }
    var isRightToLeft: Bool { get set }
    var isEncrypted: Bool { get }
    var allowsDocumentAssembly: Bool { get }
    var prefersTwoUpInLandscapeForPad: Bool { get }
    var displayMode: PDFDisplayMode { get }
    func updateScrollDirection() -> Void
    func goToPage(page: PDFPage) -> Void
    func selectOutline(outline: PDFOutline) -> Void
    func setPreferredDisplayMode(_ twoUpInLandscapeForPad: Bool) -> Void
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
    var searchBarText: String?
    
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
    
    // offset
    var offsetPortrait: CGPoint?
    var offsetLandscape: CGPoint?
    
    // delegate properties
    var isHorizontalScroll = false
    var isRightToLeft = false
    var isEncrypted = false
//    var allowsDocumentAssembly = false
    var isPageExchangedForRTL = false // if allowsDocumentAssembly is false, then the value should always be false
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
                
//                self.allowsDocumentAssembly = document.allowsDocumentAssembly
                self.isEncrypted = document.isEncrypted
                
                self.pdfView.document = document
                
                self.moveToLastViewedPage()
                self.getScaleFactorForSizeToFitAndOffset()
                self.setMinScaleFactorForSizeToFit()
                self.setScaleFactorForUser()
                
                if let documentEntity = self.currentEntity {
                    self.isHorizontalScroll = documentEntity.isHorizontalScroll
                    self.isRightToLeft = documentEntity.isRightToLeft
                    self.updateScrollDirection()
                }
                self.moveToLastViewedOffset()

                self.setPDFThumbnailView()
                
                self.checkForNewerRecords()
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    override func viewDidLoad() {
        navigationController?.barHideOnTapGestureRecognizer.addTarget(self, action: #selector(barHideOnTapGestureRecognizerHandler))

        setUpSearch()
        
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
            navigationController?.toolbar.tintColor = presentingViewController?.view.tintColor
            navigationItem.searchController?.searchBar.tintColor = presentingViewController?.view.tintColor
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
            setMinScaleFactorForSizeToFit()
            pdfView.go(to: page) // workaround to fix
            setScaleFactorForUser()
        }

    }
    
    func updateScrollDirection() {
        updateUserScaleFactorAndOffset(changeOrientation: false)
        
        // experimental feature
        if let currentPage = pdfView.currentPage, let document: PDFDocument = pdfView.document {
            if pdfView.displayMode == .singlePageContinuous && allowsDocumentAssembly {
                if isRightToLeft != isPageExchangedForRTL {
                    if pdfView.displaysRTL {
                        pdfView.displaysRTL = false
                    }
                    exchangePageForRTL(isRightToLeft)
                }
                if isRightToLeft {
                    // single page RTL use horizontal scroll
                    if isRightToLeft {
                        isHorizontalScroll = true
                    }
                }
            } else if pdfView.displayMode == .twoUpContinuous {
                if isRightToLeft != pdfView.displaysRTL  {
                    if isPageExchangedForRTL {
                        exchangePageForRTL(false)
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
                    if isPageExchangedForRTL {
                        exchangePageForRTL(false)
                    }
                    pdfView.displayDirection = .vertical
                }
            }
            
            // reset document to update interface
            pdfView.document = nil
            pdfView.document = document
            pdfView.go(to: currentPage)
        }
        
        setMinScaleFactorForSizeToFit()
        setScaleFactorForUser()
    }
    
    func exchangePageForRTL(_ exchange: Bool) {
        if exchange != isPageExchangedForRTL, let currentPage = pdfView.currentPage, let document: PDFDocument = pdfView.document {
            let currentIndex: Int = document.index(for: currentPage)
            print("currentIndex: \(currentIndex)")
            
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
        }
        
        isPageExchangedForRTL = exchange
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
        return navigationController?.isNavigationBarHidden == true && navigationItem.searchController?.isActive == false && navigationItem.searchController?.isBeingDismissed == false || super.prefersStatusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool {
        return navigationController?.isToolbarHidden == true
    }
    
    @objc func barHideOnTapGestureRecognizerHandler() {
        navigationController?.setToolbarHidden(navigationController?.isNavigationBarHidden == true, animated: true)
        updateSearchController()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    func getScaleFactorForSizeToFitAndOffset() {
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
        
        // offset
        offsetPortrait = currentEntity?.offsetLandscape as? CGPoint
        offsetLandscape = currentEntity?.offsetLandscape as? CGPoint
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
    
    func updateUserScaleFactorAndOffset(changeOrientation: Bool) {
        // for save
        // XOR operator for bool (!=)
        if UIApplication.shared.statusBarOrientation.isPortrait != changeOrientation {
            if pdfView.displayDirection == .vertical {
                scaleFactorVertical?.portrait = pdfView.scaleFactor
            } else if pdfView.displayDirection == .horizontal {
                scaleFactorHorizontal?.portrait = pdfView.scaleFactor
            }
            
            offsetPortrait = pdfView.scrollView?.contentOffset
        } else if UIApplication.shared.statusBarOrientation.isLandscape != changeOrientation {
            if pdfView.displayDirection == .vertical {
                scaleFactorVertical?.landscape = pdfView.scaleFactor
            } else if pdfView.displayDirection == .horizontal {
                scaleFactorHorizontal?.landscape = pdfView.scaleFactor
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
        updateUserScaleFactorAndOffset(changeOrientation: true)
    }
    
    @objc func didChangeOrientationHandler() {
        // detect if user enabled and update scale factor
        setPreferredDisplayMode(prefersTwoUpInLandscapeForPad)
        updateScrollDirection()
    }
    
    // MARK: - IBAction

    @IBAction func searchPrevious(_ sender: UIBarButtonItem) {
        searchText(withOptions: .backwards)
    }
    
    @IBAction func searchNext(_ sender: UIBarButtonItem) {
        searchText(withOptions: .regularExpression)
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
        entity.isHorizontalScroll = self.isHorizontalScroll
        entity.isRightToLeft = self.isRightToLeft
        entity.prefersTwoUpInLandscapeForPad = self.prefersTwoUpInLandscapeForPad
        
        // store user scale factor
        updateUserScaleFactorAndOffset(changeOrientation: false)
        if let scaleFactorVertical = scaleFactorVertical {
            entity.scaleFactorVerticalPortrait = Float(scaleFactorVertical.portrait)
            entity.scaleFactorVerticalLandscape = Float(scaleFactorVertical.landscape)
        }
        if let scaleFactorHorizontal = scaleFactorHorizontal {
            entity.scaleFactorHorizontalPortrait = Float(scaleFactorHorizontal.portrait)
            entity.scaleFactorHorizontalLandscape = Float(scaleFactorHorizontal.landscape)
        }
        
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
                var height = 289
                if !isEncrypted {
                    // 289 - 44 = 245
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

// MARK: - UISearch

extension DocumentViewController: UISearchBarDelegate, UISearchControllerDelegate {
    
    func setUpSearch() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    func updateSearchController() {
        if let navigationController = navigationController, let searchController = navigationItem.searchController {
            searchController.searchBar.superview?.isHidden = navigationController.isNavigationBarHidden
            
            if navigationController.isNavigationBarHidden {
                self.additionalSafeAreaInsets.top = -64 // fixed by a magic num
            }
            else {
                self.additionalSafeAreaInsets.top = 0
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
                pdfView.go(to: newSelection)
                pdfView.setCurrentSelection(newSelection, animate: true)
            } else {
                // for workaround: clear selected if no real search results returned
                pdfView.clearSelection()
            }
        }
    }
    
    // UISearchBarDelegate
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBarText = searchBar.text
        if isPageExchangedForRTL {
            searchText(withOptions: .backwards)
        } else {
            searchText(withOptions: .regularExpression)
        }
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
