import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { FileBarChart, Download, Calendar, TrendingUp, Package, Building2, Users } from 'lucide-react';

export const AdminReports: React.FC = () => {
  const { products, orders, shops, employees } = useAppState();
  const [activeReportTab, setActiveReportTab] = useState<'orders' | 'shop-owner' | 'employee' | 'stock'>('orders');

  const totalBags = 14850;
  const totalOrders = 348;
  const avgBags = 42.6;

  // Mock 30-day distribution data
  const trendDays = [
    { day: '01', bags: 340 },
    { day: '03', bags: 410 },
    { day: '05', bags: 290 },
    { day: '08', bags: 520 },
    { day: '10', bags: 480 },
    { day: '12', bags: 610 },
    { day: '15', bags: 550 },
    { day: '18', bags: 720 },
    { day: '20', bags: 680 },
    { day: '22', bags: 810 },
    { day: '25', bags: 740 },
    { day: '28', bags: 890 },
    { day: '30', bags: 960 },
  ];

  const maxBags = Math.max(...trendDays.map((d) => d.bags));

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Distribution & Performance Reports</h2>
          <p className="text-xs text-slate-500">Comprehensive seed dispatches, retailer demand trends and field metrics</p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-white border border-slate-200 text-xs font-semibold text-slate-700">
            <Calendar className="w-3.5 h-3.5 text-emerald-600" />
            <span>01 Sep 2026 – 22 Sep 2026</span>
          </div>

          <button
            onClick={() => alert('Yadvi Seed Distribution Performance Report exported as PDF!')}
            className="flex items-center gap-1.5 px-4 py-2 bg-emerald-800 hover:bg-emerald-900 text-white font-bold text-xs rounded-xl shadow-xs transition cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download Report</span>
          </button>
        </div>
      </div>

      {/* Report Category Subtabs */}
      <div className="flex items-center gap-2 border-b border-slate-200 pb-2 text-xs">
        <button
          onClick={() => setActiveReportTab('orders')}
          className={`px-3 py-1.5 rounded-xl font-bold transition ${
            activeReportTab === 'orders'
              ? 'bg-emerald-800 text-white'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          Seed Volume Report
        </button>
        <button
          onClick={() => setActiveReportTab('shop-owner')}
          className={`px-3 py-1.5 rounded-xl font-bold transition ${
            activeReportTab === 'shop-owner'
              ? 'bg-emerald-800 text-white'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          Shop Owner Inward Report
        </button>
        <button
          onClick={() => setActiveReportTab('employee')}
          className={`px-3 py-1.5 rounded-xl font-bold transition ${
            activeReportTab === 'employee'
              ? 'bg-emerald-800 text-white'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          Employee Field Target Report
        </button>
        <button
          onClick={() => setActiveReportTab('stock')}
          className={`px-3 py-1.5 rounded-xl font-bold transition ${
            activeReportTab === 'stock'
              ? 'bg-emerald-800 text-white'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          Warehouse Stock Audit Report
        </button>
      </div>

      {/* Top 3 Metric Tiles matching reference screenshot */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-card">
          <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Total Volume Dispatched</div>
          <div className="text-3xl font-black text-slate-900 mt-1">14,850 <span className="text-base font-bold text-slate-500">Bags</span></div>
          <div className="text-xs text-emerald-600 font-semibold mt-1 flex items-center gap-1">
            <TrendingUp className="w-3.5 h-3.5" />
            <span>+14.2% vs last month</span>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-card">
          <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Total Orders Processed</div>
          <div className="text-3xl font-black text-slate-900 mt-1">348 <span className="text-base font-bold text-slate-500">Orders</span></div>
          <div className="text-xs text-emerald-600 font-semibold mt-1 flex items-center gap-1">
            <TrendingUp className="w-3.5 h-3.5" />
            <span>+8.4% vs last month</span>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-card">
          <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Avg Volume Per Order</div>
          <div className="text-3xl font-black text-slate-900 mt-1">42.6 <span className="text-base font-bold text-slate-500">Bags</span></div>
          <div className="text-xs text-emerald-600 font-semibold mt-1 flex items-center gap-1">
            <TrendingUp className="w-3.5 h-3.5" />
            <span>+5.1% vs last month</span>
          </div>
        </div>
      </div>

      {/* Sales Trend Bar Chart + Top Products List matching reference screenshot */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Trend Bar Chart */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/80 shadow-card p-5 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-bold text-slate-900 text-sm">Monthly Seed Dispatch Trend (Bags)</h3>
              <span className="text-[11px] font-mono text-slate-400">Daily Consignment Volume</span>
            </div>

            <div className="h-56 flex items-end gap-2.5 sm:gap-4 pt-6 pb-2 px-2 border-b border-slate-100">
              {trendDays.map((item, i) => {
                const heightPercent = Math.round((item.bags / maxBags) * 100);
                return (
                  <div key={i} className="flex-1 flex flex-col items-center gap-2 group h-full justify-end">
                    <span className="text-[9px] font-mono text-slate-400 opacity-0 group-hover:opacity-100 transition">
                      {item.bags}
                    </span>
                    <div
                      style={{ height: `${heightPercent}%` }}
                      className="w-full bg-emerald-600 hover:bg-emerald-500 rounded-t-md transition duration-200 shadow-xs"
                    />
                    <span className="text-[10px] font-medium text-slate-500">{item.day}</span>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="mt-4 flex items-center justify-between text-xs text-slate-500">
            <span>Peak Day: 30th (960 Bags)</span>
            <span className="font-bold text-emerald-800">Total: 14,850 Bags</span>
          </div>
        </div>

        {/* Top Seed Products by Quantity matching reference screenshot */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5">
          <h3 className="font-bold text-slate-900 text-sm mb-4">Top Performing Seed Varieties</h3>

          <div className="space-y-3.5">
            {products.slice(0, 5).map((p, idx) => (
              <div key={p.id} className="flex items-center justify-between p-2 rounded-xl hover:bg-slate-50 transition">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-lg bg-slate-100 p-1 flex items-center justify-center shrink-0 border border-slate-200">
                    <img src={p.image} alt={p.name} className="max-h-full object-contain" />
                  </div>
                  <div>
                    <div className="font-bold text-xs text-slate-900 truncate max-w-[140px]">{p.name}</div>
                    <div className="text-[10px] text-slate-400 font-mono">{p.sku}</div>
                  </div>
                </div>

                <div className="text-right">
                  <div className="font-mono font-bold text-xs text-emerald-800">
                    {(1450 - idx * 210).toLocaleString()} Bags
                  </div>
                  <div className="text-[10px] text-slate-400 font-medium">Rank #{idx + 1}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
