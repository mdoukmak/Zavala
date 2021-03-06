//
//  AppDefaults.swift
//  Zavala
//
//  Created by Maurice Parker on 11/10/20.
//

import Foundation

final class AppDefaults {

	static let shared = AppDefaults()
	private init() {}
	
	static var store: UserDefaults = {
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let suiteName = "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
		return UserDefaults.init(suiteName: suiteName)!
	}()
	
	struct Key {
		static let lastSelectedAccountID = "lastSelectedAccountID"
		static let deletedLocalForV14 = "deletedLocalForV14"
		static let enableCloudKit = "enableCloudKit"
		static let hideLocalAccount = "hideLocalAccount"
	}
	
	var lastSelectedAccountID: Int {
		get {
			return Self.int(for: Key.lastSelectedAccountID)
		}
		set {
			Self.setInt(for: Key.lastSelectedAccountID, newValue)
		}
	}
	
	var deletedLocalForV14: Bool {
		get {
			return Self.bool(for: Key.deletedLocalForV14)
		}
		set {
			Self.setBool(for: Key.deletedLocalForV14, newValue)
		}
	}

	var enableCloudKit: Bool {
		get {
			return Self.bool(for: Key.enableCloudKit)
		}
		set {
			Self.setBool(for: Key.enableCloudKit, newValue)
		}
	}

	var hideLocalAccount: Bool {
		get {
			return Self.bool(for: Key.hideLocalAccount)
		}
		set {
			Self.setBool(for: Key.hideLocalAccount, newValue)
		}
	}

//	var addFolderAccountID: EntityID? {
//		get {
//			guard let userInfo = UserDefaults.standard.object(forKey: Key.addFolderAccountID) as? [AnyHashable : AnyHashable] else { return nil }
//			return EntityID(userInfo: userInfo)
//		}
//		set {
//			guard let userInfo = newValue?.userInfo else { return }
//			UserDefaults.standard.set(userInfo, forKey: Key.addFolderAccountID)
//		}
//	}
//
//	var addOutlineFeedFolderID: EntityID? {
//		get {
//			guard let userInfo = UserDefaults.standard.object(forKey: Key.addOutlineFeedFolderID) as? [AnyHashable : AnyHashable] else { return nil }
//			return EntityID(userInfo: userInfo)
//		}
//		set {
//			guard let userInfo = newValue?.userInfo else { return }
//			UserDefaults.standard.set(userInfo, forKey: Key.addOutlineFeedFolderID)
//		}
//	}
	
	static func registerDefaults() {
//		let defaults: [String : Any] = [Key.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
//										Key.timelineGroupByFeed: false,
//										Key.refreshClearsReadArticles: false,
//										Key.timelineNumberOfLines: 2,
//										Key.timelineIconDimension: IconSize.medium.rawValue,
//										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
//										Key.articleFullscreenAvailable: false,
//										Key.articleFullscreenEnabled: false,
//										Key.confirmMarkAllAsRead: true]
//		AppDefaults.store.register(defaults: defaults)
	}

}

private extension AppDefaults {

	static func string(for key: String) -> String? {
		return AppDefaults.store.string(forKey: key)
	}
	
	static func setString(for key: String, _ value: String?) {
		AppDefaults.store.set(value, forKey: key)
	}

	static func bool(for key: String) -> Bool {
		return AppDefaults.store.bool(forKey: key)
	}

	static func setBool(for key: String, _ flag: Bool) {
		AppDefaults.store.set(flag, forKey: key)
	}

	static func int(for key: String) -> Int {
		return AppDefaults.store.integer(forKey: key)
	}
	
	static func setInt(for key: String, _ x: Int) {
		AppDefaults.store.set(x, forKey: key)
	}
	
	static func date(for key: String) -> Date? {
		return AppDefaults.store.object(forKey: key) as? Date
	}

	static func setDate(for key: String, _ date: Date?) {
		AppDefaults.store.set(date, forKey: key)
	}

	static func sortDirection(for key:String) -> ComparisonResult {
		let rawInt = int(for: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}

	static func setSortDirection(for key: String, _ value: ComparisonResult) {
		if value == .orderedAscending {
			setInt(for: key, ComparisonResult.orderedAscending.rawValue)
		}
		else {
			setInt(for: key, ComparisonResult.orderedDescending.rawValue)
		}
	}
	
}
