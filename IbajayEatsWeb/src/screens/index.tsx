/* Mini recreations of the REAL Ibajay Eats app screens — pure CSS/JSX, no images needed.
   Structure, colors, and copy mirror the Flutter apps (AppColors tokens, Material 3 light
   theme, real screen layouts). Sample data only — no real stores or review counts. */

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

/* ---------------- shared bits (mirror Flutter widgets) ---------------- */

/** AppColors.warning star + numeric rating, like RatingStars in common.dart */
const RatingStars = ({ rating }: { rating: number }) => (
  <span className="flex items-center gap-0.5">
    <span className="text-[#E0A72E] text-[8px]" aria-hidden>★</span>
    <span className="text-[7px] font-semibold text-[#1D1A17]">{rating.toFixed(1)}</span>
  </span>
)

/** Bottom navigation bar from main_shell.dart */
const BottomNav = ({ active = 'Home' }: { active?: string }) => {
  const items: [string, string][] = [
    ['Home', 'M3 10 L12 3 L21 10 V21 H14 V15 H10 V21 H3 Z'],
    ['Orders', 'M5 3 H19 V21 L12 17 L5 21 Z'],
    ['Chats', 'M4 4 H20 V16 H8 L4 20 Z'],
    ['Favorites', 'M12 21 C6 16 2 12.5 2 8.8 C2 6 4.2 4 7 4 C9 4 11 5.2 12 7 C13 5.2 15 4 17 4 C19.8 4 22 6 22 8.8 C22 12.5 18 16 12 21 Z'],
    ['Profile', 'M12 12 A4 4 0 1 0 12 4 A4 4 0 0 0 12 12 M4 21 C4 16.5 7.5 14 12 14 C16.5 14 20 16.5 20 21'],
  ]
  return (
    <div className="mt-auto flex items-stretch justify-around border-t border-[#E7E1DB] bg-white px-1 pt-1 pb-1.5">
      {items.map(([label, d]) => {
        const on = label === active
        return (
          <span key={label} className="flex flex-col items-center gap-0.5 px-1.5">
            <svg width="13" height="13" viewBox="0 0 24 24" fill={on ? '#E85D2A' : 'none'} stroke={on ? '#E85D2A' : '#716A63'} strokeWidth="1.8" strokeLinejoin="round" aria-hidden>
              <path d={d} />
            </svg>
            <span className={`text-[5.5px] font-semibold ${on ? 'text-ember' : 'text-[#716A63]'}`}>{label}</span>
          </span>
        )
      })}
    </div>
  )
}

/** SectionHeader from common.dart */
const SectionHeader = ({ title, action }: { title: string; action?: string }) => (
  <div className="mt-2 flex items-center justify-between">
    <p className="text-[8.5px] font-bold text-[#1D1A17]">{title}</p>
    {action && <span className="text-[7px] font-semibold text-ember">{action}</span>}
  </div>
)

/** Fulfillment tag pills from VendorCard (_tag) */
const Tag = ({ label, icon }: { label: string; icon: string }) => (
  <span className="flex items-center gap-0.5 rounded-md bg-[#F1ECE8] px-1 py-[1.5px] text-[6px] font-medium text-[#716A63]">
    <span aria-hidden>{icon}</span> {label}
  </span>
)

/* ---------------- customer app ---------------- */

