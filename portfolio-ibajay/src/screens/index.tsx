/* Mini recreations of the real Ibajay Eats app screens — pure CSS/JSX, no images needed. */

const StatusBar = () => (
  <div className="flex items-center justify-between px-2 text-[9px] font-semibold text-white/85">
    <span>9:41</span>
    <span className="flex items-center gap-1">
      <svg width="12" height="8" viewBox="0 0 14 10" fill="currentColor" aria-hidden>
        <rect x="0" y="6" width="2.5" height="4" rx="0.5" />
        <rect x="3.5" y="4" width="2.5" height="6" rx="0.5" />
        <rect x="7" y="2" width="2.5" height="8" rx="0.5" />
        <rect x="10.5" y="0" width="2.5" height="10" rx="0.5" />
      </svg>
      <span className="inline-block h-[9px] w-[16px] rounded-[3px] border border-white/70 p-[1.5px]">
        <span className="block h-full w-3/4 rounded-[1px] bg-white/80" />
      </span>
    </span>
  </div>
)

const SearchPill = () => (
  <div className="mt-2 flex items-center gap-1.5 rounded-full bg-white/[0.07] border border-white/10 px-2.5 py-1.5">
    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#716A63" strokeWidth="2.5" aria-hidden>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </svg>
    <span className="text-[8px] text-[#716A63]">Carinderia, burgers, halo-halo...</span>
  </div>
)

/* ---------------- Customer screens ---------------- */

export function CustomerHome() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] px-3 pb-2 text-left overflow-hidden">
      <StatusBar />
      <div className="mt-2 flex items-center justify-between">
        <div>
          <p className="text-[7px] font-medium text-[#716A63]">DELIVER TO</p>
          <p className="text-[9px] font-bold text-[#1D1A17]">Poblacion, Ibajay</p>
        </div>
        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-ember text-[9px] font-bold text-white">
          P
        </span>
      </div>

      <SearchPill />

      <div className="mt-2.5 flex gap-1.5">
        {['All', 'Meals', 'Fast Food', 'Desserts'].map((c, i) => (
          <span
            key={c}
            className={`rounded-full px-2 py-[3px] text-[7.5px] font-semibold ${
              i === 0 ? 'bg-ember text-white' : 'bg-[#F1ECE8] text-[#716A63]'
            }`}
          >
            {c}
          </span>
        ))}
      </div>

      {/* featured card */}
      <div className="mt-2.5 rounded-xl bg-white border border-[#E7E1DB] overflow-hidden shadow-sm">
        <div className="h-12 bg-gradient-to-br from-ember via-[#F07A4E] to-gold relative">
          <span className="absolute bottom-1 left-1.5 rounded-md bg-black/35 px-1.5 py-[2px] text-[6.5px] font-semibold text-white backdrop-blur-sm">
            FEATURED
          </span>
        </div>
        <div className="p-2">
          <div className="flex items-center justify-between">
            <p className="text-[9px] font-bold text-[#1D1A17]">Chicken Adobo Rice Meal</p>
            <span className="text-[9px] font-bold text-ember">₱95</span>
          </div>
          <p className="text-[7px] text-[#716A63] mt-0.5">Soy-vinegar braised chicken, garlic rice</p>
          <div className="mt-1 flex items-center gap-1">
            <span className="text-gold text-[8px]" aria-hidden>★★★★★</span>
            <span className="text-[6.5px] text-[#716A63]">Aling Nena's · 20 min</span>
          </div>
        </div>
      </div>

      {/* vendor card */}
      <div className="mt-2 rounded-xl bg-white border border-[#E7E1DB] p-2 shadow-sm">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-moss text-[8px] font-bold text-white">
            AN
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[9px] font-bold text-[#1D1A17]">Aling Nena's Carinderia</p>
            <p className="text-[7px] text-[#716A63]">Filipino · Meals · Rizal St.</p>
          </div>
          <span className="rounded-full bg-moss/15 px-1.5 py-[2px] text-[6.5px] font-bold text-moss-bright">
            OPEN
          </span>
        </div>
        <div className="mt-1.5 flex items-center gap-2 text-[7px] text-[#716A63]">
          <span className="font-semibold text-[#1D1A17]">★ 4.7</span>
          <span>(128)</span>
          <span className="ml-auto rounded-md bg-[#F1ECE8] px-1.5 py-[2px] font-medium">₱25 base fee</span>
        </div>
      </div>

      <div className="mt-2 rounded-xl bg-white border border-[#E7E1DB] p-2 shadow-sm opacity-70">
        <div className="flex items-center gap-2">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-ember text-[8px] font-bold text-white">
            BB
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[9px] font-bold text-[#1D1A17]">Ibajay Burger Bites</p>
            <p className="text-[7px] text-[#716A63]">Fast Food · National Highway</p>
          </div>
          <span className="text-[8px] font-semibold text-[#1D1A17]">★ 4.5</span>
        </div>
      </div>
    </div>
  )
}

