//
//  PDFView+Zoom.swift
//  HGPDFKit
//
//  Created by ERU on 2018/10/28.
//  Copyright © 2018 HackingGate. All rights reserved.
//

import PDFKit

extension PDFView {
    public var isZoomedIn: Bool {
        get {
            if self.scaleFactor == self.maxScaleFactor {
                return true
            } else {
                return Holder.isZoomedIn
            }
        }
    }
    
    public func autoZoomInOrOut(location: CGPoint, animated: Bool) {
        
        var scaleFactor: CGFloat?
        
        if UIApplication.shared.statusBarOrientation.isPortrait {
            if self.displayDirection == .vertical, self.scaleFactor != hgScaleFactorVertical.portrait {
                scaleFactor = hgScaleFactorVertical.portrait
            } else if self.displayDirection == .horizontal, self.scaleFactor != hgScaleFactorHorizontal.portrait {
                scaleFactor = hgScaleFactorHorizontal.portrait
            }
        } else if UIApplication.shared.statusBarOrientation.isLandscape {
            if self.displayDirection == .vertical, self.scaleFactor != hgScaleFactorVertical.landscape {
                scaleFactor = hgScaleFactorVertical.landscape
            } else if self.displayDirection == .horizontal, self.scaleFactor != hgScaleFactorHorizontal.landscape {
                scaleFactor = hgScaleFactorHorizontal.landscape
            }
        }
        
        if let scaleFactor = scaleFactor {
            // zoom out
            self.scrollView?.setZoomScale(scaleFactor, animated: animated)
            Holder.isZoomedIn = false
            return
        }
        
        if let page = self.page(for: location, nearest: false) {
            // tap point in page space
            let pagePoint = self.convert(location, to: page)
            if let scrollView = self.scrollView {
                
                // normal zoom in
                let locationInView = location
                let boundsInView = CGRect(x: locationInView.x - 64, y: locationInView.y - 64, width: 128, height: 128)
                let boundsInPage = self.convert(boundsInView, to: page)
                var boundsInScroll = scrollView.convert(boundsInView, from: self)
                
                if let selection = page.selectionForLine(at: pagePoint), selection.pages.first == page, let string = selection.string, string.count > 1 {
                    // zoom in to fit text
                    // selection bounds in page space
                    let boundsInPage = selection.bounds(for: page)
                    // selection bounds in view space
                    let boundsInView = self.convert(boundsInPage, from: page)
                    // selection bounds in scroll space
                    boundsInScroll = scrollView.convert(boundsInView, from: self)
                }
                
                UIView.animate(withDuration: animated ? 0.25 : 0.0, delay: 0, options: [.curveEaseInOut], animations: {
                    let safeAreaWidth = self.frame.width - self.safeAreaInsets.left - self.safeAreaInsets.right
                    let safeAreaHeight = self.frame.height - self.safeAreaInsets.top - self.safeAreaInsets.bottom
                    
                    // + 10 to not overlap scroll indicator
                    let widthMultiplier = safeAreaWidth / (boundsInScroll.size.width + 20)
                    let heightMultiplier = safeAreaHeight / (boundsInScroll.size.height + 20)
                    if widthMultiplier <= heightMultiplier {
                        scrollView.setZoomScale(scrollView.zoomScale * widthMultiplier, animated: false)
                    } else {
                        scrollView.setZoomScale(scrollView.zoomScale * heightMultiplier, animated: false)
                    }
                    
                    // recalculate
                    if let selection = page.selectionForLine(at: pagePoint), selection.pages.first == page, let string = selection.string, string.count > 1 {
                        // zoom in to fit text
                        // selection bounds in page space
                        let boundsInPage = selection.bounds(for: page)
                        // selection bounds in view space
                        let boundsInView = self.convert(boundsInPage, from: page)
                        // selection bounds in scroll space
                        boundsInScroll = scrollView.convert(boundsInView, from: self)
                    } else {
                        // normal zoom in
                        // location bounds in view space
                        let boundsInView = self.convert(boundsInPage, from: page)
                        // location bounds in scroll space
                        boundsInScroll = scrollView.convert(boundsInView, from: self)
                    }
                    
                    // if navigation bar or tool bar is not hidden
                    let diffYToFix = (self.safeAreaInsets.top - self.safeAreaInsets.bottom) / 2
                    
                    let offset = CGPoint(x: boundsInScroll.midX - self.center.x, y: boundsInScroll.midY - self.frame.height / 2 - diffYToFix)
                    scrollView.setContentOffset(offset, animated: false)
                }, completion: { (successful) in
                    Holder.isZoomedIn = successful
                })
                
            }
        }
    }
}
