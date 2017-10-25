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
                        for i in 0...actionCount{
                            document.exchangePage(at: i, withPageAt: document.pageCount-i)
                        }
                    }

                    self.moveToLastReadingProsess()
                }
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    override func viewDidLoad() {
        self.navigationController?.hidesBarsOnTap = true
        
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
    }
    
    @objc func updateInterface() {
        if presentingViewController != nil {
            // use same UI style as DocumentBrowserViewController
            if UserDefaults.standard.integer(forKey: (presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey) == 2 {
                navigationController?.navigationBar.barStyle = .black
            } else {
                navigationController?.navigationBar.barStyle = .default
            }
            view.backgroundColor = presentingViewController?.view.backgroundColor
            navigationController?.navigationBar.tintColor = presentingViewController?.view.tintColor
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden == true || super.prefersStatusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
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
    
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.saveAndClose()
        }
    }
}
