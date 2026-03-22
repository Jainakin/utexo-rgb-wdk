#!/usr/bin/env node
/**
 * HRPC Schema Validation Tests
 *
 * Validates that:
 * 1. All HRPC method IDs are unique and sequential
 * 2. All RGB methods in hrpc.json have matching worklet handlers
 * 3. All worklet handlers have matching hrpc.json entries
 * 4. Request/response naming follows conventions
 * 5. All handler methods call actual wdk methods (not stubs)
 */

const fs = require('fs')
const path = require('path')

const HRPC_PATH = path.join(__dirname, '../app/node_modules/@tetherto/pear-wrk-wdk/spec/hrpc/hrpc.json')
const HRPC_DEV_PATH = path.join(__dirname, '../../pear-wrk-wdk/spec/hrpc/hrpc.json')
const WORKLET_PATH = path.join(__dirname, '../app/node_modules/@tetherto/pear-wrk-wdk/src/wdk-worklet.js')
const WORKLET_DEV_PATH = path.join(__dirname, '../../pear-wrk-wdk/src/wdk-worklet.js')

let hrpcPath = fs.existsSync(HRPC_PATH) ? HRPC_PATH : HRPC_DEV_PATH
let workletPath = fs.existsSync(WORKLET_PATH) ? WORKLET_PATH : WORKLET_DEV_PATH

let passed = 0
let failed = 0
let warnings = 0

function pass(msg) { console.log(`  \x1b[32m✓\x1b[0m ${msg}`); passed++ }
function fail(msg) { console.log(`  \x1b[31m✗\x1b[0m ${msg}`); failed++ }
function warn(msg) { console.log(`  \x1b[33m⚠\x1b[0m ${msg}`); warnings++ }
function section(msg) { console.log(`\n\x1b[1m${msg}\x1b[0m`) }

// ─── Load data ──────────────────────────────────────────────────────────
const hrpc = JSON.parse(fs.readFileSync(hrpcPath, 'utf8'))
const workletSrc = fs.readFileSync(workletPath, 'utf8')

const allMethods = hrpc.schema
const rgbMethods = allMethods.filter(m => m.name.includes('/rgb'))
const coreMethods = allMethods.filter(m => !m.name.includes('/rgb'))

