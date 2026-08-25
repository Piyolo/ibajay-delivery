import { useEffect } from 'react'
import Lenis from 'lenis'
import { motion, useScroll, useSpring } from 'framer-motion'
import SceneCanvas from './three/SceneCanvas'
import Navbar from './components/Navbar'
import Hero from './components/Hero'
import Marquee from './components/Marquee'
import Stats from './components/Stats'
import ShowcaseSection from './components/ShowcaseSection'
import HowItWorks from './components/HowItWorks'
import BentoGrid from './components/BentoGrid'
import TechStack from './components/TechStack'
import CTA from './components/CTA'
import Footer from './components/Footer'
import {
  CustomerHome,
  FoodDetail,
  OrderTracking,
  ChatPreview,
  VendorDashboard,
  VendorMenu,
  VendorAnalytics,
} from './screens'
import { scrollState } from './lib/scroll'

const CUSTOMER_STEPS = [
  {
    title: 'Discover local stores',
    body: 'Browse verified carinderias and food stalls near you — filter by category, check ratings, opening hours, and delivery fees before you even get hungry.',
    screen: <CustomerHome />,
  },
  {
    title: 'Build your order',
    body: 'Tap into any dish for photos, descriptions, and extras like extra rice or sauce. Prices update live as you customize — no checkout surprises.',
    screen: <FoodDetail />,
  },
  {
    title: 'Track it home',
    body: 'Watch your order move through seven live statuses with a real-time ETA. You will know exactly when the rider turns down your street.',
    screen: <OrderTracking />,
  },
  {
    title: 'Talk to your vendor',
    body: 'Need to change something? Chat directly with the store while your food cooks — instant messages over WebSockets, no phone calls needed.',
    screen: <ChatPreview />,
  },
]

const VENDOR_STEPS = [
  {
    title: 'Run everything from one dashboard',
    body: 'Today\'s orders, revenue, and store status on a single screen. Flip your store open or closed in one tap.',
    screen: <VendorDashboard />,
  },
  {
    title: 'Own your menu',
    body: 'Add dishes, set prices, group items into categories, and flip availability when the batch runs out — customers see changes instantly.',
    screen: <VendorMenu />,
  },
  {
    title: 'Know your numbers',
    body: 'Revenue trends, top sellers, monthly order volume, and store ratings — simple analytics that tell you what to cook more of tomorrow.',
    screen: <VendorAnalytics />,
  },
]

export default function App() {
  useEffect(() => {
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

    const computeProgress = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight
      scrollState.progress = max > 0 ? window.scrollY / max : 0
    }

    let cleanupLenis: (() => void) | undefined
    if (!reduceMotion) {
      const lenis = new Lenis({ duration: 1.15, smoothWheel: true })
      lenis.on('scroll', (e: { progress?: number; velocity?: number }) => {
        scrollState.progress = e.progress ?? scrollState.progress
        scrollState.velocity = e.velocity ?? 0
      })
      let raf = 0
      const loop = (time: number) => {
        lenis.raf(time)
        raf = requestAnimationFrame(loop)
      }
      raf = requestAnimationFrame(loop)

      // smooth anchor scrolling through lenis
      const onClick = (ev: MouseEvent) => {
        const anchor = (ev.target as HTMLElement).closest?.('a[href^="#"]') as HTMLAnchorElement | null
        if (!anchor) return
        const id = anchor.getAttribute('href')!
        if (id.length <= 1) return
        const el = document.querySelector(id)
        if (!el) return
        ev.preventDefault()
        lenis.scrollTo(el as HTMLElement, { offset: 0, duration: 1.4 })
      }
      document.addEventListener('click', onClick)

      cleanupLenis = () => {
        cancelAnimationFrame(raf)
        document.removeEventListener('click', onClick)
        lenis.destroy()
      }
    } else {
      window.addEventListener('scroll', computeProgress, { passive: true })
    }
    computeProgress()

    return () => {
      cleanupLenis?.()
      window.removeEventListener('scroll', computeProgress)
    }
  }, [])

  return (
    <div className="relative min-h-screen overflow-x-clip">
      {/* fixed 3D universe behind everything */}
      <SceneCanvas />

      {/* film grain */}
      <div className="noise-overlay" aria-hidden="true" />

      <Navbar />

      <main className="relative">
        <Hero />
        <Marquee />
        <Stats />

        <ShowcaseSection
          id="customer"
          chip="Customer App"
          chipClass=""
          heading={
            <>
              Your whole town,
              <br />
              one tap away.
            </>
          }
          accent="ember"
          steps={CUSTOMER_STEPS}
        />

        <ShowcaseSection
          id="vendor"
          chip="Vendor App"
          chipClass="section-chip--moss"
          heading={
            <>
              The POS your
              <br />
              carinderia deserves.
            </>
          }
          accent="moss"
          steps={VENDOR_STEPS}
        />

        <HowItWorks />
        <BentoGrid />
        <TechStack />
        <CTA />
      </main>

      <Footer />

      {/* subtle scroll-progress bar */}
      <ScrollProgressBar />
    </div>
  )
}

function ScrollProgressBar() {
  return (
    <motion.div
      className="fixed bottom-0 left-0 right-0 z-50 h-[3px] origin-left bg-gradient-to-r from-gold via-ember to-moss-bright"
      style={{ scaleX: useWindowScrollSpring() }}
    />
  )
}

function useWindowScrollSpring() {
  const { scrollYProgress } = useScroll()
  return useSpring(scrollYProgress, { stiffness: 90, damping: 24, restDelta: 0.001 })
}
