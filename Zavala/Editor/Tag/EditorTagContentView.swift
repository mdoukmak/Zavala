//
//  EditorTagContentView.swift
//  Zavala
//
//  Created by Maurice Parker on 1/29/21.
//

import UIKit

class EditorTagContentView: UIView, UIContentView {

	let button = UIButton()
	weak var delegate: EditorTagViewCellDelegate?
	
	var appliedConfiguration: EditorTagContentConfiguration!
	
	init(configuration: EditorTagContentConfiguration) {
		self.delegate = configuration.delegate
		super.init(frame: .zero)

		addSubview(button)
		
		button.translatesAutoresizingMaskIntoConstraints = false
		button.layer.cornerRadius = 10
		button.backgroundColor = AppAssets.accessory
		button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
		
		NSLayoutConstraint.activate([
			button.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
			button.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
			button.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
			button.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
		])

		apply(configuration: configuration)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	var configuration: UIContentConfiguration {
		get { appliedConfiguration }
		set {
			guard let newConfig = newValue as? EditorTagContentConfiguration else { return }
			apply(configuration: newConfig)
		}
	}
	
	private func apply(configuration: EditorTagContentConfiguration) {
		guard appliedConfiguration != configuration else { return }
		appliedConfiguration = configuration
		button.setTitle(configuration.name, for: .normal)
	}
	
}
