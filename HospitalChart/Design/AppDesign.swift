import SwiftUI

enum AppColor {
    static let primary   = Color.blue
    static let accent    = Color(red: 0.0, green: 0.48, blue: 0.78)
    static let inpatient = Color.orange
    static let danger    = Color.red
    static let success   = Color.green
    static let warning   = Color.yellow
}

enum AppFont {
    static let title   = Font.title2.bold()
    static let body    = Font.body
    static let caption = Font.caption
    static let mono    = Font.system(.caption, design: .monospaced)
}

// 차트 번호 포맷: YYYY-NNNNNN
func formatChartNumber(year: Int = Calendar.current.component(.year, from: Date()),
                        seq: Int) -> String {
    String(format: "%d-%06d", year, seq)
}
