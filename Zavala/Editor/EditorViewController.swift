//
//  EditorViewController.swift
//  Zavala
//
//  Created by Maurice Parker on 11/10/20.
//

import UIKit
import RSCore
import Templeton

class EditorViewController: UICollectionViewController, MainControllerIdentifiable, UndoableCommandRunner {
	var mainControllerIdentifer: MainControllerIdentifier { return .editor }

	var isOutlineFunctionsUnavailable: Bool {
		return outline == nil
	}
	
	var isOutlineFiltered: Bool {
		return outline?.isFiltered ?? false
	}
	
	var isDeleteCurrentHeadlineUnavailable: Bool {
		return currentHeadline == nil
	}
	
	var isCreateHeadlineUnavailable: Bool {
		return currentHeadline == nil
	}
	
	var isIndentHeadlineUnavailable: Bool {
		guard let outline = outline, let headline = currentHeadline else { return true }
		return outline.isIndentHeadlineUnavailable(headline: headline)
	}

	var isOutdentHeadlineUnavailable: Bool {
		guard let outline = outline, let headline = currentHeadline else { return true }
		return outline.isOutdentHeadlineUnavailable(headline: headline)
	}

	var isToggleHeadlineCompleteUnavailable: Bool {
		return currentHeadline == nil
	}

	var isCurrentHeadlineComplete: Bool {
		return currentHeadline?.isComplete ?? false
	}
	
	var isCreateHeadlineNoteUnavailable: Bool {
		return currentHeadline == nil || !currentHeadline!.isNoteEmpty
	}

	var isDeleteHeadlineNoteUnavailable: Bool {
		return currentHeadline == nil || currentHeadline!.isNoteEmpty
	}

	var isCurrentHeadlineNoteEmpty: Bool {
		return currentHeadline?.isNoteEmpty ?? false
	}
	
	var isSplitHeadlineUnavailable: Bool {
		return currentHeadline == nil
	}

	var isFormatUnavailable: Bool {
		return currentTextView == nil || !(currentTextView?.isSelecting ?? false)
	}

	var isLinkUnavailable: Bool {
		return currentTextView == nil || !(currentTextView?.isSelecting ?? false)
	}

	var isExpandAllInOutlineUnavailable: Bool {
		return outline == nil || outline!.isExpandAllUnavailable(container: outline!)
	}

	var isCollapseAllInOutlineUnavailable: Bool {
		return outline == nil || outline!.isCollapseAllUnavailable(container: outline!)
	}

	var isExpandAllUnavailable: Bool {
		guard let outline = outline, let headline = currentHeadline else { return true }
		return outline.isExpandAllUnavailable(container: headline)
	}

	var isCollapseAllUnavailable: Bool {
		guard let outline = outline, let headline = currentHeadline else { return true }
		return outline.isCollapseAllUnavailable(container: headline)
	}

	var isExpandUnavailable: Bool {
		return !(currentHeadline?.isExpandable ?? false)
	}

	var isCollapseUnavailable: Bool {
		return !(currentHeadline?.isCollapsable ?? false)
	}

	private(set) var outline: Outline?
	
	var currentTextView: OutlineTextView? {
		return UIResponder.currentFirstResponder as? OutlineTextView
	}
	
	var currentHeadline: Headline? {
		return currentTextView?.headline
	}
	
	var currentAttributedTexts: HeadlineTexts? {
		return currentTextView?.attributedTexts
	}
	
	var currentCursorPosition: Int? {
		return currentTextView?.cursorPosition
	}
	
	var undoableCommands = [UndoableCommand]()
	var currentKeyPresses = Set<UIKeyboardHIDUsage>()
	
	override var canBecomeFirstResponder: Bool { return true }
	
	private var filterBarButtonItem: UIBarButtonItem?

	private var titleRegistration: UICollectionView.CellRegistration<EditorTitleViewCell, Outline>?
	private var headerRegistration: UICollectionView.CellRegistration<EditorHeadlineViewCell, Headline>?
	
