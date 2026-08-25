import { useMemo, useRef } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Float, MeshDistortMaterial, Sparkles } from '@react-three/drei'
import * as THREE from 'three'
import { scrollState } from '../lib/scroll'

const PAGE_DEPTH = 46

/* ---- quality tiering: phones / weak devices get a much lighter scene ---- */

const LOW_POWER = (() => {
  if (typeof window === 'undefined') return false
  const nav = navigator as Navigator & { deviceMemory?: number }
  const coarse = window.matchMedia('(pointer: coarse)').matches
  const small = window.matchMedia('(max-width: 820px)').matches
  const fewCores = (nav.hardwareConcurrency ?? 8) <= 4
  const littleMem = (nav.deviceMemory ?? 8) <= 4
  return (coarse && small) || fewCores || littleMem
})()

const Q = {
  shapes: LOW_POWER ? 11 : 22,
  particles: LOW_POWER ? 550 : 1300,
  sparkles: LOW_POWER ? 30 : 85,
  dprMax: LOW_POWER ? 1 : 1.5,
  antialias: !LOW_POWER,
  blobSegments: LOW_POWER ? 20 : 40,
}

function hash(n: number) {
  const x = Math.sin(n * 127.1) * 43758.5453
  return x - Math.floor(x)
}

type ShapeDef = {
  kind: 'knot' | 'ico' | 'torus' | 'octa'
  position: [number, number, number]
  scale: number
  color: string
  wireframe: boolean
  speed: number
}

const PALETTE = ['#E85D2A', '#C44A1F', '#1F6F5C', '#2AA184', '#FFB845']

function useShapeField(count: number): ShapeDef[] {
  return useMemo(() => {
    const shapes: ShapeDef[] = []
    for (let i = 0; i < count; i++) {
      const r1 = hash(i + 1)
      const r2 = hash(i + 51)
      const r3 = hash(i + 101)
      const r4 = hash(i + 151)
      const side = r2 > 0.5 ? 1 : -1
      shapes.push({
        kind: (['knot', 'ico', 'torus', 'octa'] as const)[Math.floor(r3 * 4)],
        position: [
          side * (3.2 + r1 * 4.5),
          4 - (i / count) * PAGE_DEPTH + (r4 - 0.5) * 3,
          -5 + r2 * 8,
        ],
        scale: 0.35 + r1 * 0.85,
        color: PALETTE[Math.floor(r4 * PALETTE.length)],
        wireframe: r3 > 0.62,
        speed: 0.15 + r2 * 0.5,
      })
    }
    return shapes
  }, [count])
}

function ScrollRig() {
  useFrame((state, delta) => {
    const p = scrollState.progress
    const targetY = -p * PAGE_DEPTH
    state.camera.position.y = THREE.MathUtils.damp(
      state.camera.position.y,
      targetY,
      2.2,
      delta
    )
    state.camera.position.x = THREE.MathUtils.damp(
      state.camera.position.x,
      state.pointer.x * 0.9,
      2.5,
      delta
    )
    state.camera.lookAt(state.pointer.x * 0.4, targetY + 2, 0)
  })
  return null
}

function Shape({ def }: { def: ShapeDef }) {
  const mesh = useRef<THREE.Mesh>(null)
  const mat = useRef<THREE.MeshStandardMaterial>(null)
  const fade = useRef(0)

  useFrame((state, delta) => {
    const m = mesh.current
    if (!m || !mat.current) return
    m.rotation.x += delta * def.speed
    m.rotation.y += delta * def.speed * 1.4

    const dist = Math.abs(m.position.y - state.camera.position.y)
    const target = THREE.MathUtils.clamp(1 - (dist - 7) / 10, 0, 1)
    fade.current = THREE.MathUtils.damp(fade.current, target, 6, delta)
    mat.current.opacity = fade.current * (def.wireframe ? 0.5 : 0.85)
  })

  let geometry: JSX.Element
  if (def.kind === 'knot') {
    geometry = (
      <torusKnotGeometry args={LOW_POWER ? [0.8, 0.24, 56, 10] : [0.8, 0.26, 110, 16]} />
    )
  } else if (def.kind === 'ico') {
    geometry = <icosahedronGeometry args={[1, 0]} />
  } else if (def.kind === 'torus') {
    geometry = (
      <torusGeometry args={LOW_POWER ? [0.9, 0.26, 12, 28] : [0.9, 0.28, 18, 44]} />
    )
  } else {
    geometry = <octahedronGeometry args={[1, 0]} />
  }

  return (
    <Float speed={def.speed * 3} rotationIntensity={0.6} floatIntensity={1.4}>
      <mesh ref={mesh} position={def.position} scale={def.scale}>
        {geometry}
        <meshStandardMaterial
          ref={mat}
          color={def.color}
          emissive={def.color}
          emissiveIntensity={def.wireframe ? 0.9 : 0.32}
          wireframe={def.wireframe}
          transparent
          opacity={0}
          flatShading={!def.wireframe}
          roughness={0.35}
          metalness={0.55}
        />
      </mesh>
    </Float>
  )
}

