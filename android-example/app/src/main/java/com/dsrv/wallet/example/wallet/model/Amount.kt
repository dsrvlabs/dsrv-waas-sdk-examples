package com.dsrv.wallet.example.wallet.model

import java.math.BigInteger

/**
 * 사람이 읽는 십진 표기(예: "0.1") → ERC-20 base units BigInteger.
 *
 * USDC 는 6 decimals 이므로 toBaseUnits("0.1", 6) == 100000.
 */
fun toBaseUnits(humanAmount: String, decimals: Int): BigInteger {
    val s = humanAmount.trim()
    require(s.isNotEmpty()) { "amount 가 비어 있습니다" }
    val (whole, frac) = if ("." in s) s.split(".", limit = 2) else listOf(s, "")
    val fracPadded = frac.padEnd(decimals, '0').take(decimals)
    return BigInteger((whole + fracPadded).ifEmpty { "0" })
}

/**
 * base units BigInteger → 사람이 읽는 십진 표기. 뒤쪽 0 은 trim, 정수면 "." 도 제거.
 *
 * fromBaseUnits(BigInteger("100000"), 6) == "0.1"
 * fromBaseUnits(BigInteger("1000000"), 6) == "1"
 */
fun fromBaseUnits(amount: BigInteger, decimals: Int): String {
    if (decimals <= 0) return amount.toString()
    val s = amount.toString().padStart(decimals + 1, '0')
    val whole = s.dropLast(decimals)
    val frac = s.takeLast(decimals).trimEnd('0')
    return if (frac.isEmpty()) whole else "$whole.$frac"
}
