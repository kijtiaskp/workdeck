import * as THREE from 'three'
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js'
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js'
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js'
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js'
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js'
import { gsap } from 'gsap'

const WIDTH = 1920
const HEIGHT = 1080
export const DURATION = 48

const COLORS = {
  surface: '#1c1c21',
  surfaceRaised: '#26262c',
  border: '#2e2e35',
  text: '#f5f5f7',
  muted: '#a1a1a6',
  accent: '#2997ff',
  green: '#30d158',
  orange: '#ff9f0a',
  red: '#ff453a',
  blue: '#0a84ff',
}

const FONT = '-apple-system, "SF Pro Text", system-ui, sans-serif'
const MONO = '"SF Mono", ui-monospace, Menlo, monospace'

// ---------------------------------------------------------------------------
// Renderer, camera, post-processing
// ---------------------------------------------------------------------------

const canvas = document.getElementById('stage')
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true })
renderer.setPixelRatio(1)
renderer.setSize(WIDTH, HEIGHT, false)
renderer.toneMapping = THREE.ACESFilmicToneMapping
renderer.toneMappingExposure = 1.05

const scene = new THREE.Scene()
const camera = new THREE.PerspectiveCamera(32, WIDTH / HEIGHT, 0.1, 100)
const cameraTarget = new THREE.Vector3()
const cameraRig = { x: 0, y: 0.2, z: 11, tx: 0, ty: 0, tz: 0, roll: 0 }

const composer = new EffectComposer(renderer)
composer.addPass(new RenderPass(scene, camera))
const bloom = new UnrealBloomPass(new THREE.Vector2(WIDTH, HEIGHT), 0.55, 0.6, 0.82)
composer.addPass(bloom)
composer.addPass(new OutputPass())

scene.add(new THREE.AmbientLight(0x8fb4ff, 0.55))
const keyLight = new THREE.DirectionalLight(0xffffff, 2.4)
keyLight.position.set(3, 5, 6)
scene.add(keyLight)
const rimLight = new THREE.PointLight(0x2997ff, 40, 30)
rimLight.position.set(-5, -2, 3)
scene.add(rimLight)

// ---------------------------------------------------------------------------
// Background: animated gradient and drifting particles
// ---------------------------------------------------------------------------

