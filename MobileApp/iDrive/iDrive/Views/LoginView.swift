import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    var onLogin: (String) -> Void
    @State private var showApiError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("iDrive - Driver").font(.largeTitle)
            TextField("Driver ID", text: $vm.driverId)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red)
            }
            Button(action: { vm.login() }) {
                if vm.isLoading {
                    ProgressView()
                } else {
                    Text("Login")
                }
            }
            .disabled(vm.isLoading || vm.driverId.isEmpty)
            .padding()
            .onReceive(vm.$token) { token in
                if let t = token { onLogin(t) }
            }
            .onChange(of: vm.errorMessage) { _ in
                showApiError = vm.errorMessage != nil
            }
            .alert("API Error", isPresented: $showApiError) {
                Button("OK", role: .cancel) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "Unknown error")
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView() { _ in }
    }
}