export function CustomerHome() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      {/* AppBar: location selector + cart (home_screen.dart) */}
      <div className="flex items-center justify-between bg-white px-3 pb-1.5 pt-2 shadow-sm">
        <div className="flex items-center gap-1">
          <svg width="8" height="8" viewBox="0 0 24 24" fill="#E85D2A" aria-hidden>
            <path d="M12 2a7 7 0 0 0-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z" />
          </svg>
          <span className="max-w-[90px] truncate text-[8px] font-bold text-[#1D1A17]">Poblacion, Ibajay</span>
          <svg width="7" height="7" viewBox="0 0 24 24" fill="#716A63" aria-hidden><path d="M7 10l5 5 5-5z" /></svg>
        </div>
        <span className="relative flex h-5 w-5 items-center justify-center">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#1D1A17" strokeWidth="2" aria-hidden>
            <circle cx="9" cy="21" r="1.6" /><circle cx="19" cy="21" r="1.6" />
            <path d="M2 3h3l2.6 12.5a1.8 1.8 0 0 0 1.8 1.5h8.9a1.8 1.8 0 0 0 1.8-1.4L23 7H6" />
          </svg>
          <span className="absolute -right-1 -top-1 flex h-2.5 w-2.5 items-center justify-center rounded-full bg-ember text-[5.5px] font-bold text-white">2</span>
        </span>
      </div>

      <div className="flex-1 overflow-hidden px-3 pt-2">
        {/* search field */}
        <div className="flex items-center gap-1.5 rounded-lg border border-[#E7E1DB] bg-white px-2 py-1.5">
          <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="#716A63" strokeWidth="2.5" aria-hidden>
            <circle cx="11" cy="11" r="7" /><path d="m20 20-3.5-3.5" />
          </svg>
          <span className="text-[7.5px] text-[#716A63]">Search food or store name</span>
        </div>

        {/* category chips */}
        <div className="mt-1.5 flex gap-1">
          {['All', 'Meals', 'Fast Food', 'Snacks'].map((c, i) => (
            <span
              key={c}
              className={`rounded-full border px-1.5 py-[2px] text-[6.5px] font-semibold ${
                i === 0 ? 'border-ember bg-ember/15 text-ember' : 'border-[#E7E1DB] bg-white text-[#716A63]'
              }`}
            >
              {c}
            </span>
          ))}
        </div>

        <SectionHeader title="Featured Foods" />
        {/* Featured Foods carousel — two visible cards like the horizontal ListView */}
        <div className="mt-1 flex gap-1.5">
          {[
            ['Chicken Adobo', "Aling Nena's", '₱95', '#C44A1F'],
            ['Halo-halo', 'Iceberg Snacks', '₱55', '#1F6F5C'],
          ].map(([name, store, price, tint]) => (
            <div key={String(name)} className="w-[46%] rounded-xl border border-[#E7E1DB] bg-white p-1.5 shadow-sm">
              <div
                className="flex h-11 items-center justify-center rounded-lg"
                style={{ background: `linear-gradient(135deg, ${tint}33, #FFB84555)` }}
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={String(tint)} strokeWidth="2" aria-hidden>
                  <path d="M4 18h16M6 10v4m4-8v8m4-6v6m4-9v9" strokeLinecap="round" />
                </svg>
              </div>
              <p className="mt-1 truncate text-[7.5px] font-bold text-[#1D1A17]">{name}</p>
              <p className="truncate text-[6.5px] text-[#716A63]">{store}</p>
              <p className="mt-0.5 text-[7.5px] font-extrabold text-ember">{price}</p>
            </div>
          ))}
        </div>

        <SectionHeader title="Nearby Stores" action="See all" />
        {/* Nearby list — VendorCard layout: square logo, name, stars, tags, prep time + distance */}
        {([
          { name: "Aling Nena's Carinderia", rating: 4.8, tags: ['Delivery', 'Pickup'], mins: '15 min', km: '0.8 km' },
          { name: 'Ibajay Burger Bites', rating: 4.5, tags: ['Delivery'], mins: '20 min', km: '1.2 km' },
        ] as const).map((s) => (
          <div key={String(name)} className="mt-1.5 flex items-start gap-2 rounded-xl border border-[#E7E1DB] bg-white p-1.5 shadow-sm">
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[#F1ECE8]">
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#716A63" strokeWidth="2" aria-hidden>
                <path d="M3 9l1.5-5h15L21 9M3 9v11h18V9M3 9h18" />
              </svg>
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[8px] font-bold text-[#1D1A17]">{s.name}</p>
              <div className="mt-0.5 flex items-center gap-1.5">
                <RatingStars rating={s.rating} />
                {s.tags.map((t, ti) => (
                  <Tag key={t} label={t} icon={ti === 0 ? '🛵' : '🏪'} />
                ))}
              </div>
              <p className="mt-0.5 text-[6.5px] text-[#716A63]">⏱ {s.mins} · 📍 {s.km}</p>
            </div>
          </div>
        ))}
      </div>

      <BottomNav active="Home" />
    </div>
  )
}

