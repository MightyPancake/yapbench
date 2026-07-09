import std/strutils
import std/os
import std/tables

# Hash table insert/lookup throughput, integer-keyed -- "idiomatic
# generic-container" tier (see ../../hashmap/ for the hand-rolled
# fixed-capacity tier this pairs with). Uses std/tables.Table[K, V] out
# of the box, no initTable(initialSize=...) hint -- the plain first-cut
# usage any Nim tutorial shows, matching yap's modules/hashmap sibling
# (../../hashmap_stdlib/yap/), which has no capacity-hint API at all.
proc splitmix64(xIn: uint64): uint64 =
    var x = xIn
    x = x + 0x9E3779B97F4A7C15'u64
    x = (x xor (x shr 30)) * 0xBF58476D1CE4E5B9'u64
    x = (x xor (x shr 27)) * 0x94D049BB133111EB'u64
    x = x xor (x shr 31)
    return x

when isMainModule:
    if paramCount() < 1:
        stderr.writeLine("Usage: hashmap_stdlib <n>")
        quit(1)
    let n = parseInt(paramStr(1)).int32

    if n <= 0:
        echo 0'u64
        quit(0)

    var t = initTable[int64, uint64]()

    for i in 0 ..< n:
        t[int64(i)] = splitmix64(uint64(i + 1))

    var sum: uint64 = 0
    for i in 0 ..< n:
        sum += t.getOrDefault(int64(i), 0'u64) * uint64(i + 1)

    var missCount: uint64 = 0
    for i in n ..< 2 * n:
        if not t.hasKey(int64(i)):
            missCount += 1

    sum += missCount * 1000000007'u64
    echo sum
