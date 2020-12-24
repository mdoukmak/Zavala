//
//  EditorHeadlineNoteTextView.swift
//  Zavala
//
//  Created by Maurice Parker on 12/13/20.
//

import UIKit
import Templeton

protocol EditorHeadlineNoteTextViewDelegate: class {
	var editorHeadlineNoteTextViewUndoManager: UndoManager? { get }
	var editorHeadlineNoteTextViewAttibutedTexts: HeadlineTexts { get }
	func invalidateLayout(_ : EditorHeadlineNoteTextView)
	func textChanged(_ : EditorHeadlineNoteTextView, headline: Headline, isInNotes: Bool, cursorPosition: Int)
	func deleteHeadlineNote(_ : EditorHeadlineNoteTextView, headline: Headline)
	func moveCursorTo(_ : EditorHeadlineNoteTextView, headline: Headline)
	func moveCursorDown(_ : EditorHeadlineNoteTextView, headline: Headline)
	func editLink(_: EditorHeadlineNoteTextView, _ link: String?, range: NSRange)
}

class EditorHeadlineNoteTextView: OutlineTextView {
	
	override var editorUndoManager: UndoManager? {
		return editorDelegate?.editorHeadlineNoteTextViewUndoManager
	}
	
	override var keyCommands: [UIKeyCommand]? {
		var keys = [UIKeyCommand]()
		if cursorPosition == 0 {
			keys.append(UIKeyCommand(action: #selector(moveCursorToText(_:)), input: UIKeyCommand.inputUpArrow))
		}
		if cursorPosition == attributedText.length {
			keys.append(UIKeyCommand(action: #selector(moveCursorDown(_:)), input: UIKeyCommand.inputDownArrow))
		}
		keys.append(UIKeyCommand(action: #selector(moveCursorToText(_:)), input: UIKeyCommand.inputEscape))
		keys.append(toggleBoldCommand)
		keys.append(toggleItalicsCommand)
		keys.append(editLinkCommand)
		return keys
	}
	
	weak var editorDelegate: EditorHeadlineNoteTextViewDelegate?
	
	override var attributedTexts: HeadlineTexts? {
		return editorDelegate?.editorHeadlineNoteTextViewAttibutedTexts
	}
	
	override init(frame: CGRect, textContainer: NSTextContainer?) {
		super.init(frame: frame, textContainer: textContainer)
		
		self.delegate = self

		self.font = HeadlineFont.note
		self.textColor = .secondaryLabel
		self.linkTextAttributes = [.foregroundColor: UIColor.secondaryLabel, .underlineStyle: 1]
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
			textStorage.replaceFont(with: HeadlineFont.note)
		}
	}
	
	override func resignFirstResponder() -> Bool {
		if let headline = headline {
			CursorCoordinates.lastKnownCoordinates = CursorCoordinates(headline: headline, isInNotes: false, cursorPosition: lastCursorPosition)
		}
		return super.resignFirstResponder()
	}

	override func deleteBackward() {
		guard let headline = headline else { return }
		if attributedText.length == 0 {
			isSavingTextUnnecessary = true
			editorDelegate?.deleteHeadlineNote(self, headline: headline)
		} else {
			super.deleteBackward()
		}
	}

	@objc func moveCursorToText(_ sender: Any) {
		guard let headline = headline else { return }
		editorDelegate?.moveCursorTo(self, headline: headline)
	}
	
	@objc func moveCursorDown(_ sender: Any) {
		guard let headline = headline else { return }
		editorDelegate?.moveCursorDown(self, headline: headline)
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

extension EditorHeadlineNoteTextView: UITextViewDelegate {
	
	func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
		let fittingSize = textView.sizeThatFits(CGSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude))
		textViewHeight = fittingSize.height
		return true
	}
	
	func textViewDidEndEditing(_ textView: UITextView) {
		guard isTextChanged, let headline = headline else { return }
		
		if isSavingTextUnnecessary {
			isSavingTextUnnecessary = false
		} else {
			editorDelegate?.textChanged(self, headline: headline, isInNotes: true, cursorPosition: lastCursorPosition)
		}
		
		isTextChanged = false
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