const backgroundMaterial = new THREE.ShaderMaterial({
  depthWrite: false,
  uniforms: { uTime: { value: 0 }, uGlow: { value: 1 } },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = vec4(position.xy, 0.9999, 1.0);
    }
  `,
  fragmentShader: `
    varying vec2 vUv;
    uniform float uTime;
    uniform float uGlow;

    float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float noise(vec2 p) {
      vec2 i = floor(p);
      vec2 f = fract(p);
      vec2 u = f * f * (3.0 - 2.0 * f);
      return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
                 mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
    }

    void main() {
      vec2 p = vUv - 0.5;
      p.x *= 1.7778;
      float t = uTime * 0.05;
      float n = noise(p * 2.2 + vec2(t, -t)) * 0.6 + noise(p * 5.0 - vec2(t * 1.7, t)) * 0.4;
      float glow = smoothstep(1.1, 0.0, length(p - vec2(0.15 * sin(t * 3.0), 0.05)));
      vec3 deep = vec3(0.012, 0.016, 0.035);
      vec3 blue = vec3(0.02, 0.12, 0.38);
      vec3 cyan = vec3(0.05, 0.35, 0.75);
      vec3 color = mix(deep, blue, glow * 0.9 * uGlow);
      color = mix(color, cyan, pow(glow, 3.0) * n * 0.35 * uGlow);
      color += (hash(vUv * 1000.0) - 0.5) * 0.006;
      gl_FragColor = vec4(color, 1.0);
    }
  `,
})
const background = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), backgroundMaterial)
background.frustumCulled = false
background.renderOrder = -1
scene.add(background)

const PARTICLE_COUNT = 700
const particleSeeds = new Float32Array(PARTICLE_COUNT * 4)
const particlePositions = new Float32Array(PARTICLE_COUNT * 3)
const random = mulberry32(7)
for (let i = 0; i < PARTICLE_COUNT; i++) {
  particleSeeds[i * 4] = (random() - 0.5) * 30
  particleSeeds[i * 4 + 1] = (random() - 0.5) * 18
  particleSeeds[i * 4 + 2] = -random() * 20 - 2
  particleSeeds[i * 4 + 3] = random()
}
const particleGeometry = new THREE.BufferGeometry()
particleGeometry.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3))
const particles = new THREE.Points(particleGeometry, new THREE.PointsMaterial({
  color: 0x6fb6ff,
  size: 0.045,
  transparent: true,
  opacity: 0.7,
  depthWrite: false,
  blending: THREE.AdditiveBlending,
}))
scene.add(particles)

function updateParticles(time) {
  for (let i = 0; i < PARTICLE_COUNT; i++) {
    const phase = particleSeeds[i * 4 + 3]
    particlePositions[i * 3] = particleSeeds[i * 4] + Math.sin(time * 0.2 + phase * 6.28) * 0.4
    particlePositions[i * 3 + 1] = particleSeeds[i * 4 + 1] + ((time * (0.05 + phase * 0.1)) % 18) - 0
    particlePositions[i * 3 + 2] = particleSeeds[i * 4 + 2]
    if (particlePositions[i * 3 + 1] > 9) particlePositions[i * 3 + 1] -= 18
  }
  particleGeometry.attributes.position.needsUpdate = true
}

// ---------------------------------------------------------------------------
// Folder deck (the app icon in 3D)
// ---------------------------------------------------------------------------

function folderShape(width, height, radius, tabWidth, tabHeight) {
  const shape = new THREE.Shape()
  const left = -width / 2
  const right = width / 2
  const bottom = -height / 2
  const top = height / 2
  shape.moveTo(left + radius, bottom)
  shape.lineTo(right - radius, bottom)
  shape.quadraticCurveTo(right, bottom, right, bottom + radius)
  shape.lineTo(right, top - radius)
  shape.quadraticCurveTo(right, top, right - radius, top)
  shape.lineTo(left + tabWidth + tabHeight, top)
  shape.quadraticCurveTo(left + tabWidth + tabHeight * 0.4, top, left + tabWidth, top + tabHeight)
  shape.lineTo(left + radius, top + tabHeight)
  shape.quadraticCurveTo(left, top + tabHeight, left, top + tabHeight - radius)
  shape.lineTo(left, bottom + radius)
  shape.quadraticCurveTo(left, bottom, left + radius, bottom)
  return shape
}

const folderGeometry = new THREE.ExtrudeGeometry(folderShape(2.6, 1.9, 0.22, 1.0, 0.28), {
  depth: 0.06,
  bevelEnabled: true,
  bevelThickness: 0.04,
  bevelSize: 0.04,
  bevelSegments: 6,
  curveSegments: 24,
})
folderGeometry.center()

const deck = new THREE.Group()
scene.add(deck)
const folderColors = [0x1a4fc4, 0x2268e0, 0x2e8cf5]
const folders = folderColors.map((color, index) => {
  const material = new THREE.MeshPhysicalMaterial({
    color,
    roughness: 0.28,
    metalness: 0.05,
    clearcoat: 1,
    clearcoatRoughness: 0.2,
    emissive: new THREE.Color(color).multiplyScalar(0.22),
    transparent: true,
  })
  const mesh = new THREE.Mesh(folderGeometry, material)
  mesh.userData.rest = { x: -0.55 + index * 0.42, y: 0.42 - index * 0.32, z: index * 0.28, rz: 0.2 - index * 0.1 }
  deck.add(mesh)
  return mesh
})

const glyph = new THREE.Mesh(
  new THREE.PlaneGeometry(2.2, 1.6),
  new THREE.MeshBasicMaterial({ map: glyphTexture(), transparent: true, depthWrite: false }),
)
glyph.position.z = 0.09
folders[2].add(glyph)

function glyphTexture() {
  const size = { width: 880, height: 640 }
  const context = createCanvas(size.width, size.height)
  context.strokeStyle = 'rgba(235, 244, 255, 0.95)'
  context.lineWidth = 46
  context.lineCap = 'round'
  context.lineJoin = 'round'
  context.beginPath()
  context.moveTo(290, 190); context.lineTo(170, 310); context.lineTo(290, 430)
  context.moveTo(590, 190); context.lineTo(710, 310); context.lineTo(590, 430)
  context.moveTo(480, 150); context.lineTo(400, 470)
  context.stroke()
  context.lineWidth = 30
  context.beginPath()
  context.moveTo(700, 580); context.lineTo(800, 480)
  context.moveTo(730, 480); context.lineTo(800, 480); context.lineTo(800, 550)
  context.stroke()
  return canvasTexture(context)
}

const deckState = { spread: 0, scale: 0.8, opacity: 0, rotationY: -0.5, y: 0.95, z: 0, fly: 1 }

function updateDeck(time) {
  deck.visible = deckState.opacity > 0.001
  deck.position.set(0, deckState.y, deckState.z)
  deck.scale.setScalar(deckState.scale)
  deck.rotation.set(Math.sin(time * 0.6) * 0.06, deckState.rotationY + Math.sin(time * 0.4) * 0.08, 0)
  folders.forEach((folder, index) => {
    const rest = folder.userData.rest
    const spread = deckState.spread
    const fly = deckState.fly
    folder.position.set(
      rest.x * (1 + spread * 1.8) + fly * (index - 1) * 4,
      rest.y * (1 + spread * 1.4) + Math.sin(time * 1.1 + index) * 0.03,
      rest.z * (1 + spread * 3) - fly * (8 + index * 3),
    )
    folder.rotation.set(fly * 1.2, fly * (index - 1) * 1.4, rest.rz * (1 + spread) + fly * 2)
    folder.material.opacity = deckState.opacity
  })
  glyph.material.opacity = deckState.opacity
}

// ---------------------------------------------------------------------------
// App popup panel, drawn on a 2D canvas each frame
// ---------------------------------------------------------------------------

const PANEL = { width: 3.4, height: 4.8, pixelWidth: 720, pixelHeight: 1016 }
const panelContext = createCanvas(PANEL.pixelWidth, PANEL.pixelHeight)
const panelTexture = canvasTexture(panelContext)
const panel = new THREE.Mesh(
  new RoundedBoxGeometry(PANEL.width, PANEL.height, 0.06, 6, 0.12),
  [
    new THREE.MeshStandardMaterial({ color: 0x1c1c21, roughness: 0.5, transparent: true }),
    new THREE.MeshStandardMaterial({ color: 0x1c1c21, roughness: 0.5, transparent: true }),
    new THREE.MeshStandardMaterial({ color: 0x1c1c21, roughness: 0.5, transparent: true }),
    new THREE.MeshStandardMaterial({ color: 0x1c1c21, roughness: 0.5, transparent: true }),
    new THREE.MeshBasicMaterial({ map: panelTexture, transparent: true, toneMapped: false }),
    new THREE.MeshStandardMaterial({ color: 0x1c1c21, roughness: 0.5, transparent: true }),
  ],
)
scene.add(panel)

const ui = {
  opacity: 0,
  scale: 0.9,
  x: 0,
  y: 0,
  rotationY: 0,
  tabPosition: 0,
  workspaceReveal: 0,
  gitReveal: 0,
  badgeReveal: 0,
  statusReveal: 0,
  linkHighlight: -1,
  pressed: 0,
  pending: 0,
  running: 0,
  databaseReveal: 0,
  spinner: 0,
}

const WORKSPACE_SECTIONS = [
  { name: 'clients', rows: [
    { name: 'acme-shop', path: '~/dev/clients/acme-shop', kind: 'workspace' },
    { name: 'billing-portal', path: '~/dev/clients/billing-portal', kind: 'workspace' },
    { name: 'fleet-tracker', path: '~/dev/clients/fleet-tracker', kind: 'folder' },
  ] },
  { name: 'personal', rows: [
    { name: 'blog', path: '~/dev/personal/blog', kind: 'folder' },
    { name: 'dotfiles', path: '~/dev/personal/dotfiles', kind: 'folder' },
    { name: 'workdeck', path: '~/dev/personal/workdeck', kind: 'folder' },
  ] },
]

const GIT_SECTIONS = [
  { name: 'clients', rows: [
    { name: 'acme-shop-api', branch: 'develop', ahead: 0, behind: 0, changed: 0 },
    { name: 'acme-shop-web', branch: 'main', ahead: 2, behind: 0, changed: 3 },
    { name: 'billing-portal', branch: 'feat/invoices', ahead: 0, behind: 1, changed: 1 },
    { name: 'fleet-tracker', branch: 'main', ahead: 0, behind: 0, changed: 0 },
  ] },
  { name: 'personal', rows: [
    { name: 'workdeck', branch: 'main', ahead: 1, behind: 0, changed: 0 },
  ] },
]

const LIST_TOP = 168
const SECTION_HEIGHT = 46
const ROW_HEIGHT = 86

const STATUS_LINKS = [
  { environment: 'PROD', label: 'Web', url: 'shop.example.com', y: 298 },
  { environment: '', label: 'API', url: 'api.shop.example.com', y: 336 },
  { environment: 'DEV', label: 'Web', url: 'dev.shop.example.com', y: 386 },
  { environment: '', label: 'API', url: 'api.dev.shop.example.com', y: 424 },
]
const STATUS_APPS = [
  { name: 'shop-web', url: 'shop-web.localhost', y: 476, alwaysRunning: true },
  { name: 'shop-api', url: 'shop-api.localhost', y: 516, alwaysRunning: false },
]
export const RUN_BUTTON = { x: 176, y: 516 }
const DATABASE_LINE_Y = 552

function drawPanel() {
  const context = panelContext
  const { pixelWidth: width, pixelHeight: height } = PANEL
  context.clearRect(0, 0, width, height)
  roundRect(context, 0, 0, width, height, 26, COLORS.surface)
  context.strokeStyle = COLORS.border
  context.lineWidth = 3
  roundRectPath(context, 1.5, 1.5, width - 3, height - 3, 25)
  context.stroke()

  drawSegmentedControl(context)
  drawSearchField(context)
  divider(context, 150)

  context.save()
  context.beginPath()
  context.rect(0, 152, width, 780)
  context.clip()
  const tab = ui.tabPosition
  const fadeFor = (index) => clamp01(1 - Math.abs(tab - index) * 2)
  if (fadeFor(0) > 0) drawWorkspaces(context, fadeFor(0))
  if (fadeFor(1) > 0) drawGitRepositories(context, fadeFor(1))
  if (fadeFor(2) > 0) drawStatus(context, fadeFor(2))
  context.restore()

  divider(context, 934)
  drawFooter(context)
  panelTexture.needsUpdate = true
}

function drawSegmentedControl(context) {
  const x = 22
  const y = 22
  const width = PANEL.pixelWidth - 44
  const height = 50
  roundRect(context, x, y, width, height, 12, COLORS.surfaceRaised)
  const segmentWidth = width / 3
  roundRect(context, x + 4 + ui.tabPosition * segmentWidth, y + 4, segmentWidth - 8, height - 8, 9, '#4a4a52')
  const labels = ['Workspaces', 'Git Repos', 'Status']
  context.font = `600 23px ${FONT}`
  context.textAlign = 'center'
  context.textBaseline = 'middle'
  labels.forEach((label, index) => {
    context.fillStyle = COLORS.text
    context.fillText(label, x + segmentWidth * (index + 0.5), y + height / 2 + 1)
  })
  context.textAlign = 'left'
}

function drawSearchField(context) {
  const y = 86
  roundRect(context, 22, y, 130, 46, 10, COLORS.surfaceRaised)
  context.font = `500 22px ${FONT}`
  context.fillStyle = COLORS.text
  context.textBaseline = 'middle'
  drawFolderIcon(context, 36, y + 13, 24, 18, COLORS.accent)
  context.fillText('All', 72, y + 24)
  roundRect(context, 166, y, PANEL.pixelWidth - 188, 46, 10, '#111114')
  context.strokeStyle = COLORS.border
  context.lineWidth = 2
  roundRectPath(context, 166, y, PANEL.pixelWidth - 188, 46, 10)
  context.stroke()
  context.fillStyle = '#6e6e73'
  context.fillText('Search', 184, y + 24)
}

function drawFooter(context) {
  const y = 975
  context.font = `500 22px ${FONT}`
  context.textBaseline = 'middle'
  context.fillStyle = COLORS.text
  context.fillText('↻  Rescan', 26, y)
  context.fillStyle = COLORS.muted
  context.textAlign = 'center'
  context.font = `500 19px ${FONT}`
  context.fillText('v1.3.0', PANEL.pixelWidth / 2, y)
  context.textAlign = 'right'
  context.font = `500 22px ${FONT}`
  context.fillStyle = COLORS.text
  context.fillText('⚙︎     Quit', PANEL.pixelWidth - 26, y)
  context.textAlign = 'left'
}

function drawSectionHeader(context, name, y, alpha) {
  context.globalAlpha = alpha
  context.font = `700 19px ${FONT}`
  context.fillStyle = '#8e8e93'
  context.textBaseline = 'middle'
  context.fillText(name, 30, y + SECTION_HEIGHT / 2 + 4)
  context.globalAlpha = 1
}

export function workspaceRowY(index) {
  const sectionIndex = index < 3 ? 0 : 1
  return LIST_TOP + SECTION_HEIGHT * (sectionIndex + 1) + ROW_HEIGHT * index
}

function drawWorkspaces(context, tabAlpha) {
  let index = 0
  WORKSPACE_SECTIONS.forEach((section, sectionIndex) => {
    const headerY = LIST_TOP + sectionIndex * (SECTION_HEIGHT + ROW_HEIGHT * 3)
    drawSectionHeader(context, section.name, headerY, tabAlpha * clamp01(ui.workspaceReveal * 6 - sectionIndex * 2))
    section.rows.forEach((row) => {
      const reveal = staggered(ui.workspaceReveal, index, 6)
      const y = workspaceRowY(index)
      context.globalAlpha = tabAlpha * reveal
      const offset = (1 - easeOut(reveal)) * 30
      drawRowIcon(context, row.kind, 36, y + 22 + offset)
      context.font = `600 25px ${FONT}`
      context.fillStyle = COLORS.text
      context.textBaseline = 'alphabetic'
      context.fillText(row.name, 84, y + 36 + offset)
      context.font = `400 19px ${FONT}`
      context.fillStyle = COLORS.muted
      context.fillText(row.path, 84, y + 64 + offset)
      context.globalAlpha = 1
      index++
    })
  })
}

function drawGitRepositories(context, tabAlpha) {
  let index = 0
  let y = LIST_TOP
  GIT_SECTIONS.forEach((section) => {
    drawSectionHeader(context, section.name, y, tabAlpha * clamp01(ui.gitReveal * 4))
    y += SECTION_HEIGHT
    section.rows.forEach((row) => {
      const reveal = staggered(ui.gitReveal, index, 5)
      const offset = (1 - easeOut(reveal)) * 30
      context.globalAlpha = tabAlpha * reveal
      drawBranchIcon(context, 38, y + 24 + offset)
      context.font = `600 25px ${FONT}`
      context.fillStyle = COLORS.text
      context.textBaseline = 'alphabetic'
      context.fillText(row.name, 84, y + 36 + offset)
      context.font = `400 19px ${MONO}`
      context.fillStyle = COLORS.muted
      context.fillText(row.branch, 84, y + 64 + offset)
      drawGitBadges(context, row, y + 40 + offset, tabAlpha * staggered(ui.badgeReveal, index, 5))
      context.globalAlpha = 1
      y += ROW_HEIGHT
      index++
    })
  })
}

function drawGitBadges(context, row, y, alpha) {
  if (alpha <= 0) return
  context.save()
  context.globalAlpha = alpha
  const scale = 0.6 + easeOutBack(alpha) * 0.4
  context.translate(PANEL.pixelWidth - 30, y)
  context.scale(scale, scale)
  context.font = `600 21px ${FONT}`
  context.textBaseline = 'middle'
  context.textAlign = 'right'
  let x = 0
  const badge = (text, color) => {
    context.fillStyle = color
    context.fillText(text, x, 0)
    x -= context.measureText(text).width + 18
  }
  if (row.changed === 0) {
    context.fillStyle = COLORS.green
    context.beginPath()
    context.arc(x - 12, 0, 13, 0, Math.PI * 2)
    context.fill()
    context.strokeStyle = '#0b2a14'
    context.lineWidth = 3.5
    context.beginPath()
    context.moveTo(x - 18, 0); context.lineTo(x - 13, 5); context.lineTo(x - 5, -5)
    context.stroke()
    x -= 44
  } else {
    badge(`✎ ${row.changed}`, COLORS.orange)
  }
  if (row.behind > 0) badge(`↓ ${row.behind}`, COLORS.text)
  if (row.ahead > 0) badge(`↑ ${row.ahead}`, COLORS.text)
  context.restore()
}

function drawStatus(context, tabAlpha) {
  const reveal = (index, count = 9) => tabAlpha * staggered(ui.statusReveal, index, count)
  context.textBaseline = 'alphabetic'

  drawSectionHeader(context, 'clients', LIST_TOP, reveal(0))

  context.globalAlpha = reveal(0)
  drawServerIcon(context, 36, 232)
  context.font = `600 26px ${FONT}`
  context.fillStyle = COLORS.text
  context.fillText('acme-shop', 84, 256)
  const runningCount = 1 + (ui.running > 0.5 ? 1 : 0)
  context.font = `600 19px ${FONT}`
  context.fillStyle = COLORS.green
  context.textAlign = 'right'
  context.fillText(`● ${runningCount} running`, PANEL.pixelWidth - 30, 254)
  context.textAlign = 'left'

  STATUS_LINKS.forEach((link, index) => {
    context.globalAlpha = reveal(index + 1)
    if (link.environment) {
      context.font = `700 17px ${FONT}`
      context.fillStyle = link.environment === 'PROD' ? COLORS.red : COLORS.blue
      context.fillText(link.environment, 84, link.y)
    }
    const highlighted = Math.abs(ui.linkHighlight - index) < 0.5
    if (highlighted) {
      roundRect(context, 170, link.y - 25, 470, 34, 8, 'rgba(41, 151, 255, 0.18)')
    }
    context.font = `500 20px ${FONT}`
    context.fillStyle = COLORS.muted
    context.fillText(link.label, 180, link.y)
    context.fillStyle = highlighted ? '#8cc8ff' : COLORS.accent
    context.fillText(link.url, 238, link.y)
  })

  context.globalAlpha = reveal(5)
  context.font = `700 17px ${FONT}`
  context.fillStyle = COLORS.green
  context.fillText('LOCAL', 84, STATUS_APPS[0].y)

  STATUS_APPS.forEach((app, index) => {
    context.globalAlpha = reveal(6 + index)
    const isRunning = app.alwaysRunning || ui.running > 0.5
    drawAppControl(context, app, isRunning)
    context.fillStyle = isRunning ? COLORS.green : 'rgba(161, 161, 166, 0.45)'
    context.beginPath()
    context.arc(214, app.y - 7, 6, 0, Math.PI * 2)
    context.fill()
    context.font = `500 20px ${FONT}`
    context.globalAlpha *= isRunning ? 1 : 0.55
    context.fillStyle = COLORS.muted
    context.fillText(app.name, 232, app.y)
    context.fillStyle = COLORS.accent
    context.fillText(app.url, 338, app.y)
  })

  context.globalAlpha = tabAlpha * clamp01(Math.max(ui.databaseReveal, 0))
  context.font = `500 17px ${MONO}`
  context.fillStyle = COLORS.muted
  const databaseText = 'DB DEV · db.dev.shop.internal:5432'
  context.fillText(databaseText.slice(0, Math.round(databaseText.length * ui.databaseReveal)), 232, DATABASE_LINE_Y)

  divider(context, 590, reveal(8))
  context.globalAlpha = reveal(8)
  drawSectionHeader(context, 'personal', 598, reveal(8))
  context.globalAlpha = reveal(8)
  drawServerIcon(context, 36, 662)
  context.font = `600 26px ${FONT}`
  context.fillStyle = COLORS.text
  context.fillText('billing-portal', 84, 686)
  context.font = `700 17px ${FONT}`
  context.fillStyle = COLORS.red
  context.fillText('PROD', 84, 728)
  context.font = `500 20px ${FONT}`
  context.fillStyle = COLORS.muted
  context.fillText('Web', 180, 728)
  context.fillStyle = COLORS.accent
  context.fillText('billing.example.com', 238, 728)
  context.font = `700 17px ${FONT}`
  context.fillStyle = COLORS.green
  context.fillText('LOCAL', 84, 770)
  context.fillStyle = 'rgba(161, 161, 166, 0.45)'
  context.beginPath()
  context.arc(214, 763, 6, 0, Math.PI * 2)
  context.fill()
  drawPlayIcon(context, 176, 770, 1)
  context.font = `500 20px ${FONT}`
  context.fillStyle = 'rgba(161, 161, 166, 0.55)'
  context.fillText('billing-web', 232, 770)
  context.globalAlpha = 1
}

function drawAppControl(context, app, isRunning) {
  const x = 176
  const y = app.y
  if (!app.alwaysRunning && ui.pending > 0.5 && ui.running < 0.5) {
    context.save()
    context.translate(x, y - 7)
    context.rotate(ui.spinner * Math.PI * 2)
    context.strokeStyle = COLORS.muted
    context.lineWidth = 3
    context.lineCap = 'round'
    for (let i = 0; i < 8; i++) {
      context.globalAlpha = 0.25 + (i / 8) * 0.75
      context.beginPath()
      context.moveTo(0, -5)
      context.lineTo(0, -10)
      context.stroke()
      context.rotate(Math.PI / 4)
    }
    context.restore()
    return
  }
  if (isRunning) {
    roundRect(context, x - 8, y - 15, 16, 16, 2, COLORS.red)
  } else {
    const pressScale = 1 - ui.pressed * 0.3
    drawPlayIcon(context, x, y, pressScale)
  }
}

function drawPlayIcon(context, x, y, scale) {
  context.save()
  context.translate(x, y - 7)
  context.scale(scale, scale)
  context.fillStyle = COLORS.green
  context.beginPath()
  context.moveTo(-7, -10)
  context.lineTo(10, 0)
  context.lineTo(-7, 10)
  context.closePath()
  context.fill()
  context.restore()
}

function drawRowIcon(context, kind, x, y) {
  if (kind === 'workspace') {
    context.strokeStyle = COLORS.muted
    context.lineWidth = 2.5
    for (let i = 0; i < 3; i++) {
      roundRectPath(context, x + i * 3, y - i * 6 + 6, 26, 14, 3)
      context.stroke()
    }
  } else {
    drawFolderIcon(context, x, y - 2, 30, 22, COLORS.muted)
  }
}

function drawFolderIcon(context, x, y, width, height, color) {
  context.strokeStyle = color
  context.lineWidth = 2.5
  context.beginPath()
  context.moveTo(x, y + 3)
  context.lineTo(x + width * 0.38, y + 3)
  context.lineTo(x + width * 0.48, y + height * 0.22)
  context.lineTo(x + width, y + height * 0.22)
  context.lineTo(x + width, y + height)
  context.lineTo(x, y + height)
  context.closePath()
  context.stroke()
}

function drawBranchIcon(context, x, y) {
  context.strokeStyle = COLORS.muted
  context.lineWidth = 2.5
  context.beginPath()
  context.arc(x, y - 10, 4, 0, Math.PI * 2)
  context.moveTo(x + 4, y + 12)
  context.arc(x, y + 12, 4, 0, Math.PI * 2)
  context.moveTo(x + 20, y - 10)
  context.arc(x + 16, y - 10, 4, 0, Math.PI * 2)
  context.moveTo(x, y - 6)
  context.lineTo(x, y + 8)
  context.moveTo(x + 16, y - 6)
  context.quadraticCurveTo(x + 16, y + 4, x + 2, y + 9)
  context.stroke()
}

function drawServerIcon(context, x, y) {
  context.strokeStyle = COLORS.muted
  context.lineWidth = 2.5
  roundRectPath(context, x, y - 12, 28, 11, 3)
  context.stroke()
  roundRectPath(context, x, y + 3, 28, 11, 3)
  context.stroke()
}

function divider(context, y, alpha = 1) {
  context.globalAlpha = alpha
  context.fillStyle = COLORS.border
  context.fillRect(0, y, PANEL.pixelWidth, 2)
  context.globalAlpha = 1
}

function updatePanel() {
  panel.visible = ui.opacity > 0.001
  panel.position.set(ui.x, ui.y, 0)
  panel.scale.setScalar(ui.scale)
  panel.rotation.set(0, ui.rotationY, 0)
  panel.material.forEach((material) => { material.opacity = ui.opacity })
  if (panel.visible) drawPanel()
}

export function panelPoint(pixelX, pixelY, target = new THREE.Vector3()) {
  panel.updateMatrixWorld()
  target.set((pixelX / PANEL.pixelWidth - 0.5) * PANEL.width, (0.5 - pixelY / PANEL.pixelHeight) * PANEL.height, 0.04)
  return panel.localToWorld(target)
}

// ---------------------------------------------------------------------------
// Discovery tiles: many small project cards that fly into the panel
// ---------------------------------------------------------------------------

const DECOY_NAMES = [
  'api-gateway', 'design-tokens', 'mobile-app', 'infra', 'docs-site', 'analytics', 'auth-service', 'cli-tools',
  'landing', 'data-pipeline', 'admin-web', 'notifications', 'search', 'payments', 'scripts', 'storybook',
  'etl-jobs', 'marketing',
]
const TILE_NAMES = WORKSPACE_SECTIONS.flatMap((section) => section.rows.map((row) => row.name)).concat(DECOY_NAMES)
const tileState = { burst: 0, gather: 0, opacity: 0 }
const tileRandom = mulberry32(21)
const tiles = TILE_NAMES.map((name, index) => {
  const context = createCanvas(420, 110)
  roundRect(context, 4, 4, 412, 102, 22, 'rgba(28, 28, 33, 0.94)')
  context.strokeStyle = 'rgba(41, 151, 255, 0.7)'
  context.lineWidth = 3
  roundRectPath(context, 4, 4, 412, 102, 22)
  context.stroke()
  drawFolderIcon(context, 30, 38, 40, 30, COLORS.accent)
  context.font = `600 34px ${FONT}`
  context.fillStyle = COLORS.text
  context.textBaseline = 'middle'
  context.fillText(name, 92, 56)
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(1.53, 0.4),
    new THREE.MeshBasicMaterial({ map: canvasTexture(context), transparent: true, depthWrite: false, toneMapped: false }),
  )
  const radius = 3 + tileRandom() * 3.5
  const theta = tileRandom() * Math.PI * 2
  const phi = (tileRandom() - 0.5) * 1.6
  mesh.userData = {
    index,
    scatter: captionSafe(new THREE.Vector3(Math.cos(theta) * radius * 1.4, Math.sin(phi) * radius * 0.75, Math.sin(theta) * radius * 0.6 - 1)),
    spin: (tileRandom() - 0.5) * 1.4,
    delay: tileRandom() * 0.35,
  }
  scene.add(mesh)
  return mesh
})

function captionSafe(point) {
  if (point.x < -1.2 && point.y < 0.2) point.y = 0.8 + Math.abs(point.y) * 0.5
  return point
}

const tileTarget = new THREE.Vector3()
function updateTiles(time) {
  tiles.forEach((tile) => {
    const { index, scatter, spin, delay } = tile.userData
    const burst = easeOut(clamp01((tileState.burst - delay * 0.5) / (1 - delay * 0.5)))
    const gather = easeInOut(clamp01((tileState.gather - delay) / (1 - delay)))
    tile.visible = tileState.opacity > 0.001 && burst > 0
    if (!tile.visible) return

    const floating = scatter.clone().multiplyScalar(burst)
    floating.y += Math.sin(time * 0.9 + index) * 0.12
    const isListed = index < 6
    if (isListed) {
      panelPoint(PANEL.pixelWidth * 0.5, workspaceRowY(index) + ROW_HEIGHT / 2, tileTarget)
    } else {
      panelPoint(PANEL.pixelWidth * 0.5, 540, tileTarget)
      tileTarget.z -= 0.5
    }
    tile.position.lerpVectors(floating, tileTarget, gather)
    tile.rotation.set(0, spin * (1 - gather) * Math.sin(time * 0.5 + index), spin * 0.3 * (1 - gather))
    const listedScale = PANEL.width * ui.scale / 1.53
    tile.scale.setScalar(isListed ? THREE.MathUtils.lerp(1, listedScale, gather) : 1 - gather * 0.8)
    const fadeListed = isListed ? 1 - clamp01((ui.workspaceReveal - 0.2) * 2) : 1 - gather
    tile.material.opacity = tileState.opacity * burst * fadeListed
  })
}

// ---------------------------------------------------------------------------
// URL chips that fly out of the Status tab
// ---------------------------------------------------------------------------

const chipState = { out: 0 }
const chips = STATUS_LINKS.map((link, index) => {
  const context = createCanvas(760, 120)
  roundRect(context, 6, 6, 748, 108, 54, 'rgba(10, 30, 60, 0.92)')
  context.strokeStyle = COLORS.accent
  context.lineWidth = 4
  roundRectPath(context, 6, 6, 748, 108, 54)
  context.stroke()
  context.font = `700 26px ${FONT}`
  context.fillStyle = link.environment === 'PROD' || index === 1 ? COLORS.red : COLORS.blue
  context.textBaseline = 'middle'
  context.fillText(index < 2 ? 'PROD' : 'DEV', 44, 62)
  context.font = `600 36px ${MONO}`
  context.fillStyle = COLORS.text
  context.fillText(`https://${link.url}`, 140, 62)
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(2.53, 0.4),
    new THREE.MeshBasicMaterial({ map: canvasTexture(context), transparent: true, depthWrite: false, toneMapped: false }),
  )
  mesh.userData = { link, index }
  scene.add(mesh)
  return mesh
})

