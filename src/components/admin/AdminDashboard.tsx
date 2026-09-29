import React from 'react';
import { useAppState } from '../../context/AppStateContext';
import { LiveMap } from '../common/LiveMap';
import {
  Users,
  UserCheck,
  MapPin,
  Building2,
  Package,
  Truck,
  ArrowUpRight,
  Clock,
  CheckCircle2,
  AlertCircle,
  ExternalLink
} from 'lucide-react';

export const AdminDashboard: React.FC = () => {
  const { employees, shops, orders, shipments, setActiveTab, setSelectedOrderForTrack, updateOrderStatus } = useAppState();

  const activeEmployees = employees.filter((e) => e.status === 'Active').length;
  const presentEmployees = employees.filter((e) => e.attendanceStatus === 'Present' || e.attendanceStatus === 'In Field').length;
  const liveTrackingCount = employees.filter((e) => e.attendanceStatus === 'In Field' || e.attendanceStatus === 'Present').length;
  const totalShopOwners = shops.length * 50; // Scaled representation // Scaled representation

  // Total bags ordered across orders
  const todayOrders = orders.slice(0, 5);
  const totalBagsToday = orders.reduce((sum, ord) => sum + ord.totalQuantityBags, 0);

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* 1. Top 6 KPI Metric Cards matching reference UI screenshot */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        {/* Total Employees */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Total Employees</span>
            <div className="p-1.5 rounded-lg bg-emerald-50 text-emerald-700">
              <Users className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-2xl font-black text-slate-900">78</span>
            <span className="text-[10px] text-emerald-600 font-semibold">Active: {activeEmployees}</span>
          </div>
          <div className="text-[10px] text-slate-400 mt-1 font-medium">Headcount on roll</div>
        </div>

        {/* Present Today */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Present Today</span>
            <div className="p-1.5 rounded-lg bg-emerald-50 text-emerald-700">
              <UserCheck className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-2xl font-black text-slate-900">62</span>
            <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-emerald-100 text-emerald-800 font-bold">79.49%</span>
          </div>
          <div className="text-[10px] text-slate-400 mt-1 font-medium">Attendance verified</div>
        </div>

        {/* Live Employees */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Live Employees</span>
            <div className="p-1.5 rounded-lg bg-emerald-50 text-emerald-700">
              <MapPin className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-2xl font-black text-slate-900">28</span>
            <span className="text-[10px] text-emerald-600 font-semibold flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping" />
              Tracking Now
            </span>
          </div>
          <div className="text-[10px] text-slate-400 mt-1 font-medium">On-field GPS active</div>
        </div>

        {/* Total Shop Owners */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Total Shop Owners</span>
            <div className="p-1.5 rounded-lg bg-blue-50 text-blue-700">
              <Building2 className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-2xl font-black text-slate-900">348</span>
            <span className="text-[10px] text-blue-600 font-semibold">Active Network</span>
          </div>
          <div className="text-[10px] text-slate-400 mt-1 font-medium">Across 6 Agri Zones</div>
        </div>

        {/* Today's Orders (Strictly NO PRICE) */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Today's Orders</span>
            <div className="p-1.5 rounded-lg bg-amber-50 text-amber-700">
              <Package className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-2xl font-black text-slate-900">{orders.length}</span>
            <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-amber-100 text-amber-900 font-bold">
              {totalBagsToday} Bags
            </span>
          </div>
          <div className="text-[10px] text-slate-400 mt-1 font-medium">Volume booked today</div>
        </div>

        {/* Active Shipments */}
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">Active Shipments</span>
            <div className="p-1.5 rounded-lg bg-purple-50 text-purple-700">
              <Truck className="w-4 h-4" />
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-2xl font-black text-slate-900">{shipments.length + 12}</span>
            <span className="text-[10px] text-purple-600 font-semibold">LR Dispatched</span>
          </div>
          <div className="text-[10px] text-slate-400 mt-1 font-medium">In transit to dealers</div>
        </div>
      </div>

      {/* 2. Middle Grid: Employee Live Location Map + Today's Attendance Donut */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Employee Live Location Card (2 cols) */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/80 shadow-card p-5 flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
              <h2 className="font-bold text-slate-900 text-sm">Employee Live Location</h2>
            </div>
            <button
              onClick={() => setActiveTab('live-tracking')}
              className="text-xs font-semibold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 hover:underline cursor-pointer"
            >
              <span>View All</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Leaflet Map */}
          <div className="flex-1 min-h-[280px]">
            <LiveMap employees={employees} shops={shops} height="290px" zoom={9} />
          </div>

          {/* Map Status Footer Bar matching reference */}
          <div className="mt-3 pt-3 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="flex items-center gap-4 text-slate-600">
              <span className="flex items-center gap-1.5 font-semibold">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                28 Live
              </span>
              <span className="flex items-center gap-1.5 font-semibold">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                10 Idle
              </span>
              <span className="flex items-center gap-1.5 font-semibold">
                <span className="w-2.5 h-2.5 rounded-full bg-slate-400" />
                50 Offline
              </span>
            </div>
            <div className="text-slate-500 font-medium">
              Max Distance from Office: <span className="font-bold text-slate-800">45.6 km</span>
            </div>
          </div>
        </div>

        {/* Today's Attendance Summary (1 col) matching circular chart */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5 flex flex-col">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-bold text-slate-900 text-sm">Today's Attendance Summary</h2>
            <button
              onClick={() => setActiveTab('attendance')}
              className="text-xs font-semibold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 hover:underline cursor-pointer"
            >
              <span>View All</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* SVG Donut Chart */}
          <div className="flex-1 flex flex-col items-center justify-center py-2">
            <div className="relative w-44 h-44 flex items-center justify-center">
              <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                {/* Background Ring */}
                <circle cx="50" cy="50" r="38" stroke="#f1f5f9" strokeWidth="11" fill="none" />
                {/* Present (Green): 62 / 78 = ~79.5% -> 2*PI*38 = 238.76 -> 189.8 */}
                <circle
                  cx="50"
                  cy="50"
                  r="38"
                  stroke="#16a34a"
                  strokeWidth="11"
                  strokeDasharray="189.8 238.76"
                  strokeDashoffset="0"
                  fill="none"
                  strokeLinecap="round"
                />
                {/* Late (Orange): 6 / 78 = 7.7% -> 18.4 */}
                <circle
                  cx="50"
                  cy="50"
                  r="38"
                  stroke="#ea580c"
                  strokeWidth="11"
                  strokeDasharray="18.4 238.76"
                  strokeDashoffset="-192"
                  fill="none"
                />
                {/* Absent (Red): 5 / 78 = 6.4% -> 15.3 */}
                <circle
                  cx="50"
                  cy="50"
                  r="38"
                  stroke="#ef4444"
                  strokeWidth="11"
                  strokeDasharray="15.3 238.76"
                  strokeDashoffset="-212"
                  fill="none"
                />
                {/* Half Day (Amber): 5 / 78 = 6.4% -> 15.3 */}
                <circle
                  cx="50"
                  cy="50"
                  r="38"
                  stroke="#f59e0b"
                  strokeWidth="11"
                  strokeDasharray="15.3 238.76"
                  strokeDashoffset="-228"
                  fill="none"
                />
              </svg>

              {/* Center Counter */}
              <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
                <span className="text-3xl font-black text-slate-900">78</span>
                <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Employees</span>
              </div>
            </div>

            {/* Donut Legend */}
            <div className="grid grid-cols-2 gap-3 w-full mt-4 pt-3 border-t border-slate-100 text-xs">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-md bg-[#16a34a]" />
                <span className="text-slate-600 font-medium">62 Present</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-md bg-[#ea580c]" />
                <span className="text-slate-600 font-medium">6 Late</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-md bg-[#ef4444]" />
                <span className="text-slate-600 font-medium">5 Absent</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-md bg-[#f59e0b]" />
                <span className="text-slate-600 font-medium">5 Half Day</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 3. Today's Check In / Check Out Table matching reference screenshot */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <Clock className="w-4 h-4 text-emerald-700" />
            <h2 className="font-bold text-slate-900 text-sm">Today's Check In / Check Out</h2>
          </div>
          <button
            onClick={() => setActiveTab('attendance')}
            className="text-xs font-semibold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 hover:underline cursor-pointer"
          >
            <span>View All</span>
            <ArrowUpRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 text-slate-400 font-bold uppercase tracking-wider text-[10px] pb-2">
                <th className="pb-3 pl-1">Employee</th>
                <th className="pb-3">Check In</th>
                <th className="pb-3">Check Out</th>
                <th className="pb-3">Status</th>
                <th className="pb-3 pr-1 text-right">Distance</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {employees.slice(0, 5).map((emp) => (
                <tr key={emp.id} className="hover:bg-slate-50/80 transition">
                  <td className="py-3 pl-1">
                    <div className="flex items-center gap-2.5">
                      <img src={emp.avatar} alt={emp.name} className="w-7 h-7 rounded-full object-cover" />
                      <div>
                        <div className="font-bold text-slate-900">{emp.name}</div>
                        <div className="text-[10px] text-slate-400">{emp.empId} • {emp.role}</div>
                      </div>
                    </div>
                  </td>
                  <td className="py-3 font-mono font-medium text-slate-600">{emp.checkInTime || '--:--'}</td>
                  <td className="py-3 font-mono font-medium text-slate-600">{emp.checkOutTime || '--:--'}</td>
                  <td className="py-3">
                    <span
                      className={`inline-flex items-center px-2 py-0.5 rounded-md font-semibold text-[10px] ${
                        emp.attendanceStatus === 'Present'
                          ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          : emp.attendanceStatus === 'In Field'
                          ? 'bg-blue-50 text-blue-700 border border-blue-200'
                          : emp.attendanceStatus === 'In Office'
                          ? 'bg-amber-50 text-amber-700 border border-amber-200'
                          : 'bg-red-50 text-red-700 border border-red-200'
                      }`}
                    >
                      {emp.attendanceStatus}
                    </span>
                  </td>
                  <td className="py-3 pr-1 text-right font-mono font-semibold text-slate-800">
                    {emp.distanceCoveredTodayKm > 0 ? `${emp.distanceCoveredTodayKm} km` : '0 km'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* 4. Bottom Grid: Shop Owner Stock Summary + Recent Orders */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Shop Owner Stock Summary (Strictly Bags, NO Price) */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-bold text-slate-900 text-sm">Shop Owner Stock Summary</h2>
            <button
              onClick={() => setActiveTab('shop-owners')}
              className="text-xs font-semibold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 hover:underline cursor-pointer"
            >
              <span>View All</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-100 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                  <th className="pb-3 pl-1">Shop Owner</th>
                  <th className="pb-3">Top Product</th>
                  <th className="pb-3 text-right">Opening (Bags)</th>
                  <th className="pb-3 pr-1 text-right">Stock (Bags)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-slate-700">
                {shops.slice(0, 5).map((shop) => (
                  <tr key={shop.id} className="hover:bg-slate-50/80 transition">
                    <td className="py-3 pl-1">
                      <div className="font-bold text-slate-900">{shop.name}</div>
                      <div className="text-[10px] text-slate-400">📍 {shop.location}</div>
                    </td>
                    <td className="py-3 text-slate-600 font-medium">{shop.primaryCropDemand}</td>
                    <td className="py-3 text-right font-mono text-slate-500">{shop.openingStockBags}</td>
                    <td className="py-3 pr-1 text-right font-mono font-bold text-emerald-800">
                      {shop.currentStockBags}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Recent Orders (Strictly Bags, NO Price) */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-bold text-slate-900 text-sm">Recent Seed Orders</h2>
            <button
              onClick={() => setActiveTab('orders')}
              className="text-xs font-semibold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 hover:underline cursor-pointer"
            >
              <span>View All</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-100 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                  <th className="pb-3 pl-1">Order ID</th>
                  <th className="pb-3">Shop</th>
                  <th className="pb-3 text-center">Items</th>
                  <th className="pb-3 text-center">Total Bags</th>
                  <th className="pb-3 pr-1 text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-slate-700">
                {orders.slice(0, 5).map((ord) => (
                  <tr key={ord.id} className="hover:bg-slate-50/80 transition">
                    <td className="py-3 pl-1">
                      <div className="font-mono font-bold text-emerald-700">{ord.orderNumber}</div>
                      <div className="text-[10px] text-slate-400">{ord.orderDate}</div>
                    </td>
                    <td className="py-3">
                      <div className="font-semibold text-slate-900">{ord.shopName}</div>
                      <div className="text-[10px] text-slate-400">{ord.shopLocation}</div>
                    </td>
                    <td className="py-3 text-center font-mono">{ord.totalItemsCount}</td>
                    <td className="py-3 text-center font-mono font-bold text-slate-900">
                      {ord.totalQuantityBags} Bags
                    </td>
                    <td className="py-3 pr-1 text-right">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded-full font-bold text-[10px] ${
                          ord.status === 'New'
                            ? 'bg-amber-100 text-amber-900 animate-pulse'
                            : ord.status === 'Dispatched' || ord.status === 'In Transit'
                            ? 'bg-blue-100 text-blue-900'
                            : ord.status === 'Delivered'
                            ? 'bg-emerald-100 text-emerald-900'
                            : 'bg-slate-100 text-slate-800'
                        }`}
                      >
                        {ord.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* 5. Outstanding Consignment & Indent Summary (Strictly Bags & Indents, NO Price) */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5">
        <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div>
            <div className="flex items-center gap-2">
              <Package className="w-4 h-4 text-emerald-700" />
              <h2 className="font-bold text-slate-900 text-sm">Consignment Outstanding Summary</h2>
            </div>
            <p className="text-[11px] text-slate-400 mt-0.5">Dealer indents, pending warehouse dispatches, and in-transit volume allocation</p>
          </div>
          <button
            onClick={() => setActiveTab('shipments')}
            className="text-xs font-semibold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 hover:underline cursor-pointer"
          >
            <span>Track All Shipments</span>
            <ArrowUpRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* 4 Outstanding Metric Badges */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
          <div className="p-3.5 rounded-xl bg-amber-50/70 border border-amber-200/80">
            <span className="text-[10px] font-bold uppercase tracking-wider text-amber-800">Pending Warehouse Packing</span>
            <div className="text-xl font-black text-amber-900 mt-1">165 Bags</div>
            <span className="text-[10px] text-amber-700 font-medium">8 Dealer indents queued</span>
          </div>
          <div className="p-3.5 rounded-xl bg-blue-50/70 border border-blue-200/80">
            <span className="text-[10px] font-bold uppercase tracking-wider text-blue-800">In-Transit On Road</span>
            <div className="text-xl font-black text-blue-900 mt-1">480 Bags</div>
            <span className="text-[10px] text-blue-700 font-medium">14 Active LR consignments</span>
          </div>
          <div className="p-3.5 rounded-xl bg-purple-50/70 border border-purple-200/80">
            <span className="text-[10px] font-bold uppercase tracking-wider text-purple-800">Out For Shop Handover</span>
            <div className="text-xl font-black text-purple-900 mt-1">85 Bags</div>
            <span className="text-[10px] text-purple-700 font-medium">3 Local delivery vehicles</span>
          </div>
          <div className="p-3.5 rounded-xl bg-emerald-50/70 border border-emerald-200/80">
            <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-800">Fulfillment Ratio</span>
            <div className="text-xl font-black text-emerald-900 mt-1">91.4%</div>
            <span className="text-[10px] text-emerald-700 font-medium">Consignment SLA Met</span>
          </div>
        </div>

        {/* Outstanding Dealer Indents List */}
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                <th className="pb-2.5 pl-1">Dealer / Shop</th>
                <th className="pb-2.5">Territory</th>
                <th className="pb-2.5 text-center">Outstanding Bags</th>
                <th className="pb-2.5">Associated Order</th>
                <th className="pb-2.5 pr-1 text-right">Dispatch Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              <tr className="hover:bg-slate-50/80 transition">
                <td className="py-2.5 pl-1 font-bold text-slate-900">ABC Seeds & Fertilizers</td>
                <td className="py-2.5 text-slate-500">Guntur Market Yard</td>
                <td className="py-2.5 text-center font-mono font-bold text-amber-800">25 Bags</td>
                <td className="py-2.5 font-mono text-emerald-700 font-bold">ORD-1025</td>
                <td className="py-2.5 pr-1 text-right">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-900">
                    Awaiting LR
                  </span>
                </td>
              </tr>
              <tr className="hover:bg-slate-50/80 transition">
                <td className="py-2.5 pl-1 font-bold text-slate-900">Sri Balaji Agro Agencies</td>
                <td className="py-2.5 text-slate-500">Tenali Main Road</td>
                <td className="py-2.5 text-center font-mono font-bold text-blue-800">45 Bags</td>
                <td className="py-2.5 font-mono text-emerald-700 font-bold">ORD-1024</td>
                <td className="py-2.5 pr-1 text-right">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-blue-100 text-blue-900">
                    Dispatched (VRL)
                  </span>
                </td>
              </tr>
              <tr className="hover:bg-slate-50/80 transition">
                <td className="py-2.5 pl-1 font-bold text-slate-900">Kisan Krishi Seva Kendra</td>
                <td className="py-2.5 text-slate-500">Vijayawada Rural</td>
                <td className="py-2.5 text-center font-mono font-bold text-blue-800">30 Bags</td>
                <td className="py-2.5 font-mono text-emerald-700 font-bold">ORD-1023</td>
                <td className="py-2.5 pr-1 text-right">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-blue-100 text-blue-900">
                    In Transit
                  </span>
                </td>
              </tr>
              <tr className="hover:bg-slate-50/80 transition">
                <td className="py-2.5 pl-1 font-bold text-slate-900">Annapurna Rythu Seva</td>
                <td className="py-2.5 text-slate-500">Nandigama Bypass</td>
                <td className="py-2.5 text-center font-mono font-bold text-emerald-800">60 Bags</td>
                <td className="py-2.5 font-mono text-emerald-700 font-bold">ORD-1022</td>
                <td className="py-2.5 pr-1 text-right">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-900">
                    Delivered
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