	private var firstVisibleShadowTableIndex: Int? {
		let visibleRect = collectionView.layoutMarginsGuide.layoutFrame
		let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.minY)
		if let indexPath = collectionView.indexPathForItem(at: visiblePoint), indexPath.section == 1 {
			return indexPath.row
		}
		return nil
	}

	private var isOutlineNewFlag = false
	private var hasAlreadyMovedThisKeyPressFlag = false
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		if traitCollection.userInterfaceIdiom == .mac {
			navigationController?.setNavigationBarHidden(true, animated: false)
		} else {
			filterBarButtonItem = UIBarButtonItem(image: AppAssets.filterInactive, style: .plain, target: self, action: #selector(toggleOutlineFilter(_:)))
			navigationItem.rightBarButtonItems = [filterBarButtonItem!]
		}
		
		collectionView.collectionViewLayout = createLayout()
		collectionView.dataSource = self
		collectionView.dragDelegate = self
		collectionView.dropDelegate = self
		collectionView.dragInteractionEnabled = true
		collectionView.allowsSelection = false

		titleRegistration = UICollectionView.CellRegistration<EditorTitleViewCell, Outline> { (cell, indexPath, outline) in
			cell.outline = outline
			cell.delegate = self
		}
		
		headerRegistration = UICollectionView.CellRegistration<EditorHeadlineViewCell, Headline> { (cell, indexPath, headline) in
			cell.headline = headline
			cell.delegate = self
		}
		
		updateUI()
		collectionView.reloadData()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		restoreOutlineCursorPosition()
		restoreScrollPosition()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		moveCursorToTitleOnNew()
	}
	
	override func scrollViewDidScroll(_ scrollView: UIScrollView) {
		self.outline?.verticleScrollState = firstVisibleShadowTableIndex
	}
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		super.pressesBegan(presses, with: event)

		guard let key = presses.first?.key else { return }
		switch key.keyCode {
		case .keyboardUpArrow:
			currentKeyPresses.insert(key.keyCode)
			repeatMoveCursorUp()
		case .keyboardDownArrow:
			currentKeyPresses.insert(key.keyCode)
			repeatMoveCursorDown()
		default:
			break
		}
		
	}
	
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		super.pressesEnded(presses, with: event)
		let keyCodes = presses.compactMap { $0.key?.keyCode }
		keyCodes.forEach { currentKeyPresses.remove($0) }
	}
	
	// MARK: API
	
	func edit(_ newOutline: Outline?, isNew: Bool) {
		guard outline != newOutline else { return }
		isOutlineNewFlag = isNew
		
		// Get ready for the new outline, buy saving the current one
		outline?.cursorCoordinates = CursorCoordinates.currentCoordinates
		
		if let textField = UIResponder.currentFirstResponder as? OutlineTextView {
			textField.endEditing(true)
		}
		
		outline?.suspend()
		clearUndoableCommands()
	
		// Assign the new Outline and load it
		outline = newOutline
		
		outline?.load()
			
		guard isViewLoaded else { return }
		updateUI()
		collectionView.reloadData()
		
		restoreOutlineCursorPosition()
		restoreScrollPosition()
		moveCursorToTitleOnNew()
	}
	
	func deleteCurrentHeadline() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		deleteHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func createHeadline() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		createHeadline(afterHeadline: headline, attributedTexts: attributedTexts)
	}
	
	func indentHeadline() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		indentHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func outdentHeadline() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		outdentHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func toggleCompleteHeadline() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		toggleCompleteHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func createHeadlineNote() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		createHeadlineNote(headline, attributedTexts: attributedTexts)
	}
	
	func deleteHeadlineNote() {
		guard let headline = currentHeadline,
			  let attributedTexts = currentAttributedTexts else { return }
		deleteHeadlineNote(headline, attributedTexts: attributedTexts)
	}
	
	func splitHeadline() {
		guard let headline = currentHeadline,
			  let attributedText = currentAttributedTexts?.text,
			  let cursorPosition = currentCursorPosition else { return }
		splitHeadline(headline, attributedText: attributedText, cursorPosition: cursorPosition)
	}
	
	func outlineToggleBoldface() {
		currentTextView?.toggleBoldface(self)
	}
	
	func outlineToggleItalics() {
		currentTextView?.toggleItalics(self)
	}
	
	func link() {
		currentTextView?.editLink(self)
	}
	
	func expandAllInOutline() {
		guard let outline = outline else { return }
		expandAll(container: outline)
	}
	
	func collapseAllInOutline() {
		guard let outline = outline else { return }
		collapseAll(container: outline)
	}
	
	func expandAll() {
		guard let headline = currentHeadline else { return }
		expandAll(container: headline)
	}
	
	func collapseAll() {
		guard let headline = currentHeadline else { return }
		collapseAll(container: headline)
	}
	
	func expand() {
		guard let headline = currentHeadline else { return }
		toggleDisclosure(headline: headline)
	}
	
	func collapse() {
		guard let headline = currentHeadline else { return }
		toggleDisclosure(headline: headline)
	}
	
	// MARK: Actions
	
	@objc func toggleOutlineFilter(_ sender: Any?) {
		guard let changes = outline?.toggleFilter() else { return }
		updateUI()
		applyChangesRestoringCursor(changes)
	}
	
	@objc func repeatMoveCursorUp() {
		guard !hasAlreadyMovedThisKeyPressFlag else {
			hasAlreadyMovedThisKeyPressFlag = false
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.repeatMoveCursorUp()
			}
			return
		}
		
		if currentKeyPresses.contains(.keyboardUpArrow) {
			if let textView = UIResponder.currentFirstResponder as? EditorHeadlineTextView, !textView.isSelecting, let headline = textView.headline {
				moveCursorUp(headline: headline)
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					self.repeatMoveCursorUp()
				}
			}
		}
	}

	@objc func repeatMoveCursorDown() {
		guard !hasAlreadyMovedThisKeyPressFlag else {
			hasAlreadyMovedThisKeyPressFlag = false
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.repeatMoveCursorUp()
			}
			return
		}
		
		if currentKeyPresses.contains(.keyboardDownArrow) {
			if let textView = UIResponder.currentFirstResponder as? EditorHeadlineTextView, !textView.isSelecting, let headline = textView.headline {
				moveCursorDown(headline: headline)
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					self.repeatMoveCursorDown()
				}
			} else if let textView = UIResponder.currentFirstResponder as? EditorTitleTextView, !textView.isSelecting, outline?.shadowTable?.count ?? 0 > 0 {
				if let headlineCell = collectionView.cellForItem(at: IndexPath(row: 0, section: 1)) as? EditorHeadlineViewCell {
					headlineCell.moveToEnd()
				}
			}
		}
	}
	
}