const chipOrigin = new THREE.Vector3()
function updateChips(time) {
  chips.forEach((chip) => {
    const { link, index } = chip.userData
    const progress = easeInOut(clamp01(chipState.out * 1.6 - index * 0.2))
    chip.visible = progress > 0.001
    if (!chip.visible) return
    panelPoint(400, link.y - 8, chipOrigin)
    const target = new THREE.Vector3(2.45 + (index % 2) * 0.3, 1.3 - index * 0.6, 1.0 + Math.sin(time + index) * 0.05)
    chip.position.lerpVectors(chipOrigin, target, progress)
    chip.scale.setScalar(0.35 + progress * 0.47)
    chip.rotation.set(0, -0.25 * progress, 0)
    chip.material.opacity = Math.min(1, progress * 1.5)
  })
}

// ---------------------------------------------------------------------------
// Terminal window tailing the app log
// ---------------------------------------------------------------------------

const TERMINAL = { width: 4.2, height: 2.6, pixelWidth: 1120, pixelHeight: 694 }
const terminalContext = createCanvas(TERMINAL.pixelWidth, TERMINAL.pixelHeight)
const terminalTexture = canvasTexture(terminalContext)
const terminal = new THREE.Mesh(
  new THREE.PlaneGeometry(TERMINAL.width, TERMINAL.height),
  new THREE.MeshBasicMaterial({ map: terminalTexture, transparent: true, toneMapped: false }),
)
scene.add(terminal)
const terminalState = { opacity: 0, x: 6, lines: 0, scale: 0.85 }
const LOG_LINES = [
  ['$ ', 'tail -n 200 -f ~/Library/Logs/Workdeck/shop-api.log', '#8cc8ff'],
  ['', '', ''],
  ['', '> shop-api@1.4.0 start:dev', COLORS.muted],
  ['', '> nest start --watch', COLORS.muted],
  ['', '', ''],
  ['portless ', 'shop-api -> https://shop-api.localhost', COLORS.green],
  ['', '[Nest] LOG  Starting Nest application...', COLORS.text],
  ['', '[Nest] LOG  PrismaService connected (db.dev.shop.internal)', COLORS.text],
  ['', '[Nest] LOG  Mapped {/api/orders, GET} route', COLORS.text],
  ['', '[Nest] LOG  Mapped {/api/orders/:id, GET} route', COLORS.text],
  ['', '[Nest] LOG  Nest application successfully started', COLORS.green],
  ['', 'GET /api/orders 200 12ms', COLORS.muted],
]

