//
//  PopoverTableViewController.swift
//  PDFReader
//
//  Created by ERU on 2017/11/20.
//  Copyright © 2017年 Hacking Gate. All rights reserved.
//

import UIKit

class PopoverTableViewController: UITableViewController {
    
    var delegate: SettingsDelegate!

    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var whiteStyleButton: UIButton!
    @IBOutlet weak var lightStyleButton: UIButton!
    @IBOutlet weak var darkStyleButton: UIButton!
    @IBOutlet weak var directionDownButton: UIButton!
    @IBOutlet weak var directionLeftButton: UIButton!
    @IBOutlet weak var directionRightButton: UIButton!
    @IBOutlet weak var directionDetailLabel: UILabel!
    
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
    }
    
    // MARK: Update Interfaces
    
    @objc func updateInterface() {
        // use same UI style as DocumentBrowserViewController
        whiteStyleButton.tintColor = .clear
        lightStyleButton.tintColor = .clear
        darkStyleButton.tintColor = .clear
        presentingViewController?.view.tintColor = presentingViewController?.presentingViewController?.view.tintColor
        view.tintColor = presentingViewController?.view.tintColor
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
        updateDirection()
    }
    
    @objc func updateBrightness() {
        brightnessSlider.value = Float(UIScreen.main.brightness)
    }
    
    func updateDirection() {
        directionLeftButton.isEnabled = delegate.allowsDocumentAssembly
        directionDownButton.tintColor = .lightGray
        directionLeftButton.tintColor = .lightGray
        directionRightButton.tintColor = .lightGray
        if delegate.isVerticalWriting == false && delegate.isRightToLeft == false {
            directionDownButton.tintColor = view.tintColor
            directionDetailLabel.text = "Normal"
        } else if delegate.isVerticalWriting == true && delegate.isRightToLeft == true {
            directionLeftButton.tintColor = view.tintColor
            directionDetailLabel.text = "From right to left"
        } else if delegate.isVerticalWriting == true && delegate.isRightToLeft == false {
            directionRightButton.tintColor = view.tintColor
            directionDetailLabel.text = "From left to right"
        }
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
        directionDownButton.tintColor = .lightGray
        directionLeftButton.tintColor = .lightGray
        directionRightButton.tintColor = .lightGray
        sender.tintColor = view.tintColor
        switch sender.tag {
        case 1:
            delegate.writing(vertically: false, rightToLeft: false)
        case 2:
            delegate.writing(vertically: true, rightToLeft: true)
        case 3:
            delegate.writing(vertically: true, rightToLeft: false)
        default: break
        }
        
        updateDirection()
    }

    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !delegate.isEncrypted && indexPath.row == 3 {
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
}

