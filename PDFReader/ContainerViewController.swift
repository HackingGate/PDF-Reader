//
//  ContainerViewController.swift
//  PDFReader
//
//  Created by ERU on H29/12/25.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

class ContainerViewController: UIViewController {

    @IBOutlet weak var tableContainer: UIView!
    @IBOutlet weak var collectionContainer: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    var delegate: SettingsDelegate!
    var pdfDocument: PDFDocument?
    var displayBox: PDFDisplayBox = .cropBox
    var transformForRTL: Bool = false
    var currentIndex: Int = 0
    
    @IBAction func segmentControlValueChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            tableContainer.isHidden = true
            collectionContainer.isHidden = false
        } else if sender.selectedSegmentIndex == 1 {
            collectionContainer.isHidden = true
            tableContainer.isHidden = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.hidesBarsOnTap = false
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if pdfDocument?.outlineRoot?.numberOfChildren == nil {
            segmentedControl.removeSegment(at: 1, animated: false)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "ThumbnailCollection") {
            if let thumbnailCollectionVC: ThumbnailCollectionViewController = segue.destination as? ThumbnailCollectionViewController {
                thumbnailCollectionVC.pdfDocument = pdfDocument
                thumbnailCollectionVC.displayBox = displayBox
                thumbnailCollectionVC.transformForRTL = transformForRTL
                thumbnailCollectionVC.currentIndex = currentIndex
                thumbnailCollectionVC.delegate = delegate
            }
        } else if (segue.identifier == "OutlineTable") {
            if let outlineTableVC: OutlineTableViewController = segue.destination as? OutlineTableViewController {
                outlineTableVC.outlineRoot = pdfDocument?.outlineRoot
                outlineTableVC.delegate = delegate
            }
        }
    }
    
    @IBAction func shareAction(_ sender: UIBarButtonItem) {
        delegate.share()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
