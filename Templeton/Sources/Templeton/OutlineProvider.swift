//
//  File.swift
//  
//
//  Created by Maurice Parker on 11/9/20.
//

import Foundation
import RSCore

public protocol OutlineProvider {
	var id: EntityID { get }
	var name: String? { get }
	var image: RSImage? { get }
	var outlines: [Outline]? { get }
}

public struct LazyOutlineProvider: OutlineProvider {
	
	public var id: EntityID
	
	public var name: String? {
		switch id {
		case .all:
			return NSLocalizedString("All", comment: "All")
		case .favorites:
			return NSLocalizedString("Favorites", comment: "Favorites")
		case .recents:
			return NSLocalizedString("Recents", comment: "Recents")
		default:
			fatalError()
		}
	}
	
	public var image: RSImage? {
		switch id {
		case .all:
			return RSImage(systemName: "tray")
		case .favorites:
			return RSImage(systemName: "heart.circle")
		case .recents:
			return RSImage(systemName: "clock")
		default:
			fatalError()
		}
	}
	
	public var outlines: [Outline]? {
		return outlineCallback()
	}
	
	private var outlineCallback: (() -> [Outline])
	
	init(id: EntityID, callback: @escaping (() -> [Outline])) {
		self.id = id
		self.outlineCallback = callback
	}
	
}