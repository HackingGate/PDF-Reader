//
//  PDFReaderUITests.swift
//  PDFReaderUITests
//
//  Created by ERU on 2018/10/30.
//  Copyright © 2018 Hacking Gate. All rights reserved.
//

import XCTest

class PDFReaderUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        let app = XCUIApplication()
        
        setupSnapshot(app)
        app.launch()
        
        // Change to default style
        app.navigationBars["Apple_Environmental_Responsibility_Report_2018"].children(matching: .button).element(boundBy: 2).tap()
        
        app.tables.cells.containing(.button, identifier:"style circle").children(matching: .button).matching(identifier: "style circle").element(boundBy: 0).tap()
        
        // dismiss
        app/*@START_MENU_TOKEN@*/.otherElements["PopoverDismissRegion"]/*[[".otherElements[\"dismiss popup\"]",".otherElements[\"PopoverDismissRegion\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            sleep(3)
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testContainer() {
        let app = XCUIApplication()
        sleep(3)
        snapshot("0 launch")

        app.navigationBars["Apple_Environmental_Responsibility_Report_2018"].children(matching: .button).element(boundBy: 1).tap()
        snapshot("1 collection")
        
        app.navigationBars["PDFReader.ContainerView"]/*@START_MENU_TOKEN@*/.segmentedControls.buttons["list item Compact"]/*[[".segmentedControls.buttons[\"list item Compact\"]",".buttons[\"list item Compact\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.tap()
        snapshot("2 table")

        // Return back
        app.navigationBars["PDFReader.ContainerView"].buttons["Apple_Environmental_Responsibility_Report_2018"].tap()
    }
    
    func testStyleChange() {
        if UIDevice.current.userInterfaceIdiom == .phone {
            let app = XCUIApplication()
            sleep(3)

            app.navigationBars["Apple_Environmental_Responsibility_Report_2018"].children(matching: .button).element(boundBy: 2).tap()

            app.tables.cells.containing(.button, identifier:"style circle").children(matching: .button).matching(identifier: "style circle").element(boundBy: 2).tap()
            snapshot("3 style")

            app.tables.cells.containing(.button, identifier:"style circle").children(matching: .button).matching(identifier: "style circle").element(boundBy: 0).tap()

            // dismiss
            app/*@START_MENU_TOKEN@*/.otherElements["PopoverDismissRegion"]/*[[".otherElements[\"dismiss popup\"]",".otherElements[\"PopoverDismissRegion\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        }
    }
    
    func testTwoPagesMode() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let app = XCUIApplication()
            sleep(3)
            
            app.navigationBars["Apple_Environmental_Responsibility_Report_2018"].children(matching: .button).element(boundBy: 2).tap()
            
            app.tables.cells.containing(.button, identifier:"style circle").children(matching: .button).matching(identifier: "style circle").element(boundBy: 2).tap()

            let ltrSwitch = app.switches[localizedString("Two pages mode") + ", " + localizedString("Single page in landscape")]
            let isOn = ltrSwitch.value as! String
            if (isOn == "0") {
                ltrSwitch.tap()
                snapshot("4 twopages")
                let rtlSwitch = app.switches[localizedString("Two pages mode") + ", " + localizedString("Two pages in landscape")]
                rtlSwitch.tap()
            }
            
            app.tables.cells.containing(.button, identifier:"style circle").children(matching: .button).matching(identifier: "style circle").element(boundBy: 0).tap()
            
            // dismiss
            app/*@START_MENU_TOKEN@*/.otherElements["PopoverDismissRegion"]/*[[".otherElements[\"dismiss popup\"]",".otherElements[\"PopoverDismissRegion\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        }
    }
    
    func testSearch() {
        let app = XCUIApplication()
        sleep(3)

        app.navigationBars["Apple_Environmental_Responsibility_Report_2018"].buttons[localizedString("Search")].tap()
        app.typeText("renewable")

        app.keyboards.buttons["Search"].tap()
        snapshot("5 search")
    }
 
}

// From: https://stackoverflow.com/a/49302480/4063462
extension PDFReaderUITests {
    func localizedString(_ key: String) -> String {
        return Bundle(for: PDFReaderUITests.self).localizedString(forKey: key, value: nil, table: nil)
    }
}
