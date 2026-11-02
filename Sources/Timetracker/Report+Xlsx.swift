import Foundation

/// Excel export of every billable Project over a period: one row per day and Project, rounded hours, the day's
/// 1–3 biggest Tasks as "Work performed". Styled like the client's own timesheet.
extension Report {
    struct XlsxLine: Equatable { var day: String; var projectId: Int64; var project: String; var hours: Double; var work: String }

    /// One line per day and Project with billed time; `work` starts as the three longest named Tasks ("General" says
    /// nothing) and WorkPerformed rewrites it for the client.
    static func xlsxLines(_ reports: [Report]) -> [XlsxLine] {
        reports.flatMap { r in r.days.filter { $0.roundedSeconds > 0 }.map { XlsxLine(day: $0.day, projectId: r.project.id, project: r.project.name, hours: $0.roundedSeconds / 3600, work: work($0.tasks)) } }
            .sorted { ($0.day, $0.project) < ($1.day, $1.project) }
    }

    private static func work(_ tasks: [TaskItem]) -> String {
        tasks.filter { $0.name != "General" }.sorted { $0.totalSeconds > $1.totalSeconds }.prefix(3).map(\.name).joined(separator: "; ")
    }

    // ponytail: zip via /usr/bin/zip; an in-process writer only if the app ever gets sandboxed
    static func writeXlsx(_ lines: [XlsxLine], from: Date, to: Date, to url: URL) throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("xlsx-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: dir) }
        let parts = [
            "[Content_Types].xml": contentTypes, "_rels/.rels": rels, "xl/workbook.xml": workbook,
            "xl/_rels/workbook.xml.rels": workbookRels, "xl/styles.xml": styles,
            "xl/worksheets/sheet1.xml": sheet(lines, subtitle: "\(Format.date(from, "d MMMM")) – \(Format.date(to, "d MMMM yyyy"))"),
        ]
        for (path, xml) in parts {
            let f = dir.appendingPathComponent(path)
            try fm.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            try xml.write(to: f, atomically: true, encoding: .utf8)
        }
        try? fm.removeItem(at: url)
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.arguments = ["-r", "-X", "-q", url.path, "."]
        zip.currentDirectoryURL = dir
        try zip.run(); zip.waitUntilExit()
        guard zip.terminationStatus == 0 else { throw NSError(domain: "zip", code: Int(zip.terminationStatus)) }
        Log.write("export", "xlsx \(lines.count) rows → \(url.lastPathComponent)")
    }

    // MARK: sheet
    private static func sheet(_ lines: [XlsxLine], subtitle: String) -> String {
        let epoch = Day.date("1899-12-30")
        var rows = ""
        for (i, l) in lines.enumerated() {
            let r = i + 5, s = i % 2 == 0 ? 5 : 9   // odd rows plain, even rows tinted; styles 5–8 / 9–12
            let d = Day.date(l.day)
            let serial = Calendar.current.dateComponents([.day], from: epoch, to: d).day ?? 0
            rows += """
            <row r="\(r)" ht="18" customHeight="1"><c r="A\(r)" s="\(s)"><v>\(serial)</v></c>\
            \(text("B\(r)", s + 1, Format.date(d, "EEE")))<c r="C\(r)" s="\(s + 2)"><v>\(String(format: "%.2f", l.hours))</v></c>\
            \(text("D\(r)", s + 3, l.project))\(text("E\(r)", s + 3, l.work))</row>
            """
        }
        let last = lines.count + 4, total = last + 1
        return """
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>\
        <dimension ref="A1:E\(total)"/><sheetViews><sheetView showGridLines="0" workbookViewId="0"><pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>\
        <sheetFormatPr defaultRowHeight="15"/><cols><col min="1" max="1" width="15" customWidth="1"/><col min="2" max="2" width="8" customWidth="1"/>\
        <col min="3" max="3" width="9" customWidth="1"/><col min="4" max="4" width="24" customWidth="1"/><col min="5" max="5" width="72" customWidth="1"/></cols><sheetData>\
        <row r="1" ht="30" customHeight="1">\(text("A1", 1, "Timesheet"))</row><row r="2">\(text("A2", 2, subtitle))</row>\
        <row r="4" ht="22" customHeight="1">\(text("A4", 3, "Date"))\(text("B4", 4, "Day"))\(text("C4", 4, "Hours"))\(text("D4", 3, "Project"))\(text("E4", 3, "Work performed"))</row>\
        \(rows)<row r="\(total)" ht="22" customHeight="1">\(text("A\(total)", 13, "Total"))<c r="B\(total)" s="13"/><c r="C\(total)" s="14"><f>SUM(C5:C\(last))</f><v>\(String(format: "%.2f", lines.reduce(0) { $0 + $1.hours }))</v></c><c r="D\(total)" s="13"/><c r="E\(total)" s="13"/></row>\
        </sheetData><pageMargins left="0.75" right="0.75" top="1" bottom="1" header="0.5" footer="0.5"/><pageSetup orientation="landscape" fitToHeight="0" fitToWidth="1"/></worksheet>
        """
    }

