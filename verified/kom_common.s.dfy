include "ARMdef.s.dfy"
include "sha/sha256.s.dfy" // for K_SHA256

const KOM_MAGIC:int := 0x4b6d646f;

//-----------------------------------------------------------------------------
// SMC/SVC Call Numbers
//-----------------------------------------------------------------------------
const KOM_SMC_QUERY:int             := 1;
const KOM_SMC_GETPHYSPAGES:int      := 2;
const KOM_SMC_INIT_ADDRSPACE:int    := 10;
const KOM_SMC_INIT_DISPATCHER:int   := 11;
const KOM_SMC_INIT_L2PTABLE:int     := 12;
const KOM_SMC_MAP_SECURE:int        := 13;
const KOM_SMC_MAP_INSECURE:int      := 14;
const KOM_SMC_ALLOC_SPARE:int       := 15;
const KOM_SMC_REMOVE:int            := 20;
const KOM_SMC_FINALISE:int          := 21;
const KOM_SMC_ENTER:int             := 22;
const KOM_SMC_RESUME:int            := 23;
const KOM_SMC_STOP:int              := 29;

const KOM_SVC_EXIT:int              := 0;
const KOM_SVC_ATTEST:int            := 1;
const KOM_SVC_VERIFY_STEP0:int      := 2;
const KOM_SVC_VERIFY_STEP1:int      := 3;
const KOM_SVC_VERIFY_STEP2:int      := 4;
const KOM_SVC_MAP_DATA:int          := 10;
const KOM_SVC_UNMAP_DATA:int        := 11;
const KOM_SVC_INIT_L2PTABLE:int     := 12;
const KOM_SVC_GET_RANDOM:int        := 20;

//-----------------------------------------------------------------------------
// Errors
//-----------------------------------------------------------------------------
const KOM_ERR_SUCCESS:int           := 0;
const KOM_ERR_INVALID_PAGENO:int    := 1;
const KOM_ERR_PAGEINUSE:int         := 2;
const KOM_ERR_INVALID_ADDRSPACE:int := 3;
const KOM_ERR_ALREADY_FINAL:int     := 4;
const KOM_ERR_NOT_FINAL:int         := 5;
const KOM_ERR_INVALID_MAPPING:int   := 6;
const KOM_ERR_ADDRINUSE:int         := 7;
const KOM_ERR_NOT_STOPPED:int       := 8;
const KOM_ERR_INTERRUPTED:int       := 9;
const KOM_ERR_FAULT:int             := 10;
const KOM_ERR_ALREADY_ENTERED:int   := 11;
const KOM_ERR_NOT_ENTERED:int       := 12;
const KOM_ERR_STOPPED:int           := 13;
const KOM_ERR_INVALID:int           := 0xffffffff;

//-----------------------------------------------------------------------------
// Memory Regions
//-----------------------------------------------------------------------------
const KOM_MON_VBASE:addr := 0x4000_0000;
const KOM_DIRECTMAP_VBASE:addr := 0x8000_0000;
const KOM_DIRECTMAP_SIZE:word := 0x8000_0000;
const KOM_SECURE_RESERVE:addr := 0x100000; // 1MB
const KOM_SECURE_NPAGES:word := 256; // KOM_SECURE_RESERVE / PAGESIZE

// we don't support/consider more than 1GB of physical memory in our maps
const KOM_PHYSMEM_LIMIT:addr := 0x4000_0000;

const KOM_STACK_SIZE:addr := 0x4000;

// we don't know where the stack is exactly, but we know how big it is
function {:axiom} StackLimit():addr
    ensures KOM_MON_VBASE <= StackLimit()
    ensures StackLimit() <= KOM_DIRECTMAP_VBASE - KOM_STACK_SIZE

function StackBase():addr
{
    reveal WordAligned(); StackLimit() + KOM_STACK_SIZE
}