// MARK: Collection View

extension EditorViewController {
	
	private func createLayout() -> UICollectionViewLayout {
		let layout = UICollectionViewCompositionalLayout() { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
			var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
			configuration.showsSeparators = false
			return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
		}
		return layout
	}
	
	override func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 2
	}
	
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if section == 0 {
			return outline == nil ? 0 : 1
		} else {
			return outline?.shadowTable?.count ?? 0
		}
	}
	
	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		if indexPath.section == 0 {
			return collectionView.dequeueConfiguredReusableCell(using: titleRegistration!, for: indexPath, item: outline)
		} else {
			let headline = outline?.shadowTable?[indexPath.row] ?? Headline()
			return collectionView.dequeueConfiguredReusableCell(using: headerRegistration!, for: indexPath, item: headline)
		}
	}
	
	override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
		guard let editorCell = collectionView.cellForItem(at: indexPath) as? EditorHeadlineViewCell,
			  let headline = editorCell.headline,
			  let attributedTexts = editorCell.attributedTexts else { return nil }
		
		return makeHeadlineContextMenu(headline: headline, attributedTexts: attributedTexts)
	}
	
	override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
		guard let headline = configuration.identifier as? Headline,
			  let row = headline.shadowTableIndex,
			  let cell = collectionView.cellForItem(at: IndexPath(row: row, section: 1)) as? EditorHeadlineViewCell else { return nil }
		
		return UITargetedPreview(view: cell, parameters: EditorHeadlinePreviewParameters(cell: cell, headline: headline))
	}
	
}