    private static func text(_ ref: String, _ style: Int, _ s: String) -> String {
        let e = s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        return "<c r=\"\(ref)\" s=\"\(style)\" t=\"inlineStr\"><is><t>\(e)</t></is></c>"
    }

    // MARK: package parts
    private static let contentTypes = """
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
    """
    private static let rels = """
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
    """
    private static let workbook = """
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Timesheet" sheetId="1" r:id="rId1"/></sheets></workbook>
    """
    private static let workbookRels = """
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
    """
    /// Fonts 1 title, 2 subtitle, 3 header, 4 body, 5 total. Fills 2 navy, 3 zebra, 4 total. Xfs: 1 title, 2 subtitle, 3/4 header
    /// left/center, 5–8 row (date, center, hours, text), 9–12 same tinted, 13/14 total text/hours.
    private static let styles = """
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="165" formatCode="d mmm yyyy"/><numFmt numFmtId="166" formatCode="0.0#"/></numFmts>\
    <fonts count="6"><font><name val="Calibri"/><sz val="11"/></font><font><name val="Arial"/><b val="1"/><color rgb="001F3864"/><sz val="20"/></font><font><name val="Arial"/><color rgb="00595959"/><sz val="11"/></font>\
    <font><name val="Arial"/><b val="1"/><color rgb="00FFFFFF"/></font><font><name val="Arial"/><sz val="10"/></font><font><name val="Arial"/><b val="1"/><color rgb="001F3864"/><sz val="11"/></font></fonts>\
    <fills count="5"><fill><patternFill/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="001F3864"/></patternFill></fill>\
    <fill><patternFill patternType="solid"><fgColor rgb="00F4F6FA"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="00E3E8F1"/></patternFill></fill></fills>\
    <borders count="3"><border><left/><right/><top/><bottom/><diagonal/></border><border><bottom style="thin"><color rgb="00D9DEE7"/></bottom></border><border><top style="medium"><color rgb="001F3864"/></top></border></borders>\
    <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="15"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0"/>\
    <xf numFmtId="0" fontId="3" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>\
    <xf numFmtId="0" fontId="3" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>\
    <xf numFmtId="165" fontId="4" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>\
    <xf numFmtId="0" fontId="4" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>\
    <xf numFmtId="166" fontId="4" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>\
    <xf numFmtId="0" fontId="4" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>\
    <xf numFmtId="165" fontId="4" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>\
    <xf numFmtId="0" fontId="4" fillId="3" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>\
    <xf numFmtId="166" fontId="4" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>\
    <xf numFmtId="0" fontId="4" fillId="3" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>\
    <xf numFmtId="0" fontId="5" fillId="4" borderId="2" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" indent="1"/></xf>\
    <xf numFmtId="166" fontId="5" fillId="4" borderId="2" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf></cellXfs>\
    <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
    """
}
