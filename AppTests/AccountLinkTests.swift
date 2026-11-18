import Foundation
import Testing
@testable import trAIning

@Suite struct AccountLinkTests {
    @Test func parsesTheThreeEmailLinks() {
        #expect(AccountLink(url: URL(string: "training://convite?c=abc")!) == .invite("abc"))
        #expect(AccountLink(url: URL(string: "training://confirmar?token=t1")!) == .verify("t1"))
        #expect(AccountLink(url: URL(string: "training://redefinir-senha?token=t2")!) == .reset("t2"))
    }

    @Test func ignoresOtherLinks() {
        #expect(AccountLink(url: URL(string: "training://hoje/prontidao")!) == nil)
        #expect(AccountLink(url: URL(string: "training://convite")!) == nil)
        #expect(AccountLink(url: URL(string: "training://confirmar?token=")!) == nil)
        #expect(AccountLink(url: URL(string: "https://training.aglv.dev/convite?c=abc")!) == nil)
    }

    @Test func passwordRuleChecksLengthThenConfirmation() {
        #expect(AccountPasswordRule.problem(password: "curta", confirmation: "curta") == AccountConstants.shortPassword)
        #expect(AccountPasswordRule.problem(password: "senha-longa-1", confirmation: "senha-longa-2") == AccountConstants.mismatch)
        #expect(AccountPasswordRule.problem(password: "senha-longa-1", confirmation: "senha-longa-1") == nil)
    }
}
