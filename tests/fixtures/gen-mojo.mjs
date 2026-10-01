// Emit tests/mojo/fixtures.mojo — the JS oracle corpus, flattened into a form
// the Mojo parity harness can read without a JSON parser.
//
// Mojo 1.1.0 ships no std.json, and a recursive JSON DOM in Mojo fights the
// ownership rules. So the JSONL is flattened here, in JS, into one flat
// list of `dotted.path=lexeme` pairs per step. Nothing nests, so the Mojo
// side only needs to split on ';' and '='.
//
// Record shape, one per fixture step:
//
//   call | rng lexemes | arg pairs | return pairs | state pairs
//
// Pairs keep document order, which is load-bearing: the JS engine's
// `state.prices` and `state.inventory` are insertion-ordered objects, and
// Object.keys() order drives randomTradeableDrug() and the dogChase branch.
// The fixture runner's deepEqual is JSON.stringify, so order is compared too.
//
// The ignore-list below is CLOSED. Generation fails on any path that is not
// explicitly allowed, so a new field appearing in index.html's engine cannot
// silently slip past the Mojo port. The ignored paths are the JS-only
// artifacts the core deliberately does not produce: presentation `message`
// strings (docs/layer-boundaries.md forbids them in core) and fixture 08's
// JSON save string.
//
// Usage: node tests/fixtures/gen-mojo.mjs
// Verify:  task core:test:check-generated  (regeneration must be a no-op)
import { readFileSync, writeFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const FIXTURES = __dirname
const OUT = path.join(__dirname, '..', 'mojo', 'fixtures.mojo')

// Presentation strings and the JS-only save blob. Matched as a leaf name, at
// any depth, in any of the three pair groups.
const IGNORED_LEAVES = new Set(['message', 'json'])

// Every leaf path the oracle may produce, as a dotted path with the group
// prefix stripped ('ret.', 'state.', 'args.'). `'*'` matches one segment. A
// path that is not covered is a hard generation error, so a new field in
// index.html's engine cannot slip past the Mojo port unnoticed.
const ALLOWED = [
  // newGame / travel return values and state snapshots both carry these.
  'seed', 'day', 'numDays', 'cash', 'debt', 'bank', 'health', 'coatCapacity',
  'guns', 'location', 'dead', 'lastDayWarned', 'rngState',
  // ordered dicts, one leaf per traded / held drug
  'prices.*', 'prevPrices.*', 'inventory.*.qty', 'inventory.*.avgPrice',
  'priceEvents.*.type', 'priceEvents.*.drug',
  // trade / travel / finances / dealer / combat results
  'ok', 'reason', 'amount', 'pockets', 'escaped', 'hit',
  'damage', 'won', 'cop', 'deputies', 'canFight', 'score', 'dead', 'day',
  'attack', 'defend',
  // a call that returns a bare scalar (shouldStartChase -> bool,
  // applyDamage -> health) has no field name, so it lands under `.value`.
  'value',
  // arrival-event and price-event results
  'type', 'drug', 'qty',
  // bare-array returns (generatePrices -> [{type,drug,message}]) have no
  // enclosing field name, so their first segment is an array index.
  '*.type', '*.drug', '*.qty',
  // runner-helper results
  'drug', 'price', 'equal', 'scores',
  // dealer visit kind and offers
  'kind', 'offered', 'nameIndex',
  // high-score entries, in ranked order (fixture 07 checks top-10 truncation)
  'scores.*.name', 'scores.*.score', 'scores.*.day', 'scores.*.dead',
  'scores.*.date',
  // fixture arguments
  'seed', 'action', 'dest', 'isAggressor', 'offer', 'count', 'cash', 'debt',
  'bank', 'health', 'coatCapacity', 'guns', 'day', 'location', 'rng',
  'offer.*', 'chase.*', 'pockets', 'price', 'deputies', 'canFight', 'qty',
  'drug', 'amount',
  // an empty container argument (setField {inventory: {}}) emits a bare path
  'inventory', 'prices',
]

// setPrices and setInventory take a bare drug id as the key, so their argument
// keys are not enumerable ahead of time. Scoped to those two calls only —
// widening this to a global 'args.*' would make the whole table a no-op.
const ARG_KEY_IS_DRUG_ID = new Set(['setPrices', 'setInventory'])

function allowed(stripped, call, group) {
  if (group === 'args' && ARG_KEY_IS_DRUG_ID.has(call)) return true
  return ALLOWED.some((p) => {
    if (p === stripped) return true
    const a = p.split('.')
    const b = stripped.split('.')
    if (a.length !== b.length) return false
    return a.every((seg, i) => seg === '*' || seg === b[i])
  })
}

// A lexeme is a JSON scalar rendered as one structural-character-free token.
// The corpus's strings are drug ids, location ids, action names and JS failure
// reasons, none of which contain a structural character -- so rather than
// carrying an escape scheme through the Mojo reader, a violation fails
// generation loudly.
const STRUCTURAL = /[%;=|"\\]/

// Non-integer values are emitted as an IEEE-754 decomposition, `d:sign:exp:mant`,
// rather than as a decimal. A float64's shortest round-trip decimal can need 17
// significant digits, which overflows the 2^53 that Int64 mantissa arithmetic
// holds exactly -- 128.16666666666666 (a bank-interest product) is the one such
// value in the corpus, and no scale of a power-of-ten denominator reproduces it
// exactly. Decomposing into sign/exponent/mantissa and reassembling by scaling
// with powers of two is exact at every step, so the reader recovers the original
// float64 bit-for-bit using only integer arithmetic and exact float scaling.
function floatLexeme(v) {
  const buf = Buffer.alloc(8)
  buf.writeDoubleBE(v)
  const bits = buf.readBigUInt64BE()
  const sign = Number(bits >> 63n)
  const exponent = Number((bits >> 52n) & 0x7ffn)
  const mantissa = bits & 0xfffffffffffffn
  if (exponent === 0) {
    throw new Error(`${v} is zero or subnormal; the decomposition assumes a normal`)
  }
  return `d:${sign}:${exponent}:${mantissa}`
}

function lexeme(v) {
  if (v === null) return '-'
  if (v === true) return 't'
  if (v === false) return 'f'
  if (typeof v === 'number') {
    if (Number.isInteger(v)) return String(v)
    if (Math.abs(v) > Number.MAX_SAFE_INTEGER) {
      throw new Error(`${v} is not exactly representable as an integer`)
    }
    return floatLexeme(v)
  }
  if (typeof v === 'string') {
    if (STRUCTURAL.test(v)) {
      throw new Error(
        `string "${v}" contains a structural character in ${fixtureName}/${record.step}.\n` +
          'The flat format has no escape scheme; add one to gen-mojo.mjs and lexeme.mojo.'
      )
    }
    return v
  }
  throw new Error('lexeme() got a non-scalar: ' + JSON.stringify(v))
}

const pairs = []
function flatten(prefix, value) {
  if (Array.isArray(value)) {
    // An empty container emits a bare `path=` so the reader can tell "set this
    // to empty" from "this field was not mentioned". No string lexeme is ever
    // empty, so the empty value is unambiguous.
    if (value.length === 0) {
      pairs.push(`${prefix}=`)
      return
    }
    value.forEach((v, i) => flatten(`${prefix}.${i}`, v))
    return
  }
  if (value !== null && typeof value === 'object') {
    const entries = Object.entries(value)
    if (entries.length === 0) {
      pairs.push(`${prefix}=`)
      return
    }
    for (const [k, v] of entries) flatten(`${prefix}.${k}`, v)
    return
  }
  const stripped = prefix.slice(prefix.indexOf('.') + 1)
  const lastSegment = stripped.split('.').pop()
  if (IGNORED_LEAVES.has(lastSegment)) return
  const groupName = prefix.slice(0, prefix.indexOf('.'))
  if (!allowed(stripped, record.call, groupName)) {
    throw new Error(
      `unmapped oracle field "${prefix}" in ${fixtureName}/${record.step}/${record.call}.\n` +
        `Add it to ALLOWED (or IGNORED_LEAVES) in tests/fixtures/gen-mojo.mjs.`
    )
  }
  pairs.push(`${prefix}=${lexeme(value)}`)
}

let fixtureName = ''
let record = null
function group(prefix, value) {
  pairs.length = 0
  // A bare scalar return (shouldStartChase -> bool, applyDamage -> health) has
  // no field name to hang a path on, so it lands under `<group>.value`.
  if (value === null || typeof value !== 'object') {
    flatten(`${prefix}.value`, value)
    return pairs.join(';')
  }
  flatten(prefix, value)
  return pairs.join(';')
}

function encodeStep(fx, rec) {
  fixtureName = fx
  record = rec
  const call = rec.call
  // Scripted RNG floats go through the same encoder as every other number, so
  // the reader never has to parse a decimal. An absent `rng` is `-`; a present
  // but empty one is the empty string, which means "scripted with no draws" and
  // must not silently fall back to the seeded stream.
  const rng = rec.rng === undefined ? '-' : rec.rng.map(lexeme).join(',')
  const args = group('args', rec.args ?? {})
  const ret = group('ret', rec.expect.return)
  const state = group('state', rec.expect.state ?? {})
  // The fixture basename leads so a harness can replay one fixture at a time.
  return `${fx.replace(/\.jsonl$/, '')}|${call}|${rng}|${args}|${ret}|${state}`
}

function main() {
  const files = readdirSync(FIXTURES).filter((f) => f.endsWith('.jsonl')).sort()
  const lines = []
  for (const file of files) {
    const raw = readFileSync(path.join(FIXTURES, file), 'utf8').trim()
    for (const l of raw.split('\n').filter((x) => x.length > 0)) {
      lines.push(encodeStep(file, JSON.parse(l)))
    }
  }

  const header = `# tests/mojo/fixtures.mojo — GENERATED, do not edit.
#
# Source of truth is tests/fixtures/*.jsonl. Regenerate with
# \`node tests/fixtures/gen-mojo.mjs\`; \`task core:test:check-generated\` fails
# if this file is stale.
#
# One record per fixture step:
#   fixture | call | rng lexemes | arg pairs | return pairs | state pairs
# Pairs are \`dotted.path=lexeme\`, ';'-separated, in document order.
#
# Mojo 1.1.0 has no global variables, so the corpus is returned by a function.

def mjo_steps() -> List[String]:
    return [
`
  const body = lines.map((l) => `        "${escapeMojo(l)}",`).join('\n')
  writeFileSync(OUT, header + body + '\n    ]\n')
  const bytes = readFileSync(OUT).length
  console.log(`wrote ${OUT}: ${lines.length} steps, ${(bytes / 1024).toFixed(1)} KiB`)
}

// Mojo string literals. The flat format already excludes `"` and `\` from
// lexemes, so this is a guard rather than a real escape path.
function escapeMojo(s) {
  return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"')
}

main()
