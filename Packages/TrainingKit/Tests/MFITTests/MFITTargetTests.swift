import Testing
@testable import MFIT

@Suite struct MFITTargetTests {
    @Test func readsRepsAndSecondsFromTheTeacherText() {
        #expect(MFITParser.target(in: "3 séries de 12 repetições cada perna") == (12, nil))
        #expect(MFITParser.target(in: "4 séries de 8 a 10 reps") == (10, nil))
        #expect(MFITParser.target(in: "3 séries de 45 segundos") == (nil, 45))
        #expect(MFITParser.target(in: "até a falha") == (nil, nil))
    }
}
