import Supabase
import Foundation

// Supabase URL·Key는 Info.plist 또는 환경변수에서 로드 (소스코드에 하드코딩 금지)
let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "")!,
    supabaseKey: Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
)
