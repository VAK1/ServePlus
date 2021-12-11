//
//  BundleType.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/9/21.
//

import Foundation

protocol BundleType {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: BundleType {}
