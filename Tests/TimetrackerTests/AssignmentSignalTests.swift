import Testing
@testable import Timetracker

@Test func projectNameMatchesTitleIgnoringSpacesAndPunctuationInsideIt() {
    let migration = Project(row: Row(values: ["id": Int64(7), "name": "h2prime-migration"]))
    #expect(migration.match(in: "H2 Prime - Migration, part 2") == "h2prime-migration")
    #expect(migration.match(in: "h2prime-migration plan") == "h2prime-migration")
    #expect(migration.match(in: "h2prime migrations") == nil)
    let workers = Project(row: Row(values: ["id": Int64(1), "name": "h2-workers", "keywords": "Worker database"]))
    #expect(workers.match(in: "Worker database - weekly") == "Worker database")
    #expect(workers.match(in: "H2 Prime - Migration") == nil)
}

@Test func firstPromptTitlesAreVagueAndRealLabelsAreNot() {
    for vague in ["hi", "Tutorial 5", "Attached PNG screenshot", "Mas taste skill?", "Branch management"] {
        #expect(Summarizer.isVague(vague), "\(vague)")
    }
    for label in ["Dependabot PRs review", "Open PR rebase", "Worker photo upload via Cloudflare"] {
        #expect(!Summarizer.isVague(label), "\(label)")
    }
}
