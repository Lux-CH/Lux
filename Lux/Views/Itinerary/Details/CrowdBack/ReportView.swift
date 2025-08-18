//
//  ReportView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.06.2025.
//

import SwiftUI
import LuxCom

struct ReportView: View {
    let leg: Leg
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var currentStep: Int = 0
    @State private var attributeValues: [ReportAttribute: Int] = [
        .crowd: 3,
        .clean: 3,
        .heat: 3,
        .noise: 3
    ]
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    
    @State private var submissionProgress: Float = 0
    @State private var submittingAttributeIndex: Int = 0
    @State private var failedReportsCount: Int = 0
    
    private let attributes: [ReportAttribute] = [.crowd, .clean, .heat, .noise]
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Text(String(localized: "Signaler une situation"))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Button(String(localized: "Annuler")) {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)
                    
                    HStack {
                        LinePill(
                            line: leg.routeShortName ?? "",
                            mode: leg.mode,
                            width: 35,
                            height: 22,
                            fontSize: 11
                        )
                        Text(leg.headsign ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ProgressIndicator(
                        currentStep: currentStep,
                        totalSteps: attributes.count
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                if currentStep < attributes.count {
                    AttributeStepView(
                        attribute: attributes[currentStep],
                        selectedLevel: attributeValues[attributes[currentStep]] ?? 3,
                    ) { level in
                        attributeValues[attributes[currentStep]] = level
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    
                    HStack(spacing: 12) {
                        if currentStep > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep -= 1
                                }
                            } label: {
                                Text(String(localized: "Précédent"))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        
                        Button {
                            if currentStep == attributes.count - 1 {
                                submitAllReports()
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentStep += 1
                                }
                            }
                        } label: {
                            Text(currentStep == attributes.count - 1 ? String(localized: "Terminer") : String(localized: "Suivant"))
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .blur(radius: showSuccess || showError || isSubmitting ? 3 : 0)
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
            .animation(.easeInOut(duration: 0.3), value: showError)
            .animation(.easeInOut(duration: 0.3), value: isSubmitting)
            
            if isSubmitting {
                SubmittingOverlay(
                    currentAttribute: getCurrentSubmittingAttribute(),
                    progress: getSubmissionProgress()
                )
            }
            
            if showSuccess {
                SuccessOverlay()
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showSuccess)
            }
            
            if showError {
                ErrorOverlay(
                    failedReports: getFailedReportsCount()
                ) {
                    showError = false
                    dismiss()
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showError)
            }
        }
    }
    
    private func getCurrentSubmittingAttribute() -> ReportAttribute {
        guard submittingAttributeIndex < attributes.count else { return attributes.first! }
        return attributes[submittingAttributeIndex]
    }
    
    private func getSubmissionProgress() -> Float {
        return Float(submittingAttributeIndex) / Float(attributes.count)
    }
    
    private func getFailedReportsCount() -> Int {
        return failedReportsCount
    }
    
    private func submitAllReports() {
        guard let tripId = leg.tripId,
              let routeShortName = leg.routeShortName,
              let location = locationManager.location else { return }
        
        isSubmitting = true
        submissionProgress = 0
        submittingAttributeIndex = 0
        failedReportsCount = 0
        
        Task {
            var successCount = 0
            
            for (index, attribute) in attributes.enumerated() {
                guard let level = attributeValues[attribute] else { continue }
                
                await MainActor.run {
                    submittingAttributeIndex = index
                    submissionProgress = Float(index) / Float(attributes.count)
                }
                
                let report = Report(
                    tripId: tripId,
                    routeShortName: routeShortName,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    attribute: attribute,
                    level: level
                )
                
                do {
                    try await sendLCBReport(report: report)
                    successCount += 1
                    
                    try await Task.sleep(nanoseconds: 200_000_000)
                } catch {
                    await MainActor.run {
                        failedReportsCount += 1
                    }
                    print("error sending report for \(attribute): \(error)")
                }
            }
            
            await MainActor.run {
                isSubmitting = false
                
                if successCount > 0 {
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        dismiss()
                    }
                } else {
                    showError = true
                }
            }
        }
    }
}
