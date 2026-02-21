import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    @Published var driverId: String = ""
    @Published var token: String?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    func login() {
        guard !driverId.isEmpty else { self.errorMessage = "Driver ID required"; return }
        isLoading = true
        APIClient.shared.login(driverId: driverId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let t):
                    self.token = t
                    self.errorMessage = nil
                    _ = KeychainHelper.shared.save(t, account: "api_token")
                    UserDefaults.standard.set(self.driverId, forKey: "driver_id")
                case .failure(let e):
                    self.errorMessage = e.localizedDescription
                }
            }
        }
    }
}

