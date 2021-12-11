//
//  TestHelper.swift
//  ServePlusDraft
//
//  Created by Vikram Khandelwal on 10/9/21.
//

import Foundation

/// Class to provide utility functions for unit tests
class TestHelper {
    static func inject<T>(into classType: T.Type, value: NSData) {
        let selector = #selector(NSData.init(contentsOf:))
        guard let originalMethod = class_getInstanceMethod(NSData.self, selector) else {
            fatalError("\(selector) must be implemented")
        }

        let swizzledBlock: @convention(block) () -> NSData = {
            return value
        }

        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(swizzledBlock, to: AnyObject.self))
        method_setImplementation(originalMethod, swizzledIMP)
    }
}

