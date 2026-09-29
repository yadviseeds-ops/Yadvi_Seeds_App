import React from 'react';
import { useAppState } from '../../context/AppStateContext';
import { YadviLogo } from '../common/YadviLogo';
import {
  LayoutDashboard,
  Users,
  MapPin,
  CalendarCheck,
  CalendarX2,
  Briefcase,
  Building2,
  Store,
  Sprout,
  ShoppingCart,
  Truck,
  TrendingUp,
  FileBarChart,
  Bell,
  Settings,
  LogOut,
  Layers,
  ChevronRight
} from 'lucide-react';

export const AdminSidebar: React.FC = () => {
  const { activeTab, setActiveTab, handleLogout, orders, leaves } = useAppState();

  const pendingLeavesCount = leaves.filter((l) => l.status === 'Pending').length;
  const newOrdersCount = orders.filter((o) => o.status === 'New').length;

  const menuItems = [
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { id: 'employees', label: 'Employees', icon: Users },
    { id: 'live-tracking', label: 'Live Tracking', icon: MapPin },
    { id: 'attendance', label: 'Attendance', icon: CalendarCheck },
    { id: 'leaves', label: 'Leaves', icon: CalendarX2, badge: pendingLeavesCount > 0 ? pendingLeavesCount : undefined },
    { id: 'field-visits', label: 'Field Visits', icon: Briefcase },
    { id: 'shop-owners', label: 'Shop Owners', icon: Store },
    { id: 'products', label: 'Products', icon: Sprout },
    { id: 'orders', label: 'Orders', icon: ShoppingCart, badge: newOrdersCount > 0 ? newOrdersCount : undefined },
    { id: 'shipments', label: 'LR Tracking / Shipments', icon: Truck },
    { id: 'inventory', label: 'Inventory / Stock', icon: Layers },
    { id: 'reports', label: 'Reports', icon: FileBarChart },
    { id: 'notifications', label: 'Notifications', icon: Bell, badge: 3 },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  return (
    <aside className="w-64 bg-[#0a3528] text-white flex flex-col shrink-0 border-r border-[#07241b] select-none min-h-screen">
      {/* Brand Header */}
      <div className="p-5 border-b border-[#124b3b]/60 flex items-center gap-3">
        <YadviLogo size="md" variant="white" showTagline={false} />
      </div>

      {/* Navigation List */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        <div className="px-3 pb-2 text-[10px] font-bold uppercase tracking-wider text-emerald-400/70">
          Management Portal
        </div>
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all group ${
                isActive
                  ? 'bg-emerald-600/90 text-white shadow-md shadow-emerald-950/40'
                  : 'text-emerald-100/70 hover:bg-[#124b3b]/70 hover:text-white'
              }`}
            >
              <div className="flex items-center gap-3">
                <Icon
                  className={`w-4 h-4 transition-colors ${
                    isActive ? 'text-white' : 'text-emerald-300/80 group-hover:text-emerald-200'
                  }`}
                />
                <span className="truncate">{item.label}</span>
              </div>

              {item.badge !== undefined && (
                <span
                  className={`px-1.5 py-0.5 rounded-full text-[10px] font-black ${
                    isActive
                      ? 'bg-white text-emerald-900'
                      : 'bg-emerald-500 text-slate-950'
                  }`}
                >
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Admin Profile & Logout Footer */}
      <div className="p-3 border-t border-[#124b3b]/60 bg-[#07251c]">
        <div className="flex items-center justify-between p-2 rounded-xl bg-[#0b3b2c]/60 border border-[#165a46]/40">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/40 flex items-center justify-center font-bold text-xs">
              RK
            </div>
            <div className="overflow-hidden">
              <div className="font-bold text-xs text-white truncate">Ramesh Kumar</div>
              <div className="text-[10px] text-emerald-300/70 truncate">Admin • +91 9876543210</div>
            </div>
          </div>
          <button
            onClick={handleLogout}
            title="Sign Out"
            className="p-1.5 rounded-lg text-emerald-300/80 hover:text-red-300 hover:bg-red-500/20 transition"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </div>
    </aside>
  );
};
