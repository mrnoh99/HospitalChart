import SwiftUI
import Supabase

@MainActor
class HospitalViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentStaff: StaffProfile?
    @Published var patients: [Patient] = []
    @Published var selectedPatient: Patient?
    @Published var selectedTab: ChartTab = .chart
    @Published var searchText = ""
    @Published var statusFilter: Patient.AdmissionStatus? = nil
    @Published var reviewsDueToday: [Admission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = HospitalRepository.shared

    enum ChartTab: String, CaseIterable {
        case chart = "chart"
        case admission = "admission"
        case prescription = "prescription"
        case psychology = "psychology"

        var label: String {
            switch self {
            case .chart:        return "진료기록"
            case .admission:    return "입원"
            case .prescription: return "처방"
            case .psychology:   return "심리"
            }
        }
        var icon: String {
            switch self {
            case .chart:        return "doc.text"
            case .admission:    return "bed.double"
            case .prescription: return "pills"
            case .psychology:   return "brain.head.profile"
            }
        }
    }

    func restoreSession() async {
        if let session = await repo.currentSession() {
            isAuthenticated = true
            do {
                currentStaff = try await repo.myProfile()
                await loadPatients()
                await loadReviewsDueToday()
            } catch {
                errorMessage = error.localizedDescription
            }
            _ = session
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await repo.signIn(email: email, password: password)
            currentStaff = try await repo.myProfile()
            isAuthenticated = true
            await loadPatients()
            await loadReviewsDueToday()
        } catch {
            errorMessage = "로그인 실패: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        try? await repo.signOut()
        isAuthenticated = false
        currentStaff = nil
        patients = []
        selectedPatient = nil
    }

    func loadPatients() async {
        do {
            patients = try await repo.fetchPatients(status: statusFilter, search: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadReviewsDueToday() async {
        do {
            reviewsDueToday = try await repo.fetchReviewsDueToday()
        } catch {}
    }

    func selectPatient(_ patient: Patient) {
        selectedPatient = patient
        selectedTab = .chart
    }

    // 비서는 차트 열람 불가
    var canViewCharts: Bool {
        currentStaff?.staff_role.canViewCharts ?? false
    }

    var canPrescribe: Bool {
        currentStaff?.staff_role.canPrescribe ?? false
    }
}