export function FoodDetail() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <div className="h-[30%] bg-gradient-to-br from-[#C44A1F] via-ember to-gold relative">
        <div className="absolute top-2 left-2 flex h-5 w-5 items-center justify-center rounded-full bg-white/90 text-[9px] text-[#1D1A17]">
          ←
        </div>
      </div>
      <div className="-mt-3 flex flex-1 flex-col rounded-t-2xl bg-[#FAF7F4] px-3 pt-3">
        <p className="text-[10px] font-bold text-[#1D1A17]">Sinigang na Baboy (Bowl)</p>
        <p className="mt-0.5 text-[7px] leading-relaxed text-[#716A63]">
          Tamarind pork soup with fresh vegetables. Best served with extra rice.
        </p>
        <div className="mt-1.5 flex items-center justify-between">
          <span className="text-[11px] font-bold text-ember">₱110</span>
          {/* quantity stepper — bordered pill like food_detail_sheet.dart */}
          <div className="flex items-center gap-2 rounded-full border border-[#E7E1DB] px-2 py-0.5">
            <span className="text-[9px] font-bold text-ember">−</span>
            <span className="text-[8px] font-bold text-[#1D1A17]">1</span>
            <span className="text-[9px] font-bold text-ember">+</span>
          </div>
        </div>

        <p className="mt-2 text-[7px] font-bold uppercase tracking-wide text-[#716A63]">Extras</p>
        {([
          { label: 'Extra Rice', price: '+₱15', checked: true },
          { label: 'Extra Sauce', price: '+₱10', checked: false },
        ]).map(({ label, price, checked }) => (
          <div key={String(label)} className="mt-1 flex items-center gap-1.5 rounded-lg border border-[#E7E1DB] bg-white px-2 py-1">
            <span
              className={`flex h-2.5 w-2.5 items-center justify-center rounded-[3px] border ${
                checked ? 'border-ember bg-ember' : 'border-[#E7E1DB] bg-white'
              } text-[6px] text-white`}
            >
              {checked ? '✓' : ''}
            </span>
            <span className="text-[7.5px] font-medium text-[#1D1A17]">{label}</span>
            <span className="ml-auto text-[7.5px] font-semibold text-[#716A63]">{price}</span>
          </div>
        ))}

        {/* bottom bar: stepper left, Add to Cart right (matches real sheet) */}
        <div className="mt-auto -mx-3 mt-2 flex items-center gap-1.5 border-t border-[#E7E1DB] bg-white px-3 py-2">
          <div className="flex items-center gap-1.5 rounded-full border border-[#E7E1DB] px-1.5 py-1">
            <span className="text-[8px] font-bold text-ember">−</span>
            <span className="text-[7.5px] font-bold text-[#1D1A17]">1</span>
            <span className="text-[8px] font-bold text-ember">+</span>
          </div>
          <button className="flex-1 rounded-lg bg-ember py-1.5 text-[8px] font-bold text-white shadow-sm">
            Add to Cart · ₱125
          </button>
        </div>
      </div>
    </div>
  )
}