function drawTerminal(time) {
  const context = terminalContext
  const { pixelWidth: width, pixelHeight: height } = TERMINAL
  context.clearRect(0, 0, width, height)
  roundRect(context, 0, 0, width, height, 22, 'rgba(14, 14, 18, 0.97)')
  roundRect(context, 0, 0, width, 56, 22, '#2a2a30')
  context.fillStyle = '#2a2a30'
  context.fillRect(0, 30, width, 26)
  ;['#ff5f57', '#febc2e', '#28c840'].forEach((color, index) => {
    context.fillStyle = color
    context.beginPath()
    context.arc(32 + index * 30, 28, 9, 0, Math.PI * 2)
    context.fill()
  })
  context.font = `600 22px ${FONT}`
  context.fillStyle = COLORS.muted
  context.textAlign = 'center'
  context.textBaseline = 'middle'
  context.fillText('shop-api.command — tail', width / 2, 29)
  context.textAlign = 'left'
  context.font = `500 24px ${MONO}`
  context.textBaseline = 'alphabetic'
  const visibleLines = Math.floor(terminalState.lines)
  const partial = terminalState.lines - visibleLines
  LOG_LINES.forEach(([prefix, text, color], index) => {
    if (index > visibleLines) return
    const y = 104 + index * 46
    let shown = text
    if (index === visibleLines) shown = text.slice(0, Math.floor(text.length * partial))
    context.fillStyle = prefix === 'portless ' ? '#bf5af2' : COLORS.muted
    context.fillText(prefix, 30, y)
    context.fillStyle = color
    context.fillText(shown, 30 + context.measureText(prefix).width, y)
  })
  const cursorVisible = Math.floor(time * 2) % 2 === 0
  if (cursorVisible && terminalState.lines >= LOG_LINES.length - 1) {
    context.fillStyle = COLORS.text
    context.fillRect(30, 104 + LOG_LINES.length * 46 - 22, 14, 28)
  }
  terminalTexture.needsUpdate = true
}

