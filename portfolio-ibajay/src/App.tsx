import React, { useRef, useEffect } from 'react'
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import Lenis from 'lenis'
import { motion } from 'framer-motion'
import './styles/global.css'

function SmoothScroll() {
  const lenis = useRef(Lenis)

  useEffect(() => {
    const lenisRef = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      loop: false,
    })

    lenis.current = lenisRef

    function raf(time: number) {
      lenisRef.update(time)
      requestAnimationFrame(raf)
    }

    requestAnimationFrame(raf)

    return () => {
      lenis.current = undefined
    }
  }, [])

  return null
}

export default function App() {
  return (
    <div className="min-h-screen bg-black text-white overflow-x-hidden">
      <SmoothScroll />

      <Canvas camera={{ position: [0, 0, 10] }}>
        <ambientLight intensity={0.5} />
        <directionalLight position={[5, 5, 5]} intensity={1} />
        <OrbitControls enableZoom={false} enablePan={false} />

        <group rotation={[-0.3, 0, 0]}>
          <boxGeometry args={[4, 4, 4]} />
          <meshStandardMaterial color="#E85D2A" opacity={0.6} transparent />
        </group>

        <group position={[-6, 0, 0]} rotation={[-0.3, 0, 0]}>
          <boxGeometry args={[4, 4, 4]} />
          <meshStandardMaterial color="#1F6F5C" opacity={0.6} transparent />
        </group>

        <group position={[6, 0, 0]} rotation={[-0.3, 0, 0]}>
          <boxGeometry args={[4, 4, 4]} />
          <meshStandardMaterial color="#FFB845" opacity={0.6} transparent />
        </group>
      </Canvas>

      <nav className="fixed top-0 left-0 right-0 z-50 py-6 px-6 md:px-12">
        <div className="max-w-7xl mx-auto flex justify-between items-center">
          <h1 className="text-2xl md:text-3xl font-bold tracking-wider">
            <span className="text-emerald-400">IB</span>JAY
          </h1>
          <ul className="flex gap-8 md:gap-12">
            <li>
              <a
                href="#projects"
                className="relative text-white hover:text-emerald-400 transition-colors"
              >
                Projects
              </a>
            </li>
            <li>
              <a
                href="#about"
                className="relative text-white hover:text-emerald-400 transition-colors"
              >
                About
              </a>
            </li>
            <li>
              <a
                href="#contact"
                className="relative text-white hover:text-emerald-400 transition-colors"
              >
                Contact
              </a>
            </li>
          </ul>
        </div>
      </nav>

      <main className="relative z-10 min-h-screen">
        <section id="hero" className="min-h-screen flex items-center justify-center">
          <div className="text-center">
            <h2 className="motion-reduce:transition-none text-4xl md:text-5xl font-bold mb-4">
              Modern Flutter & Backend Portfolio
            </h2>
            <p className="motion-reduce:transition-none text-lg md:text-xl text-gray-300 max-w-2xl mx-auto mb-12">
              A showcase of IbajayDelivery — a complete local food delivery platform built with
              Flutter, FastAPI, and React, featuring customer apps, vendor panels, and admin dashboards.
            </p>
            <div className="motion-reduce:grid-cols-1 grid-cols-2 gap-4 max-w-md mx-auto">
              <a
                href="https://github.com/PioloMangilog/ibajaydelivery"
                className="group relative inline-block px-6 py-3 text-lg font-medium text-white bg-emerald-600 rounded-full hover:bg-emerald-500 transition-colors"
              >
                GitHub Repo
              </a>
              <a
                href="#contact"
                className="group relative inline-block px-6 py-3 text-lg font-medium text-white bg-transparent border-2 border-white rounded-full hover:bg-white hover-text-black transition-colors"
              >
                Get in Touch
              </a>
            </div>
          </div>
        </section>

        <section id="projects" className="py-24 md:py-32">
          <div className="max-w-7xl mx-auto px-6">
            <h2 className="text-3xl md:text-4xl font-bold mb-12 text-center">
              Featured Projects
            </h2>
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {/* Customer App Card */}
              <motion.div
                className="group rounded-2xl overflow-hidden bg-gray-800 hover:bg-gray-700 transition-colors duration-300"
                whileHover={{ scale: 1.02, y: -10 }}
              >
                <div className="p-6">
                  <h3 className="text-xl font-medium mb-2">Ibajay Eats Customer</h3>
                  <p className="text-sm text-gray-300">
                    Flutter mobile app — full auth, search, cart, checkout, live order tracking,
                    chat, favorites, and settings with 7-step order status.
                  </p>
                </div>
              </motion.div>

              {/* Vendor App Card */}
              <motion.div
                className="group rounded-2xl overflow-hidden bg-gray-800 hover:bg-gray-700 transition-colors duration-300"
                whileHover={{ scale: 1.02, y: -10 }}
              >
                <div className="p-6">
                  <h3 className="text-xl font-medium mb-2">Ibajay Eats Vendor</h3>
                  <p className="text-sm text-gray-300">
                    Flutter vendor app — store management, menu CRUD, orders dashboard, delivery
                    tracking, analytics with barchart, and chat interface.
                  </p>
                </div>
              </motion.div>

              {/* Admin Dashboard Card */}
              <motion.div
                className="group rounded-2xl overflow-hidden bg-gray-800 hover:bg-gray-700 transition-colors duration-300"
                whileHover={{ scale: 1.02, y: -10 }}
              >
                <div className="p-6">
                  <h3 className="text-xl font-medium mb-2">Admin Dashboard</h3>
                  <p className="text-sm text-gray-300">
                    React admin console — 3 roles (Developer/Manager/Staff), KPIs, vendor/order
                    analytics, paginated tables, and audit logs.
                  </p>
                </div>
              </motion.div>
            </div>
          </div>
        </section>

        <section id="about" className="py-24 md:py-32 bg-gray-900">
          <div className="max-w-7xl mx-auto px-6">
            <div className="grid md:grid-cols-2 gap-12 items-center">
              <div>
                <h2 className="text-3xl md:text-4xl font-bold mb-6">
                  About the Platform
                </h2>
                <p className="text-lg text-gray-300 leading-relaxed">
                  Ibajay Eats is a complete local food delivery platform connecting customers
                  with local stores. The project spans three interfaces:
                </p>
                <ul className="list-disc list-inside space-y-4 text-gray-300">
                  <li>
                    <strong>Customer App:</strong> Browse vendors, place orders (delivery/pickup/scheduled),
                    track live order status, manage favorites and addresses, and chat with vendors.
                  </li>
                  <li>
                    <strong>Vendor App:</strong> Manage menu, view/accept orders, track deliveries,
                    view analytics, and configure store settings.
                  </li>
                  <li>
                    <strong>Admin Dashboard:</strong> Internal console with 3 roles for vendor
                    verification, platform analytics, and user/category management.
                  </li>
                </ul>
                <p className="mt-6 text-lg text-gray-300">
                  Built with Flutter for mobile, FastAPI for the backend, and React for the
                  admin dashboard. All components are mock-first, with clear seams for backend
                  integration.
                </p>
              </div>
              <div className="relative">
                <div className="relative h-64 w-64 rounded-2xl overflow-hidden bg-gradient-to-br from-emerald-600 to-emerald-500">
                  <div className="absolute inset-0 flex items-center justify-center">
                    <svg className="w-24 h-24 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M22 11.08V12a10 10 0 1 1-5.94-9.14" />
                      <polyline points="22 4 12 14 9 10" />
                      <line x1="12" y1="1" x2="12" y2="3" />
                      <line x1="12" y1="23" x2="12" y2="21" />
                    </svg>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section id="contact" className="py-24 md:py-32 bg-black">
          <div className="max-w-4xl mx-auto px-6">
            <h2 className="text-3xl md:text-4xl font-bold mb-12 text-center">
              Get in Touch
            </h2>
            <form className="space-y-6">
              <div>
                <label className="block text-sm font-medium mb-2">
                  Name
                </label>
                <input
                  type="text"
                  placeholder="Your name"
                  className="w-full px-4 py-3 bg-gray-800 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">
                  Email
                </label>
                <input
                  type="email"
                  placeholder="your@email.com"
                  className="w-full px-4 py-3 bg-gray-800 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">
                  Message
                </label>
                <textarea
                  rows={4}
                  placeholder="How can I help?..."
                  className="w-full px-4 py-3 bg-gray-800 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-emerald-500 resize-none"
                ></textarea>
              </div>
              <button
                type="submit"
                className="w-full px-6 py-3 text-lg font-medium text-white bg-emerald-600 rounded-full hover:bg-emerald-500 transition-colors"
              >
                Send Message
              </button>
            </form>
          </div>
        </section>
      </main>
    </div>
  )
}