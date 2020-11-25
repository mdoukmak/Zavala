//
//  HeadlineContainer.swift
//  
//
//  Created by Maurice Parker on 11/22/20.
//

import Foundation
import SWXMLHash

protocol HeadlineContainer: class {
	var headlines: [Headline]? { get set }
}

extension HeadlineContainer {
	
	public func importOPML(_ headlineIndexers: [XMLIndexer]) {
		var headlines = [Headline]()
		for headlineIndexer in headlineIndexers {
			let headline = Headline(plainText: headlineIndexer.element?.attribute(by: "text")?.text ?? "")
			headline.importOPML(headlineIndexer["outline"].all)
			headlines.append(headline)
		}
		self.headlines = headlines
	}

}