extension EditorViewController: EditorTitleViewCellDelegate {
	
	var editorTitleUndoManager: UndoManager? {
		return undoManager
	}
	
	func editorTitleInvalidateLayout() {
		collectionView.collectionViewLayout.invalidateLayout()
	}
	
	func editorTitleCreateHeadline(attibutedTexts: HeadlineTexts?) {
		createHeadline(afterHeadline: nil, attributedTexts: attibutedTexts)
	}
	
	
}

extension EditorViewController: EditorHeadlineViewCellDelegate {

	var editorHeadlineUndoManager: UndoManager? {
		return undoManager
	}
	
	func editorHeadlineInvalidateLayout() {
		collectionView.collectionViewLayout.invalidateLayout()
	}
	
	func editorHeadlineToggleDisclosure(headline: Headline) {
		toggleDisclosure(headline: headline)
	}
	
	func editorHeadlineTextChanged(headline: Headline, attributedTexts: HeadlineTexts, isInNotes: Bool, cursorPosition: Int) {
		textChanged(headline: headline, attributedTexts: attributedTexts, isInNotes: isInNotes, cursorPosition: cursorPosition)
	}
	
	func editorHeadlineDeleteHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		deleteHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineCreateHeadline(beforeHeadline: Headline, attributedTexts: HeadlineTexts?) {
		createHeadline(beforeHeadline: beforeHeadline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineCreateHeadline(afterHeadline: Headline?, attributedTexts: HeadlineTexts?) {
		createHeadline(afterHeadline: afterHeadline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineIndentHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		indentHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineOutdentHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		outdentHeadline(headline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineSplitHeadline(_ headline: Headline, attributedText: NSAttributedString, cursorPosition: Int) {
		splitHeadline(headline, attributedText: attributedText, cursorPosition: cursorPosition)
	}
	
	func editorHeadlineCreateHeadlineNote(_ headline: Headline, attributedTexts: HeadlineTexts) {
		createHeadlineNote(headline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineDeleteHeadlineNote(_ headline: Headline, attributedTexts: HeadlineTexts) {
		deleteHeadlineNote(headline, attributedTexts: attributedTexts)
	}
	
	func editorHeadlineMoveCursorTo(headline: Headline) {
		moveCursorTo(headline: headline)
		hasAlreadyMovedThisKeyPressFlag = true
	}
	
	func editorHeadlineMoveCursorDown(headline: Headline) {
		moveCursorDown(headline: headline)
		hasAlreadyMovedThisKeyPressFlag = true
	}
	
	func editorHeadlineEditLink(_ link: String?, range: NSRange) {
		editLink(link, range: range)
	}

}

// MARK: EditorOutlineCommandDelegate

extension EditorViewController: EditorOutlineCommandDelegate {
	
	func applyChanges(_ changes: ShadowTableChanges) {
		if let deletes = changes.deleteIndexPaths, !deletes.isEmpty {
			collectionView.deleteItems(at: deletes)
		}
		if let inserts = changes.insertIndexPaths, !inserts.isEmpty {
			collectionView.insertItems(at: inserts)
		}
		if let moves = changes.moveIndexPaths, !moves.isEmpty {
			collectionView.performBatchUpdates {
				for move in moves {
					collectionView.moveItem(at: move.0, to: move.1)
				}
			}
		}
		if let reloads = changes.reloadIndexPaths, !reloads.isEmpty {
			collectionView.reloadItems(at: reloads)
		}
	}
	
	func applyChangesRestoringCursor(_ changes: ShadowTableChanges) {
		var textRange: UITextRange? = nil
		var cursorHeadline: Headline? = nil
		if let editorTextView = UIResponder.currentFirstResponder as? EditorHeadlineTextView {
			textRange = editorTextView.selectedTextRange
			cursorHeadline = editorTextView.headline
		}
		
		applyChanges(changes)
		
		if let textRange = textRange,
		   let updated = cursorHeadline?.shadowTableIndex,
		   let headlineCell = collectionView.cellForItem(at: IndexPath(row: updated, section: 1)) as? EditorHeadlineViewCell {
			headlineCell.restoreSelection(textRange)
		}
	}

	func restoreCursorPosition(_ cursorCoordinates: CursorCoordinates) {
		guard let shadowTableIndex = cursorCoordinates.headline.shadowTableIndex else { return }
		let indexPath = IndexPath(row: shadowTableIndex, section: 1)

		func restoreCursor() {
			guard let headlineCell = collectionView.cellForItem(at: indexPath) as? EditorHeadlineViewCell else { return	}
			headlineCell.restoreCursor(cursorCoordinates)
		}
		
		if !collectionView.indexPathsForVisibleItems.contains(indexPath) {
			CATransaction.begin()
			CATransaction.setCompletionBlock {
				// Got to wait or the headline cell won't be found
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
					restoreCursor()
				}
			}
			collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
			CATransaction.commit()
		} else {
			restoreCursor()
		}
	}
	
}

// MARK: LinkViewControllerDelegate

extension EditorViewController: LinkViewControllerDelegate {
	
	func updateLink(_: LinkViewController, cursorCoordinates: CursorCoordinates, link: String?, range: NSRange) {
		guard let shadowTableIndex = cursorCoordinates.headline.shadowTableIndex else { return }
		let indexPath = IndexPath(row: shadowTableIndex, section: 1)
		guard let headlineCell = collectionView.cellForItem(at: indexPath) as? EditorHeadlineViewCell else { return	}
		
		if cursorCoordinates.isInNotes {
			headlineCell.noteTextView?.updateLinkForCurrentSelection(link: link, range: range)
		} else {
			headlineCell.textView?.updateLinkForCurrentSelection(link: link, range: range)
		}
	}
	
}

// MARK: Helpers

private extension EditorViewController {
	
	private func updateUI() {
		navigationItem.title = outline?.title
		navigationItem.largeTitleDisplayMode = .never
		
		if traitCollection.userInterfaceIdiom != .mac {
			if outline?.isFiltered ?? false {
				filterBarButtonItem?.image = AppAssets.filterActive
			} else {
				filterBarButtonItem?.image = AppAssets.filterInactive
			}
		}
	}
	
	private func restoreOutlineCursorPosition() {
		if let cursorCoordinates = outline?.cursorCoordinates {
			restoreCursorPosition(cursorCoordinates)
		}
	}
	
	private func restoreScrollPosition() {
		if let verticleScrollState = outline?.verticleScrollState, verticleScrollState != 0 {
			collectionView.scrollToItem(at: IndexPath(row: verticleScrollState, section: 1), at: .top, animated: false)
			DispatchQueue.main.async {
				self.collectionView.scrollToItem(at: IndexPath(row: verticleScrollState, section: 1), at: .top, animated: false)
			}
		}
	}
	
	private func moveCursorToTitleOnNew() {
		if isOutlineNewFlag {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
				self.moveCursorToTitle()
			}
		}
		isOutlineNewFlag = false
	}
	
	private func moveCursorToTitle() {
		if let titleCell = self.collectionView.cellForItem(at: IndexPath(row: 0, section: 0)) as? EditorTitleViewCell {
			titleCell.takeCursor()
		}
	}
	
	private func editLink(_ link: String?, range: NSRange) {
		if traitCollection.userInterfaceIdiom == .mac {
		
			let linkViewController = UIStoryboard.dialog.instantiateController(ofType: LinkViewController.self)
			linkViewController.preferredContentSize = LinkViewController.preferredContentSize
			linkViewController.cursorCoordinates = CursorCoordinates.bestCoordinates
			linkViewController.link = link
			linkViewController.range = range
			linkViewController.delegate = self
			present(linkViewController, animated: true)
		
		} else {
			
			let linkNavViewController = UIStoryboard.dialog.instantiateViewController(withIdentifier: "LinkViewControllerNav") as! UINavigationController
			linkNavViewController.preferredContentSize = LinkViewController.preferredContentSize
			linkNavViewController.modalPresentationStyle = .formSheet

			let linkViewController = linkNavViewController.topViewController as! LinkViewController
			linkViewController.cursorCoordinates = CursorCoordinates.bestCoordinates
			linkViewController.link = link
			linkViewController.range = range
			linkViewController.delegate = self
			present(linkNavViewController, animated: true)
			
		}
	}
	
	private func makeHeadlineContextMenu(headline: Headline, attributedTexts: HeadlineTexts) -> UIContextMenuConfiguration {
		return UIContextMenuConfiguration(identifier: headline as NSCopying, previewProvider: nil, actionProvider: { [weak self] suggestedActions in
			guard let self = self, let outline = self.outline else { return nil }
			
			var menuItems = [UIMenu]()

			var firstOutlineActions = [UIAction]()
			firstOutlineActions.append(self.addAction(headline: headline, attributedTexts: attributedTexts))
			if !outline.isIndentHeadlineUnavailable(headline: headline) {
				firstOutlineActions.append(self.indentAction(headline: headline, attributedTexts: attributedTexts))
			}
			if !outline.isOutdentHeadlineUnavailable(headline: headline) {
				firstOutlineActions.append(self.outdentAction(headline: headline, attributedTexts: attributedTexts))
			}
			menuItems.append(UIMenu(title: "", options: .displayInline, children: firstOutlineActions))
			
			var secondOutlineActions = [UIAction]()
			secondOutlineActions.append(self.toggleCompleteAction(headline: headline, attributedTexts: attributedTexts))
			secondOutlineActions.append(self.toggleNoteAction(headline: headline, attributedTexts: attributedTexts))
			menuItems.append(UIMenu(title: "", options: .displayInline, children: secondOutlineActions))

			var viewActions = [UIAction]()
			if !outline.isExpandAllUnavailable(container: headline) {
				viewActions.append(self.expandAllAction(headline: headline))
			}
			if !outline.isCollapseAllUnavailable(container: headline) {
				viewActions.append(self.collapseAllAction(headline: headline))
			}
			menuItems.append(UIMenu(title: "", options: .displayInline, children: viewActions))
			
			let deleteAction = self.deleteAction(headline: headline, attributedTexts: attributedTexts)
			menuItems.append(UIMenu(title: "", options: .displayInline, children: [deleteAction]))

			return UIMenu(title: "", children: menuItems)
		})
	}
	
	private func addAction(headline: Headline, attributedTexts: HeadlineTexts) -> UIAction {
		return UIAction(title: L10n.addRow, image: AppAssets.add) { [weak self] action in
			// Have to let the text field get the first responder by getting it away from this
			// action which appears to be holding on to it.
			DispatchQueue.main.async {
				self?.createHeadline(afterHeadline: headline, attributedTexts: attributedTexts)
			}
		}
	}

	private func indentAction(headline: Headline, attributedTexts: HeadlineTexts) -> UIAction {
		return UIAction(title: L10n.indent, image: AppAssets.indent) { [weak self] action in
			self?.indentHeadline(headline, attributedTexts: attributedTexts)
		}
	}

	private func outdentAction(headline: Headline, attributedTexts: HeadlineTexts) -> UIAction {
		return UIAction(title: L10n.outdent, image: AppAssets.outdent) { [weak self] action in
			self?.outdentHeadline(headline, attributedTexts: attributedTexts)
		}
	}

	private func expandAllAction(headline: Headline) -> UIAction {
		return UIAction(title: L10n.expandAll, image: AppAssets.expandAll) { [weak self] action in
			self?.expandAll(container: headline)
		}
	}

	private func collapseAllAction(headline: Headline) -> UIAction {
		return UIAction(title: L10n.collapseAll, image: AppAssets.collapseAll) { [weak self] action in
			self?.collapseAll(container: headline)
		}
	}

	private func toggleCompleteAction(headline: Headline, attributedTexts: HeadlineTexts) -> UIAction {
		let title = headline.isComplete ?? false ? L10n.uncomplete : L10n.complete
		let image = headline.isComplete ?? false ? AppAssets.uncompleteHeadline : AppAssets.completeHeadline
		return UIAction(title: title, image: image) { [weak self] action in
			self?.toggleCompleteHeadline(headline, attributedTexts: attributedTexts)
		}
	}
	
	private func toggleNoteAction(headline: Headline, attributedTexts: HeadlineTexts) -> UIAction {
		if headline.isNoteEmpty {
			return UIAction(title: L10n.addNote, image: AppAssets.note) { [weak self] action in
				self?.createHeadlineNote(headline, attributedTexts: attributedTexts)
			}
		} else {
			return UIAction(title: L10n.deleteNote, image: AppAssets.delete, attributes: .destructive) { [weak self] action in
				self?.deleteHeadlineNote(headline, attributedTexts: attributedTexts)
			}
		}
	}

	private func deleteAction(headline: Headline, attributedTexts: HeadlineTexts) -> UIAction {
		return UIAction(title: L10n.deleteRow, image: AppAssets.delete, attributes: .destructive) { [weak self] action in
			self?.deleteHeadline(headline, attributedTexts: attributedTexts)
		}
	}

	func moveCursorTo(headline: Headline) {
		guard let shadowTableIndex = headline.shadowTableIndex else {
			return
		}
		
		let indexPath = IndexPath(row: shadowTableIndex, section: 1)
		if let headlineCell = collectionView.cellForItem(at: indexPath) as? EditorHeadlineViewCell {
			headlineCell.moveToEnd()
		}
	}
	
	func moveCursorUp(headline: Headline) {
		guard let shadowTableIndex = headline.shadowTableIndex, shadowTableIndex > 0 else {
			moveCursorToTitle()
			return
		}
		
		let indexPath = IndexPath(row: shadowTableIndex - 1, section: 1)
		if let headlineCell = collectionView.cellForItem(at: indexPath) as? EditorHeadlineViewCell {
			headlineCell.moveToEnd()
		}
	}
	
	func moveCursorDown(headline: Headline) {
		guard let shadowTableIndex = headline.shadowTableIndex, let shadowTable = outline?.shadowTable, shadowTableIndex < (shadowTable.count - 1) else { return }
		let indexPath = IndexPath(row: shadowTableIndex + 1, section: 1)
		if let headlineCell = collectionView.cellForItem(at: indexPath) as? EditorHeadlineViewCell {
			headlineCell.moveToEnd()
		}
	}
	
	func toggleDisclosure(headline: Headline) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorToggleDisclosureCommand(undoManager: undoManager,
													delegate: self,
													outline: outline,
													headline: headline)
		
		runCommand(command)
	}

	func expandAll(container: HeadlineContainer) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorExpandAllCommand(undoManager: undoManager,
											 delegate: self,
											 outline: outline,
											 container: container)
		
		runCommand(command)
	}

	func collapseAll(container: HeadlineContainer) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorCollapseAllCommand(undoManager: undoManager,
											   delegate: self,
											   outline: outline,
											   container: container)

		runCommand(command)
	}

	func textChanged(headline: Headline, attributedTexts: HeadlineTexts, isInNotes: Bool, cursorPosition: Int) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorTextChangedCommand(undoManager: undoManager,
											   delegate: self,
											   outline: outline,
											   headline: headline,
											   attributedTexts: attributedTexts,
											   isInNotes: isInNotes,
											   cursorPosition: cursorPosition)
		runCommand(command)
	}
	
	func deleteHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		guard let undoManager = undoManager, let outline = outline else { return }

		let command = EditorDeleteHeadlineCommand(undoManager: undoManager,
												  delegate: self,
												  outline: outline,
												  headline: headline,
												  attributedTexts: attributedTexts)

		runCommand(command)
		
		if let deleteIndex = command.changes?.deletes?.first {
			if deleteIndex > 0, let headlineCell = collectionView.cellForItem(at: IndexPath(row: deleteIndex - 1, section: 1)) as? EditorHeadlineViewCell {
				headlineCell.moveToEnd()
			} else {
				moveCursorToTitle()
			}
		}
	}
	
