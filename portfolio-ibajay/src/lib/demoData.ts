/**
 * Sample marketplace content for the homepage scene.
 * Everything here is ILLUSTRATIVE — these are not real businesses, prices,
 * or ratings. Every card that renders this data carries a visible
 * "sample" marker so nobody mistakes it for a live listing.
 */

export type DemoFood = {
  name: string
  store: string
  price: string
  emoji: string
  tint: string
}

export type DemoVendor = {
  kind: string
  blurb: string
  mode: 'delivery' | 'pickup'
  emoji: string
  tint: string
  /** sample menu lines shown as a mini preview on the storefront card */
  menu: [string, string][]
}

export const DEMO_FOOD: DemoFood[] = [
  { name: 'Chicken Adobo', store: 'Carinderia', price: '₱65 / order', emoji: '🍗', tint: '#E85D2A' },
  { name: 'Burger w/ egg', store: 'Food stall', price: '₱45', emoji: '🍔', tint: '#FFB845' },
  { name: 'Halo-halo', store: 'Dessert stand', price: '₱55', emoji: '🍨', tint: '#2AA184' },
  { name: 'Brown sugar milk tea', store: 'Milk tea spot', price: '₱70', emoji: '🧋', tint: '#C98A5B' },
  { name: 'Pandesal (6 pcs)', store: 'Bakery', price: '₱25', emoji: '🥖', tint: '#E0A72E' },
]

export const DEMO_VENDORS: DemoVendor[] = [
  {
    kind: 'Carinderia',
    blurb: 'Home-style ulam, changes daily',
    mode: 'delivery',
    emoji: '🍲',
    tint: '#E85D2A',
    menu: [['Chicken Adobo', '₱65'], ['Sinigang na Baboy', '₱110'], ['Extra Rice', '₱15']],
  },
  {
    kind: 'Bakery',
    blurb: 'Fresh pandesal every morning',
    mode: 'pickup',
    emoji: '🥖',
    tint: '#E0A72E',
    menu: [['Pandesal (6 pcs)', '₱25'], ['Spanish Bread', '₱30'], ['Monay', '₱20']],
  },
  {
    kind: 'Cafe',
    blurb: 'Coffee, snacks, and wifi',
    mode: 'pickup',
    emoji: '☕',
    tint: '#8A5CF6',
    menu: [['Iced Latte', '₱90'], ['Cheesecake slice', '₱85'], ['Ham & cheese croissant', '₱70']],
  },
  {
    kind: 'Milk Tea Shop',
    blurb: 'Brown sugar, okinawa, wintermelon',
    mode: 'delivery',
    emoji: '🧋',
    tint: '#C98A5B',
    menu: [['Brown Sugar Milk Tea', '₱70'], ['Okinawa', '₱75'], ['Wintermelon', '₱65']],
  },
  {
    kind: 'Restaurant',
    blurb: 'Family meals and party trays',
    mode: 'delivery',
    emoji: '🍽️',
    tint: '#2AA184',
    menu: [['Bilao Family Meal', '₱450'], ['Pancit Bilao', '₱280'], ['Lechon Kawali', '₱180']],
  },
]
