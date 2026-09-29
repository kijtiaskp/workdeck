import { createServer } from 'node:http'
import { readFile, mkdir, rm } from 'node:fs/promises'
import { extname, join, normalize } from 'node:path'
import { fileURLToPath } from 'node:url'
import puppeteer from 'puppeteer-core'

const ROOT = fileURLToPath(new URL('.', import.meta.url))
const FPS = 30
const CHROME_PATH = process.env.CHROME_PATH ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const CONTENT_TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' }

const stillTimes = process.argv.slice(2).map(Number).filter((value) => !Number.isNaN(value))
const outputDirectory = join(ROOT, stillTimes.length ? 'out/stills' : 'frames')

const server = createServer(async (request, response) => {
  const requestedPath = normalize(decodeURIComponent(new URL(request.url, 'http://localhost').pathname))
  const path = requestedPath === '/' ? '/index.html' : requestedPath
  try {
    const body = await readFile(join(ROOT, path))
    response.writeHead(200, { 'Content-Type': CONTENT_TYPES[extname(path)] ?? 'application/octet-stream' })
    response.end(body)
  } catch {
    response.writeHead(404)
    response.end()
  }
})
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
const { port } = server.address()

const browser = await puppeteer.launch({
  executablePath: CHROME_PATH,
  headless: true,
  args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--hide-scrollbars'],
})

try {
  const page = await browser.newPage()
  page.on('pageerror', (error) => console.error('page error:', error.message))
  page.on('console', (message) => { if (message.type() === 'error') console.error('console:', message.text()) })
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 })
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'load' })
  await page.waitForFunction(() => window.sceneReady === true, { timeout: 30000 })

  if (!stillTimes.length) await rm(outputDirectory, { recursive: true, force: true })
  await mkdir(outputDirectory, { recursive: true })

  const duration = await page.evaluate(() => window.videoDuration)
  const times = stillTimes.length ? stillTimes : Array.from({ length: Math.round(duration * FPS) }, (_, frame) => frame / FPS)

  const startedAt = Date.now()
  for (const [index, time] of times.entries()) {
    await page.evaluate((value) => window.renderFrame(value), time)
    const name = stillTimes.length ? `t${time.toFixed(2)}.jpg` : `frame-${String(index).padStart(5, '0')}.jpg`
    await page.screenshot({ path: join(outputDirectory, name), type: 'jpeg', quality: 94 })
    if (!stillTimes.length && index % 150 === 0) {
      console.log(`frame ${index}/${times.length} (${((Date.now() - startedAt) / 1000).toFixed(0)}s)`)
    }
  }
  console.log(`rendered ${times.length} frame(s) to ${outputDirectory}`)
} finally {
  await browser.close()
  server.close()
}
