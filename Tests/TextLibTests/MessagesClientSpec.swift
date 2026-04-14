// MessagesClientSpec.swift
//
// Tests for TextLib MessagesClient — AppleScript escaping and script generation.

import Quick
import Nimble
import Foundation
import TextLib

final class MessagesClientSpec: QuickSpec {
    override class func spec() {
        describe("appleScriptLiteral") {
            context("plain strings with no double quotes") {
                it("wraps the string in double quotes") {
                    expect(appleScriptLiteral("hello")) == "\"hello\""
                }

                it("handles an empty string") {
                    expect(appleScriptLiteral("")) == "\"\""
                }

                it("preserves spaces") {
                    expect(appleScriptLiteral("hello world")) == "\"hello world\""
                }

                it("preserves single quotes") {
                    expect(appleScriptLiteral("it's fine")) == "\"it's fine\""
                }

                it("preserves backslashes") {
                    expect(appleScriptLiteral("a\\b")) == "\"a\\b\""
                }

                it("preserves newlines") {
                    expect(appleScriptLiteral("line1\nline2")) == "\"line1\nline2\""
                }

                it("preserves tabs") {
                    expect(appleScriptLiteral("col1\tcol2")) == "\"col1\tcol2\""
                }
            }

            context("strings containing double quotes") {
                it("splits on double quote and joins with & quote &") {
                    expect(appleScriptLiteral("say \"hi\"")) == "\"say \" & quote & \"hi\" & quote & \"\""
                }

                it("handles a string that is only a double quote") {
                    expect(appleScriptLiteral("\"")) == "\"\" & quote & \"\""
                }

                it("handles a string that starts with a double quote") {
                    expect(appleScriptLiteral("\"hello")) == "\"\" & quote & \"hello\""
                }

                it("handles a string that ends with a double quote") {
                    expect(appleScriptLiteral("hello\"")) == "\"hello\" & quote & \"\""
                }

                it("handles multiple consecutive double quotes") {
                    expect(appleScriptLiteral("\"\"")) == "\"\" & quote & \"\" & quote & \"\""
                }

                it("handles multiple separated double quotes") {
                    expect(appleScriptLiteral("a\"b\"c")) == "\"a\" & quote & \"b\" & quote & \"c\""
                }
            }

            context("injection-relevant inputs") {
                it("does not allow AppleScript keywords to break out of the literal") {
                    // A crafted message with a double quote cannot escape into AppleScript syntax
                    let result = appleScriptLiteral("\" & do shell script \"rm -rf /\"")
                    // Must not contain unquoted AppleScript command text
                    expect(result).to(beginWith("\"\""))
                    expect(result).to(contain("& quote &"))
                }

                it("handles a message with only AppleScript-significant characters") {
                    // Backslash, newline, and single quotes are safe inside AppleScript strings
                    let result = appleScriptLiteral("\\ \n '")
                    expect(result) == "\"\\ \n '\""
                }
            }
        }

        describe("buildScript") {
            it("produces a tell-send-end tell structure") {
                let script = buildScript(recipient: "+15551234567", message: "hello")
                expect(script).to(contain("tell application \"Messages\""))
                expect(script).to(contain("end tell"))
            }

            it("includes the escaped message") {
                let script = buildScript(recipient: "+15551234567", message: "hello")
                expect(script).to(contain("\"hello\""))
            }

            it("includes the escaped recipient") {
                let script = buildScript(recipient: "+15551234567", message: "hello")
                expect(script).to(contain("\"+15551234567\""))
            }

            it("uses send ... to buddy syntax") {
                let script = buildScript(recipient: "+15551234567", message: "hello")
                expect(script).to(contain("send"))
                expect(script).to(contain("to buddy"))
            }

            it("escapes double quotes in the message") {
                let script = buildScript(recipient: "a@b.com", message: "say \"hi\"")
                expect(script).to(contain("& quote &"))
                expect(script).notTo(contain("say \"hi\""))
            }

            it("escapes double quotes in the recipient") {
                // Unusual but safe — the function escapes both arguments
                let script = buildScript(recipient: "weird\"addr", message: "hi")
                expect(script).to(contain("& quote &"))
            }
        }
    }
}
