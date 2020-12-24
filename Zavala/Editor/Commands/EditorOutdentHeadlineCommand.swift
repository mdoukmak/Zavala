//
//  EditorOutdentHeadlineCommand.swift
//  Zavala
//
//  Created by Maurice Parker on 11/28/20.
//

import Foundation
import RSCore
import Templeton

final class EditorOutdentHeadlineCommand: EditorOutlineCommand {
	var undoActionName: String
	var redoActionName: String
	var undoManager: UndoManager
	weak var delegate: EditorOutlineCommandDelegate?
	var cursorCoordinates: CursorCoordinates?
	
	var outline: Outline
	var headline: Headline
	var oldParent: Headline?
	var oldChildIndex: Int?
	var oldAttributedTexts: HeadlineTexts
	var newAttributedTexts: HeadlineTexts
	
	init(undoManager: UndoManager, delegate: EditorOutlineCommandDelegate, outline: Outline, headline: Headline, attributedTexts: HeadlineTexts) {
		self.undoManager = undoManager
		self.delegate = delegate
		self.outline = outline
		self.headline = headline
		self.undoActionName = L10n.outdent
		self.redoActionName = L10n.outdent
		
		// This is going to move, so we save the parent and child index
		if headline != headline.parent?.headlines?.last {
			self.oldParent = headline.parent as? Headline
			self.oldChildIndex = headline.parent?.headlines?.firstIndex(of: headline)
		}
		
		self.oldAttributedTexts = headline.attributedTexts
		self.newAttributedTexts = attributedTexts
	}
	
	func perform() {
		saveCursorCoordinates()
		let changes = outline.outdentHeadline(headline: headline, attributedTexts: newAttributedTexts)
		delegate?.applyChangesRestoringCursor(changes)
		registerUndo()
	}
	
	func undo() {
		if let oldParent = oldParent, let oldChildIndex = oldChildIndex {
			let changes = outline.moveHeadline(headline, attributedTexts: oldAttributedTexts, toParent: oldParent, childIndex: oldChildIndex)
			delegate?.applyChangesRestoringCursor(changes)
		} else {
			let changes = outline.indentHeadline(headline: headline, attributedTexts: oldAttributedTexts)
			delegate?.applyChangesRestoringCursor(changes)
		}
		registerRedo()
		restoreCursorPosition()
	}
	
}