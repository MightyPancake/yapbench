import std/strutils
import std/os

# splitmix64 (public domain, Vigna), same generator as the lcs benchmark,
# reduced mod 256 here for a full-byte-range (not small-alphabet)
# distribution.
proc splitmix64(xIn: uint64): uint64 =
    var x = xIn
    x = x + 0x9E3779B97F4A7C15'u64
    x = (x xor (x shr 30)) * 0xBF58476D1CE4E5B9'u64
    x = (x xor (x shr 27)) * 0x94D049BB133111EB'u64
    x = x xor (x shr 31)
    return x

type ByteArr = ptr UncheckedArray[uint8]
type CountArr = ptr UncheckedArray[uint64]

proc fill(buf: ByteArr, n: int32) =
    for i in 0 ..< n:
        let idx = uint64(i + 1)
        buf[i] = uint8(splitmix64(idx) mod 256)

proc histogram(buf: ByteArr, n: int32, counts: CountArr) =
    for b in 0 ..< 256:
        counts[b] = 0
    for i in 0 ..< n:
        let bucket = int(buf[i])
        counts[bucket] += 1

proc checksum(counts: CountArr): uint64 =
    var sum: uint64 = 0
    for b in 0 ..< 256:
        sum += counts[b] * uint64(b + 1)
    return sum

when isMainModule:
    if paramCount() < 1:
        stderr.writeLine("Usage: histogram <n>")
        quit(1)
    let n = parseInt(paramStr(1)).int32

    if n <= 0:
        echo 0'u64
        quit(0)

    let buf = cast[ByteArr](alloc(int(n)))
    let counts = cast[CountArr](alloc(256 * sizeof(uint64)))

    fill(buf, n)
    histogram(buf, n, counts)
    let result = checksum(counts)

    dealloc(buf)
    dealloc(counts)
    echo result
