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
    var transformForRTL: Bool = false
    var isWidthGreaterThanHeight: Bool = false
    var currentIndex: Int = 0
    var onceOnly = false
    let thumbnailCache = NSCache<NSNumber, UIImage>()

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
        
    }
    
    // Start UICollectionView at a specific indexpath
    // https://stackoverflow.com/a/35679859/4063462
    internal override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !onceOnly {
            collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredVertically, animated: false)
            onceOnly = true
        }
        
        let imageView = cell.viewWithTag(1) as? UIImageView
        if imageView?.image == nil {
            if let thumbnail: UIImage = thumbnailCache.object(forKey: NSNumber(value: indexPath.item)) {
                imageView?.image = thumbnail
            }
        }
        
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
        
        var multiplier: CGFloat = 1.0
        if UIApplication.shared.statusBarOrientation.isPortrait {
            // calculate size for landscape
            var safeAreaWidth = UIScreen.main.bounds.height
            if UIApplication.shared.statusBarFrame.height != 20 {
                // for iPhone X
                safeAreaWidth -= UIApplication.shared.statusBarFrame.height * 2
            }
            let width: CGFloat = (safeAreaWidth - (isWidthGreaterThanHeight ? 64 : 80)) / (isWidthGreaterThanHeight ? 3 : 4)
            let flooredWidth = width.flooredFloat
            multiplier = flooredWidth / cell.bounds.size.width
        }
        
        let cellScreenSize = CGSize(width: cell.bounds.size.width * UIScreen.main.scale * multiplier, height: cell.bounds.size.height * UIScreen.main.scale * multiplier)
        
        let imageView = cell.viewWithTag(1) as? UIImageView
        
        if let thumbnail: UIImage = thumbnailCache.object(forKey: NSNumber(value: indexPath.item)) {
            imageView?.image = thumbnail
        } else {
            imageView?.image = nil
            // cache images
            // https://stackoverflow.com/a/16694019/4063462
            DispatchQueue.global(qos: .userInteractive).async {
                if let page = self.pdfDocument?.page(at: indexPath.item) {
                    let thumbnail = page.thumbnail(of: cellScreenSize, for: self.displayBox)
                    self.thumbnailCache.setObject(thumbnail, forKey: NSNumber(value: indexPath.item))
                    DispatchQueue.main.async {
                        let updateCell = collectionView.cellForItem(at: indexPath)
                        let updateImageView = updateCell?.viewWithTag(1) as? UIImageView
                        if updateImageView?.image == nil {
                            updateImageView?.image = thumbnail
                        }
                    }
                }
            }
        }
        
        imageView?.transform = CGAffineTransform(rotationAngle: transformForRTL ? .pi : 0)

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
        
        var width: CGFloat = 0.0
        
        if UIApplication.shared.statusBarOrientation.isPortrait {
            // 3 items per line or 2 when width greater than height
            width = (collectionViewSafeAreaWidth - (isWidthGreaterThanHeight ? 48 : 64)) / (isWidthGreaterThanHeight ? 2 : 3)
        } else {
            // 4 items per line or 3 when width greater than height
            width = (collectionViewSafeAreaWidth - (isWidthGreaterThanHeight ? 64 : 80)) / (isWidthGreaterThanHeight ? 3 : 4)
        }
        
        let flooredWidth = width.flooredFloat
        
        if let page = pdfDocument?.page(at: indexPath.item) {
            
            let rect = page.bounds(for: displayBox)
            let aspectRatio = rect.width / rect.height
            
            let height = flooredWidth / aspectRatio
            
            return CGSize(width: flooredWidth, height: height)
        }
        
        return .zero
    }
}

extension CGFloat {
    // 64-bit device
    var flooredFloat: CGFloat {
        let flooredFloat = CGFloat(floor(Double(self) * 1000000000000) / 1000000000000)
        return flooredFloat
    }
}

