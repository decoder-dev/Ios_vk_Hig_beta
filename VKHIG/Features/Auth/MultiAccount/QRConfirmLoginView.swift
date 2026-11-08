import SwiftUI

/// Scans the QR VK shows on its own login page and confirms it with the currently active account —
/// the official "log in on another device" flow, distinct from scanning a QR that just encodes a token.
struct QRConfirmLoginView: View {
    @State private var resume = 0
    @State private var hash: String?
    @State private var device: VKQRLoginService.DeviceInfo?
    @State private var error: String?
    @State private var isWorking = false
    @State private var confirmed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            QRScannerView(onCode: handleScan, onFailure: { error = $0 }, resumeToken: resume)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                if isWorking { ProgressView().tint(.white) }
                if confirmed {
                    Text("Вход подтверждён").foregroundStyle(.green)
                } else if let error {
                    Text(error).foregroundStyle(.white)
                } else {
                    Text("Наведите камеру на QR-код входа VK").foregroundStyle(.white)
                }
            }
            .font(.footnote).multilineTextAlignment(.center)
            .padding().frame(maxWidth: .infinity).background(.black.opacity(0.6))
        }
        .navigationTitle("Подтверждение по QR")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Подтвердить вход?", isPresented: Binding(get: { device != nil }, set: { if !$0 { device = nil } }),
                            titleVisibility: .visible) {
            Button("Подтвердить вход\(device?.platform.map { " (\($0))" } ?? "")") { Task { await confirm() } }
            Button("Отмена", role: .cancel) { device = nil; resume += 1 }
        } message: {
            Text(device?.location ?? "Устройство не определено VK.")
        }
    }

    private func handleScan(_ code: String) {
        guard let parsedHash = VKQRLoginService.authHash(from: code) else {
            error = "Это не QR-код входа VK."; resume += 1; return
        }
        hash = parsedHash
        Task {
            isWorking = true; error = nil
            defer { isWorking = false }
            do { device = try await VKQRLoginService.describe(hash: parsedHash) }
            catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription; resume += 1 }
        }
    }

    private func confirm() async {
        guard let hash else { return }
        device = nil
        isWorking = true; error = nil
        defer { isWorking = false }
        do { try await VKQRLoginService.confirm(hash: hash); confirmed = true }
        catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            resume += 1
        }
    }
}
