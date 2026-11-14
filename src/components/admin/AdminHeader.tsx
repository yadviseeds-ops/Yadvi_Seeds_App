import React from 'react';
import { useAppState } from '../../context/AppStateContext';
import { Calendar, Bell, Search, ShieldCheck } from 'lucide-react';

interface AdminHeaderProps {
  title?: string;
  subtitle?: string;
}

export const AdminHeader: React.FC<AdminHeaderProps> = ({
  title = 'Good Morning, Ramesh Kumar 👋',
  subtitle = "Here's what's happening with your seed business today.",
}) => {
  const { triggerWhatsAppAlert, orders } = useAppState();

  const newOrdersCount = orders.filter((o) => o.status === 'New').length;

  return (
    <header className="bg-white border-b border-slate-200/80 px-6 py-4 flex flex-wrap items-center justify-between gap-4 sticky top-0 z-20 shadow-xs">
      {/* Title & Subtitle */}
      <div className="flex items-center gap-3">
        <div>
          <h1 className="text-xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            {title}
          </h1>
          <p className="text-xs text-slate-500 font-medium mt-0.5">{subtitle}</p>
        </div>
      </div>

      {/* Right Header Actions */}
      <div className="flex items-center gap-3.5">
        {/* Date Selector Badge */}
        <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-700">
          <Calendar className="w-3.5 h-3.5 text-emerald-600" />
          <span>22 Sep 2026, Tuesday</span>
        </div>

        {/* Notifications Icon with Badge */}
        <button
          onClick={() =>
            triggerWhatsAppAlert({
              show: true,
              orderNumber: 'ORD-1025',
              shopName: 'ABC Seeds & Fertilizers',
              itemsCount: 5,
              totalQuantity: 25,
              timestamp: '10:24 AM',
              status: 'New',
            })
          }
          className="relative p-2 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-600 transition"
          title="Simulate WhatsApp notification"
        >
          <Bell className="w-4 h-4" />
          {newOrdersCount > 0 && (
            <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white rounded-full text-[9px] font-bold flex items-center justify-center animate-pulse">
              {newOrdersCount}
            </span>
          )}
        </button>

        {/* Profile */}
        <div className="flex items-center gap-3 pl-2 border-l border-slate-200">
          <img
            src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80"
            alt="Ramesh Kumar"
            className="w-9 h-9 rounded-full object-cover ring-2 ring-emerald-600/30"
          />
          <div className="hidden lg:block text-left leading-tight">
            <div className="text-xs font-bold text-slate-900">Ramesh Kumar</div>
            <div className="text-[10px] font-semibold text-emerald-600 flex items-center gap-1">
              <ShieldCheck className="w-3 h-3" />
              <span>Admin</span>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
};
