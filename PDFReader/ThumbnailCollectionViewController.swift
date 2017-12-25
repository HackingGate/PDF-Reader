//
//  ThumbnailCollectionViewController.swift
//  PDFReader
//
//  Created by ERU on H29/12/16.
//  Copyright © 平成29年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

private let reuseIdentifier = "ThumbnailCell"

class ThumbnailCollectionViewController: UICollectionViewController {
    
    var delegate: SettingsDelegate!
    var pdfDocument: PDFDocument?
    var displayBox: PDFDisplayBox = .cropBox
    var isWidthGreaterThanHeight: Bool = false
    var currentIndex: Int = 0

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.hidesBarsOnTap = false
        super.viewWillAppear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()


        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false


        // Do any additional setup after loading the view.
        
        let page0 = pdfDocument?.page(at: 0)
        let page1 = pdfDocument?.page(at: 1)
        
        if let bounds0 = page0?.bounds(for: displayBox), let bounds1 = page1?.bounds(for: displayBox) {
            
            if bounds0.size.width > bounds0.size.height && bounds1.size.width > bounds1.size.height {
                isWidthGreaterThanHeight = true
            }
        }
        
        collectionView?.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredVertically, animated: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return pdfDocument?.pageCount ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        
        let numberLabel = cell.viewWithTag(2) as? PaddingLabel
        numberLabel?.text = String(indexPath.item + 1)
        
        let cellScreenSize = CGSize(width: cell.bounds.size.width * UIScreen.main.scale, height: cell.bounds.size.height * UIScreen.main.scale)
        
        let imageView = cell.viewWithTag(1) as? UIImageView
        
        if let page = self.pdfDocument?.page(at: indexPath.item) {
            
            let thumbnail = page.thumbnail(of: cellScreenSize, for: displayBox)
            imageView?.image = thumbnail
        }

        cell.layer.shadowOffset = CGSize(width: 1, height: 1)
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowRadius = 5
        cell.layer.shadowOpacity = 0.35
        
        cell.clipsToBounds = false
        cell.layer.masksToBounds = false
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let page = pdfDocument?.page(at: indexPath.item) {
            delegate.goToPage(page: page)
            navigationController?.popViewController(animated: true)
        }
    }

}

extension ThumbnailCollectionViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let collectionViewSafeAreaWidth = collectionView.frame.size.width - collectionView.safeAreaInsets.left - collectionView.safeAreaInsets.right
        
        var width: Double = 0.0
        
        if UIApplication.shared.statusBarOrientation.isPortrait {
            // 3 items per line or 2 when width greater than height
            width = Double((collectionViewSafeAreaWidth - (isWidthGreaterThanHeight ? 48 : 64)) / (isWidthGreaterThanHeight ? 2 : 3))
        } else {
            // 4 items per line or 3 when width greater than height
            width = Double((collectionViewSafeAreaWidth - (isWidthGreaterThanHeight ? 64 : 80)) / (isWidthGreaterThanHeight ? 3 : 4))
        }
        
        // This app requires iOS 11. And iOS 11 requires 64-bit device.
        let flooredWidth = CGFloat(floor(width * 1000000000000) / 1000000000000)
        
        if let page = pdfDocument?.page(at: indexPath.item) {
            
            let rect = page.bounds(for: displayBox)
            let aspectRatio = rect.width / rect.height
            
            let height = flooredWidth / aspectRatio
            
            return CGSize(width: flooredWidth, height: height)
        }
        
        return .zero
    }
}