// Extract handler registrations from worklet source
const handlerRegex = /rpc\.on(Rgb\w+)\(/g
const handlers = []
let match
while ((match = handlerRegex.exec(workletSrc)) !== null) {
  handlers.push(match[1]) // e.g., "RgbCreateUtxos"
}

// ─── Test 1: Method ID uniqueness ───────────────────────────────────────
section('1. Method ID uniqueness')

const ids = allMethods.map(m => m.id)
const uniqueIds = new Set(ids)
if (uniqueIds.size === ids.length) {
  pass(`All ${ids.length} method IDs are unique`)
} else {
  const dupes = ids.filter((id, i) => ids.indexOf(id) !== i)
  fail(`Duplicate IDs found: ${dupes.join(', ')}`)
}

// ─── Test 2: ID sequential check ───────────────────────────────────────
section('2. ID sequencing')

const sortedIds = [...ids].sort((a, b) => a - b)
const expectedMax = sortedIds[sortedIds.length - 1]
const missingIds = []
for (let i = 0; i <= expectedMax; i++) {
  if (!uniqueIds.has(i)) missingIds.push(i)
}
if (missingIds.length === 0) {
  pass(`IDs 0-${expectedMax} are sequential with no gaps`)
} else {
  warn(`Missing IDs in sequence: ${missingIds.join(', ')}`)
}

// ─── Test 3: Naming conventions ─────────────────────────────────────────
section('3. Request/response naming conventions')

let namingOk = true
for (const m of allMethods) {
  const shortName = m.name.replace('@wdk-core/', '')

  // Request name should be @wdk-core/{method}-request
  if (m.request && m.request.name !== `@wdk-core/${shortName}-request`) {
    fail(`Method "${m.name}" (ID ${m.id}): request name "${m.request.name}" doesn't follow convention`)
    namingOk = false
  }

  // Response name should be @wdk-core/{method}-response (if exists)
  if (m.response && m.response.name !== `@wdk-core/${shortName}-response`) {
    fail(`Method "${m.name}" (ID ${m.id}): response name "${m.response.name}" doesn't follow convention`)
    namingOk = false
  }
}
if (namingOk) {
  pass(`All ${allMethods.length} methods follow naming convention: @wdk-core/{method}-request/response`)
}

// ─── Test 4: RGB methods have responses ─────────────────────────────────
section('4. RGB methods have request+response pairs')

let responsesOk = true
for (const m of rgbMethods) {
  if (!m.response) {
    fail(`RGB method "${m.name}" (ID ${m.id}) has no response definition`)
    responsesOk = false
  }
  if (!m.request) {
    fail(`RGB method "${m.name}" (ID ${m.id}) has no request definition`)
    responsesOk = false
  }
}
if (responsesOk) {
  pass(`All ${rgbMethods.length} RGB methods have both request and response definitions`)
}

// ─── Test 5: Schema → Handler coverage ──────────────────────────────────
section('5. Schema → Handler coverage (every RGB schema entry has a worklet handler)')

// Convert schema name to handler name: @wdk-core/rgbCreateUtxos → RgbCreateUtxos
function schemaToHandler(schemaName) {
  const short = schemaName.replace('@wdk-core/', '')
  return short.charAt(0).toUpperCase() + short.slice(1)
}

let schemaCoverage = true
for (const m of rgbMethods) {
  const expected = schemaToHandler(m.name)
  if (handlers.includes(expected)) {
    pass(`${m.name} (ID ${m.id}) → rpc.on${expected}()`)
  } else {
    fail(`${m.name} (ID ${m.id}) → NO handler rpc.on${expected}() found in worklet`)
    schemaCoverage = false
  }
}

// ─── Test 6: Handler → Schema coverage ──────────────────────────────────
section('6. Handler → Schema coverage (every worklet handler has a schema entry)')

const rgbSchemaNames = new Set(rgbMethods.map(m => schemaToHandler(m.name)))
let handlerCoverage = true
for (const h of handlers) {
  if (rgbSchemaNames.has(h)) {
    // Already reported above
  } else {
    fail(`Handler rpc.on${h}() has no matching schema entry in hrpc.json`)
    handlerCoverage = false
  }
}
if (handlerCoverage) {
  pass(`All ${handlers.length} handlers have matching schema entries`)
}

// ─── Test 7: Version consistency ────────────────────────────────────────
section('7. Version consistency')

const v1Methods = allMethods.filter(m => m.version === 1)
const v2Methods = allMethods.filter(m => m.version === 2)
const v1Rgb = v1Methods.filter(m => m.name.includes('/rgb'))
const v2Core = v2Methods.filter(m => !m.name.includes('/rgb'))

pass(`${v1Methods.length} core methods at version 1, ${v2Methods.length} RGB methods at version 2`)
if (v1Rgb.length > 0) {
  warn(`${v1Rgb.length} RGB methods still at version 1: ${v1Rgb.map(m => m.name).join(', ')}`)
}
if (v2Core.length > 0) {
  warn(`${v2Core.length} core methods at version 2: ${v2Core.map(m => m.name).join(', ')}`)
}

// ─── Test 8: Check handler implementations for stubs ────────────────────
section('8. Handler implementation quality (checking for stubs/TODOs)')

const stubPatterns = [
  /throw new Error\(['"]not implemented/i,
  /throw new Error\(['"]TODO/i,
  /throw new Error\(['"]UTEXO Gateway not configured/i,
  /throw new Error\(['"]VSS not configured/i,
  /\/\/ TODO/,
  /\/\/ STUB/,
  /return \{\}.*\/\/ stub/i,
]

// Read each handler's body
const handlerBodies = {}
const handlerStartRegex = /rpc\.on(Rgb\w+)\(async\s+(?:payload|\(\))?\s*=>\s*\{/g
let hMatch
while ((hMatch = handlerStartRegex.exec(workletSrc)) !== null) {
  const name = hMatch[1]
  const startPos = hMatch.index + hMatch[0].length
  // Find the closing of this handler (next rpc.on or end)
  const nextHandler = workletSrc.indexOf('rpc.on', startPos)
  const body = workletSrc.substring(startPos, nextHandler > 0 ? nextHandler : startPos + 500)
  handlerBodies[name] = body
}

let stubCount = 0
for (const [name, body] of Object.entries(handlerBodies)) {
  for (const pattern of stubPatterns) {
    if (pattern.test(body)) {
      warn(`rpc.on${name}: contains stub/TODO pattern matching ${pattern}`)
      stubCount++
      break
    }
  }
}
if (stubCount === 0) {
  pass('No stub/TODO patterns found in any handler')
} else {
  warn(`${stubCount} handlers contain stub/TODO patterns`)
}

// ─── Test 9: Check for wdk method delegation ────────────────────────────
section('9. Handler delegation (handlers call wdk.rgb* methods)')

let delegationIssues = 0
for (const [name, body] of Object.entries(handlerBodies)) {
  const methodName = name.charAt(0).toLowerCase() + name.slice(1) // RgbCreateUtxos → rgbCreateUtxos
  const callsWdk = body.includes(`wdk.${methodName}`) ||
                   body.includes(`wdk.rgb`) ||
                   body.includes('await wdk.')
  if (!callsWdk) {
    warn(`rpc.on${name}: may not delegate to wdk.${methodName}() — check implementation`)
    delegationIssues++
  }
}
if (delegationIssues === 0) {
  pass(`All ${Object.keys(handlerBodies).length} handlers delegate to wdk methods`)
}

// ─── Summary ────────────────────────────────────────────────────────────
section('Summary')
console.log(`  Total methods in schema: ${allMethods.length} (${coreMethods.length} core + ${rgbMethods.length} RGB)`)
console.log(`  Worklet handlers found:  ${handlers.length}`)
console.log(`  ID range:                0-${expectedMax}`)
console.log()
console.log(`  \x1b[32m${passed} passed\x1b[0m, \x1b[31m${failed} failed\x1b[0m, \x1b[33m${warnings} warnings\x1b[0m`)
console.log()

process.exit(failed > 0 ? 1 : 0)
