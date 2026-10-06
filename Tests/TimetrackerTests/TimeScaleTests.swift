import CoreGraphics
import Testing
@testable import Timetracker

@Test func timeScaleStretchesSoShortCardsEndAtTheirEndTimeAndNextStartsOnItsClock() {
    let scale = TimeScale(origin: 0, pxPerHour: 200, items: [(0, 60, 38, 0..<1), (120, 180, 38, 1..<2)])
    let a = scale.frames[0], b = scale.frames[1]
    #expect(abs(a.y + a.h + 4 - scale.y(60)) < 0.001)
    #expect(abs(b.y - scale.y(120)) < 0.001 && b.y > a.y + a.h)
    #expect(abs(b.y + b.h + 4 - scale.y(180)) < 0.001)
}

@Test func timeScaleStaysLinearWhenNothingOverlaps() {
    let scale = TimeScale(origin: 0, pxPerHour: 200, items: [(0, 3600, 38, 0..<1), (7200, 9000, 38, 0..<1)])
    #expect(scale.y(7200) == 400)
}

@Test func timeScaleKeepsOverlappingCardsOnTheirClockTime() {
    let items: [TimeScale.Item] = [(0, 600, 38, 0..<1), (60, 120, 38, 0..<1), (90, 1200, 38, 0..<1), (150, 200, 38, 0..<1), (180, 900, 38, 0..<1)]
    let scale = TimeScale(origin: 0, pxPerHour: 200, items: items)
    for (it, f) in zip(items, scale.frames) { #expect(abs(f.y - scale.y(it.start)) < 0.001) }
}

@Test func timeScaleCardGrowsOverStretchFromOtherColumnSoNoGapAppears() {
    let scale = TimeScale(origin: 0, pxPerHour: 200, items: [(0, 240, 38, 0..<1), (240, 1500, 38, 0..<1), (0, 60, 38, 1..<2), (120, 600, 38, 1..<2)])
    let a = scale.frames[0], b = scale.frames[1]
    #expect(abs(a.y + a.h + 4 - b.y) < 0.001)
}

@Test func packPutsOverlappingCardsSideBySideAndLaterOnesBelowTheWholeCluster() {
    let packed = TimeScale.pack([(0, 600), (60, 300), (300, 700), (2000, 2060)], minHeight: 38)
    #expect(packed.slots.map(\.lane) == [0, 1, 1, 0])
    #expect(packed.slots.map(\.lanes) == [2, 2, 2, 1])
    let scale = TimeScale(origin: 0, pxPerHour: 200, items: packed.items)
    let f = packed.slots.map { scale.frames[$0.item] }
    #expect(abs(f[1].y - scale.y(60)) < 0.001 && f[1].y < f[0].y + f[0].h)
    #expect(f[3].y >= max(f[0].y + f[0].h, f[2].y + f[2].h))
}
