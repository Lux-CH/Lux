//
//  LuxPassManager.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import Foundation
import Security

class LuxPassManager: ObservableObject {
    static let shared = LuxPassManager()
    
    @Published var hasSwissPass: Bool = false
    @Published var swissQRCodePass: String = ""
    @Published var swiss128Pass: String = ""
    
    private let keychainService = "ch.cclerc.lux.luxpass"
    private let qrCodeKey = "swisspass_qr"
    private let barcodeKey = "swisspass_barcode"
    
    private init() {
        loadSwissPassFromKeychain()
    }
    
    // MARK: - Public Methods
    func saveSwissPass(qrCode: String, barcode: String) {
        guard saveToKeychain(value: qrCode, key: qrCodeKey),
              saveToKeychain(value: barcode, key: barcodeKey) else {
            print("failed to save SwissPass to keychain")
            return
        }
        
        DispatchQueue.main.async {
            self.swissQRCodePass = qrCode
            self.swiss128Pass = barcode
            self.hasSwissPass = true
        }
    }
    
    func deleteSwissPass() {
        deleteFromKeychain(key: qrCodeKey)
        deleteFromKeychain(key: barcodeKey)
        
        DispatchQueue.main.async {
            self.swissQRCodePass = ""
            self.swiss128Pass = ""
            self.hasSwissPass = false
        }
    }
    
    func loadSwissPassFromKeychain() {
        let qrCode = loadFromKeychain(key: qrCodeKey) ?? ""
        let barcode = loadFromKeychain(key: barcodeKey) ?? ""
        
        DispatchQueue.main.async {
            self.swissQRCodePass = qrCode
            self.swiss128Pass = barcode
            self.hasSwissPass = !qrCode.isEmpty && !barcode.isEmpty
        }
    }
    
    // MARK: - Private Keychain Methods
    private func saveToKeychain(value: String, key: String) -> Bool {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
