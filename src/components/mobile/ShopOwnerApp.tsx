import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { SeedProduct } from '../../data/seedProducts';
import { Order } from '../../data/mockOrders';
import { DeviceFrame } from './DeviceFrame';
import confetti from 'canvas-confetti';
import {
  Home,
  Sprout,
  ShoppingCart,
  Truck,
  User,
  Search,
  Plus,
  Minus,
  Trash2,
  CheckCircle,
  Package,
  ArrowRight,
  ShieldCheck,
  MapPin,
  Clock,
  Sparkles,
  ChevronRight,
  Share2,
  LogOut,
  FileText,
  X,
  Calendar,
  Hash,
  Scale,
  Building2
} from 'lucide-react';

export const formatOrderDateTime = (dateStr?: string) => {
  if (!dateStr) return { date: 'N/A', time: '', full: 'N/A' };
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) {
      return { date: dateStr, time: '', full: dateStr };
    }
    const dateFormatted = d.toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    });
    const timeFormatted = d.toLocaleTimeString('en-IN', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    });
    return {
      date: dateFormatted,
      time: timeFormatted,
      full: `${dateFormatted}, ${timeFormatted}`
    };
  } catch (e) {
    return { date: dateStr, time: '', full: dateStr };
  }
};

export const ShopOwnerApp: React.FC = () => {
  const {
    products,
    cart,
    addToCart,
    removeFromCart,
    updateCartQuantity,
    placeOrder,
    orders,
    shipments,
    selectedOrderForTrack,
    setSelectedOrderForTrack,
    setCurrentRole,
    authenticatedUser,
    handleLogout
  } = useAppState();

  const currentShopName = authenticatedUser?.metadata?.shop_name || 'My Shop';
  const currentOwnerName = authenticatedUser?.full_name || 'Shop Owner';

  const [activeNav, setActiveNav] = useState<'home' | 'products' | 'cart' | 'orders' | 'tracking' | 'profile'>('home');
  const [selectedProduct, setSelectedProduct] = useState<SeedProduct | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [searchTerm, setSearchTerm] = useState('');
  const [orderPlacedSuccess, setOrderPlacedSuccess] = useState<Order | any | null>(null);
  const [selectedOrderForInvoice, setSelectedOrderForInvoice] = useState<Order | null>(null);
  const [modalQuantity, setModalQuantity] = useState<number>(5);
  const [modalUnit, setModalUnit] = useState<'kg' | 'g'>('kg');
  const [modalPkgSize, setModalPkgSize] = useState<string>('');

  // Filter products for Shop Owner
  const filteredProducts = products.filter((p) => {
    const matchesCategory = selectedCategory === 'All' || p.category === selectedCategory;
    const matchesSearch =
      p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      p.sku.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  // Strict shop owner order filtering
  const shopOrders = orders.filter((o) => {
    if (authenticatedUser?.metadata?.shop_id) {
      return String(o.shopId) === String(authenticatedUser.metadata.shop_id);
    }
    return (
      o.shopName.toLowerCase().includes(currentShopName.toLowerCase()) ||
      currentShopName.toLowerCase().includes(o.shopName.toLowerCase())
    );
  });
  const totalCartKg = cart.reduce((sum, item) => sum + (item.unit === 'g' ? item.quantity / 1000 : item.quantity), 0);

  const handlePlaceOrder = async () => {
    if (cart.length === 0) return;

    // Trigger confetti celebration
    try {
      confetti({
        particleCount: 80,
        spread: 70,
        origin: { y: 0.6 },
      });
    } catch (e) {
      // ignore in headless
    }

    try {
      const createdOrder = await placeOrder('Direct booking from Shop Owner App');
      setOrderPlacedSuccess(createdOrder);
      setSelectedOrderForTrack(createdOrder);
    } catch (err: any) {
      console.error('Error placing order:', err);
      alert(err?.message || 'Failed to place seed order. Please check item quantities and try again.');
    }
  };

  return (
    <DeviceFrame appName="Yadvi Seeds - Dealer App">
      {/* Top Mobile App Header */}
      <header className="bg-[#0b3b2c] text-white px-4 py-3.5 flex items-center justify-between sticky top-0 z-20 shadow-md">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-emerald-700/80 p-1 flex items-center justify-center border border-emerald-500/30">
            <Sprout className="w-5 h-5 text-emerald-300" />
          </div>
          <div>
            <div className="font-bold text-xs leading-none">{currentShopName}</div>
            <div className="text-[10px] text-emerald-200/80 mt-0.5">{currentOwnerName}</div>
          </div>
        </div>

        {/* Cart Quick Shortcut */}
        <button
          onClick={() => setActiveNav('cart')}
          className="relative p-2 rounded-xl bg-emerald-900/60 hover:bg-emerald-900 text-emerald-100 transition"
        >
          <ShoppingCart className="w-4 h-4" />
          {cart.length > 0 && (
            <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-amber-500 text-slate-950 font-black text-[9px] flex items-center justify-center">
              {cart.length}
            </span>
          )}
        </button>
      </header>

      {/* Main Content Area */}
      <div className="flex-1 pb-20 overflow-y-auto">
        {/* ================= TAB 1: HOME ================= */}
        {activeNav === 'home' && (
          <div className="p-4 space-y-4">
            {/* Promotional Yadvi Banner */}
            <div className="relative rounded-2xl overflow-hidden bg-gradient-to-br from-[#0b3b2c] to-[#07241b] text-white p-4.5 shadow-md border border-emerald-700/30">
              <div className="relative z-10 space-y-1.5 max-w-[70%]">
                <span className="px-2 py-0.5 rounded-full bg-emerald-500/30 text-emerald-200 text-[9px] font-bold uppercase tracking-wider">
                  Kharif Season High Yield
                </span>
                <h2 className="text-base font-black leading-tight">Yadvi Hybrid Seeds Guarantee</h2>
                <p className="text-[11px] text-emerald-100/80 leading-relaxed">
                  90%+ certified germination with robust resistance against leaf curls & sucking pests.
                </p>
                <button
                  onClick={() => setActiveNav('products')}
                  className="mt-2 px-3 py-1.5 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold rounded-xl text-xs flex items-center gap-1.5 shadow"
                >
                  <span>Order Seeds Now</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>

              {/* Decorative graphic */}
              <div className="absolute -right-4 -bottom-4 w-32 h-32 opacity-20 pointer-events-none">
                <Sprout className="w-full h-full text-emerald-300" />
              </div>
            </div>

            {/* Quick Action Cards */}
            <div className="grid grid-cols-3 gap-2.5 text-center">
              <button
                onClick={() => setActiveNav('products')}
                className="p-3 bg-white rounded-xl border border-slate-200/80 shadow-xs hover:border-emerald-500 transition flex flex-col items-center justify-center gap-1.5"
              >
                <div className="w-8 h-8 rounded-full bg-emerald-50 text-emerald-700 flex items-center justify-center">
                  <Sprout className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-bold text-slate-800">Seed Catalog</span>
              </button>

              <button
                onClick={() => setActiveNav('orders')}
                className="p-3 bg-white rounded-xl border border-slate-200/80 shadow-xs hover:border-emerald-500 transition flex flex-col items-center justify-center gap-1.5"
              >
                <div className="w-8 h-8 rounded-full bg-blue-50 text-blue-700 flex items-center justify-center">
                  <Package className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-bold text-slate-800">My Orders</span>
              </button>

              <button
                onClick={() => setActiveNav('tracking')}
                className="p-3 bg-white rounded-xl border border-slate-200/80 shadow-xs hover:border-emerald-500 transition flex flex-col items-center justify-center gap-1.5"
              >
                <div className="w-8 h-8 rounded-full bg-purple-50 text-purple-700 flex items-center justify-center">
                  <Truck className="w-4 h-4" />
                </div>
                <span className="text-[10px] font-bold text-slate-800">LR Tracking</span>
              </button>
            </div>

            {/* Order & Shipment Status Widget */}
            <div className="bg-white rounded-2xl border border-slate-200/80 shadow-xs p-3.5 space-y-2.5">
              <div className="flex items-center justify-between">
                <span className="font-bold text-xs text-slate-900">Current Consignments</span>
                <button
                  onClick={() => setActiveNav('tracking')}
                  className="text-[11px] font-bold text-emerald-700 hover:underline"
                >
                  Track All →
                </button>
              </div>

              {shipments[0] && (
                <div className="p-3 bg-emerald-50/60 rounded-xl border border-emerald-200/80 flex items-center justify-between">
                  <div>
                    <div className="text-[10px] font-mono font-bold text-emerald-800">{shipments[0].lrNumber}</div>
                    <div className="font-bold text-xs text-slate-900">{shipments[0].shopName}</div>
                    <div className="text-[10px] text-slate-500">Status: <b>{shipments[0].status}</b></div>
                  </div>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-600 text-white font-bold">
                    In Transit
                  </span>
                </div>
              )}
            </div>

            {/* Popular Seeds Highlight with Real Packet Images */}
            <div className="space-y-2.5">
              <div className="flex items-center justify-between">
                <h3 className="font-bold text-xs text-slate-900">Popular In Your Territory</h3>
                <button
                  onClick={() => setActiveNav('products')}
                  className="text-[11px] font-bold text-emerald-700 hover:underline"
                >
                  View All
                </button>
              </div>

              <div className="grid grid-cols-2 gap-3">
                {products.slice(0, 4).map((p) => (
                  <div
                    key={p.id}
                    onClick={() => {
                      setSelectedProduct(p);
                      setActiveNav('products');
                    }}
                    className="bg-white rounded-xl border border-slate-200 p-2.5 shadow-xs flex flex-col justify-between cursor-pointer hover:border-emerald-500 transition"
                  >
                    <div className="h-32 bg-slate-100 rounded-lg p-1.5 flex items-center justify-center">
                      <img src={p.image} alt={p.name} className="max-h-full object-contain drop-shadow" />
                    </div>
                    <div className="mt-2">
                      <div className="font-bold text-[11px] text-slate-900 leading-tight truncate">{p.name}</div>
                      <div className="text-[9px] text-slate-400 font-mono mt-0.5">{p.sku}</div>
                      <div className="text-[10px] font-bold text-emerald-700 mt-1">Stock: {p.stockKg ?? 0} kg</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ================= TAB 2: PRODUCTS ================= */}
        {activeNav === 'products' && (
          <div className="p-4 space-y-4">
            {/* Search */}
            <div className="relative">
              <Search className="w-4 h-4 absolute left-3 top-2.5 text-slate-400" />
              <input
                type="text"
                placeholder="Search seed variety or SKU..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-3 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-emerald-600 shadow-xs"
              />
            </div>

            {/* Category Filter Horizontal Scroll */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs">
              {['All', 'Chilli', 'Okra', 'Dolichos', 'Pulses', 'Field Crops'].map((cat) => (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-3 py-1.5 rounded-xl font-bold whitespace-nowrap transition ${
                    selectedCategory === cat
                      ? 'bg-emerald-800 text-white shadow-xs'
                      : 'bg-white border border-slate-200 text-slate-600'
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>

            {/* Products List */}
            <div className="space-y-3">
              {filteredProducts.map((p) => (
                <div
                  key={p.id}
                  className="bg-white rounded-2xl border border-slate-200 p-3.5 shadow-xs flex gap-3 hover:border-emerald-400 transition"
                >
                  {/* Real Seed Packet Photo */}
                  <div
                    onClick={() => setSelectedProduct(p)}
                    className="w-24 h-28 bg-slate-100 rounded-xl p-1.5 flex items-center justify-center shrink-0 border border-slate-200 cursor-pointer"
                  >
                    <img src={p.image} alt={p.name} className="max-h-full object-contain drop-shadow" />
                  </div>

                  {/* Details */}
                  <div className="flex-1 flex flex-col justify-between">
                    <div>
                      <div className="flex items-center justify-between">
                        <span className="text-[9px] font-mono font-bold text-emerald-800 bg-emerald-50 px-1.5 py-0.2 rounded">
                          {p.sku}
                        </span>
                        <span className="text-[9px] font-bold text-emerald-700">{p.availability}</span>
                      </div>
                      <h4
                        onClick={() => setSelectedProduct(p)}
                        className="font-bold text-xs text-slate-900 mt-1 cursor-pointer hover:text-emerald-800 leading-snug"
                      >
                        {p.name}
                      </h4>
                      <p className="text-[10px] text-slate-500 line-clamp-2 mt-0.5 leading-relaxed">
                        {p.description}
                      </p>
                    </div>

                    <div className="mt-2 pt-2 border-t border-slate-100 flex items-center justify-between">
                      <span className="text-[10px] font-bold text-slate-700">Stock: {p.stockKg ?? 0} kg</span>
                      <button
                        onClick={() => {
                          setSelectedProduct(p);
                          setModalQuantity(5);
                          setModalUnit('kg');
                          setModalPkgSize(p.packageSizes[0] || 'Standard Pack');
                        }}
                        className="px-3 py-1 bg-emerald-800 hover:bg-emerald-900 text-white rounded-lg text-[10px] font-bold transition flex items-center gap-1 shadow-xs cursor-pointer"
                      >
                        <Plus className="w-3 h-3" />
                        <span>Select Qty</span>
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* ================= TAB 3: CART ================= */}
        {activeNav === 'cart' && (
          <div className="p-4 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-900">Seed Indent / Order Cart</h3>
              <span className="text-xs font-bold text-emerald-800">{cart.length} Items Selected</span>
            </div>

            {orderPlacedSuccess ? (
              /* Enhanced Order Confirmation matching requirements */
              <div className="bg-white rounded-2xl border border-emerald-300 p-5 text-center space-y-4 shadow-md animate-scale-in">
                <div className="w-13 h-13 bg-emerald-100 text-emerald-800 rounded-full flex items-center justify-center mx-auto">
                  <CheckCircle className="w-7 h-7" />
                </div>
                <div>
                  <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-600 block">
                    Submission Confirmed
                  </span>
                  <h4 className="text-base font-black text-slate-900 mt-0.5">ORDER PLACED SUCCESSFULLY</h4>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Order <b className="font-mono text-emerald-800">{orderPlacedSuccess.orderNumber}</b> booked with Yadvi Central Fulfillment.
                  </p>
                </div>

                {/* Key Invoice Summary Card */}
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-xs text-left space-y-2">
                  <div className="flex justify-between items-center border-b border-slate-200/80 pb-2">
                    <span className="text-slate-500 flex items-center gap-1">
                      <Hash className="w-3.5 h-3.5 text-slate-400" /> Invoice / Order Ref:
                    </span>
                    <span className="font-mono font-black text-emerald-800 text-xs">{orderPlacedSuccess.orderNumber}</span>
                  </div>

                  <div className="flex justify-between items-center">
                    <span className="text-slate-500 flex items-center gap-1">
                      <Calendar className="w-3.5 h-3.5 text-slate-400" /> Date & Time:
                    </span>
                    <span className="font-medium text-slate-800 text-[11px]">
                      {formatOrderDateTime(orderPlacedSuccess.orderDate).full}
                    </span>
                  </div>

                  <div className="flex justify-between items-center">
                    <span className="text-slate-500 flex items-center gap-1">
                      <Building2 className="w-3.5 h-3.5 text-slate-400" /> Shop / Consignee:
                    </span>
                    <span className="font-bold text-slate-800 truncate max-w-[160px] text-right">
                      {orderPlacedSuccess.shopName}
                    </span>
                  </div>

                  <div className="flex justify-between items-center">
                    <span className="text-slate-500 flex items-center gap-1">
                      <Scale className="w-3.5 h-3.5 text-slate-400" /> Total Volume:
                    </span>
                    <span className="font-mono font-black text-slate-900">
                      {orderPlacedSuccess.totalQuantityKg ?? 0} kg
                    </span>
                  </div>

                  <div className="flex justify-between items-center">
                    <span className="text-slate-500">Order Status:</span>
                    <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-bold text-[10px]">
                      {orderPlacedSuccess.status || 'New'} (Saved)
                    </span>
                  </div>

                  {/* Itemized preview */}
                  <div className="pt-2 border-t border-slate-200/80">
                    <div className="text-[11px] font-bold text-slate-700 mb-1.5 flex items-center justify-between">
                      <span>Ordered Varieties ({orderPlacedSuccess.items?.length || 0}):</span>
                      <span className="text-[10px] text-slate-400 font-normal">Grams (g) / Kilograms (kg)</span>
                    </div>
                    <div className="space-y-1 max-h-32 overflow-y-auto pr-1">
                      {(orderPlacedSuccess.items || []).map((item: any, idx: number) => (
                        <div key={idx} className="flex justify-between items-center text-[11px] bg-white p-1.5 rounded border border-slate-100">
                          <span className="text-slate-800 font-medium truncate max-w-[160px]">
                            {item.productName || item.product_name}
                            <span className="text-[10px] text-slate-400 block font-normal">
                              {item.packageSize || item.package_size || 'Standard'}
                            </span>
                          </span>
                          <span className="font-mono font-bold text-emerald-800 shrink-0">
                            {item.quantity} {item.unit || 'kg'}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="pt-1.5 text-[10px] text-slate-400 italic">
                    * Official GST Invoice & LR docket will accompany consignment dispatch.
                  </div>
                </div>

                <div className="space-y-2 pt-1">
                  <button
                    onClick={() => {
                      setSelectedOrderForInvoice(orderPlacedSuccess);
                    }}
                    className="w-full py-2.5 bg-emerald-800 hover:bg-emerald-900 text-white font-bold rounded-xl text-xs shadow transition flex items-center justify-center gap-1.5 cursor-pointer"
                  >
                    <FileText className="w-3.5 h-3.5" />
                    <span>View Complete Invoice Details</span>
                  </button>

                  <div className="grid grid-cols-2 gap-2">
                    <button
                      onClick={() => {
                        setOrderPlacedSuccess(null);
                        setActiveNav('orders');
                      }}
                      className="py-2 bg-slate-100 text-slate-800 font-bold rounded-xl text-xs hover:bg-slate-200 transition"
                    >
                      My Seed Orders
                    </button>
                    <button
                      onClick={() => {
                        setOrderPlacedSuccess(null);
                        setActiveNav('products');
                      }}
                      className="py-2 bg-slate-100 text-slate-700 font-bold rounded-xl text-xs hover:bg-slate-200 transition"
                    >
                      Order More Seeds
                    </button>
                  </div>
                </div>
              </div>
            ) : cart.length === 0 ? (
              <div className="bg-white rounded-2xl border border-slate-200 p-8 text-center space-y-3">
                <ShoppingCart className="w-12 h-12 text-slate-300 mx-auto" />
                <h4 className="font-bold text-sm text-slate-800">Your Cart is Empty</h4>
                <p className="text-xs text-slate-400">Browse the catalog to add Yadvi hybrid seed varieties.</p>
                <button
                  onClick={() => setActiveNav('products')}
                  className="mt-2 px-4 py-2 bg-emerald-800 text-white font-bold rounded-xl text-xs shadow"
                >
                  Browse Catalogue
                </button>
              </div>
            ) : (
              <>
                <div className="space-y-2.5">
                  {cart.map((item) => (
                    <div
                      key={item.product.id}
                      className="bg-white rounded-xl border border-slate-200 p-3 shadow-xs flex items-center justify-between gap-3"
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-lg bg-slate-100 p-1 flex items-center justify-center shrink-0 border border-slate-200">
                          <img src={item.product.image} alt={item.product.name} className="max-h-full object-contain" />
                        </div>
                        <div>
                          <div className="font-bold text-xs text-slate-900 truncate max-w-[140px]">
                            {item.product.name}
                          </div>
                          <div className="text-[10px] text-slate-400 font-mono">
                            {item.packageSize}
                          </div>
                        </div>
                      </div>

                      {/* Quantity Controls (NO PRICE) */}
                      <div className="flex items-center gap-2">
                        <div className="flex items-center border border-slate-200 rounded-lg overflow-hidden bg-slate-50">
                          <button
                            onClick={() => {
                              const step = item.unit === 'g' ? 50 : 1;
                              if (item.quantity - step > 0) {
                                updateCartQuantity(item.product.id, Math.round((item.quantity - step) * 100) / 100);
                              }
                            }}
                            className="p-1 hover:bg-slate-200 text-slate-600"
                          >
                            <Minus className="w-3 h-3" />
                          </button>
                          <span className="px-2 text-xs font-bold font-mono text-slate-900">
                            {item.quantity} {item.unit}
                          </span>
                          <button
                            onClick={() => {
                              const step = item.unit === 'g' ? 50 : 1;
                              updateCartQuantity(item.product.id, Math.round((item.quantity + step) * 100) / 100);
                            }}
                            className="p-1 hover:bg-slate-200 text-slate-600"
                          >
                            <Plus className="w-3 h-3" />
                          </button>
                        </div>

                        <button
                          onClick={() => removeFromCart(item.product.id)}
                          className="p-1 text-slate-400 hover:text-red-500"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Order Summary (Strictly Volume in kg, NO Price) */}
                <div className="bg-white rounded-xl border border-slate-200 p-4 space-y-2 text-xs">
                  <div className="font-bold text-slate-900 border-b border-slate-100 pb-2">Indent Summary</div>
                  <div className="flex justify-between text-slate-600">
                    <span>Total Varieties:</span>
                    <span className="font-bold text-slate-900">{cart.length} Varieties</span>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>Total Consignment Volume:</span>
                    <span className="font-mono font-bold text-emerald-800 text-sm">{Number(totalCartKg.toFixed(3))} kg</span>
                  </div>
                  <div className="flex justify-between text-slate-600">
                    <span>Destination Shop:</span>
                    <span className="font-bold text-slate-900">{currentShopName}</span>
                  </div>

                  <div className="pt-2 border-t border-slate-100">
                    <button
                      onClick={handlePlaceOrder}
                      className="w-full py-3 bg-emerald-800 hover:bg-emerald-900 text-white font-bold rounded-xl text-xs shadow-md transition flex items-center justify-center gap-2 cursor-pointer"
                    >
                      <CheckCircle className="w-4 h-4 text-emerald-300" />
                      <span>Place Seed Order ({Number(totalCartKg.toFixed(3))} kg)</span>
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        )}

        {/* ================= TAB 4: MY ORDERS ================= */}
        {activeNav === 'orders' && (
          <div className="p-4 space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-bold text-sm text-slate-900">My Seed Orders</h3>
                <p className="text-[11px] text-slate-500">Official consignment bookings for {currentShopName}</p>
              </div>
              <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 font-mono font-bold text-xs">
                {shopOrders.length} Orders
              </span>
            </div>

            {shopOrders.length === 0 ? (
              <div className="bg-white rounded-2xl border border-slate-200 p-8 text-center space-y-3 shadow-xs">
                <Package className="w-10 h-10 text-slate-300 mx-auto" />
                <h4 className="font-bold text-xs text-slate-700">No Orders Placed Yet</h4>
                <p className="text-[11px] text-slate-400">
                  Select Yadvi hybrid seeds from the catalog to submit your first dealer indent.
                </p>
                <button
                  onClick={() => setActiveNav('products')}
                  className="px-4 py-2 bg-emerald-800 text-white font-bold rounded-xl text-xs shadow transition"
                >
                  Browse Hybrid Seeds
                </button>
              </div>
            ) : (
              <div className="space-y-3">
                {shopOrders.map((ord) => {
                  const dt = formatOrderDateTime(ord.orderDate);
                  return (
                    <div
                      key={ord.id}
                      className="bg-white rounded-xl border border-slate-200 p-3.5 shadow-xs space-y-2.5 hover:border-emerald-500 transition"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="font-mono font-black text-xs text-emerald-800">{ord.orderNumber}</span>
                          <span className="text-[10px] text-slate-400 font-mono flex items-center gap-1">
                            <Clock className="w-3 h-3 text-slate-400" />
                            {dt.time || dt.date}
                          </span>
                        </div>
                        <span
                          className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                            ord.status === 'New'
                              ? 'bg-amber-100 text-amber-800'
                              : ord.status === 'Dispatched' || ord.status === 'In Transit'
                              ? 'bg-blue-100 text-blue-800'
                              : ord.status === 'Delivered'
                              ? 'bg-emerald-100 text-emerald-800'
                              : 'bg-slate-100 text-slate-700'
                          }`}
                        >
                          {ord.status}
                        </span>
                      </div>

                      {/* Item Preview list */}
                      <div className="bg-slate-50 p-2 rounded-lg border border-slate-100 space-y-1">
                        <div className="text-[10px] font-bold text-slate-500 flex justify-between">
                          <span>Items ({ord.items?.length || ord.totalItemsCount || 0} varieties):</span>
                          <span className="font-mono text-slate-700 font-bold">{ord.totalQuantityKg ?? 0} kg Total</span>
                        </div>
                        <div className="flex flex-wrap gap-1">
                          {(ord.items || []).slice(0, 3).map((item, idx) => (
                            <span
                              key={idx}
                              className="px-1.5 py-0.5 bg-white rounded border border-slate-200 text-[10px] text-slate-700 font-medium truncate max-w-[150px]"
                            >
                              {item.productName}: <b>{item.quantity} {item.unit || 'kg'}</b>
                            </span>
                          ))}
                          {(ord.items?.length || 0) > 3 && (
                            <span className="px-1.5 py-0.5 bg-slate-200 text-slate-600 rounded text-[10px]">
                              +{ord.items.length - 3} more
                            </span>
                          )}
                        </div>
                      </div>

                      <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px]">
                        <span className="text-slate-400 text-[10px]">{dt.date}</span>
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => setSelectedOrderForInvoice(ord)}
                            className="px-2.5 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-800 rounded-lg font-bold text-[10px] flex items-center gap-1 transition cursor-pointer"
                          >
                            <FileText className="w-3 h-3" />
                            <span>View Details</span>
                          </button>
                          <button
                            onClick={() => {
                              setSelectedOrderForTrack(ord);
                              setActiveNav('tracking');
                            }}
                            className="px-2 py-1 text-slate-600 hover:text-emerald-800 font-bold text-[10px] flex items-center gap-0.5 transition cursor-pointer"
                          >
                            <span>Track</span>
                            <ChevronRight className="w-3 h-3" />
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* ================= TAB 5: TRACKING ================= */}
        {activeNav === 'tracking' && (
          <div className="p-4 space-y-4">
            <h3 className="font-bold text-sm text-slate-900">Consignment Live Status</h3>

            {selectedOrderForTrack ? (
              <div className="space-y-4">
                <div className="bg-[#0b3b2c] p-4 rounded-2xl text-white shadow">
                  <div className="text-[10px] text-emerald-200 font-mono">ORDER #{selectedOrderForTrack.orderNumber}</div>
                  <div className="font-bold text-sm mt-0.5">{selectedOrderForTrack.shopName}</div>
                  <div className="text-xs text-emerald-100/80 mt-1">
                    Volume: <b>{selectedOrderForTrack.totalQuantityKg ?? 0} kg</b>
                  </div>
                  {selectedOrderForTrack.lrNumber && (
                    <div className="mt-2 pt-2 border-t border-emerald-800/80 flex items-center justify-between text-xs">
                      <span>LR Docket:</span>
                      <span className="font-mono font-bold text-emerald-200">{selectedOrderForTrack.lrNumber}</span>
                    </div>
                  )}
                </div>

                {/* Tracking Stepper */}
                <div className="bg-white rounded-2xl border border-slate-200 p-4 space-y-4">
                  <div className="font-bold text-xs text-slate-800">Transit Milestones</div>

                  <div className="relative pl-5 space-y-5 before:content-[''] before:absolute before:left-2 before:top-1.5 before:bottom-1.5 before:w-0.5 before:bg-slate-200">
                    <div className="relative">
                      <span className="absolute -left-5 top-0.5 w-4 h-4 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[9px]">
                        ✓
                      </span>
                      <div className="font-bold text-xs text-slate-900">Order Received & Confirmed</div>
                      <div className="text-[10px] text-slate-500">Processed at Gannavaram Central Seed Plant</div>
                    </div>

                    <div className="relative">
                      <span
                        className={`absolute -left-5 top-0.5 w-4 h-4 rounded-full flex items-center justify-center text-[9px] ${
                          selectedOrderForTrack.status !== 'New' && selectedOrderForTrack.status !== 'Confirmed'
                            ? 'bg-emerald-600 text-white'
                            : 'bg-slate-200 text-slate-400'
                        }`}
                      >
                        {selectedOrderForTrack.status !== 'New' && selectedOrderForTrack.status !== 'Confirmed' ? '✓' : '2'}
                      </span>
                      <div className="font-bold text-xs text-slate-900">Moisture-Proof Packaging & Batch Tagging</div>
                      <div className="text-[10px] text-slate-500">ISTA certified testing verified</div>
                    </div>

                    <div className="relative">
                      <span
                        className={`absolute -left-5 top-0.5 w-4 h-4 rounded-full flex items-center justify-center text-[9px] ${
                          selectedOrderForTrack.lrNumber ? 'bg-emerald-600 text-white' : 'bg-slate-200 text-slate-400'
                        }`}
                      >
                        {selectedOrderForTrack.lrNumber ? '✓' : '3'}
                      </span>
                      <div className="font-bold text-xs text-slate-900">Transporter Dispatched (LR Issued)</div>
                      <div className="text-[10px] text-slate-500">
                        {selectedOrderForTrack.lrNumber ? `Docket ${selectedOrderForTrack.lrNumber}` : 'Awaiting transporter assignment'}
                      </div>
                    </div>

                    <div className="relative">
                      <span
                        className={`absolute -left-5 top-0.5 w-4 h-4 rounded-full flex items-center justify-center text-[9px] ${
                          selectedOrderForTrack.status === 'Delivered'
                            ? 'bg-emerald-600 text-white'
                            : 'bg-slate-200 text-slate-400'
                        }`}
                      >
                        {selectedOrderForTrack.status === 'Delivered' ? '✓' : '4'}
                      </span>
                      <div className="font-bold text-xs text-slate-900">Delivered to Dealer</div>
                      <div className="text-[10px] text-slate-500">Direct shop handover</div>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="text-center py-10 text-slate-400 text-xs">
                Select an order to view its live tracking timeline.
              </div>
            )}
          </div>
        )}

        {/* ================= TAB 6: PROFILE ================= */}
        {activeNav === 'profile' && (
          <div className="p-4 space-y-4 text-xs text-slate-700">
            <div className="bg-white rounded-2xl border border-slate-200 p-4 flex items-center gap-3">
              <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-800 font-black text-base flex items-center justify-center">
                {currentOwnerName.charAt(0)}
              </div>
              <div>
                <h4 className="font-bold text-sm text-slate-900">{currentOwnerName}</h4>
                <div className="text-slate-500 text-[11px]">{currentShopName}</div>
                <div className="text-emerald-700 font-mono text-[10px] mt-0.5">{authenticatedUser?.phone || '+91 00000 00000'}</div>
              </div>
            </div>

            <div className="bg-white rounded-2xl border border-slate-200 p-4 space-y-3">
              <div className="font-bold text-slate-900">Distributor Credentials</div>
              <div className="space-y-2 text-slate-600">
                <div className="flex justify-between">
                  <span>Seed License:</span>
                  <span className="font-mono font-bold text-slate-900">AP/GNT/SEED/2022/441</span>
                </div>
                <div className="flex justify-between">
                  <span>GSTIN:</span>
                  <span className="font-mono font-bold text-slate-900">37AABCU9603R1ZM</span>
                </div>
                <div className="flex justify-between">
                  <span>Territory Officer:</span>
                  <span className="font-bold text-emerald-800">Suresh Babu (+91 98765 43211)</span>
                </div>
              </div>
            </div>

            <button
              onClick={handleLogout}
              className="w-full mt-4 py-3 bg-red-50 text-red-600 hover:bg-red-100 font-bold rounded-xl text-xs shadow transition flex items-center justify-center gap-2 cursor-pointer border border-red-200"
            >
              <LogOut className="w-4 h-4" />
              <span>Sign Out</span>
            </button>
          </div>
        )}
      </div>

      {/* Product Detail Modal */}
      {selectedProduct && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full overflow-hidden border border-slate-200 animate-scale-in">
            <div className="relative h-64 bg-slate-100 p-4 flex items-center justify-center">
              <img src={selectedProduct.image} alt={selectedProduct.name} className="max-h-full object-contain drop-shadow-lg" />
              <button
                onClick={() => setSelectedProduct(null)}
                className="absolute top-3 right-3 p-1 rounded-full bg-white/80 text-slate-700 hover:bg-white shadow"
              >
                ✕
              </button>
            </div>

            <div className="p-4 space-y-3 text-xs">
              <div>
                <span className="text-[10px] font-mono font-bold text-emerald-700 uppercase">{selectedProduct.sku}</span>
                <h3 className="font-bold text-sm text-slate-900">{selectedProduct.name}</h3>
                <p className="text-[11px] text-slate-500 mt-1">{selectedProduct.description}</p>
              </div>

              <div className="bg-slate-50 p-2.5 rounded-xl border border-slate-200 space-y-1 text-[11px]">
                <div className="flex justify-between">
                  <span className="text-slate-500">Germination:</span>
                  <span className="font-bold text-emerald-800">{selectedProduct.germinationRate}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Maturity:</span>
                  <span className="font-bold text-slate-800">{selectedProduct.maturityDays}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Available Stock:</span>
                  <span className="font-mono font-bold text-slate-900">{selectedProduct.stockKg ?? 0} kg</span>
                </div>
              </div>

              {/* Package size selection */}
              {selectedProduct.packageSizes && selectedProduct.packageSizes.length > 0 && (
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-700">Package Size:</label>
                  <select
                    value={modalPkgSize || selectedProduct.packageSizes[0]}
                    onChange={(e) => setModalPkgSize(e.target.value)}
                    className="w-full text-xs font-semibold p-2 border border-slate-200 rounded-lg bg-white"
                  >
                    {selectedProduct.packageSizes.map((sz) => (
                      <option key={sz} value={sz}>{sz}</option>
                    ))}
                  </select>
                </div>
              )}

              {/* Quantity and Unit Input */}
              <div className="space-y-1">
                <label className="text-[11px] font-bold text-slate-700">Order Quantity & Unit:</label>
                <div className="flex gap-2">
                  <input
                    type="number"
                    min="0.1"
                    step={modalUnit === 'g' ? '50' : '0.5'}
                    value={modalQuantity}
                    onChange={(e) => setModalQuantity(parseFloat(e.target.value) || 0)}
                    className="flex-1 text-xs font-bold p-2 border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-emerald-600"
                    placeholder="Enter quantity"
                  />
                  <div className="flex border border-slate-200 rounded-lg overflow-hidden">
                    <button
                      type="button"
                      onClick={() => setModalUnit('kg')}
                      className={`px-3 text-xs font-bold transition ${modalUnit === 'kg' ? 'bg-emerald-700 text-white' : 'bg-slate-100 text-slate-600'}`}
                    >
                      kg
                    </button>
                    <button
                      type="button"
                      onClick={() => setModalUnit('g')}
                      className={`px-3 text-xs font-bold transition ${modalUnit === 'g' ? 'bg-emerald-700 text-white' : 'bg-slate-100 text-slate-600'}`}
                    >
                      g
                    </button>
                  </div>
                </div>
              </div>

              <button
                disabled={modalQuantity <= 0}
                onClick={() => {
                  if (modalQuantity <= 0) return;
                  addToCart(selectedProduct, modalPkgSize || selectedProduct.packageSizes[0] || 'Standard Pack', modalQuantity, modalUnit);
                  setSelectedProduct(null);
                  setActiveNav('cart');
                }}
                className="w-full py-2.5 bg-emerald-800 hover:bg-emerald-900 disabled:opacity-50 text-white font-bold rounded-xl text-xs shadow transition flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Plus className="w-4 h-4" />
                <span>Add {modalQuantity > 0 ? `${modalQuantity} ${modalUnit}` : ''} to Cart</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Order Invoice Details Modal */}
      {selectedOrderForInvoice && (
        <div className="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-xs flex items-center justify-center p-3 animate-fade-in">
          <div className="bg-white rounded-2xl max-w-sm w-full max-h-[92vh] flex flex-col shadow-2xl border border-emerald-900/20 overflow-hidden animate-scale-in">
            {/* Modal Header */}
            <div className="bg-[#0b3b2c] text-white p-3.5 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-emerald-700/80 flex items-center justify-center border border-emerald-500/30">
                  <Sprout className="w-4 h-4 text-emerald-300" />
                </div>
                <div>
                  <h3 className="font-black text-xs leading-none">ORDER INVOICE DETAILS</h3>
                  <div className="text-[10px] text-emerald-200/90 font-mono mt-0.5">
                    {selectedOrderForInvoice.orderNumber}
                  </div>
                </div>
              </div>
              <button
                onClick={() => setSelectedOrderForInvoice(null)}
                className="w-7 h-7 rounded-full bg-emerald-900/60 hover:bg-emerald-800 text-emerald-200 flex items-center justify-center transition cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Body - Scrollable */}
            <div className="p-4 overflow-y-auto space-y-3.5 text-xs">
              {/* Order Meta Bar */}
              <div className="bg-emerald-50/70 border border-emerald-200/70 rounded-xl p-3 space-y-1.5">
                <div className="flex justify-between items-center">
                  <span className="text-[11px] text-emerald-900 font-semibold">Consignment Invoice #:</span>
                  <span className="font-mono font-black text-xs text-emerald-900">
                    {selectedOrderForInvoice.orderNumber}
                  </span>
                </div>
                <div className="flex justify-between items-center text-[11px]">
                  <span className="text-slate-600">Booking Date & Time:</span>
                  <span className="font-medium text-slate-900">
                    {formatOrderDateTime(selectedOrderForInvoice.orderDate).full}
                  </span>
                </div>
                <div className="flex justify-between items-center text-[11px]">
                  <span className="text-slate-600">Order Channel:</span>
                  <span className="font-medium text-slate-800">{selectedOrderForInvoice.source || 'Shop Owner App'}</span>
                </div>
                <div className="flex justify-between items-center text-[11px]">
                  <span className="text-slate-600">Consignment Status:</span>
                  <span
                    className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                      selectedOrderForInvoice.status === 'New'
                        ? 'bg-amber-100 text-amber-800'
                        : selectedOrderForInvoice.status === 'Dispatched' || selectedOrderForInvoice.status === 'In Transit'
                        ? 'bg-blue-100 text-blue-800'
                        : selectedOrderForInvoice.status === 'Delivered'
                        ? 'bg-emerald-100 text-emerald-800'
                        : 'bg-slate-100 text-slate-700'
                    }`}
                  >
                    {selectedOrderForInvoice.status}
                  </span>
                </div>
              </div>

              {/* Consignee / Shop Information */}
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-3 space-y-1.5">
                <div className="text-[11px] font-bold text-slate-800 uppercase tracking-wider flex items-center gap-1 border-b border-slate-200 pb-1">
                  <Building2 className="w-3.5 h-3.5 text-emerald-700" />
                  <span>Consignee Details</span>
                </div>
                <div className="grid grid-cols-2 gap-2 pt-1 text-[11px]">
                  <div>
                    <span className="text-slate-400 block text-[10px]">Shop Name</span>
                    <span className="font-bold text-slate-800">{selectedOrderForInvoice.shopName}</span>
                  </div>
                  <div>
                    <span className="text-slate-400 block text-[10px]">Proprietor / Contact</span>
                    <span className="font-semibold text-slate-800">
                      {selectedOrderForInvoice.ownerName || currentOwnerName}
                    </span>
                  </div>
                </div>
                <div className="pt-1 text-[11px]">
                  <span className="text-slate-400 block text-[10px]">Delivery Address & Location</span>
                  <span className="text-slate-700">
                    {selectedOrderForInvoice.deliveryAddress || selectedOrderForInvoice.shopLocation || 'Guntur Seed Market Yard'}
                  </span>
                </div>
                {selectedOrderForInvoice.contactPhone && (
                  <div className="pt-0.5 text-[11px]">
                    <span className="text-slate-400 block text-[10px]">Phone</span>
                    <span className="font-mono text-slate-700">{selectedOrderForInvoice.contactPhone}</span>
                  </div>
                )}
              </div>

              {/* Ordered Products Table */}
              <div className="border border-slate-200 rounded-xl overflow-hidden">
                <div className="bg-slate-100/90 px-3 py-2 border-b border-slate-200 flex justify-between items-center">
                  <span className="text-[11px] font-bold text-slate-800 uppercase tracking-wider flex items-center gap-1">
                    <Package className="w-3.5 h-3.5 text-emerald-700" />
                    <span>Ordered Hybrid Varieties</span>
                  </span>
                  <span className="text-[10px] font-mono text-slate-500 font-bold">
                    {selectedOrderForInvoice.items?.length || 0} Items
                  </span>
                </div>

                <div className="divide-y divide-slate-100 max-h-48 overflow-y-auto">
                  {(selectedOrderForInvoice.items || []).map((item, idx) => (
                    <div key={idx} className="p-2.5 flex items-center justify-between gap-2 hover:bg-slate-50 transition">
                      <div className="min-w-0 flex-1">
                        <div className="font-bold text-xs text-slate-900 truncate">
                          {item.productName}
                        </div>
                        <div className="text-[10px] text-slate-400 font-mono flex items-center gap-2 mt-0.5">
                          <span>Pack: {item.packageSize || 'Standard'}</span>
                          {item.sku && <span>SKU: {item.sku}</span>}
                        </div>
                      </div>
                      <div className="text-right shrink-0">
                        <div className="font-mono font-black text-xs text-emerald-900 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200/60">
                          {item.quantity} {item.unit || 'kg'}
                        </div>
                        <span className="text-[9px] text-slate-400 block mt-0.5">Unit: {item.unit || 'kg'}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Total Summary & Pricing / Dispatch Note */}
              <div className="bg-slate-900 text-white rounded-xl p-3 space-y-2">
                <div className="flex justify-between items-center text-xs">
                  <span className="text-slate-300">Total Varieties:</span>
                  <span className="font-bold">{selectedOrderForInvoice.items?.length || selectedOrderForInvoice.totalItemsCount || 0}</span>
                </div>
                <div className="flex justify-between items-center text-xs border-t border-slate-800 pt-1.5">
                  <span className="text-slate-300 font-bold">Total Order Volume:</span>
                  <span className="font-mono font-black text-sm text-emerald-400">
                    {selectedOrderForInvoice.totalQuantityKg ?? 0} kg
                  </span>
                </div>
                <div className="text-[10px] text-slate-400 border-t border-slate-800 pt-1.5 leading-relaxed">
                  Consignment Indent: Official tax invoice & applicable GST pricing are finalized at dispatch with consignment LR docket.
                </div>
              </div>

              {/* Logistics & LR Info */}
              {(selectedOrderForInvoice.lrNumber || selectedOrderForInvoice.assignedExecutiveName) && (
                <div className="bg-slate-50 border border-slate-200 rounded-xl p-3 space-y-1 text-[11px]">
                  <div className="font-bold text-slate-700 flex items-center gap-1">
                    <Truck className="w-3.5 h-3.5 text-blue-600" />
                    <span>Logistics & Fulfillment</span>
                  </div>
                  {selectedOrderForInvoice.lrNumber && (
                    <div className="flex justify-between pt-0.5">
                      <span className="text-slate-500">LR Docket:</span>
                      <span className="font-mono font-bold text-slate-800">{selectedOrderForInvoice.lrNumber}</span>
                    </div>
                  )}
                  {selectedOrderForInvoice.transporterName && (
                    <div className="flex justify-between">
                      <span className="text-slate-500">Transporter:</span>
                      <span className="text-slate-800">{selectedOrderForInvoice.transporterName}</span>
                    </div>
                  )}
                  {selectedOrderForInvoice.assignedExecutiveName && (
                    <div className="flex justify-between">
                      <span className="text-slate-500">Field Executive:</span>
                      <span className="text-slate-800">{selectedOrderForInvoice.assignedExecutiveName}</span>
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="p-3 bg-slate-50 border-t border-slate-200 flex items-center gap-2">
              <button
                onClick={() => {
                  setSelectedOrderForTrack(selectedOrderForInvoice);
                  setSelectedOrderForInvoice(null);
                  setActiveNav('tracking');
                }}
                className="flex-1 py-2 bg-emerald-800 hover:bg-emerald-900 text-white rounded-xl font-bold text-xs shadow transition flex items-center justify-center gap-1.5 cursor-pointer"
              >
                <Truck className="w-3.5 h-3.5" />
                <span>Track Consignment</span>
              </button>
              <button
                onClick={() => setSelectedOrderForInvoice(null)}
                className="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-700 rounded-xl font-bold text-xs transition cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bottom Navigation Bar */}
      <nav className="bg-white border-t border-slate-200 px-3 py-2 flex items-center justify-around absolute bottom-0 left-0 right-0 z-30 shadow-lg select-none">
        <button
          onClick={() => setActiveNav('home')}
          className={`flex flex-col items-center gap-0.5 text-[10px] font-bold transition ${
            activeNav === 'home' ? 'text-emerald-800' : 'text-slate-400 hover:text-slate-700'
          }`}
        >
          <Home className="w-4 h-4" />
          <span>Home</span>
        </button>

        <button
          onClick={() => setActiveNav('products')}
          className={`flex flex-col items-center gap-0.5 text-[10px] font-bold transition ${
            activeNav === 'products' ? 'text-emerald-800' : 'text-slate-400 hover:text-slate-700'
          }`}
        >
          <Sprout className="w-4 h-4" />
          <span>Products</span>
        </button>

        <button
          onClick={() => setActiveNav('cart')}
          className={`relative flex flex-col items-center gap-0.5 text-[10px] font-bold transition ${
            activeNav === 'cart' ? 'text-emerald-800' : 'text-slate-400 hover:text-slate-700'
          }`}
        >
          <ShoppingCart className="w-4 h-4" />
          <span>Cart</span>
          {cart.length > 0 && (
            <span className="absolute -top-1 right-2 w-3.5 h-3.5 bg-amber-500 text-slate-950 font-black text-[8px] rounded-full flex items-center justify-center">
              {cart.length}
            </span>
          )}
        </button>

        <button
          onClick={() => setActiveNav('orders')}
          className={`flex flex-col items-center gap-0.5 text-[10px] font-bold transition ${
            activeNav === 'orders' ? 'text-emerald-800' : 'text-slate-400 hover:text-slate-700'
          }`}
        >
          <Package className="w-4 h-4" />
          <span>Orders</span>
        </button>

        <button
          onClick={() => setActiveNav('tracking')}
          className={`flex flex-col items-center gap-0.5 text-[10px] font-bold transition ${
            activeNav === 'tracking' ? 'text-emerald-800' : 'text-slate-400 hover:text-slate-700'
          }`}
        >
          <Truck className="w-4 h-4" />
          <span>Tracking</span>
        </button>

        <button
          onClick={() => setActiveNav('profile')}
          className={`flex flex-col items-center gap-0.5 text-[10px] font-bold transition ${
            activeNav === 'profile' ? 'text-emerald-800' : 'text-slate-400 hover:text-slate-700'
          }`}
        >
          <User className="w-4 h-4" />
          <span>Profile</span>
        </button>
      </nav>
    </DeviceFrame>
  );
};
