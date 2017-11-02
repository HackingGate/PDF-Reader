//
//  DocumentViewController.swift
//  PDFReader
//
//  Created by Eru on H29/09/28.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

class DocumentViewController: UIViewController {
    
    @IBOutlet weak var pdfView: PDFView!
    
    var document: Document?
    
    let userDeaults = UserDefaults.standard
    
    var portraitScaleFactorForSizeToFit: CGFloat = 0.0
    var landscapeScaleFactorForSizeToFit: CGFloat = 0.0
    
//    縦書き
    var verticalWriting = false
    
    override func viewWillAppear(_ animated: Bool) {
        updateInterface()
        super.viewWillAppear(animated)
        
        // Access the document
        document?.open(completionHandler: { (success) in
            if success {
                // Display the content of the document, e.g.:
                self.navigationItem.title = self.document?.localizedName
            
                if let document = PDFDocument(url: (self.document?.fileURL)!) {
                    self.pdfView.document = document
                    let pageSize = self.pdfView.rowSize(for: self.pdfView.currentPage!)
                    
                    if (pageSize.width > pageSize.height) {
                        self.pdfView.displayDirection = .horizontal
                        self.verticalWriting = true
                        // document must be reset after displayDirection setted
                        self.pdfView.document = nil
                        self.pdfView.document = document
                    }
                    
                    if self.verticalWriting {
                        // ページ交換ファンクションを利用して、降順ソートして置き換える。
                        let actionCount = document.pageCount/2
                        for i in 0...actionCount {
                            document.exchangePage(at: i, withPageAt: document.pageCount-i)
                        }
                    }

                    self.moveToLastReadingProsess()
                    if self.pdfView.displayDirection == .vertical {
                        self.getScaleFactorForSizeToFit()
                    }
                    
                    self.setPDFThumbnailView()
                }
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    override func viewDidLoad() {
        navigationController?.hidesBarsOnTap = true
        navigationController?.barHideOnTapGestureRecognizer.addTarget(self, action: #selector(barHideOnTapGestureRecognizerHandler))
        
        
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = false
        pdfView.displayBox = .cropBox
        pdfView.displayMode = .singlePageContinuous
        
        
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
            if UserDefaults.standard.integer(forKey: (presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey) == 2 {
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
    
    func setPDFThumbnailView() {
        let pdfThumbnailView = PDFThumbnailView.init()
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .horizontal
        pdfThumbnailView.translatesAutoresizingMaskIntoConstraints = false
        navigationController!.toolbar.addSubview(pdfThumbnailView)
        let margins = navigationController!.toolbar.safeAreaLayoutGuide
        pdfThumbnailView.leadingAnchor.constraint(equalTo: margins.leadingAnchor).isActive = true
        pdfThumbnailView.trailingAnchor.constraint(equalTo: margins.trailingAnchor).isActive = true
        pdfThumbnailView.topAnchor.constraint(equalTo: margins.topAnchor).isActive = true
        pdfThumbnailView.bottomAnchor.constraint(equalTo: margins.bottomAnchor).isActive = true
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
        if portraitScaleFactorForSizeToFit == 0.0 && UIApplication.shared.statusBarOrientation.isPortrait {
            portraitScaleFactorForSizeToFit = pdfView.scaleFactorForSizeToFit 
            landscapeScaleFactorForSizeToFit = portraitScaleFactorForSizeToFit / aspectRatio            
            pdfView.minScaleFactor = portraitScaleFactorForSizeToFit
            pdfView.scaleFactor = portraitScaleFactorForSizeToFit
        } else if landscapeScaleFactorForSizeToFit == 0.0 && UIApplication.shared.statusBarOrientation.isLandscape {
            landscapeScaleFactorForSizeToFit = pdfView.scaleFactorForSizeToFit
            portraitScaleFactorForSizeToFit = landscapeScaleFactorForSizeToFit / aspectRatio
            pdfView.minScaleFactor = landscapeScaleFactorForSizeToFit
            pdfView.scaleFactor = landscapeScaleFactorForSizeToFit
        }
    }
    
    func moveToLastReadingProsess() {
        var pageIndex = 0
        if self.userDeaults.object(forKey: (self.pdfView.document?.documentURL?.path)!) != nil {
            // key exists
            pageIndex = self.userDeaults.integer(forKey: (self.pdfView.document?.documentURL?.path)!)
        } else if verticalWriting {
            // 初めて読む　且つ　縦書き
            pageIndex = (self.pdfView.document?.pageCount)! - 1
        }
        
        // TODO: if pageIndex == pageCount - 1, then go to last CGRect
        self.pdfView.go(to: (self.pdfView.document?.page(at: pageIndex)!)!)
    }
    
    @objc func saveAndClose() {
        self.userDeaults.set(self.pdfView.document?.index(for: self.pdfView.currentPage!), forKey: (self.pdfView.document?.documentURL?.path)!)
        
        self.document?.close(completionHandler: nil)
    }
    
    @objc func didChangeOrientationHandler() {
        if portraitScaleFactorForSizeToFit != 0.0 && UIApplication.shared.statusBarOrientation.isPortrait {
            pdfView.minScaleFactor = portraitScaleFactorForSizeToFit
            pdfView.scaleFactor = portraitScaleFactorForSizeToFit
        } else if landscapeScaleFactorForSizeToFit != 0.0 && UIApplication.shared.statusBarOrientation.isLandscape {
            pdfView.minScaleFactor = landscapeScaleFactorForSizeToFit
            pdfView.scaleFactor = landscapeScaleFactorForSizeToFit
        }
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
