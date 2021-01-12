//
//  SidebarSearchCell.swift
//  Zavala
//
//  Created by Maurice Parker on 1/11/21.
//

import UIKit

protocol SidebarSearchCellDelegate: class {
	func sidebarSearchDidBecomeActive()
	func sidebarSearchDidUpdate(searchText: String?)
}

class SidebarSearchCell: UICollectionViewListCell {
	
	var searchText: String? {
		didSet {
			setNeedsUpdateConfiguration()
		}
	}
	
	weak var delegate: SidebarSearchCellDelegate? {
		didSet {
			setNeedsUpdateConfiguration()
		}
	}
	
	override func updateConfiguration(using state: UICellConfigurationState) {
		super.updateConfiguration(using: state)
		
		layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
		
		var content = SidebarSearchContentConfiguration(searchText: searchText).updated(for: state)
		content.delegate = delegate
		contentConfiguration = content
	}
	
	func setSearchField(searchText: String) {
		(contentView as? SidebarSearchContentView)?.searchTextField.text = searchText
		(contentView as? SidebarSearchContentView)?.searchTextField.becomeFirstResponder()
	}
	
	func clearSearchField() {
		(contentView as? SidebarSearchContentView)?.searchTextField.text = nil
	}
	
}
