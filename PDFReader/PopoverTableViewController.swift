//
//  PopoverTableViewController.swift
//  PDFReader
//
//  Created by ERU on 2017/11/20.
//  Copyright © 2017年 Hacking Gate. All rights reserved.
//

import UIKit
import PDFKit

class PopoverTableViewController: UITableViewController {
    
    var delegate: SettingsDelegate!
    var pdfDocument: PDFDocument?
    var displayBox: PDFDisplayBox = .cropBox

    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var whiteStyleButton: UIButton!
    @IBOutlet weak var lightStyleButton: UIButton!
    @IBOutlet weak var darkStyleButton: UIButton!
    @IBOutlet weak var scrollVerticalButton: UIButton!
    @IBOutlet weak var scrollHorizontalButton: UIButton!
    @IBOutlet weak var scrollDetailLabel: UILabel!
    @IBOutlet weak var twoUpSwitch: UISwitch!
    @IBOutlet weak var twoUpDetailLabel: UILabel!
    @IBOutlet weak var rightToLeftSwitch: UISwitch!
    @IBOutlet weak var findOnPageSwitch: UISwitch!
    
    override func viewWillAppear(_ animated: Bool) {
        updateInterface()
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        popoverPresentationController?.backgroundColor = tableView.backgroundColor

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateInterface),
                           name: .UIApplicationWillEnterForeground,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateBrightness),
                           name: .UIScreenBrightnessDidChange,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(didChangeOrientationHandler),
                           name: .UIApplicationDidChangeStatusBarOrientation,
                           object: nil)
    }
    
    // MARK: Update Interfaces
    
    @objc func updateInterface() {
        // use same UI style as DocumentBrowserViewController
        whiteStyleButton.tintColor = .clear
        lightStyleButton.tintColor = .clear
        darkStyleButton.tintColor = .clear
        presentingViewController?.view.tintColor = presentingViewController?.presentingViewController?.view.tintColor
        view.tintColor = presentingViewController?.view.tintColor
        presentedViewController?.view.tintColor = presentingViewController?.view.tintColor
        let styleRawValue = UserDefaults.standard.integer(forKey: (presentingViewController?.presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey)
        if styleRawValue == UIDocumentBrowserViewController.BrowserUserInterfaceStyle.white.rawValue {
//            popoverPresentationController?.backgroundColor = .white
            whiteStyleButton.tintColor = view.tintColor
        } else if styleRawValue == UIDocumentBrowserViewController.BrowserUserInterfaceStyle.light.rawValue {
//            popoverPresentationController?.backgroundColor = .white
            lightStyleButton.tintColor = view.tintColor
        } else if styleRawValue == UIDocumentBrowserViewController.BrowserUserInterfaceStyle.dark.rawValue {
//            popoverPresentationController?.backgroundColor = .darkGray
            darkStyleButton.tintColor = view.tintColor
        }
//            tableView.backgroundColor = popoverPresentationController?.backgroundColor
        
        updateBrightness()
        updateTwoUp()
        updateRightToLeft()
        updateScrollDirection()
        updateFindOnPage()
    }
    
    @objc func updateBrightness() {
        brightnessSlider.value = Float(UIScreen.main.brightness)
    }
    
    func updateScrollDirection() {
        if delegate.isHorizontalScroll {
            scrollVerticalButton.tintColor = .lightGray
            scrollHorizontalButton.tintColor = view.tintColor
            scrollDetailLabel.text = NSLocalizedString("Horizontal", comment: "")
        } else {
            scrollHorizontalButton.tintColor = .lightGray
            scrollVerticalButton.tintColor = view.tintColor
            scrollDetailLabel.text = NSLocalizedString("Vertical", comment: "")
        }
        scrollHorizontalButton.isEnabled = delegate.displayMode == .singlePageContinuous
        if rightToLeftSwitch.isOn {
            scrollHorizontalButton.setImage(#imageLiteral(resourceName: "direction_left"), for: .normal)
            if !delegate.allowsDocumentAssembly && delegate.displayMode == .singlePageContinuous {
                scrollHorizontalButton.setImage(#imageLiteral(resourceName: "direction_right"), for: .normal)
            }
        } else {
            scrollHorizontalButton.setImage(#imageLiteral(resourceName: "direction_right"), for: .normal)
        }
    }
    
    func updateTwoUp() {
        twoUpSwitch.isOn = delegate.prefersTwoUpInLandscapeForPad
        twoUpDetailLabel.text = twoUpSwitch.isOn ? NSLocalizedString("Two pages in landscape", comment: "") : NSLocalizedString("Single page in landscape", comment: "")
    }
    
    func updateRightToLeft() {
        rightToLeftSwitch.isOn = delegate.isRightToLeft
        if delegate.displayMode == .singlePageContinuous {
            rightToLeftSwitch.isEnabled = delegate.allowsDocumentAssembly
        } else if delegate.displayMode == .twoUpContinuous {
            rightToLeftSwitch.isEnabled = true
        }
    }
    
    func updateFindOnPage() {
        findOnPageSwitch.isOn = delegate.isFindOnPageEnabled
    }
    
    // MARK: Actions
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        UIScreen.main.brightness = CGFloat(sender.value)
    }
    
    @IBAction func styleButtonAction(_ sender: UIButton) {
        whiteStyleButton.tintColor = .clear
        lightStyleButton.tintColor = .clear
        darkStyleButton.tintColor = .clear
        sender.tintColor = view.tintColor
        switch sender.tag {
        case 1:
            UserDefaults.standard.set(0, forKey: (presentingViewController?.presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey)
        case 2:
            UserDefaults.standard.set(1, forKey: (presentingViewController?.presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey)
        case 3:
            UserDefaults.standard.set(2, forKey: (presentingViewController?.presentingViewController as! DocumentBrowserViewController).browserUserInterfaceStyleKey)
        default: break
        }
        
        let center = NotificationCenter.default
        center.post(name: .UIApplicationWillEnterForeground, object: nil)
    }
    
    @IBAction func directionButtonAction(_ sender: UIButton) {
        scrollVerticalButton.tintColor = .lightGray
        scrollHorizontalButton.tintColor = .lightGray
        sender.tintColor = view.tintColor
        switch sender.tag {
        case 1:
            delegate.isHorizontalScroll = false
            if delegate.displayMode == .singlePageContinuous {
                delegate.isRightToLeft = false
            }
        case 2:
            delegate.isHorizontalScroll = true
        default: break
        }
        
        delegate.updateScrollDirection()
        updateRightToLeft()
        updateScrollDirection()
    }

    @IBAction func twoUpSwitchValueChanged(_ sender: UISwitch) {
        delegate.setPreferredDisplayMode(sender.isOn)
        delegate.updateScrollDirection()
        twoUpDetailLabel.text = twoUpSwitch.isOn ? NSLocalizedString("Two pages in landscape", comment: "") : NSLocalizedString("Single page in landscape", comment: "")
        updateRightToLeft()
        updateScrollDirection()
    }
    
    @IBAction func rightToLeftSwitchValueChanged(_ sender: UISwitch) {
        delegate.isRightToLeft = sender.isOn
        delegate.updateScrollDirection()
        updateScrollDirection()
    }
    
    @IBAction func findOnPageSwitchValueChanged(_ sender: UISwitch) {
        delegate.isFindOnPageEnabled = sender.isOn
    }
    
    @objc func didChangeOrientationHandler() {
        updateRightToLeft()
        updateScrollDirection()
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !delegate.isEncrypted && indexPath.row == 3 {
            return 0
        }
        if UIDevice.current.userInterfaceIdiom != .pad && indexPath.row == 6 {
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 4 {
            // search
            let storyBoard = UIStoryboard(name: "Main", bundle: nil)
            if let searchResultsTVC = storyBoard.instantiateViewController(withIdentifier: "SearchResults") as? SearchResultsTableViewController {
                self.presentedViewController?.dismiss(animated: true, completion: nil)
                searchResultsTVC.delegate = delegate
                searchResultsTVC.pdfDocument = pdfDocument
                searchResultsTVC.displayBox = displayBox
                
                let searchController =  UISearchController(searchResultsController: searchResultsTVC)
                searchController.dimsBackgroundDuringPresentation = true
                searchController.view.tintColor = view.tintColor
                searchController.searchResultsUpdater = searchResultsTVC
                searchController.searchBar.delegate = searchResultsTVC
                
                self.present(searchController, animated: true, completion: nil)
            }
            
        }
    }
}