predicate address_is_secure(m:addr)
{
    (KOM_DIRECTMAP_VBASE + SecurePhysBase()) <= m <
        (KOM_DIRECTMAP_VBASE + SecurePhysBase() + KOM_SECURE_RESERVE)
}

//-----------------------------------------------------------------------------
//  Memory Mapping Config Args
//-----------------------------------------------------------------------------
const KOM_MAPPING_R:int := 1;
const KOM_MAPPING_W:int := 2;
const KOM_MAPPING_X:int := 4;

//-----------------------------------------------------------------------------
// Globals
//-----------------------------------------------------------------------------

const PAGEDB_ENTRY_SIZE:int := 2 * WORDSIZE;
const G_PAGEDB_SIZE:int := KOM_SECURE_NPAGES * PAGEDB_ENTRY_SIZE;

function method {:opaque} PageDb(): symbol { "g_pagedb" }
function method {:opaque} MonitorPhysBaseOp(): symbol {"g_monitor_physbase" }
function method {:opaque} SecurePhysBaseOp(): symbol {"g_secure_physbase" }
function method {:opaque} CurDispatcherOp(): symbol { "g_cur_dispatcher" }
function method {:opaque} PendingInterruptOp(): symbol { "g_pending_interrupt" }
function method {:opaque} K_SHA256s(): symbol { "g_k_sha256" }
function method {:opaque} AttestKeyOp(): symbol { "g_attestkey" }
function method {:opaque} RngBaseOp(): symbol { "g_rngbase" }

// XXX: workaround so dafny sees that these are distinct, despite the opaques
predicate DistinctGlobals()
{
    PageDb() != MonitorPhysBaseOp()
    && PageDb() != SecurePhysBaseOp()
    && PageDb() != CurDispatcherOp()
    && PageDb() != PendingInterruptOp()
    && PageDb() != K_SHA256s()
    && PageDb() != AttestKeyOp()
    && PageDb() != RngBaseOp()
    && MonitorPhysBaseOp() != SecurePhysBaseOp()
    && MonitorPhysBaseOp() != CurDispatcherOp()
    && MonitorPhysBaseOp() != PendingInterruptOp()
    && MonitorPhysBaseOp() != K_SHA256s()
    && MonitorPhysBaseOp() != AttestKeyOp()
    && MonitorPhysBaseOp() != RngBaseOp()
    && SecurePhysBaseOp() != CurDispatcherOp()
    && SecurePhysBaseOp() != PendingInterruptOp()
    && SecurePhysBaseOp() != K_SHA256s()
    && SecurePhysBaseOp() != AttestKeyOp()
    && SecurePhysBaseOp() != RngBaseOp()
    && CurDispatcherOp() != PendingInterruptOp()
    && CurDispatcherOp() != K_SHA256s()
    && CurDispatcherOp() != AttestKeyOp()
    && CurDispatcherOp() != RngBaseOp()
    && PendingInterruptOp() != K_SHA256s()
    && PendingInterruptOp() != AttestKeyOp()
    && PendingInterruptOp() != RngBaseOp()
    && K_SHA256s() != AttestKeyOp()
    && K_SHA256s() != RngBaseOp()
    && AttestKeyOp() != RngBaseOp()
}

lemma lemma_DistinctGlobals()
    ensures DistinctGlobals()
{
    reveal PageDb();
    reveal MonitorPhysBaseOp();
    reveal SecurePhysBaseOp();
    reveal CurDispatcherOp();
    reveal PendingInterruptOp();
    reveal K_SHA256s();
    reveal AttestKeyOp();
    reveal RngBaseOp();
}

// the phys bases are unknown, but never change

// monitor phys base: phys base of monitor's own allocation
function {:axiom} MonitorPhysBase(): addr
    ensures 0 < MonitorPhysBase() <= SecurePhysBase()
    ensures PageAligned(MonitorPhysBase())

// secure phys base: phys addr of alloc'able secure pages
function {:axiom} SecurePhysBase(): addr
    ensures 0 < SecurePhysBase() <= KOM_PHYSMEM_LIMIT - KOM_SECURE_RESERVE
    ensures PageAligned(SecurePhysBase())

