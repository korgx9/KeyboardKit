//
//  Input+Preview.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-25.
//  Copyright © 2021-2023 Daniel Saidi. All rights reserved.
//

import Foundation

@available(*, deprecated, message: "Use input sets directly instead.")
public extension InputSetProvider where Self == PreviewInputSetProvider {
    
    static var preview: InputSetProvider { PreviewInputSetProvider() }
}

@available(*, deprecated, message: "Use input sets directly instead.")
public class PreviewInputSetProvider: InputSetProvider {
    
    /**
     Create a preview provider.
     
     - Parameters:
       - context: The context to use by the preview, by default `.preview`.
     */
    public init(keyboardContext: KeyboardContext = .preview) {
        self.keyboardContext = keyboardContext
        self.provider = StandardInputSetProvider(
            keyboardContext: keyboardContext)
    }
    
    private let keyboardContext: KeyboardContext
    private let provider: InputSetProvider
    
    /**
     The input set to use for alphabetic keyboards.
     */
    public var alphabeticInputSet: AlphabeticInputSet {
        provider.alphabeticInputSet
    }
    
    /**
     The input set to use for numeric keyboards.
     */
    public var numericInputSet: NumericInputSet {
        provider.numericInputSet
    }
    
    /**
     The input set to use for symbolic keyboards.
     */
    public var symbolicInputSet: SymbolicInputSet {
        provider.symbolicInputSet
    }
}
