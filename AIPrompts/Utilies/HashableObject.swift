//
//  HashableObject.swift
//  AIPrompts
//
//  Created by Lulin Yang on 2025/7/18.
//

import Foundation

protocol HashableObject: AnyObject, Hashable {}

extension HashableObject {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs === rhs
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
