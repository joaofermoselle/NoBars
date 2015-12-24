//
//  AppDelegate.swift
//  NoBars
//
//  Created by Joao Fermoselle on 09/12/2015.
//  Copyright © 2015 JRFS. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    
    // ---------------------
    // MARK: Properties
    // ---------------------
    
    // Create new status bar item
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)
    
    // Create a menu for the app
    let menu = NSMenu()
    
    // Declare the app status variable
    var status: Status = .Bars
    
    
    
    // ---------------------
    // MARK: App start
    // ---------------------
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        // Check what the current status is and update the variable.
        status = currentStatus()
        
        // Initialise the menu bar button with the correct icon.
        initIcon()
        
        // Add items to menu
        menu.addItem(NSMenuItem(title: "About", action: Selector("aboutButton:"), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: Selector("terminate:"), keyEquivalent: "q"))
        
    }
    
    
    
    // ---------------------
    // MARK: Methods
    // ---------------------
    
    /**
    Checks the value of the key `_HIHideMenuBar` in .GlobalPreferences,
    located at ~/Library/Preferences/.
    
    - Returns: Current status of the visibility of the system menu bar.
    */
    func currentStatus() -> Status {
        
        // Load .GlobalPreferences.plist to a dictionary.
        guard let preferencesDict = NSUserDefaults.standardUserDefaults().persistentDomainForName(NSGlobalDomain) else {
            print("Could not read .GlobalPreferences.plist")
            return .Bars
        }
        
        if preferencesDict["_HIHideMenuBar"] as! Bool {
            return .NoBars
        } else {
            return .Bars
        }
    }
    
    
    /**
    Initialises the menu bar icon with the action that should be performed
    upon a click and updates the icon image.
    */
    func initIcon() {
        statusItem.button!.action = Selector("toggleBars:")
        statusItem.button!.sendActionOn(Int(NSEventMask.LeftMouseUpMask.rawValue)|Int(NSEventMask.RightMouseUpMask.rawValue))
        updateIcon()
    }
    
    
    /**
    Updates the icon image according to the value of the variable `status`.
    */
    func updateIcon() {
        statusItem.button!.image = NSImage(named: status.rawValue)
        statusItem.button!.image?.template = true
    }
    
    
    /**
    Toggle the visibility of the system's menu bar.
    Currently called toggleBars as we may implement the hiding of other bars
    in the future.
    */
    func toggleBars(sender: AnyObject) {
        
        let event = NSApplication.sharedApplication().currentEvent!
        
        let isRightClick = event.type == NSEventType.RightMouseUp
        let isControlClick = Int(event.modifierFlags.rawValue) & Int(NSEventModifierFlags.ControlKeyMask.rawValue) != 0
        
        // If right-click or Ctrl+click
        if (isRightClick || isControlClick) {
            statusItem.popUpStatusItemMenu(menu)
            return
        }
        
        if status == .Bars {
            
            status = .NoBars
            
            // Set value of key `_HIHideMenuBar` in .GlobalPreferences to true.
            guard setMenuHidingKey(true) else {
                print("Could not set the menu hiding key.")
                return
            }
            
            // Set value of key `autohide` in com.apple.dock to true.
            guard hideDock(true) else {
                print("Could not turn off Dock hiding.")
                return
            }
            
        } else {
            
            status = .Bars
            
            // Set value of key `_HIHideMenuBar` in .GlobalPreferences to false.
            guard setMenuHidingKey(false) else {
                print("Could not set the menu hiding key.")
                return
            }
            
            // Set value of key `autohide` in com.apple.dock to false.
            guard hideDock(false) else {
                print("Could not turn on Dock hiding.")
                return
            }
            
        }
        
        // Send notifications for the OS to listen, check .GlobalPreferences and com.apple.dock,
        // and update the menu and dock bars visibility accordingly.
        dispatch_async(dispatch_get_main_queue()) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), "AppleInterfaceMenuBarHidingChangedNotification", nil, nil, true)
        }
        
        guard cleanUpDesktop() else {
            print("Could not clean up Desktop.")
            return
        }
        
        updateIcon()
        
    }
    
    
    /**
    Sets the value of the key `_HIHideMenuBar` in .GlobalPreferences,
    located at ~/Library/Preferences/ to the value of `bool`.
    
    - Parameter bool: Value to which `_HIHideMenuBar` should be set.
    
    - Returns: True if the operation succeeded, false if it did not.
    */
    func setMenuHidingKey(bool: Bool) -> Bool {
        
        // Load .GlobalPreferences.plist to a dictionary
        guard let preferencesDictTemp = NSUserDefaults.standardUserDefaults().persistentDomainForName(NSGlobalDomain) else {
            print("Could not read .GlobalPreferences.plist")
            return false
        }
        
        var preferencesDict = preferencesDictTemp
        preferencesDict.updateValue(bool, forKey: "_HIHideMenuBar")
        NSUserDefaults.standardUserDefaults().setPersistentDomain(preferencesDict, forName: NSGlobalDomain)
        
        return true
        
    }
    
    
    /**
    Sets the automatic hiding property of the Dock. It is implemented using AppleScript.
    
    - Parameter bool: True if automatic Dock hiding should be on.
    
    - Returns: True if the operation succeeded, false if it did not.
    */
    func hideDock(bool: Bool) -> Bool {
        
        let source = "tell application \"System Events\" to set autohide of dock preferences to \(bool)"
        
        guard let script = NSAppleScript(source: source) else {
            print("Could not create script to show/hide the Dock.")
            return false
        }
        
        script.executeAndReturnError(nil)
        
        return true
        
    }
    
    
    func cleanUpDesktop() -> Bool {
        var source = ""
        source += "tell application \"System Events\"\n"
        source += "tell application \"Finder\" to activate\n"
        source += "repeat while (value of attribute \"AXfocused\" of group 1 of scroll area of process \"Finder\" is {false})\n"
        source += "tell process \"Finder\" to click menu item \"Cycle Through Windows\" of menu \"Window\" of menu bar item \"Window\" of front menu bar\n"
        source += "end repeat\n"
        source += "tell process \"Finder\" to click menu item \"Clean Up\" of menu \"View\" of menu bar item \"View\" of front menu bar\n"
        source += "end tell"
        print(source)
        
        guard let script = NSAppleScript(source: source) else {
            print("Could not create script to clean up the desktop.")
            return false
        }
        
        var errorDict: NSDictionary?
        
        script.executeAndReturnError(&errorDict)
        
        if errorDict != nil {
            print(errorDict)
            print("An error occurred executing script to clean up the desktop.")
            return false
        }
        
        print("Executed script")
        
        return true
    }
    
    
    func aboutButton(sender:AnyObject) {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        NSApplication.sharedApplication().orderFrontStandardAboutPanel(sender)
    }


}

