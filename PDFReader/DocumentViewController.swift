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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Access the document
        document?.open(completionHandler: { (success) in
            if success {
                // Display the content of the document, e.g.:

            
                if let document = PDFDocument(url: (self.document?.fileURL)!) {
                    self.pdfView.document = document
                    self.moveToLastReadingProsess()
                }
            } else {
                // Make sure to handle the failed import appropriately, e.g., by presenting an error message to the user.
            }
        })
    }
    
    override func viewDidLoad() {
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = false
        pdfView.displayBox = .cropBox
        
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(saveCurrentPage),
                           name: .UIApplicationDidEnterBackground,
                           object: nil)
    }
    
    func moveToLastReadingProsess() {
        let pageIndex = self.userDeaults.integer(forKey: (self.pdfView.document?.documentURL?.path)!)
        self.pdfView.go(to: (self.pdfView.document?.page(at: pageIndex)!)!)
    }
    
    @objc func saveCurrentPage() {
        self.userDeaults.set(self.pdfView.document?.index(for: self.pdfView.currentPage!), forKey: (self.pdfView.document?.documentURL?.path)!)
        
        self.document?.close(completionHandler: nil)
    }
    
    @IBAction func dismissDocumentViewController() {
        dismiss(animated: true) {
            self.document?.close(completionHandler: nil)
        }
    }
}