export function FoodDetail() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <div className="h-[34%] bg-gradient-to-br from-[#C44A1F] via-ember to-gold relative">
        <div className="absolute top-2 left-2 h-5 w-5 rounded-full bg-white/90 flex items-center justify-center text-[9px] text-[#1D1A17]">
          ←
        </div>
      </div>
      <div className="-mt-3 flex-1 rounded-t-2xl bg-[#FAF7F4] px-3 pt-3">
        <p className="text-[11px] font-bold text-[#1D1A17]">Sinigang na Baboy (Bowl)</p>
        <p className="text-[7.5px] text-[#716A63] mt-0.5 leading-relaxed">
          Tamarind pork soup with fresh vegetables. Best served with extra rice.
        </p>
        <div className="mt-1.5 flex items-center justify-between">
          <span className="text-[12px] font-bold text-ember">₱110</span>
          <div className="flex items-center gap-2 rounded-full bg-white border border-[#E7E1DB] px-2 py-1">
            <span className="text-[9px] text-ember font-bold">−</span>
            <span className="text-[9px] font-bold text-[#1D1A17]">1</span>
            <span className="text-[9px] text-ember font-bold">+</span>
          </div>
        </div>

        <p className="mt-2.5 text-[8px] font-bold uppercase tracking-wide text-[#716A63]">Extras</p>
        {[
          ['Extra Rice', '+₱15'],
          ['Extra Sauce', '+₱10'],
        ].map(([label, price], i) => (
          <label key={label} className="mt-1.5 flex items-center gap-2 rounded-lg bg-white border border-[#E7E1DB] px-2 py-1.5">
            <span
              className={`h-3 w-3 rounded-[4px] border ${
                i === 0 ? 'bg-ember border-ember' : 'border-[#E7E1DB]'
              } flex items-center justify-center text-[7px] text-white`}
            >
              {i === 0 ? '✓' : ''}
            </span>
            <span className="text-[8px] font-medium text-[#1D1A17]">{label}</span>
            <span className="ml-auto text-[8px] font-semibold text-[#716A63]">{price}</span>
          </label>
        ))}

        <button className="mt-2.5 w-full rounded-xl bg-ember py-2 text-[9px] font-bold text-white shadow-lg shadow-ember/30">
          Add to Cart · ₱125
        </button>
      </div>
    </div>
  )
}