function updateTerminal(time) {
  terminal.visible = terminalState.opacity > 0.001
  terminal.position.set(terminalState.x, -0.5, 0.6)
  terminal.scale.setScalar(terminalState.scale)
  terminal.rotation.set(0, -0.28, 0)
  terminal.material.opacity = terminalState.opacity
  if (terminal.visible) drawTerminal(time)
}

// ---------------------------------------------------------------------------
// DOM overlay: cursor and pulse ring projected from 3D
// ---------------------------------------------------------------------------

const cursorElement = document.getElementById('cursor')
const pulseElement = document.getElementById('pulse')
const overlayState = { cursorOpacity: 0, cursorTravel: 0, pulse: 0 }
const projected = new THREE.Vector3()

function screenPoint(worldPoint) {
  projected.copy(worldPoint).project(camera)
  return { x: (projected.x + 1) / 2 * WIDTH, y: (1 - projected.y) / 2 * HEIGHT }
}

function updateOverlay() {
  const buttonPoint = screenPoint(panelPoint(RUN_BUTTON.x, RUN_BUTTON.y - 7))
  const start = { x: buttonPoint.x + 260, y: buttonPoint.y + 180 }
  const travel = easeInOut(overlayState.cursorTravel)
  const x = THREE.MathUtils.lerp(start.x, buttonPoint.x, travel)
  const y = THREE.MathUtils.lerp(start.y, buttonPoint.y, travel)
  cursorElement.style.opacity = overlayState.cursorOpacity
  cursorElement.style.transform = `translate(${x - 6}px, ${y - 4}px) scale(${1 - ui.pressed * 0.12})`

  const dotPoint = screenPoint(panelPoint(214, STATUS_APPS[1].y - 7))
  const pulse = overlayState.pulse
  pulseElement.style.opacity = pulse > 0 && pulse < 1 ? (1 - pulse) : 0
  pulseElement.style.transform = `translate(${dotPoint.x}px, ${dotPoint.y}px) scale(${1 + pulse * 7})`
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

const timeline = gsap.timeline({ paused: true })
const byId = (id) => document.getElementById(id)

function showCaption(id, start, end) {
  timeline.fromTo(byId(id), { opacity: 0, y: 30 }, { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out' }, start)
  timeline.to(byId(id), { opacity: 0, y: -20, duration: 0.6, ease: 'power2.in' }, end - 0.6)
}

// Scene 1 — the deck assembles (0–6s)
timeline.to(byId('fade'), { opacity: 0, duration: 1.2, ease: 'power1.out' }, 0)
timeline.to(deckState, { opacity: 1, duration: 0.8 }, 0.2)
timeline.to(deckState, { fly: 0, duration: 2.4, ease: 'expo.out' }, 0.2)
timeline.to(deckState, { rotationY: 0.25, duration: 5.5, ease: 'sine.inOut' }, 0.2)
timeline.fromTo(byId('intro-title'), { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 1.2, ease: 'power3.out' }, 1.6)
timeline.to(byId('intro-title'), { opacity: 0, y: -30, duration: 0.6, ease: 'power2.in' }, 5.2)
timeline.fromTo(cameraRig, { z: 11.5 }, { z: 9.5, duration: 6, ease: 'sine.inOut' }, 0)
timeline.to(deckState, { spread: 1, duration: 0.8, ease: 'power2.in' }, 5.4)
timeline.to(deckState, { opacity: 0, scale: 0.4, duration: 0.6, ease: 'power2.in' }, 5.8)

// Scene 2 — discovery (6–14s)
timeline.to(tileState, { opacity: 1, duration: 0.3 }, 6)
timeline.to(tileState, { burst: 1, duration: 1.6, ease: 'expo.out' }, 6)
timeline.fromTo(cameraRig, { x: 0, z: 9.5, ty: 0 }, { x: -1.4, z: 12, duration: 3.5, ease: 'sine.inOut' }, 6)
timeline.to(ui, { opacity: 1, scale: 1, x: 1.6, duration: 1.2, ease: 'power3.out' }, 8.8)
timeline.to(tileState, { gather: 1, duration: 2, ease: 'none' }, 9.6)
timeline.to(ui, { workspaceReveal: 1, duration: 1.4, ease: 'power1.inOut' }, 11.2)
timeline.to(tileState, { opacity: 0, duration: 0.5 }, 12.6)
timeline.to(cameraRig, { x: 0.6, z: 10.2, duration: 2.5, ease: 'sine.inOut' }, 10.5)
showCaption('caption-discover', 6.6, 14)
timeline.to(byId('vignette'), { opacity: 1, duration: 1 }, 6.2)
timeline.to(byId('vignette'), { opacity: 0, duration: 1 }, 41.6)

// Scene 3 — git status (14–22s)
timeline.to(ui, { tabPosition: 1, duration: 0.5, ease: 'power2.inOut' }, 14.4)
timeline.to(ui, { gitReveal: 1, duration: 1.2, ease: 'power1.out' }, 14.6)
timeline.to(ui, { badgeReveal: 1, duration: 1.6, ease: 'power1.inOut' }, 15.8)
timeline.to(ui, { rotationY: -0.12, duration: 7, ease: 'sine.inOut' }, 14.5)
timeline.to(cameraRig, { x: 0.9, y: 0.1, z: 9.4, duration: 7.5, ease: 'sine.inOut' }, 14.5)
showCaption('caption-git', 14.6, 22)

// Scene 4 — environments (22–32s)
timeline.to(ui, { tabPosition: 2, duration: 0.5, ease: 'power2.inOut' }, 22.3)
timeline.to(ui, { statusReveal: 1, duration: 1.6, ease: 'power1.out' }, 22.5)
timeline.to(ui, { rotationY: 0.1, x: 0.5, duration: 1.5, ease: 'power2.inOut' }, 22.4)
timeline.to(cameraRig, { x: 1.2, y: 0.3, z: 10.4, duration: 3, ease: 'sine.inOut' }, 22.4)
timeline.fromTo(ui, { linkHighlight: -0.6 }, { linkHighlight: 3.6, duration: 2.4, ease: 'none' }, 24.4)
timeline.to(chipState, { out: 1, duration: 2.2, ease: 'power2.out' }, 25)
timeline.set(ui, { linkHighlight: -1 }, 26.9)
timeline.to(chipState, { out: 0, duration: 1.2, ease: 'power2.in' }, 30.2)
showCaption('caption-status', 22.6, 32)

// Scene 5 — run and tail logs (32–42s)
timeline.to(ui, { x: 1.3, scale: 0.92, rotationY: 0.12, duration: 1.6, ease: 'power2.inOut' }, 32)
timeline.to(cameraRig, { x: 1.0, y: 0, z: 9.2, tx: 0.8, ty: 0, duration: 2, ease: 'sine.inOut' }, 32)
timeline.to(overlayState, { cursorOpacity: 1, duration: 0.3 }, 32.8)
timeline.to(overlayState, { cursorTravel: 1, duration: 1.1, ease: 'power2.inOut' }, 32.9)
timeline.to(ui, { pressed: 1, duration: 0.12, yoyo: true, repeat: 1 }, 34.1)
timeline.set(ui, { pending: 1 }, 34.35)
timeline.fromTo(ui, { spinner: 0 }, { spinner: 3, duration: 1.4, ease: 'none' }, 34.35)
timeline.set(ui, { running: 1 }, 35.8)
timeline.fromTo(overlayState, { pulse: 0 }, { pulse: 1, duration: 0.9, ease: 'power2.out' }, 35.8)
timeline.to(overlayState, { cursorOpacity: 0, duration: 0.4 }, 36.2)
timeline.to(ui, { databaseReveal: 1, duration: 0.9, ease: 'none' }, 36.2)
timeline.to(terminalState, { opacity: 1, x: 3.9, duration: 1.1, ease: 'power3.out' }, 36.8)
timeline.to(terminalState, { lines: LOG_LINES.length - 0.001, duration: 3.6, ease: 'none' }, 37.6)
timeline.to(cameraRig, { x: 1.7, y: -0.2, z: 11, tx: 1.3, ty: -0.1, duration: 3, ease: 'sine.inOut' }, 36.6)
showCaption('caption-run', 32.4, 42)

// Scene 6 — outro (42–48s)
timeline.to(terminalState, { opacity: 0, x: 5, duration: 0.8, ease: 'power2.in' }, 42)
timeline.to(ui, { opacity: 0, scale: 0.8, y: 0.6, duration: 0.8, ease: 'power2.in' }, 42.1)
timeline.set(deckState, { spread: 0, fly: 1, scale: 0.8, rotationY: -0.4 }, 42.5)
timeline.to(deckState, { opacity: 1, duration: 0.6 }, 42.6)
timeline.to(deckState, { fly: 0, duration: 2, ease: 'expo.out' }, 42.6)
timeline.to(deckState, { rotationY: 0.2, duration: 5, ease: 'sine.inOut' }, 42.6)
timeline.to(cameraRig, { x: 0, y: 0.2, z: 10.5, tx: 0, ty: 0, duration: 1.8, ease: 'power2.inOut' }, 42.2)
timeline.fromTo(byId('outro-title'), { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 1.2, ease: 'power3.out' }, 44)
timeline.to(byId('fade'), { opacity: 1, duration: 0.8, ease: 'power1.in' }, 47.2)
timeline.set({}, {}, DURATION)

// ---------------------------------------------------------------------------
// Frame rendering
// ---------------------------------------------------------------------------

function renderFrame(time) {
  timeline.seek(time, false)
  backgroundMaterial.uniforms.uTime.value = time
  camera.position.set(cameraRig.x, cameraRig.y, cameraRig.z)
  cameraTarget.set(cameraRig.tx, cameraRig.ty, cameraRig.tz)
  camera.lookAt(cameraTarget)
  camera.updateMatrixWorld()
  updateParticles(time)
  updateDeck(time)
  updatePanel()
  updateTiles(time)
  updateChips(time)
  updateTerminal(time)
  updateOverlay()
  composer.render()
}

window.renderFrame = (time) => {
  renderFrame(time)
  return new Promise((resolve) => requestAnimationFrame(() => resolve()))
}
window.videoDuration = DURATION

await document.fonts.ready
window.sceneReady = true

if (new URLSearchParams(location.search).has('preview')) {
  const startedAt = performance.now()
  const loop = () => {
    renderFrame(((performance.now() - startedAt) / 1000) % DURATION)
    requestAnimationFrame(loop)
  }
  loop()
} else {
  renderFrame(0)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createCanvas(width, height) {
  const element = document.createElement('canvas')
  element.width = width
  element.height = height
  return element.getContext('2d')
}

function canvasTexture(context) {
  const texture = new THREE.CanvasTexture(context.canvas)
  texture.colorSpace = THREE.SRGBColorSpace
  texture.anisotropy = 8
  return texture
}

function roundRectPath(context, x, y, width, height, radius) {
  context.beginPath()
  context.roundRect(x, y, width, height, radius)
}

function roundRect(context, x, y, width, height, radius, fill) {
  roundRectPath(context, x, y, width, height, radius)
  context.fillStyle = fill
  context.fill()
}

function clamp01(value) {
  return Math.min(1, Math.max(0, value))
}

function staggered(progress, index, count) {
  const span = 1 / (count * 0.6)
  return clamp01((progress - (index / count) * (1 - span)) / span)
}

function easeOut(value) {
  return 1 - Math.pow(1 - value, 3)
}

function easeInOut(value) {
  return value < 0.5 ? 4 * value * value * value : 1 - Math.pow(-2 * value + 2, 3) / 2
}

function easeOutBack(value) {
  const overshoot = 1.70158
  return 1 + (overshoot + 1) * Math.pow(value - 1, 3) + overshoot * Math.pow(value - 1, 2)
}

function mulberry32(seed) {
  return () => {
    seed |= 0
    seed = (seed + 0x6d2b79f5) | 0
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
