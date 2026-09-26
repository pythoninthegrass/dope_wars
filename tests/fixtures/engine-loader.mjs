// Shared engine loader for fixture generation and replay. Extracts the
// <script id="engine"> block from index.html and evaluates it in a fresh
// node:vm context so the fixtures exercise the exact code that ships in the
// single-file prototype.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import vm from 'node:vm'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const INDEX_HTML = path.join(__dirname, '..', '..', 'index.html')

export function loadEngine() {
  const html = readFileSync(INDEX_HTML, 'utf8')
  const m = html.match(/<script id="engine">([\s\S]*?)<\/script>/)
  if (!m) throw new Error('could not find <script id="engine"> in index.html')
  const context = { console }
  context.window = context
  vm.createContext(context)
  vm.runInContext(m[1], context, { filename: 'engine.js' })
  return context.DopeWarsEngine
}

// A scripted RNG that draws from a fixed list of floats. Used for fixtures
// that need to force specific arrival-event / combat branches. Throws if the
// script under-provisions calls, so shortfalls surface immediately instead
// of silently returning undefined.
export function scriptedRng(floats) {
  let i = 0
  return () => {
    if (i >= floats.length) {
      throw new Error(`scriptedRng exhausted after ${floats.length} calls`)
    }
    return floats[i++]
  }
}

// Snapshot the serializable subset of engine state. Strips `rng` (a closure)
// and instead records its integer internal state, matching what
// serializeState() does on save. Any implementation replaying a fixture can
// reconstruct the same RNG by seeding mulberry32 and calling setState.
export function snapshotState(state) {
  const obj = {}
  for (const k of Object.keys(state)) {
    if (k === 'rng') continue
    obj[k] = state[k]
  }
  if (state.rng && typeof state.rng.getState === 'function') {
    obj.rngState = state.rng.getState()
  }
  return JSON.parse(JSON.stringify(obj))
}
