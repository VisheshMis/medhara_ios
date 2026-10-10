import SwiftUI
import AppKit

public struct PinnedPropertyBarView: View {
    @ObservedObject public var store: BlockStore
    public let doc: Block

    @State private var isVerificationSheetPresented: Bool = false
    @State private var verificationAuthor: String = "Author"
    @State private var selectedDays: Int = 90

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 1. Page Verification Pill
                if doc.isVerified {
                    Menu {
                        Text("Verified by: \(doc.verifiedBy ?? "Author")")
                        Text("Days remaining: \(doc.verificationDaysRemaining) days")
                        Divider()
                        Button("Renew Verification (90 Days)") {
                            store.setDocumentVerification(docId: doc.id, days: 90, verifiedBy: doc.verifiedBy ?? "Author")
                        }
                        Button("Renew Verification (365 Days)") {
                            store.setDocumentVerification(docId: doc.id, days: 365, verifiedBy: doc.verifiedBy ?? "Author")
                        }
                        Divider()
                        Button(role: .destructive, action: {
                            store.clearDocumentVerification(docId: doc.id)
                        }) {
                            Label("Remove Verification", systemImage: "xmark.seal")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Verified (\(doc.verificationDaysRemaining)d)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(MedhaTheme.Colors.success.opacity(0.14))
                        .foregroundColor(MedhaTheme.Colors.success)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(MedhaTheme.Colors.success.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .menuStyle(.borderlessButton)
                } else {
                    Button(action: { isVerificationSheetPresented = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "seal")
                                .font(.system(size: 10))
                            Text("Verify Note")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MedhaTheme.Colors.bgSurface.opacity(0.7))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(MedhaTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Mark document as authoritative for 30, 90, or 365 days")
                }

                // 2. Document Egress Lock Pill
                if doc.isLocked == true {
                    Button(action: {
                        store.setDocumentLock(docId: doc.id, isLocked: false)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Locked (Read-Only)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.14))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Click to unlock document for editing")
                } else {
                    Button(action: {
                        store.setDocumentLock(docId: doc.id, isLocked: true)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.open")
                                .font(.system(size: 10))
                            Text("Lock")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MedhaTheme.Colors.bgSurface.opacity(0.7))
                        .foregroundColor(MedhaTheme.Colors.textTertiary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(MedhaTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Lock document to prevent accidental edits or deletions")
                }

                // 3. Blocks Count Metric Chip
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 10))
                    Text("\(store.blocks.count) blocks")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MedhaTheme.Colors.bgSurface.opacity(0.5))
                .foregroundColor(MedhaTheme.Colors.textTertiary)
                .clipShape(Capsule())

                // 4. Last Edited Timestamp Chip
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(doc.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MedhaTheme.Colors.bgSurface.opacity(0.5))
                .foregroundColor(MedhaTheme.Colors.textTertiary)
                .clipShape(Capsule())
            }
            .padding(.vertical, 2)
        }
        .sheet(isPresented: $isVerificationSheetPresented) {
            verificationModal
        }
    }

    private var verificationModal: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MedhaTheme.Colors.success)
                Text("Verify Document")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button("Cancel") { isVerificationSheetPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
            }

            Text("Certified documents receive an authoritative badge and higher relevance weighting in FTS5 searches.")
                .font(.system(size: 12))
                .foregroundColor(MedhaTheme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Verification Interval")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                Picker("Duration", selection: $selectedDays) {
                    Text("30 Days").tag(30)
                    Text("90 Days (Recommended)").tag(90)
                    Text("365 Days (1 Year)").tag(365)
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Certifier Name / Role")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MedhaTheme.Colors.textSecondary)
                TextField("e.g. Lead Author, Vishesh, Subject Lead", text: $verificationAuthor)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Verify Now") {
                    store.setDocumentVerification(
                        docId: doc.id,
                        days: selectedDays,
                        verifiedBy: verificationAuthor.isEmpty ? "Author" : verificationAuthor
                    )
                    isVerificationSheetPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(MedhaTheme.Colors.success)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
