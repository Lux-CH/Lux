//
//  UIKitBridges.swift
//  Lux
//
//  Created by Constantin Clerc on 19.08.2025.
//

import SafariServices
import MessageUI
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// https://codewithchris.com/sending-email-in-swiftui/ ; i couldnt get dismiss working
struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var recipients: [String]
    var subject: String
    var messageBody: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(messageBody, isHTML: false)
        return mailComposer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

struct MessageComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var recipients: [String]
    var messageBody: String
    var onResult: ((MessageSendResult) -> Void)?
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let messageComposer = MFMessageComposeViewController()
        messageComposer.messageComposeDelegate = context.coordinator
        messageComposer.recipients = recipients
        messageComposer.body = messageBody
        return messageComposer
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var parent: MessageComposerView

        init(_ parent: MessageComposerView) {
            self.parent = parent
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            let sendResult = MessageSendResult(from: result)
            parent.onResult?(sendResult)
            parent.dismiss()
        }
    }
}

enum MessageSendResult {
    case sent
    case cancelled
    case failed
    
    init(from result: MessageComposeResult) {
        switch result {
        case .sent:
            self = .sent
        case .cancelled:
            self = .cancelled
        case .failed:
            self = .failed
        @unknown default:
            self = .failed
        }
    }
    
    var description: String {
        switch self {
        case .sent:
            return "Message sent successfully"
        case .cancelled:
            return "Message cancelled"
        case .failed:
            return "Failed to send message"
        }
    }
}
