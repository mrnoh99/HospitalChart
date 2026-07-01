import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var vm: HospitalViewModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cross.case.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("아주 정신과 차트")
                .font(.largeTitle.bold())
            Text("아주대학교병원 정신건강의학과 EMR")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("이메일", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }

                SecureField("비밀번호", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .password)
                    .onSubmit { Task { await vm.signIn(email: email, password: password) } }
            }
            .frame(width: 320)

            if let msg = vm.errorMessage {
                Text(msg)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button(action: { Task { await vm.signIn(email: email, password: password) } }) {
                if vm.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("로그인")
                        .frame(width: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading || email.isEmpty || password.isEmpty)

            Spacer()

            Text("의료법·개인정보보호법에 따라 모든 접근 이력이 기록됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .frame(width: 480, height: 520)
        .onAppear { focus = .email }
    }
}
