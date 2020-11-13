//
//  ValidatingToolbarItem.swift
//  Manhattan
//
//  Created by Maurice Parker on 11/13/20.
//

import UIKit

#if targetEnvironment(macCatalyst)

public class ValidatingToolbarItem: NSToolbarItem {

	var checkForUnavailable: (() -> Bool)?
	
	override public func validate() {
		guard let checkForUnavailable = checkForUnavailable else {
			isEnabled = false
			return
		}
		isEnabled = !checkForUnavailable()
	}
	
}

#endif
