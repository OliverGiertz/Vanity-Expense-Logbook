//
//  KeychainHelper.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 27.02.25.
//


import Foundation
import Security

struct KeychainHelper {
    /// Save data to the keychain with the specified key
    /// - Parameters:
    ///   - key: The key to store the data under
    ///   - data: The data to store
    /// - Returns: OSStatus result code
    static func save(key: String, data: Data) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }
    
    /// Load data from the keychain with the specified key
    /// - Parameter key: The key to retrieve data for
    /// - Returns: The stored data, if any
    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            return dataTypeRef as? Data
        } else {
            return nil
        }
    }
    
    /// Delete data from the keychain with the specified key
    /// - Parameter key: The key to delete
    /// - Returns: OSStatus result code
    static func delete(key: String) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        return SecItemDelete(query as CFDictionary)
    }
    
    /// Save a string to the keychain
    /// - Parameters:
    ///   - key: The key to store the string under
    ///   - string: The string to store
    /// - Returns: OSStatus result code
    static func saveString(_ string: String, forKey key: String) -> OSStatus {
        if let data = string.data(using: .utf8) {
            return save(key: key, data: data)
        }
        return errSecParam
    }
    
    /// Load a string from the keychain
    /// - Parameter key: The key to retrieve the string for
    /// - Returns: The stored string, if any
    static func loadString(forKey key: String) -> String? {
        if let data = load(key: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}