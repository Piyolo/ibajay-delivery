# Vercel deploy — Ibajay Eats website (portfolio-ibajay)
#
# 1. Push this repo to GitHub (already done: Piyolo/ibajay-delivery, branch website-redesign).
# 2. Vercel dashboard → Add New → Project → import the repo.
# 3. Settings:
#      Root Directory: portfolio-ibajay
#      Framework Preset: Vite (auto-detected via vercel.json)
#      Build Command: npm run build
#      Output Directory: dist
# 4. Environment Variables (Project → Settings → Environment Variables):
#      VITE_API_URL = <your Render backend URL, e.g. https://ibajayeats-api.onrender.com>
#      (no trailing slash; required — the waitlist form calls $VITE_API_URL/api/v1/waitlist)
# 5. Deploy.
#
# Notes:
# - vercel.json handles SPA routing (all paths → index.html).
# - The backend (Render Docker service) must have CORS_ORIGINS including this
#   site's *.vercel.app domain(s) and any custom domain. render.yaml already sets
#   it to https://ibajayeatswebsite.onrender.com — update it if your Vercel
#   domain differs.
# - Free-tier Render backends sleep after ~15 min idle; first request after a
#   quiet period takes ~50s while the container wakes.
