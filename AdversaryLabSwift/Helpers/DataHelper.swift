//
//  DataHelper.swift
//  AdversaryLabSwift
//
//  Created by Adelita Schule on 3/1/18.
//  Copyright © 2018 Operator Foundation. All rights reserved.
//

import Foundation

extension Data
{
    struct HexEncodingOptions: OptionSet
    {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String
    {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}