	func createHeadline(beforeHeadline: Headline, attributedTexts: HeadlineTexts?) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorCreateHeadlineBeforeCommand(undoManager: undoManager,
														delegate: self,
														outline: outline,
														beforeHeadline: beforeHeadline,
														attributedTexts: attributedTexts)
		
		runCommand(command)
		
		if let insert = command.changes?.insertIndexPaths?.first {
			if let headlineCell = collectionView.cellForItem(at: insert) as? EditorHeadlineViewCell {
				headlineCell.moveToEnd()
			}
		}
	}
	
	func createHeadline(afterHeadline: Headline?, attributedTexts: HeadlineTexts?) {
		guard let undoManager = undoManager, let outline = outline else { return }

		let command = EditorCreateHeadlineAfterCommand(undoManager: undoManager,
												  delegate: self,
												  outline: outline,
												  afterHeadline: afterHeadline,
												  attributedTexts: attributedTexts)
		
		runCommand(command)
		
		if let insert = command.changes?.insertIndexPaths?.first {
			if let headlineCell = collectionView.cellForItem(at: insert) as? EditorHeadlineViewCell {
				headlineCell.moveToEnd()
			}
		}
	}
	
	func indentHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorIndentHeadlineCommand(undoManager: undoManager,
												  delegate: self,
												  outline: outline,
												  headline: headline,
												  attributedTexts: attributedTexts)
		
		runCommand(command)
	}
	
	func outdentHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorOutdentHeadlineCommand(undoManager: undoManager,
												  delegate: self,
												  outline: outline,
												  headline: headline,
												  attributedTexts: attributedTexts)
		
		runCommand(command)
	}

	func splitHeadline(_ headline: Headline, attributedText: NSAttributedString, cursorPosition: Int) {
		guard let undoManager = undoManager, let outline = outline else { return }

		let command = EditorSplitHeadlineCommand(undoManager: undoManager,
												 delegate: self,
												 outline: outline,
												 headline: headline,
												 attributedText: attributedText,
												 cursorPosition: cursorPosition)
												  
		
		runCommand(command)
		
		if let insert = command.changes?.insertIndexPaths?.first {
			if let headlineCell = collectionView.cellForItem(at: insert) as? EditorHeadlineViewCell {
				headlineCell.moveToStart()
			}
		}
	}

	func toggleCompleteHeadline(_ headline: Headline, attributedTexts: HeadlineTexts) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorToggleCompleteHeadlineCommand(undoManager: undoManager,
														  delegate: self,
														  outline: outline,
														  headline: headline,
														  attributedTexts: attributedTexts)
		
		runCommand(command)
		
		if let deleteIndex = command.changes?.deletes?.first {
			let cursorIndex = deleteIndex < outline.shadowTable?.count ?? 0 ? deleteIndex : (outline.shadowTable?.count ?? 1) - 1
			if let headlineCell = collectionView.cellForItem(at: IndexPath(row: cursorIndex, section: 1)) as? EditorHeadlineViewCell {
				headlineCell.moveToEnd()
			}
		}
	}
	
	func createHeadlineNote(_ headline: Headline, attributedTexts: HeadlineTexts) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorCreateNoteCommand(undoManager: undoManager,
											  delegate: self,
											  outline: outline,
											  headline: headline,
											  attributedTexts: attributedTexts)
		
		runCommand(command)
		
		if let reloadIndex = command.changes?.reloads?.first {
			if let headlineCell = collectionView.cellForItem(at: IndexPath(row: reloadIndex, section: 1)) as? EditorHeadlineViewCell {
				headlineCell.moveToNote()
			}
		}
	}

	func deleteHeadlineNote(_ headline: Headline, attributedTexts: HeadlineTexts) {
		guard let undoManager = undoManager, let outline = outline else { return }
		
		let command = EditorDeleteNoteCommand(undoManager: undoManager,
											  delegate: self,
											  outline: outline,
											  headline: headline,
											  attributedTexts: attributedTexts)
		
		runCommand(command)

		if let reloadIndex = command.changes?.reloads?.first {
			if let headlineCell = collectionView.cellForItem(at: IndexPath(row: reloadIndex, section: 1)) as? EditorHeadlineViewCell {
				headlineCell.moveToEnd()
			}
		}
	}

}