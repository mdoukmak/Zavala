//
//  EditorTextRowTopicTextView.swift
//  Zavala
//
//  Created by Maurice Parker on 11/17/20.
//

import UIKit
import Templeton

protocol EditorTextRowTopicTextViewDelegate: class {
	var editorRowTopicTextViewUndoManager: UndoManager? { get }
	var editorRowTopicTextViewTextRowStrings: TextRowStrings { get }
	func invalidateLayout(_: EditorTextRowTopicTextView)
	func textChanged(_: EditorTextRowTopicTextView, row: TextRow, isInNotes: Bool, cursorPosition: Int)
	func deleteRow(_: EditorTextRowTopicTextView, row: TextRow)
	func createRow(_: EditorTextRowTopicTextView, beforeRow: TextRow)
	func createRow(_: EditorTextRowTopicTextView, afterRow: TextRow)
	func indentRow(_: EditorTextRowTopicTextView, row: TextRow)
	func outdentRow(_: EditorTextRowTopicTextView, row: TextRow)
	func splitRow(_: EditorTextRowTopicTextView, row: TextRow, topic: NSAttributedString, cursorPosition: Int)
	func createRowNote(_: EditorTextRowTopicTextView, row: TextRow)
	func editLink(_: EditorTextRowTopicTextView, _ link: String?, range: NSRange)
}

class EditorTextRowTopicTextView: OutlineTextView {
	
	override var editorUndoManager: UndoManager? {
		return editorDelegate?.editorRowTopicTextViewUndoManager
	}
	
	override var keyCommands: [UIKeyCommand]? {
		let keys = [
			UIKeyCommand(action: #selector(indent(_:)), input: "\t"),
			UIKeyCommand(input: "\t", modifierFlags: [.shift], action: #selector(outdent(_:))),
			UIKeyCommand(input: "\t", modifierFlags: [.alternate], action: #selector(insertTab(_:))),
			UIKeyCommand(input: "\r", modifierFlags: [.alternate], action: #selector(insertReturn(_:))),
			UIKeyCommand(input: "\r", modifierFlags: [.shift], action: #selector(addNote(_:))),
			UIKeyCommand(input: "\r", modifierFlags: [.shift, .alternate], action: #selector(split(_:))),
			toggleBoldCommand,
			toggleItalicsCommand,
			editLinkCommand
		]
		return keys
	}
	
	weak var editorDelegate: EditorTextRowTopicTextViewDelegate?
	
	override var textRowStrings: TextRowStrings? {
		return editorDelegate?.editorRowTopicTextViewTextRowStrings
	}
	
	override init(frame: CGRect, textContainer: NSTextContainer?) {
		super.init(frame: frame, textContainer: textContainer)

		self.delegate = self

		self.font = OutlineFont.topic
		self.linkTextAttributes = [.foregroundColor: UIColor.label, .underlineStyle: 1]
	}
	
	private var textViewHeight: CGFloat?
	private var isTextChanged = false
	private var isSavingTextUnnecessary = false

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
			textStorage.replaceFont(with: OutlineFont.topic)
		}
	}
	
	override func resignFirstResponder() -> Bool {
		if let textRow = textRow {
			CursorCoordinates.lastKnownCoordinates = CursorCoordinates(row: textRow, isInNotes: false, cursorPosition: lastCursorPosition)
		}
		return super.resignFirstResponder()
	}

	override func deleteBackward() {
		guard let textRow = textRow else { return }
		if attributedText.length == 0 {
			editorDelegate?.deleteRow(self, row: textRow)
		} else {
			super.deleteBackward()
		}
	}

	@objc func indent(_ sender: Any) {
		guard let textRow = textRow else { return }
		editorDelegate?.indentRow(self, row: textRow)
	}
	
	@objc func outdent(_ sender: Any) {
		guard let textRow = textRow else { return }
		editorDelegate?.outdentRow(self, row: textRow)
	}
	
	@objc func insertTab(_ sender: Any) {
		insertText("\t")
	}
	
	@objc func insertReturn(_ sender: Any) {
		insertText("\n")
	}
	
	@objc func addNote(_ sender: Any) {
		guard let textRow = textRow else { return }
		isSavingTextUnnecessary = true
		editorDelegate?.createRowNote(self, row: textRow)
	}
	
	@objc func split(_ sender: Any) {
		guard let textRow = textRow else { return }
		
		isSavingTextUnnecessary = true
		
		if cursorPosition == 0 {
			editorDelegate?.createRow(self, beforeRow: textRow)
		} else {
			editorDelegate?.splitRow(self, row: textRow, topic: attributedText, cursorPosition: cursorPosition)
		}
	}
	
	@objc override func editLink(_ sender: Any?) {
		let result = findAndSelectLink()
		editorDelegate?.editLink(self, result.0, range: result.1)
	}
	
	override func updateLinkForCurrentSelection(link: String?, range: NSRange) {
		super.updateLinkForCurrentSelection(link: link, range: range)
		isTextChanged = true
	}
	
}

// MARK: UITextViewDelegate

extension EditorTextRowTopicTextView: UITextViewDelegate {
	
	func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
		let fittingSize = textView.sizeThatFits(CGSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude))
		textViewHeight = fittingSize.height
		return true
	}
	
	func textViewDidEndEditing(_ textView: UITextView) {
		guard isTextChanged, let textRow = textRow else { return }
		
		if isSavingTextUnnecessary {
			isSavingTextUnnecessary = false
		} else {
			editorDelegate?.textChanged(self, row: textRow, isInNotes: false, cursorPosition: lastCursorPosition)
		}
		
		isTextChanged = false
	}
	
	func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
		guard let textRow = textRow else { return true }
		switch text {
		case "\n":
			editorDelegate?.createRow(self, afterRow: textRow)
			return false
		default:
			return true
		}
	}
	
	func textViewDidChange(_ textView: UITextView) {
		isTextChanged = true
		lastCursorPosition = cursorPosition

		let fittingSize = textView.sizeThatFits(CGSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude))
		if textViewHeight != fittingSize.height {
			textViewHeight = fittingSize.height
			editorDelegate?.invalidateLayout(self)
		}
	}
	
}