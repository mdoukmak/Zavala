//
//  Account.swift
//  
//
//  Created by Maurice Parker on 11/6/20.
//

import Foundation

public extension Notification.Name {
	static let AccountFoldersDidChange = Notification.Name(rawValue: "AccountFoldersDidChange")
}

public final class Account: Identifiable, Equatable, Codable {

	public var id: EntityID {
		return EntityID.account(type.rawValue)
	}
	
	public var name: String {
		return type.name
	}
	
	public var type: AccountType
	public var isActive: Bool
	public var folders: [Folder]?
	
	public var sortedFolders: [Folder] {
		guard let folders = folders else { return [Folder]() }
		return folders.sorted(by: { $0.name ?? "" < $1.name ?? "" })
	}
	
	public var outlines: [Outline] {
		return folders?.reduce(into: [Outline]()) { $0.append(contentsOf: $1.outlines ?? [Outline]()) } ?? [Outline]()
	}
	
	enum CodingKeys: String, CodingKey {
		case type = "type"
		case isActive = "isActive"
		case folders = "folders"
	}

	init(accountType: AccountType) {
		self.type = accountType
		self.isActive = true
		self.folders = [Folder]()
	}
	
	public func createFolder(_ name: String) -> Folder {
		let folder = Folder(parentID: id, name: name)
		folders?.append(folder)
		accountFoldersDidChange()
		return folder
	}
	
	public func deleteFolder(_ folder: Folder) {
		guard let folders = folders else {
			return
		}
		
		self.folders = folders.filter { $0 != folder }
		accountFoldersDidChange()
		folder.folderDidDelete()
	}
	
	public static func == (lhs: Account, rhs: Account) -> Bool {
		return lhs.id == rhs.id
	}
	
}

extension Account {

	func findFolder(folderID: String) -> Folder? {
		return folders?.first(where: { $0.id.folderID == folderID })
	}

}

private extension Account {
	
	func accountFoldersDidChange() {
		NotificationCenter.default.post(name: .AccountFoldersDidChange, object: self, userInfo: nil)
	}
	
}