export function OrderTracking() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      {/* map placeholder card (order_tracking_screen.dart) */}
      <div className="relative h-[34%] overflow-hidden bg-[#F1ECE8] px-2 pt-2">
        <div className="relative h-full rounded-xl bg-[#EAF0EC]">
          <div
            className="absolute inset-0 opacity-60"
            style={{
              backgroundImage:
                'linear-gradient(#d3ddd6 1px, transparent 1px), linear-gradient(90deg, #d3ddd6 1px, transparent 1px)',
              backgroundSize: '18px 18px',
            }}
          />
          <svg className="absolute inset-0 h-full w-full" viewBox="0 0 100 60" fill="none" aria-hidden>
            <path d="M8 52 C 30 48, 28 26, 52 22 S 88 15, 92 8" stroke="#1F6F5C" strokeWidth="2.5" strokeDasharray="5 4" strokeLinecap="round" />
            <circle cx="92" cy="8" r="4" fill="#E85D2A" />
            <circle cx="55" cy="23" r="5" fill="#fff" />
            <circle cx="55" cy="23" r="3.2" fill="#E85D2A" />
          </svg>
          {/* live banner — "Vendor is on the way", matching the real banner copy */}
          <div className="absolute inset-x-2 bottom-1.5 rounded-full bg-ember py-1 text-center text-[6.5px] font-semibold text-white">
            Vendor is on the way
          </div>
        </div>
      </div>

      <div className="flex flex-1 flex-col px-3 pt-2">
        <div className="flex items-center justify-between">
          {/* appBar title = order number */}
          <p className="text-[9px] font-bold text-[#1D1A17]">#IBJ-1042</p>
          {/* StatusBadge out_for_delivery = ember */}
          <span className="rounded-full bg-ember px-2 py-[3px] text-[6.5px] font-bold text-white animate-pulse-glow">
            OUT FOR DELIVERY
          </span>
        </div>

        {/* stepper: pending → accepted → preparing → ready → out for delivery → delivered */}
        <div className="mt-2 space-y-1.5">
          {[
            ['Pending', true],
            ['Accepted', true],
            ['Preparing', true],
            ['Ready', true],
            ['Out for Delivery', true],
            ['Delivered', false],
          ].map(([step, done], i, arr) => (
            <div key={String(step)} className="flex items-center gap-2">
              <span
                className={`flex h-3.5 w-3.5 shrink-0 items-center justify-center rounded-full text-[6px] font-bold ${
                  done ? 'bg-moss text-white' : 'border border-dashed border-[#B9B0A8] text-transparent'
                } ${i === arr.length - 2 ? 'ring-4 ring-moss/15' : ''}`}
              >
                ✓
              </span>
              {i < arr.length - 1 && (
                <span className={`absolute h-3 w-px ${done ? 'bg-moss/40' : 'bg-[#E7E1DB]'}`} style={{ marginLeft: 6.5, marginTop: 14 }} aria-hidden />
              )}
              <p className={`text-[7.5px] font-semibold ${done ? 'text-[#1D1A17]' : 'text-[#B9B0A8]'}`}>{step}</p>
            </div>
          ))}
        </div>

        {/* order details card */}
        <div className="mt-auto mb-2 rounded-xl border border-[#E7E1DB] bg-white p-2">
          <p className="text-[7px] font-bold text-[#1D1A17]">Order Details</p>
          <div className="mt-1 flex justify-between text-[6.5px] text-[#716A63]">
            <span>1× Chicken Adobo Rice Meal</span><span>₱95</span>
          </div>
          <div className="mt-0.5 flex justify-between text-[6.5px] text-[#716A63]">
            <span>1× Extra Rice</span><span>₱15</span>
          </div>
          <div className="mt-1 flex justify-between border-t border-[#F1ECE8] pt-1 text-[7px] font-extrabold text-[#1D1A17]">
            <span>Total</span><span>₱110</span>
          </div>
          <p className="mt-0.5 text-[6px] text-[#716A63]">Deliver to Purok 2, Ibajay</p>
        </div>
      </div>
    </div>
  )
}

export function ChatPreview() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <div className="flex items-center gap-1.5 border-b border-[#E7E1DB] bg-white px-2.5 py-2">
        <span className="text-[8px] text-[#1D1A17]">←</span>
        <span className="flex h-5 w-5 items-center justify-center rounded-md bg-moss text-[7px] font-bold text-white">AN</span>
        <div>
          <p className="text-[8px] font-bold text-[#1D1A17]">Aling Nena's Carinderia</p>
          <p className="text-[6px] text-moss-bright">● Online</p>
        </div>
      </div>
      <div className="flex-1 space-y-1.5 px-2.5 pt-2">
        <div className="mr-8 rounded-xl rounded-bl-sm bg-white px-2 py-1.5 text-[7.5px] text-[#1D1A17] shadow-sm">
          Good am! Pwede po walang sili yung adobo?
        </div>
        <div className="ml-8 rounded-xl rounded-br-sm bg-ember px-2 py-1.5 text-[7.5px] text-white shadow-sm">
          Opo, noted. Extra rice pa po ba?
        </div>
        <div className="mr-8 rounded-xl rounded-bl-sm bg-white px-2 py-1.5 text-[7.5px] text-[#1D1A17] shadow-sm">
          Yes po 🙏
        </div>
        <div className="ml-8 rounded-xl rounded-br-sm bg-ember px-2 py-1.5 text-[7.5px] text-white shadow-sm">
          Malapit na po maging ready 👨‍🍳
        </div>
      </div>
      <div className="m-2 mt-0 flex items-center gap-1.5 rounded-full border border-[#E7E1DB] bg-white px-2 py-1.5">
        <span className="flex-1 text-[7px] text-[#B9B0A8]">Type a message…</span>
        <span className="text-ember">➤</span>
      </div>
    </div>
  )
}