export function OrderTracking() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      {/* map */}
      <div className="relative h-[36%] bg-[#EAF0EC] overflow-hidden">
        <div
          className="absolute inset-0 opacity-60"
          style={{
            backgroundImage:
              'linear-gradient(#d3ddd6 1px, transparent 1px), linear-gradient(90deg, #d3ddd6 1px, transparent 1px)',
            backgroundSize: '22px 22px',
          }}
        />
        <svg className="absolute inset-0 h-full w-full" viewBox="0 0 100 70" fill="none" aria-hidden>
          <path d="M8 62 C 30 58, 28 30, 52 26 S 88 18, 92 8" stroke="#1F6F5C" strokeWidth="2.5" strokeDasharray="5 4" strokeLinecap="round" />
          <circle cx="8" cy="62" r="4" fill="#1F6F5C" />
          <circle cx="92" cy="8" r="4" fill="#E85D2A" />
          <circle cx="55" cy="27" r="5.5" fill="#fff" />
          <circle cx="55" cy="27" r="3.5" fill="#E85D2A" />
        </svg>
        <div className="absolute left-2 top-2 rounded-full bg-white px-2 py-1 text-[7px] font-bold text-[#1D1A17] shadow">
          ETA · 15 min
        </div>
      </div>

      <div className="flex-1 -mt-3 rounded-t-2xl bg-[#FAF7F4] px-3 pt-3">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-[7px] font-semibold uppercase tracking-wide text-ember">Out for delivery</p>
            <p className="text-[10px] font-bold text-[#1D1A17]">Order #1042 · ₱220</p>
          </div>
          <span className="rounded-full bg-ember px-2.5 py-1 text-[7.5px] font-bold text-white animate-pulse-glow">
            LIVE
          </span>
        </div>

        <div className="mt-2.5 space-y-2">
          {[
            ['Order accepted', true],
            ['Preparing your food', true],
            ['Rider on the way', true],
            ['Delivered', false],
          ].map(([step, done], i) => (
            <div key={String(step)} className="flex items-center gap-2">
              <span
                className={`flex h-4 w-4 items-center justify-center rounded-full text-[7px] font-bold ${
                  done ? 'bg-moss text-white' : 'border border-dashed border-[#B9B0A8] text-transparent'
                } ${i === 2 ? 'ring-4 ring-moss/15' : ''}`}
              >
                ✓
              </span>
              <div className="flex-1">
                <p className={`text-[8.5px] font-semibold ${done ? 'text-[#1D1A17]' : 'text-[#B9B0A8]'}`}>
                  {step}
                </p>
              </div>
              {i === 2 && (
                <span className="text-[7px] font-medium text-[#716A63]">Kuya Jun · Motorcycle</span>
              )}
            </div>
          ))}
        </div>

        <div className="mt-2.5 flex gap-2">
          <button className="flex-1 rounded-xl bg-ember py-1.5 text-[8.5px] font-bold text-white">Chat vendor</button>
          <button className="flex-1 rounded-xl bg-white border border-[#E7E1DB] py-1.5 text-[8.5px] font-bold text-[#1D1A17]">
            View order
          </button>
        </div>
      </div>
    </div>
  )
}

export function ChatPreview() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <div className="flex items-center gap-2 border-b border-[#E7E1DB] bg-white px-3 py-2">
        <span className="text-[10px] text-[#1D1A17]">←</span>
        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-moss text-[8px] font-bold text-white">AN</span>
        <div>
          <p className="text-[9px] font-bold text-[#1D1A17]">Aling Nena's Carinderia</p>
          <p className="text-[6.5px] font-semibold text-moss-bright">Online now</p>
        </div>
      </div>

      <div className="flex-1 space-y-2 px-3 py-3">
        <div className="max-w-[75%] rounded-2xl rounded-bl-md bg-white border border-[#E7E1DB] px-2.5 py-1.5">
          <p className="text-[8px] text-[#1D1A17]">Hi! Na-receive na ang order mo.</p>
          <p className="text-right text-[6px] text-[#B9B0A8]">9:38 AM</p>
        </div>
        <div className="max-w-[75%] ml-auto rounded-2xl rounded-br-md bg-ember px-2.5 py-1.5">
          <p className="text-[8px] text-white">Salamat! Extra rice ha.</p>
          <p className="text-right text-[6px] text-white/70">9:39 AM · Read</p>
        </div>
        <div className="max-w-[75%] rounded-2xl rounded-bl-md bg-white border border-[#E7E1DB] px-2.5 py-1.5">
          <p className="text-[8px] text-[#1D1A17]">Oo, isasama ko na. Malapit nang lutuin!</p>
          <p className="text-right text-[6px] text-[#B9B0A8]">9:40 AM</p>
        </div>
        <div className="flex w-fit items-center gap-1 rounded-full bg-white border border-[#E7E1DB] px-2.5 py-2">
          {[0, 1, 2].map((i) => (
            <span key={i} className="h-1 w-1 rounded-full bg-[#B9B0A8] animate-pulse-glow" style={{ animationDelay: `${i * 0.25}s` }} />
          ))}
        </div>
      </div>

      <div className="mx-3 mb-3 flex items-center gap-2 rounded-full bg-white border border-[#E7E1DB] px-3 py-1.5">
        <span className="text-[8px] text-[#B9B0A8] flex-1">Type a message...</span>
        <span className="flex h-5 w-5 items-center justify-center rounded-full bg-ember text-[8px] text-white">➤</span>
      </div>
    </div>
  )
}