function Blob({
  position,
  color,
  scale,
}: {
  position: [number, number, number]
  color: string
  scale: number
}) {
  const mesh = useRef<THREE.Mesh>(null)
  const mat = useRef<any>(null)

  useFrame((state, delta) => {
    if (!mesh.current || !mat.current) return
    const dist = Math.abs(mesh.current.position.y - state.camera.position.y)
    const target = THREE.MathUtils.clamp(1 - (dist - 5) / 12, 0, 1)
    mat.current.opacity = THREE.MathUtils.damp(
      mat.current.opacity,
      target * 0.34,
      5,
      delta
    )
  })

  return (
    <mesh ref={mesh} position={position} scale={scale}>
      <sphereGeometry args={[1, Q.blobSegments, Q.blobSegments]} />
      <MeshDistortMaterial
        ref={mat}
        color={color}
        emissive={color}
        emissiveIntensity={0.25}
        distort={LOW_POWER ? 0.4 : 0.55}
        speed={1.2}
        roughness={0.15}
        metalness={0.1}
        transparent
        opacity={0}
        depthWrite={false}
      />
    </mesh>
  )
}

function Particles() {
  const points = useRef<THREE.Points>(null)
  const count = Q.particles

  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3)
    for (let i = 0; i < count; i++) {
      arr[i * 3] = (hash(i * 3 + 7) - 0.5) * 22
      arr[i * 3 + 1] = 6 - hash(i * 3 + 8) * (PAGE_DEPTH + 12)
      arr[i * 3 + 2] = (hash(i * 3 + 9) - 0.5) * 14
    }
    return arr
  }, [])

  useFrame((_, delta) => {
    if (!points.current) return
    points.current.rotation.z += delta * 0.012
  })

  return (
    <points ref={points}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial
        size={0.035}
        color="#FFCBA8"
        transparent
        opacity={0.5}
        sizeAttenuation
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  )
}

function GlowLights() {
  const ember = useRef<THREE.PointLight>(null)
  const moss = useRef<THREE.PointLight>(null)

  useFrame((state) => {
    const t = state.clock.elapsedTime
    if (ember.current) {
      ember.current.position.y = state.camera.position.y + 4 + Math.sin(t * 0.5) * 1.5
    }
    if (moss.current) {
      moss.current.position.y = state.camera.position.y - 5 + Math.cos(t * 0.4) * 2
    }
  })

  return (
    <>
      <ambientLight intensity={0.45} />
      <directionalLight position={[6, 8, 6]} intensity={0.7} />
      <pointLight ref={ember} position={[5, 4, 2]} intensity={38} distance={22} color="#FF6B33" />
      <pointLight ref={moss} position={[-5, -5, 2]} intensity={30} distance={24} color="#2AA184" />
      {!LOW_POWER && (
        <pointLight position={[0, 0, 6]} intensity={10} distance={30} color="#FFB845" />
      )}
    </>
  )
}

export default function SceneCanvas() {
  const shapes = useShapeField(Q.shapes)

  return (
    <div className="fixed inset-0 z-0" aria-hidden="true">
      <Canvas
        dpr={[1, Q.dprMax]}
        camera={{ position: [0, 4, 9], fov: 58 }}
        gl={{
          antialias: Q.antialias,
          alpha: true,
          powerPreference: 'high-performance',
        }}
      >
        <ScrollRig />
        <GlowLights />
        <Particles />
        <Sparkles
          count={Q.sparkles}
          scale={[16, PAGE_DEPTH + 10, 8]}
          position={[0, -PAGE_DEPTH / 2, 0]}
          size={2.2}
          speed={0.35}
          color="#FFB845"
          opacity={0.5}
        />
        {shapes.map((def, i) => (
          <Shape key={i} def={def} />
        ))}
        <Blob position={[4.6, -3, -3]} color="#E85D2A" scale={2.1} />
        <Blob position={[-4.8, -13, -2]} color="#1F6F5C" scale={2.4} />
        <Blob position={[4.4, -23, -3]} color="#FFB845" scale={1.7} />
        <Blob position={[-4.2, -33, -2.5]} color="#E85D2A" scale={2.2} />
      </Canvas>
    </div>
  )
}