/* ---------------- vendor app (LIGHT theme, matches vendor_app/lib) ---------------- */

function StatCard({ icon, label, value, color }: { icon: string; label: string; value: string; color: string }) {
  return (
    <div className="rounded-xl border border-[#E7E1DB] bg-white p-1.5 shadow-sm">
      <div className="flex items-center gap-1">
        <span
          className="flex h-3.5 w-3.5 items-center justify-center rounded text-[6.5px]"
          style={{ backgroundColor: `${color}22`, color }}
          aria-hidden
        >
          {icon}
        </span>
        <p className="text-[6px] font-medium leading-none text-[#716A63]">{label}</p>
      </div>
      <p className="mt-1 text-[11px] font-extrabold text-[#1D1A17]">{value}</p>
    </div>
  )
}

export function VendorDashboard() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <StatusBar />
      {/* AppBar: Dashboard title + store status pill */}
      <div className="flex items-center justify-between bg-white px-3 pb-1.5 pt-1 shadow-sm">
        <p className="text-[9px] font-bold text-[#1D1A17]">Dashboard</p>
        <span className="flex items-center gap-1 rounded-full bg-emerald-50 px-1.5 py-[2px]" style={{ border: '1px solid #2AA18455' }}>
          <span className="h-1.5 w-1.5 rounded-full bg-[#2AA184] animate-pulse-glow" />
          <span className="text-[6px] font-bold text-[#1F6F5C]">OPEN</span>
        </span>
      </div>

      <div className="flex-1 overflow-hidden px-2.5 pt-2">
        {/* greeting header */}
        <p className="text-[9.5px] font-extrabold text-[#1D1A17]">Good morning, Piolo 👋</p>
        <p className="text-[6.5px] text-[#716A63]">Sample Carinderia</p>

        {/* 2×2 stat grid (dashboard_screen.dart) */}
        <div className="mt-2 grid grid-cols-2 gap-1.5">
          <StatCard icon="🧾" label="Today's Orders" value="12" color="#1F6F5C" />
          <StatCard icon="💰" label="Today's Revenue" value="₱2,340" color="#E85D2A" />
          <StatCard icon="⏳" label="Pending Orders" value="3" color="#E0A72E" />
          <StatCard icon="⭐" label="Store Rating" value="4.8" color="#2E9E5B" />
        </div>

        <SectionHeader title="Menu Highlights" action="Full Analytics" />
        {[
          ['Chicken Adobo', '32 sold today'],
          ['Sinigang na Baboy', '21 sold today'],
        ].map(([name, sub]) => (
          <div key={String(name)} className="mt-1 flex items-center gap-1.5 rounded-xl border border-[#E7E1DB] bg-white p-1.5 shadow-sm">
            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-[#F1ECE8] text-[7px]" aria-hidden>🍗</span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[7.5px] font-semibold text-[#1D1A17]">{name}</p>
              <p className="text-[6px] text-[#716A63]">{sub}</p>
            </div>
          </div>
        ))}
      </div>

      <BottomNav active="Orders" />
    </div>
  )
}