/* ---------------- Vendor screens ---------------- */

export function VendorDashboard() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#101613] px-3 pb-2 text-left overflow-hidden">
      <StatusBar />
      <div className="mt-2 flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <span className="flex h-6 w-6 items-center justify-center rounded-lg bg-moss text-[8px] font-bold text-white">AN</span>
          <div>
            <p className="text-[9px] font-bold text-white">Aling Nena's</p>
            <p className="text-[6.5px] text-emerald-300/80">Vendor Dashboard</p>
          </div>
        </div>
        <span className="flex items-center gap-1 rounded-full bg-emerald-400/10 border border-emerald-400/30 px-2 py-[3px]">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse-glow" />
          <span className="text-[7px] font-bold text-emerald-300">OPEN</span>
        </span>
      </div>

      <div className="mt-2.5 grid grid-cols-2 gap-2">
        {[
          ['Orders today', '12', '+4 vs yesterday'],
          ['Revenue', '₱2,340', '+18% this week'],
        ].map(([label, value, sub]) => (
          <div key={label} className="rounded-xl border border-white/10 bg-white/[0.05] p-2">
            <p className="text-[6.5px] uppercase tracking-wide text-white/50">{label}</p>
            <p className="text-[13px] font-bold text-white mt-0.5">{value}</p>
            <p className="text-[6.5px] font-semibold text-emerald-300/80 mt-0.5">{sub}</p>
          </div>
        ))}
      </div>

      {/* mini chart */}
      <div className="mt-2 rounded-xl border border-white/10 bg-white/[0.05] p-2">
        <p className="text-[6.5px] uppercase tracking-wide text-white/50">Sales · last 7 days</p>
        <div className="mt-1.5 flex h-12 items-end gap-1.5">
          {[35, 55, 42, 78, 60, 92, 70].map((h, i) => (
            <div
              key={i}
              className="flex-1 rounded-t-sm bg-gradient-to-t from-moss to-moss-bright"
              style={{ height: `${h}%`, opacity: 0.45 + (h / 100) * 0.55 }}
            />
          ))}
        </div>
      </div>

      {/* incoming order */}
      <div className="mt-2 flex-1 rounded-xl border border-gold/25 bg-gold/[0.06] p-2">
        <div className="flex items-center justify-between">
          <p className="text-[8px] font-bold text-white">New order #1042</p>
          <span className="rounded-full bg-gold/20 px-1.5 py-[2px] text-[6.5px] font-bold text-gold">PENDING</span>
        </div>
        <p className="mt-1 text-[7.5px] text-white/60">1× Chicken Adobo · 1× Sinigang · 1× Extra Rice</p>
        <p className="text-[8px] font-bold text-gold mt-1">Total: ₱235</p>
        <div className="mt-1.5 flex gap-1.5">
          <button className="flex-1 rounded-lg bg-moss-bright py-1 text-[7.5px] font-bold text-white">Accept</button>
          <button className="flex-1 rounded-lg border border-white/15 py-1 text-[7.5px] font-bold text-white/70">Reject</button>
        </div>
      </div>
    </div>
  )
}