function {:axiom} AttestKey(): seq<word>
    ensures |AttestKey()| == 8

const K_SHA256_WORDS:int := 64;

function method KomGlobalDecls(): globaldecls
    ensures ValidGlobalDecls(KomGlobalDecls());
{
    map[PageDb() := G_PAGEDB_SIZE,
        MonitorPhysBaseOp() := WORDSIZE,
        SecurePhysBaseOp() := WORDSIZE,
        CurDispatcherOp() := WORDSIZE,
        PendingInterruptOp() := WORDSIZE,
        K_SHA256s() := K_SHA256_WORDS * WORDSIZE,
        AttestKeyOp() := 8*WORDSIZE,
        RngBaseOp() := WORDSIZE
        ]
}

//-----------------------------------------------------------------------------
// Application-level state invariants
//
// These are part of the spec, since we rely on the bootloader setting
// up our execution environment so they are ensured on SMC handler entry.
//-----------------------------------------------------------------------------

predicate SaneStackPointer(sp:word)
{
    WordAligned(sp) && StackLimit() < sp <= StackBase()
}

predicate SaneStack(s:state)
    requires ValidState(s)
{
    reveal ValidRegState();
    var sp := s.regs[SP(Monitor)];
    SaneStackPointer(sp)
}

predicate SaneMem(s:memstate)
{
    SaneConstants() && ValidMemState(s)
    // globals are as we expect
    && GlobalFullContents(s, MonitorPhysBaseOp()) == [MonitorPhysBase()]
    && GlobalFullContents(s, SecurePhysBaseOp()) == [SecurePhysBase()]
    && GlobalFullContents(s, AttestKeyOp()) == AttestKey()
    && GlobalFullContents(s, RngBaseOp()) == [RngBase()]
    // SHA const table is valid
    && forall j :: 0 <= j < K_SHA256_WORDS
        ==> GlobalWord(s, K_SHA256s(), WordsToBytes(j)) == K_SHA256(j)
    // extra-tight requirement for SHA spec to avoid wraparound
    && AddressOfGlobal(K_SHA256s()) + SizeOfGlobal(K_SHA256s()) < UINT32_LIM
}

predicate SaneConstants()
    ensures DistinctGlobals()
{
    lemma_DistinctGlobals();
    PhysBase() == KOM_DIRECTMAP_VBASE
    // stack
    && ValidMemRange(StackLimit(), StackBase())
    // insecure phys mapping (read-only)
    && ValidMemRangeForRead(KOM_DIRECTMAP_VBASE,
                           KOM_DIRECTMAP_VBASE + MonitorPhysBase())
    // secure phys mapping
    && ValidMemRange(KOM_DIRECTMAP_VBASE + SecurePhysBase(),
                    KOM_DIRECTMAP_VBASE + SecurePhysBase() + KOM_SECURE_RESERVE)
    // globals are as we expect
    && KomGlobalDecls() == TheGlobalDecls()
    && (forall a:addr :: address_is_secure(a) <==> addrIsSecure(a))
}

predicate SaneState(s:state)
{
    SaneConstants()
    && ValidState(s) && s.ok
    && SaneStack(s)
    && SaneMem(s.m)
    && mode_of_state(s) == Monitor
    && !interrupts_enabled(s)
}


//-----------------------------------------------------------------------------
// Stack/procedure invariants
//-----------------------------------------------------------------------------
predicate InsecureMemInvariant(s:state, r:state)
    requires ValidState(s) && ValidState(r)
{
    ValidMemRangeForRead(KOM_DIRECTMAP_VBASE, KOM_DIRECTMAP_VBASE + MonitorPhysBase())
    && forall m:addr :: KOM_DIRECTMAP_VBASE <= m < KOM_DIRECTMAP_VBASE + MonitorPhysBase()
        ==> MemContents(s.m, m) == MemContents(r.m, m)
}
