//
//  EditorCreateRowBeforeCommand.swift
//  Zavala
//
//  Created by Maurice Parker on 12/15/20.
//

import Foundation
import RSCore
import Templeton

final class EditorCreateRowBeforeCommand: EditorOutlineCommand {
	var undoActionName: String
	var redoActionName: String
	var undoManager: UndoManager
	weak var delegate: EditorOutlineCommandDelegate?
	var cursorCoordinates: CursorCoordinates?
	
	var outline: Outline
	var headline: TextRow
	var beforeRow: TextRow
	var changes: ShadowTableChanges?
	
	init(undoManager: UndoManager, delegate: EditorOutlineCommandDelegate, outline: Outline, beforeRow: TextRow) {
		self.undoManager = undoManager
		self.delegate = delegate
		self.outline = outline
		self.headline = TextRow()
		self.beforeRow = beforeRow
		undoActionName = L10n.addRow
		redoActionName = L10n.addRow
	}
	
	func perform() {
		saveCursorCoordinates()
		changes = outline.createRow(headline, beforeRow: beforeRow)
		delegate?.applyChanges(changes!)
		registerUndo()
	}
	
	func undo() {
		let changes = outline.deleteRow(headline)
		delegate?.applyChanges(changes)
		registerRedo()
		restoreCursorPosition()
	}
	
}