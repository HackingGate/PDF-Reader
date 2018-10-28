//
//  PDFView+ScaleFactor.swift
//  HGPDFKit
//
//  Created by ERU on 2018/10/28.
//  Copyright © 2018 HackingGate. All rights reserved.
//

import PDFKit

extension PDFView {
    public var hgScaleFactorForSizeToFit: HGPDFScaleFactor? {
        get {
            return Holder.hgScaleFactorForSizeToFit
        }
        set(newValue) {
            Holder.hgScaleFactorForSizeToFit = newValue
        }
    }
    
    public var hgScaleFactorVertical: HGPDFScaleFactor {
        get {
            return Holder.hgScaleFactorVertical
        }
        set(newValue) {
            Holder.hgScaleFactorVertical = newValue
        }
    }
    
    public var hgScaleFactorHorizontal: HGPDFScaleFactor {
        get {
            return Holder.hgScaleFactorHorizontal
        }
        set(newValue) {
            Holder.hgScaleFactorHorizontal = newValue
        }
    }
    
    public func getScaleFactorForSizeToFit() {
        if self.displayDirection == .vertical, let superViewFrame = self.superview?.frame {
            let aspectRatio = superViewFrame.size.width / superViewFrame.size.height
            // if it is iPhoneX, the pdfView.scaleFactorForSizeToFit is already optimized for save area
            let divider = (self.frame.width - self.safeAreaInsets.left - self.safeAreaInsets.right) / self.frame.width
            // the scaleFactor defines the super area scale factor
            var scaleFactor = self.scaleFactorForSizeToFit / divider
            if self.displayMode == .twoUpContinuous {
                scaleFactor *= 2
            }
            if UIApplication.shared.statusBarOrientation.isPortrait {
                self.hgScaleFactorForSizeToFit = HGPDFScaleFactor(portrait: scaleFactor,
                                                                  landscape: scaleFactor / aspectRatio)
            } else if UIApplication.shared.statusBarOrientation.isLandscape {
                self.hgScaleFactorForSizeToFit = HGPDFScaleFactor(portrait: scaleFactor / aspectRatio,
                                                                  landscape: scaleFactor)
            }
        }
    }
    
    // SizeToFit currentlly only works for vertical display direction
    public func setMinScaleFactorForSizeToFit() {
        if self.displayDirection == .vertical, let scaleFactorForSizeToFit = self.hgScaleFactorForSizeToFit {
            if UIApplication.shared.statusBarOrientation.isPortrait {
                if self.displayMode == .singlePageContinuous {
                    self.minScaleFactor = scaleFactorForSizeToFit.portrait
                } else if self.displayMode == .twoUpContinuous {
                    self.minScaleFactor = scaleFactorForSizeToFit.portrait / 2
                }
            } else if UIApplication.shared.statusBarOrientation.isLandscape {
                // set minScaleFactor to safe area for iPhone X and later
                var coreWidth = self.frame.width - self.safeAreaInsets.left - self.safeAreaInsets.right
                
                if self.parentViewController?.navigationController?.isNavigationBarHidden == true,
                    let windowSafeAreaInsets = UIApplication.shared.delegate?.window??.safeAreaInsets,
                    windowSafeAreaInsets.left == windowSafeAreaInsets.right {
                    coreWidth -= windowSafeAreaInsets.left
                }
                
                let multiplier = coreWidth / self.frame.width
                
                if self.displayMode == .singlePageContinuous {
                    self.minScaleFactor = scaleFactorForSizeToFit.landscape * multiplier
                } else if self.displayMode == .twoUpContinuous {
                    self.minScaleFactor = scaleFactorForSizeToFit.landscape / 2 * multiplier
                }
            }
        }
    }
    
    public func setScaleFactorForUser() {
        var scaleFactor: HGPDFScaleFactor?
        // if user had opened this PDF before, the stored scaleFactor is already optimized for safeArea.
        if self.displayDirection == .vertical {
            scaleFactor = self.hgScaleFactorVertical
        } else if self.displayDirection == .horizontal {
            scaleFactor = self.hgScaleFactorHorizontal
        }
        
        if let scaleFactor = scaleFactor {
            if UIApplication.shared.statusBarOrientation.isPortrait {
                if self.displayMode == .singlePageContinuous {
                    self.scaleFactor = scaleFactor.portrait
                } else if self.displayMode == .twoUpContinuous {
                    self.scaleFactor = scaleFactor.portrait / 2
                }
            } else if UIApplication.shared.statusBarOrientation.isLandscape {
                if self.displayMode == .singlePageContinuous {
                    self.scaleFactor = scaleFactor.landscape
                } else if self.displayMode == .twoUpContinuous {
                    self.scaleFactor = scaleFactor.landscape / 2
                }
            }
        }
    }
}
