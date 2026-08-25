# Ibajay Eats — Showcase Website

Marketing site for **Ibajay Eats**, the local food delivery platform for Ibajay, Aklan.
Showcases the Customer App (Flutter) and Vendor App (Flutter) with a scroll-driven 3D experience.

**Live at:** https://ibajayeats.linkpc.net

## Stack

- React 18 + TypeScript + Vite
- Three.js via @react-three/fiber + drei (scroll-reactive 3D scene)
- Framer Motion (scroll-linked section animations)
- Lenis (smooth scrolling)
- Tailwind CSS

## Develop

```bash
npm install
npm run dev      # local dev server
npm run build    # production build -> dist/
npm run preview  # preview the production build
```

## Deploy to Render (Static Site)

1. Push this folder to GitHub (see below).
2. On [render.com](https://render.com) → **New → Static Site** → connect the repo.
3. Settings:
   - **Build Command:** `npm install && npm run build`
   - **Publish Directory:** `dist`
4. Deploy. You'll get a URL like `https://ibajay-eats.onrender.com`.

## Point the domain

1. In Render: Static Site → **Custom Domains** → add `ibajayeats.linkpc.net`.
2. At your DNS provider for `linkpc.net` (where the subdomain is managed), add:
   - Type: `CNAME`
   - Host: `ibajayeats`
   - Value: `<your-site>.onrender.com`
3. Wait for DNS propagation and certificate provisioning.

## Push to GitHub

```bash
cd portfolio-ibajay
git init
git add .
git commit -m "Ibajay Eats showcase site"
git branch -M main
git remote add origin https://github.com/<your-user>/<repo-name>.git
git push -u origin main
```

Render auto-redeploys on every push to `main`.
