//
//  LuxPassManager.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import Foundation
import Security

struct PurchasedTicket: Codable, Identifiable {
    var id = UUID()
    var ticketName: String
    var expiry: Date
}

class LuxPassManager: ObservableObject {
    static let shared = LuxPassManager()
    
    @Published var hasSwissPass: Bool = false
    @Published var swissQRCodePass: String = ""
    @Published var swiss128Pass: String = ""
    @Published var isLoading: Bool = true
    
    private let keychainService = "ch.cclerc.lux.luxpass"
    private let combinedKey = "swisspass"
    private let separator = ":::"
    private let keychainQueue = DispatchQueue(label: "ch.cclerc.lux.keychain", qos: .userInitiated)
    
    private init() {
        loadSwissPassFromKeychain()
    }
    
    func saveSwissPass(qrCode: String, barcode: String) {
        keychainQueue.async {
            let combinedValue = qrCode + self.separator + barcode
            
            guard self.saveToKeychain(value: combinedValue, key: self.combinedKey) else {
                print("failed to save SwissPass to keychain")
                return
            }
            
            DispatchQueue.main.async {
                self.swissQRCodePass = qrCode
                self.swiss128Pass = barcode
                self.hasSwissPass = true
            }
        }
    }
    
    func deleteSwissPass() {
        keychainQueue.async {
            self.deleteFromKeychain(key: self.combinedKey)
            
            DispatchQueue.main.async {
                self.swissQRCodePass = ""
                self.swiss128Pass = ""
                self.hasSwissPass = false
            }
        }
    }
    
    func loadSwissPassFromKeychain() {
        keychainQueue.async {
            guard let combinedValue = self.loadFromKeychain(key: self.combinedKey) else {
                DispatchQueue.main.async {
                    self.swissQRCodePass = ""
                    self.swiss128Pass = ""
                    self.hasSwissPass = false
                }
                self.migrateFromOldFormat()
                return
            }
            
            let components = combinedValue.components(separatedBy: self.separator)
            let qrCode = components.first ?? ""
            let barcode = components.count > 1 ? components[1] : ""
            
            DispatchQueue.main.async {
                self.swissQRCodePass = qrCode
                self.swiss128Pass = barcode
                self.hasSwissPass = !qrCode.isEmpty && !barcode.isEmpty
                self.isLoading = false
            }
        }
    }
    
    private func migrateFromOldFormat() {
        let qrCodeKey = "swisspass_qr"
        let barcodeKey = "swisspass_barcode"
        
        if let qrCode = loadFromKeychain(key: qrCodeKey),
           let barcode = loadFromKeychain(key: barcodeKey) {
            
            let combinedValue = qrCode + separator + barcode
            saveToKeychain(value: combinedValue, key: combinedKey)
            
            deleteFromKeychain(key: qrCodeKey)
            deleteFromKeychain(key: barcodeKey)
            DispatchQueue.main.async {
                self.loadSwissPassFromKeychain()
            }
        } else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    @discardableResult
    private func saveToKeychain(value: String, key: String) -> Bool {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
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
    
    func loadTickets() -> [PurchasedTicket] {
        guard let data = UserDefaults.standard.data(forKey: "purchasedTickets"),
              let tickets = try? JSONDecoder().decode([PurchasedTicket].self, from: data) else {
            return []
        }
        return tickets
    }
        
    func saveTickets(_ tickets: [PurchasedTicket]) {
        if let data = try? JSONEncoder().encode(tickets) {
            UserDefaults.standard.set(data, forKey: "purchasedTickets")
        }
    }
    
    func addTicket(ticketName: String, duration: TimeInterval) {
        var tickets = loadTickets()
        tickets.append(PurchasedTicket(ticketName: ticketName, expiry: Date().addingTimeInterval(duration)))
        saveTickets(tickets)
    }
    
    func removeExpiredTickets() {
        saveTickets(loadTickets().filter { $0.expiry > Date() })
    }
    
    func validTickets() -> [PurchasedTicket] {
        removeExpiredTickets()
        return loadTickets()
    }
}
