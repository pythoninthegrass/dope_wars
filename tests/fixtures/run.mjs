// Fixture runner. Replays every .jsonl fixture under tests/fixtures/ through
// a freshly loaded engine and deep-equals each step's return value and
// post-call state snapshot against the recorded oracle. Exits non-zero on
// any mismatch, so this doubles as the CI gate for engine parity.
//
// Usage:
//   node tests/fixtures/run.mjs           # run all fixtures
//   node tests/fixtures/run.mjs 04 05     # run only fixtures whose basename matches any arg
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { loadEngine, snapshotState } from './engine-loader.mjs'
import { makeRunStep } from './run-step.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const Engine = loadEngine()
const runStep = makeRunStep(Engine)

function deepEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b)
}

function diffPreview(actual, expected) {
  const aStr = JSON.stringify(actual)
  const eStr = JSON.stringify(expected)
  const max = 400
  return `  actual  : ${aStr.length > max ? aStr.slice(0, max) + '…' : aStr}\n  expected: ${eStr.length > max ? eStr.slice(0, max) + '…' : eStr}`
}

function replay(fixturePath) {
  const raw = readFileSync(fixturePath, 'utf8').trim()
  const lines = raw.split('\n').filter((l) => l.length > 0)
  const failures = []
  let state = null
  for (const line of lines) {
    const record = JSON.parse(line)
    const step = { call: record.call, args: record.args, rng: record.rng }
    let ret
    try {
      ret = runStep(state, step)
    } catch (err) {
      failures.push({ step: record.step, call: record.call, error: err.message })
      break
    }
    if (record.call === 'newGame') state = ret
    const actualReturn = JSON.parse(JSON.stringify(ret))
    if (!deepEqual(actualReturn, record.expect.return)) {
      failures.push({
        step: record.step,
        call: record.call,
        kind: 'return',
        detail: diffPreview(actualReturn, record.expect.return),
      })
    }
    const actualState = state ? snapshotState(state) : null
    if (!deepEqual(actualState, record.expect.state)) {
      failures.push({
        step: record.step,
        call: record.call,
        kind: 'state',
        detail: diffPreview(actualState, record.expect.state),
      })
    }
  }
  return { steps: lines.length, failures }
}

function main() {
  const filters = process.argv.slice(2)
  const files = readdirSync(__dirname)
    .filter((f) => f.endsWith('.jsonl'))
    .filter((f) => filters.length === 0 || filters.some((q) => f.includes(q)))
    .sort()

  if (files.length === 0) {
    console.error('no fixtures matched')
    process.exit(1)
  }

  let totalFailures = 0
  for (const file of files) {
    const result = replay(path.join(__dirname, file))
    const status = result.failures.length === 0 ? 'OK' : 'FAIL'
    console.log(`${status}  ${file}  (${result.steps} steps, ${result.failures.length} failure(s))`)
    for (const f of result.failures) {
      console.log(`  step ${f.step} ${f.call} ${f.kind || 'error'}`)
      if (f.detail) console.log(f.detail)
      if (f.error) console.log(`  error: ${f.error}`)
    }
    totalFailures += result.failures.length
  }
  process.exit(totalFailures === 0 ? 0 : 1)
}

main()
