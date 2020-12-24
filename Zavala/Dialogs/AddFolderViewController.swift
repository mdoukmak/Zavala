//
//  AddFolderViewController.swift
//  Zavala
//
//  Created by Maurice Parker on 11/11/20.
//

import UIKit
import Templeton

class AddFolderViewController: FormViewController {

	static let preferredContentSize = CGSize(width: 400, height: 150)

	var account: Account?
	
	@IBOutlet weak var nameTextField: UITextField!
	
	@IBOutlet weak var addBarButtonItem: UIBarButtonItem!

	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var cancelButton: UIButton!
	@IBOutlet weak var submitButton: UIButton!
	
	override func viewDidLoad() {
        super.viewDidLoad()
	
		if traitCollection.userInterfaceIdiom == .mac {
			nameTextField.placeholder = nil
			nameTextField.borderStyle = .bezel
			navigationController?.setNavigationBarHidden(true, animated: false)
			submitButton.role = .primary
		} else {
			nameLabel.isHidden = true
			cancelButton.isHidden = true
			submitButton.isHidden = true
		}

		nameTextField.addTarget(self, action: #selector(nameTextFieldDidChange), for: .editingChanged)
		nameTextField.delegate = self
	}
	
	override func viewDidAppear(_ animated: Bool) {
		nameTextField.becomeFirstResponder()
	}
	
	@objc func nameTextFieldDidChange(textField: UITextField) {
		updateUI()
	}
	
	@IBAction override func submit(_ sender: Any) {
		guard let account = account, let folderName = nameTextField.text, !folderName.isEmpty else { return	}
		
		let folder = account.createFolder(folderName)
		
		var userInfo = [AnyHashable: Any]()
		userInfo[UserInfoKeys.folder] = folder
		NotificationCenter.default.post(name: .UserDidAddFolder, object: self, userInfo: userInfo)

		dismiss(animated: true)
	}
	
	func updateUI() {
		let isReady = !(nameTextField.text?.isEmpty ?? false)
		addBarButtonItem.isEnabled = isReady
		submitButton.isEnabled = isReady
	}

}

extension AddFolderViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}