export function VendorMenu() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <div className="flex items-center justify-between bg-white border-b border-[#E7E1DB] px-3 py-2">
        <p className="text-[10px] font-bold text-[#1D1A17]">Menu Manager</p>
        <span className="rounded-full bg-ember px-2 py-[3px] text-[7px] font-bold text-white">+ New item</span>
      </div>

      <div className="flex-1 space-y-2 px-3 py-2.5">
        {[
          ['Chicken Adobo Rice Meal', '₱95', 'Meals', true],
          ['Sinigang na Baboy', '₱110', 'Meals', true],
          ['Halo-Halo', '₱65', 'Desserts', false],
          ['Iced Tea (Large)', '₱35', 'Drinks', true],
        ].map(([name, price, cat, available]) => (
          <div key={String(name)} className="rounded-xl bg-white border border-[#E7E1DB] p-2 flex items-center gap-2">
            <span className="h-8 w-8 rounded-lg bg-gradient-to-br from-ember/80 to-gold/80 shrink-0" />
            <div className="min-w-0 flex-1">
              <p className="truncate text-[8.5px] font-bold text-[#1D1A17]">{name}</p>
              <p className="text-[7px] text-[#716A63]">
                {cat} · <span className="font-semibold text-ember">{price}</span>
              </p>
            </div>
            <span
              className={`relative h-4 w-7 rounded-full transition-colors ${
                available ? 'bg-moss' : 'bg-[#D8D1CA]'
              }`}
            >
              <span
                className={`absolute top-[2px] h-3 w-3 rounded-full bg-white shadow ${
                  available ? 'right-[2px]' : 'left-[2px]'
                }`}
              />
            </span>
          </div>
        ))}

        <div className="rounded-xl border border-dashed border-[#D8D1CA] p-2 text-center">
          <p className="text-[8px] font-semibold text-[#716A63]">Categories: Meals · Desserts · Drinks</p>
        </div>
      </div>
    </div>
  )
}

export function VendorAnalytics() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#101613] px-3 pb-2 text-left overflow-hidden">
      <StatusBar />
      <p className="mt-2 text-[10px] font-bold text-white">Analytics</p>
      <p className="text-[6.5px] text-white/50">This month · Ibajay, Aklan</p>

      <div className="mt-2 rounded-xl border border-white/10 bg-white/[0.05] p-2.5">
        <p className="text-[6.5px] uppercase tracking-wide text-white/50">Total revenue</p>
        <p className="text-[17px] font-bold text-gradient">₱31,450</p>
        <div className="mt-1.5 flex h-16 items-end gap-1">
          {[30, 48, 38, 65, 52, 82, 74, 95].map((h, i) => (
            <div key={i} className="flex-1 space-y-[2px]">
              <div className="rounded-t-sm bg-gradient-to-t from-ember-dark to-ember-bright" style={{ height: `${h * 0.56}px` }} />
            </div>
          ))}
        </div>
        <div className="mt-1 flex justify-between text-[5.5px] text-white/40">
          <span>W1</span><span>W2</span><span>W3</span><span>W4</span>
        </div>
      </div>

      <p className="mt-2 text-[6.5px] uppercase tracking-wide text-white/50">Top sellers</p>
      <div className="mt-1 space-y-1.5">
        {[
          ['Chicken Adobo Rice Meal', 92],
          ['Sinigang na Baboy', 64],
          ['Halo-Halo', 38],
        ].map(([item, pct]) => (
          <div key={String(item)} className="rounded-lg border border-white/10 bg-white/[0.04] px-2 py-1.5">
            <div className="flex justify-between">
              <p className="text-[8px] font-semibold text-white/90 truncate">{item}</p>
              <p className="text-[7.5px] font-bold text-gold">{pct}%</p>
            </div>
            <div className="mt-1 h-1 rounded-full bg-white/10">
              <div className="h-full rounded-full bg-gradient-to-r from-gold to-ember" style={{ width: `${pct}%` }} />
            </div>
          </div>
        ))}
      </div>

      <div className="mt-auto grid grid-cols-2 gap-2 pt-2">
        <div className="rounded-lg border border-white/10 bg-white/[0.05] p-1.5 text-center">
          <p className="text-[10px] font-bold text-white">186</p>
          <p className="text-[6px] text-white/50">orders / month</p>
        </div>
        <div className="rounded-lg border border-white/10 bg-white/[0.05] p-1.5 text-center">
          <p className="text-[10px] font-bold text-emerald-300">★ 4.7</p>
          <p className="text-[6px] text-white/50">store rating</p>
        </div>
      </div>
    </div>
  )
}
