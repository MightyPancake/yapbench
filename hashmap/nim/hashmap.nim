import std/strutils
import std/os

# splitmix64 (public domain, Vigna), same generator as the lcs/histogram
# benchmarks -- reused here as the hash function itself, not just for data
# generation.
proc splitmix64(xIn: uint64): uint64 =
    var x = xIn
    x = x + 0x9E3779B97F4A7C15'u64
    x = (x xor (x shr 30)) * 0xBF58476D1CE4E5B9'u64
    x = (x xor (x shr 27)) * 0x94D049BB133111EB'u64
    x = x xor (x shr 31)
    return x

type I64Arr = ptr UncheckedArray[int64]
type U64Arr = ptr UncheckedArray[uint64]

# Hand-rolled open addressing (linear probing) hash table, fixed capacity
# (no growth) sized upfront from n at a <=50% load factor -- see hashmap.c
# for the full rationale, identical across all 4 languages.
type Map = object
    keys: I64Arr
    values: U64Arr
    mask: int32

proc nextCap(n: int32): int32 =
    var cap: int32 = 16
    while cap < 2 * n:
        cap *= 2
    return cap

proc mapInit(m: var Map, n: int32) =
    let cap = nextCap(n)
    m.mask = cap - 1
    m.keys = cast[I64Arr](alloc(int(cap) * sizeof(int64)))
    m.values = cast[U64Arr](alloc(int(cap) * sizeof(uint64)))
    for i in 0 ..< cap:
        m.keys[i] = -1

proc mapInsert(m: var Map, key: int64, value: uint64) =
    var idx = int32(splitmix64(uint64(key)) and uint64(m.mask))
    while m.keys[idx] != -1:
        if m.keys[idx] == key:
            m.values[idx] = value
            return
        idx = (idx + 1) and m.mask
    m.keys[idx] = key
    m.values[idx] = value

proc mapLookup(m: Map, key: int64, outVal: var uint64): bool =
    var idx = int32(splitmix64(uint64(key)) and uint64(m.mask))
    while m.keys[idx] != -1:
        if m.keys[idx] == key:
            outVal = m.values[idx]
            return true
        idx = (idx + 1) and m.mask
    return false

proc mapFree(m: Map) =
    dealloc(m.keys)
    dealloc(m.values)

when isMainModule:
    if paramCount() < 1:
        stderr.writeLine("Usage: hashmap <n>")
        quit(1)
    let n = parseInt(paramStr(1)).int32

    if n <= 0:
        echo 0'u64
        quit(0)

    var m: Map
    mapInit(m, n)

    for i in 0 ..< n:
        mapInsert(m, int64(i), splitmix64(uint64(i + 1)))

    var sum: uint64 = 0
    for i in 0 ..< n:
        var val: uint64 = 0
        discard mapLookup(m, int64(i), val)
        sum += val * uint64(i + 1)

    var missCount: uint64 = 0
    for i in n ..< 2 * n:
        var val: uint64 = 0
        if not mapLookup(m, int64(i), val):
            missCount += 1

    sum += missCount * 1000000007'u64
    mapFree(m)
    echo sum
