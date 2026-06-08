import Foundation

enum AmountError: Error {
    case invalidFormat(String)
}

/// 사람이 읽는 십진 표기("0.1") → base units decimal string. 임의 정밀도 (BigInt 미사용).
func toBaseUnits(_ humanAmount: String, decimals: Int) throws -> String {
    let s = humanAmount.trimmingCharacters(in: .whitespaces)
    guard !s.isEmpty else { throw AmountError.invalidFormat("amount 가 비어 있습니다") }
    let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
    let whole = parts.first ?? "0"
    let frac = parts.count > 1 ? parts[1] : ""

    guard whole.allSatisfy({ $0.isASCII && $0.isNumber }),
          frac.allSatisfy({ $0.isASCII && $0.isNumber }) else {
        throw AmountError.invalidFormat("숫자가 아닌 문자 포함: \(s)")
    }

    let fracPadded = String((frac + String(repeating: "0", count: max(0, decimals))).prefix(decimals))
    let combined = whole + fracPadded
    let trimmed = combined.drop(while: { $0 == "0" })
    return trimmed.isEmpty ? "0" : String(trimmed)
}

/// base units decimal string → 사람이 읽는 십진 표기. trailing 0 제거.
func fromBaseUnits(_ amount: String, decimals: Int) -> String {
    guard decimals > 0 else { return amount }
    let digits = amount.allSatisfy({ $0.isNumber }) ? amount : amount.filter { $0.isNumber }
    let padded = String(repeating: "0", count: max(0, decimals + 1 - digits.count)) + digits
    let whole = String(padded.dropLast(decimals))
    let fracRaw = String(padded.suffix(decimals))
    let frac = String(fracRaw.reversed().drop(while: { $0 == "0" }).reversed())
    return frac.isEmpty ? whole : "\(whole).\(frac)"
}

/// hex 문자열 ("0x..." or "...") → decimal string. 임의 정밀도.
func hexToDecimalString(_ hex: String) -> String {
    var clean = hex
    if clean.hasPrefix("0x") || clean.hasPrefix("0X") { clean = String(clean.dropFirst(2)) }
    if clean.isEmpty { return "0" }

    var digits: [UInt8] = [0]
    for ch in clean {
        guard let nibble = ch.hexDigitValue else { continue }
        var carry = nibble
        for i in 0..<digits.count {
            let v = Int(digits[i]) * 16 + carry
            digits[i] = UInt8(v % 10)
            carry = v / 10
        }
        while carry > 0 {
            digits.append(UInt8(carry % 10))
            carry /= 10
        }
    }
    return String(digits.reversed().map { Character(String($0)) })
}
