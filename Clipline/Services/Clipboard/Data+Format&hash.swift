//
//  Data+Format&hash.swift
//  Clipline
//
//  Created by mazhj on 2025/11/30.
//

import Foundation
import CryptoKit

extension Data {
    
    public func toSha256() -> String {
        let digest = SHA256.hash(data: self)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public func formatBytes() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self.count))
    }

}
