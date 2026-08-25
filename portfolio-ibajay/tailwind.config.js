/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: {
          DEFAULT: '#0C0A09',
          soft: '#151110',
          card: '#1B1614',
          line: '#2A2320',
        },
        ember: {
          DEFAULT: '#E85D2A',
          dark: '#C44A1F',
          bright: '#F07A4E',
          soft: 'rgba(232, 93, 42, 0.12)',
        },
        moss: {
          DEFAULT: '#1F6F5C',
          bright: '#2AA184',
          soft: 'rgba(31, 111, 92, 0.14)',
        },
        gold: {
          DEFAULT: '#FFB845',
          soft: 'rgba(255, 184, 69, 0.12)',
        },
        cream: {
          DEFAULT: '#FAF7F4',
          muted: '#F1ECE8',
        },
      },
      fontFamily: {
        display: ['"Space Grotesk"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        body: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      animation: {
        marquee: 'marquee 28s linear infinite',
        float: 'float 7s ease-in-out infinite',
        'float-slow': 'float 11s ease-in-out infinite',
        'pulse-glow': 'pulseGlow 3.2s ease-in-out infinite',
        'spin-slower': 'spin 22s linear infinite',
        shimmer: 'shimmer 5s linear infinite',
      },
      keyframes: {
        marquee: {
          from: { transform: 'translateX(0)' },
          to: { transform: 'translateX(-50%)' },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0px)' },
          '50%': { transform: 'translateY(-16px)' },
        },
        pulseGlow: {
          '0%, 100%': { opacity: '0.55' },
          '50%': { opacity: '1' },
        },
        shimmer: {
          from: { backgroundPosition: '200% center' },
          to: { backgroundPosition: '-200% center' },
        },
      },
      boxShadow: {
        glow: '0 0 60px -12px rgba(232, 93, 42, 0.45)',
        'glow-moss': '0 0 60px -12px rgba(31, 111, 92, 0.55)',
        phone: '0 40px 90px -20px rgba(0, 0, 0, 0.75)',
      },
    },
  },
  plugins: [],
}
