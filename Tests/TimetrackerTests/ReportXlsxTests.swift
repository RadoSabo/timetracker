import Testing
import Foundation
@testable import Timetracker

private func task(_ name: String, seconds: Double) -> TaskItem {
    var t = TaskItem(row: Row(values: ["id": Int64(name.hashValue), "project_id": Int64(1), "day": "d", "name": name, "name_edited": Int64(0), "adjustment": 0.0, "adjustment_note": ""]))
    t.tracked = [Interval(start: 0, end: seconds)]
    return t
}
private func project(_ name: String, id: Int64) -> Project {
    Project(row: Row(values: ["id": id, "name": name, "billable": Int64(1), "rate": 50.0, "color": Int64(0), "hidden": Int64(0), "keywords": "", "description": ""]))
}
private func report(_ name: String, id: Int64, _ days: [Report.DayLine]) -> Report {
    Report(project: project(name, id: id), from: Date(), to: Date(), days: days)
}

@Test func twoProjectsOnOneDayBecomeTwoRowsAndDaysWithoutBilledTimeAreLeftOut() {
    let a = report("Acme", id: 1, [Report.DayLine(day: "2026-10-02", tasks: [task("Login", seconds: 100)], exactSeconds: 7100, roundedSeconds: 7200),
                                   Report.DayLine(day: "2026-10-03", tasks: [task("General", seconds: 100)], exactSeconds: 300, roundedSeconds: 0)])
    let b = report("Beta", id: 2, [Report.DayLine(day: "2026-10-01", tasks: [task("Import", seconds: 100)], exactSeconds: 1800, roundedSeconds: 1800),
                                   Report.DayLine(day: "2026-10-02", tasks: [task("Search", seconds: 100)], exactSeconds: 3600, roundedSeconds: 3600)])
    #expect(Report.xlsxLines([a, b]) == [
        Report.XlsxLine(day: "2026-10-01", projectId: 2, project: "Beta", hours: 0.5, work: "Import"),
        Report.XlsxLine(day: "2026-10-02", projectId: 1, project: "Acme", hours: 2, work: "Login"),
        Report.XlsxLine(day: "2026-10-02", projectId: 2, project: "Beta", hours: 1, work: "Search"),
    ])
}

@Test func fallbackWorkListsTheThreeLongestTasksAndNeverGeneral() {
    let tasks = [task("General", seconds: 9000), task("Small", seconds: 100), task("Big", seconds: 5000), task("Mid", seconds: 3000), task("Tiny", seconds: 10)]
    let r = report("Acme", id: 1, [Report.DayLine(day: "2026-10-01", tasks: tasks, exactSeconds: 0, roundedSeconds: 3600)])
    #expect(Report.xlsxLines([r])[0].work == "Big; Mid; Small")
    let only = report("Acme", id: 1, [Report.DayLine(day: "2026-10-01", tasks: [task("General", seconds: 60)], exactSeconds: 0, roundedSeconds: 3600)])
    #expect(Report.xlsxLines([only])[0].work == "")
}

@Test func claudeAnswerReplacesWorkByDayAndProjectAndSkippedRowsKeepTheirNames() {
    let lines = [Report.XlsxLine(day: "2026-10-01", projectId: 1, project: "Acme", hours: 1, work: "Rails eager loading"),
                 Report.XlsxLine(day: "2026-10-02", projectId: 1, project: "Acme", hours: 1, work: "Kept")]
    let answer = WorkPerformed.parse("Sure:\n[{\"day\":\"2026-10-01\",\"project\":\"acme\",\"work\":\"Faster worker list\"},{\"day\":\"2026-10-09\",\"project\":\"Acme\",\"work\":\"x\"}]")
    let merged = lines.map { var l = $0; l.work = answer["\(l.day)|\(l.project.lowercased())"] ?? l.work; return l }
    #expect(merged.map(\.work) == ["Faster worker list", "Kept"])
}

@Test func writesAZipWithTheSheetInside() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("xlsx-test-\(UUID().uuidString).xlsx")
    defer { try? FileManager.default.removeItem(at: url) }
    let lines = [Report.XlsxLine(day: "2026-10-01", projectId: 1, project: "Acme <&>", hours: 1, work: "A & B")]
    try Report.writeXlsx(lines, from: Day.date("2026-10-01"), to: Day.date("2026-10-31"), to: url)
    let list = Process(); list.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); list.arguments = ["-p", url.path, "xl/worksheets/sheet1.xml"]
    let pipe = Pipe(); list.standardOutput = pipe; try list.run(); list.waitUntilExit()
    let xml = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    #expect(xml.contains("<t>Acme &lt;&amp;&gt;</t>"))
    #expect(xml.contains("<t>A &amp; B</t>"))
    #expect(xml.contains("<f>SUM(C5:C5)</f><v>1.00</v>"))
}