export function VendorMenu() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <StatusBar />
      <div className="flex items-center justify-between bg-white px-3 pb-1.5 pt-1 shadow-sm">
        <p className="text-[9px] font-bold text-[#1D1A17]">Menu</p>
        <span className="rounded-lg bg-ember px-1.5 py-[2px] text-[6px] font-bold text-white">+ Add item</span>
      </div>

      {/* category tabs */}
      <div className="flex gap-2 border-b border-[#E7E1DB] bg-white px-3 pb-1">
        {['Meals', 'Extras'].map((t, i) => (
          <span key={t} className={`pb-0.5 text-[7.5px] font-bold ${i === 0 ? 'border-b-2 border-ember text-ember' : 'text-[#716A63]'}`}>
            {t}
          </span>
        ))}
      </div>

      <div className="flex-1 space-y-1.5 overflow-hidden px-2.5 pt-2">
        {[
          ['Chicken Adobo Rice Meal', '₱95', true],
          ['Sinigang na Baboy (Bowl)', '₱110', true],
          ['Extra Rice', '₱15', false],
        ].map(([name, price, available], i) => (
          <div key={String(name)} className={`flex items-center gap-2 rounded-xl border border-[#E7E1DB] bg-white p-1.5 shadow-sm ${!available ? 'opacity-60' : ''}`}>
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-ember/25 to-gold/25">
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#E85D2A" strokeWidth="2" aria-hidden>
                <path d="M4 18h16M6 10v4m4-8v8m4-6v6m4-9v9" strokeLinecap="round" />
              </svg>
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[7.5px] font-bold text-[#1D1A17]">{name}</p>
              <p className="text-[7px] font-bold text-ember">{price}</p>
            </div>
            {/* availability switch */}
            <span
              className={`flex h-3 w-5 items-center rounded-full p-[1.5px] ${i === 2 ? 'bg-[#E7E1DB]' : 'justify-end bg-moss'}`}
              aria-hidden
            >
              <span className="h-2 w-2 rounded-full bg-white shadow" />
            </span>
          </div>
        ))}
      </div>

      <BottomNav active="Orders" />
    </div>
  )
}

export function VendorAnalytics() {
  return (
    <div className="flex h-full flex-col rounded-[1.4rem] bg-[#FAF7F4] text-left overflow-hidden">
      <StatusBar />
      <div className="bg-white px-3 pb-1.5 pt-1 shadow-sm">
        <p className="text-[9px] font-bold text-[#1D1A17]">Analytics</p>
      </div>
      <div className="flex-1 overflow-hidden px-2.5 pt-2">
        {/* summary strip */}
        <div className="grid grid-cols-3 gap-1.5">
          {[
            ['Revenue', '₱2,340', '#E85D2A'],
            ['Orders', '12', '#1F6F5C'],
            ['Avg. order', '₱195', '#3378C9'],
          ].map(([label, value, color]) => (
            <div key={String(label)} className="rounded-xl border border-[#E7E1DB] bg-white p-1.5 text-center shadow-sm">
              <p className="text-[5.5px] uppercase tracking-wide text-[#716A63]">{label}</p>
              <p className="mt-0.5 text-[9px] font-extrabold" style={{ color: String(color) }}>{value}</p>
            </div>
          ))}
        </div>

        <SectionHeader title="Sales · last 7 days" />
        <div className="mt-1 rounded-xl border border-[#E7E1DB] bg-white p-2 shadow-sm">
          <div className="flex h-14 items-end gap-1">
            {[35, 55, 42, 78, 60, 92, 70].map((h, i) => (
              <div key={i} className="flex flex-1 flex-col items-center gap-0.5">
                <div
                  className="w-full rounded-t-sm bg-gradient-to-t from-moss to-moss-bright"
                  style={{ height: `${h}%`, opacity: 0.45 + (h / 100) * 0.55 }}
                />
                <span className="text-[4.5px] text-[#716A63]">{['M', 'T', 'W', 'Th', 'F', 'Sa', 'Su'][i]}</span>
              </div>
            ))}
          </div>
        </div>

        <SectionHeader title="Top sellers" />
        {[
          ['Chicken Adobo Rice Meal', '32 orders'],
          ['Sinigang na Baboy', '21 orders'],
          ['Extra Rice', '40 orders'],
        ].map(([name, n], i) => (
          <div key={String(name)} className="mt-1 flex items-center gap-1.5">
            <span className="flex h-4 w-4 items-center justify-center rounded-full bg-ember/15 text-[6.5px] font-extrabold text-ember">{i + 1}</span>
            <p className="flex-1 truncate text-[7.5px] font-semibold text-[#1D1A17]">{name}</p>
            <p className="text-[6.5px] text-[#716A63]">{n}</p>
          </div>
        ))}
      </div>
      <BottomNav active="Orders" />
    </div>
  )
}
