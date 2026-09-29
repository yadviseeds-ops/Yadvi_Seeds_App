import React from 'react';
import { AppStateProvider, useAppState } from './context/AppStateContext';
import { WhatsAppModal } from './components/common/WhatsAppModal';
import { UnifiedLogin } from './components/auth/UnifiedLogin';
import { AdminSidebar } from './components/admin/AdminSidebar';
import { AdminHeader } from './components/admin/AdminHeader';
import { AdminDashboard } from './components/admin/AdminDashboard';
import { AdminEmployees } from './components/admin/AdminEmployees';
import { AdminLiveTracking } from './components/admin/AdminLiveTracking';
import { AdminAttendance } from './components/admin/AdminAttendance';
import { AdminFieldVisits } from './components/admin/AdminFieldVisits';
import { AdminShopOwners } from './components/admin/AdminShopOwners';
import { AdminProducts } from './components/admin/AdminProducts';
import { AdminOrders } from './components/admin/AdminOrders';
import { AdminShipments } from './components/admin/AdminShipments';
import { AdminReports } from './components/admin/AdminReports';
import { AdminSettings } from './components/admin/AdminSettings';
import { ShopOwnerApp } from './components/mobile/ShopOwnerApp';
import { FieldExecutiveApp } from './components/mobile/FieldExecutiveApp';

const MainApp: React.FC = () => {
  const { currentRole, isAuthenticated, activeTab } = useAppState();

  const renderAdminContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <AdminDashboard />;
      case 'employees':
        return <AdminEmployees />;
      case 'live-tracking':
        return <AdminLiveTracking />;
      case 'attendance':
      case 'leaves':
        return <AdminAttendance />;
      case 'field-visits':
        return <AdminFieldVisits />;
      case 'shop-owners':
        return <AdminShopOwners />;
      case 'products':
      case 'inventory':
        return <AdminProducts />;
      case 'orders':
        return <AdminOrders />;
      case 'shipments':
        return <AdminShipments />;
      case 'reports':
        return <AdminReports />;
      case 'settings':
        return <AdminSettings />;
      default:
        return <AdminDashboard />;
    }
  };

  // If not authenticated, display the unified login matching the user's screenshot
  if (!isAuthenticated) {
    return <UnifiedLogin />;
  }

  return (
    <div className="min-h-screen bg-[#f4f7f6] flex flex-col font-sans text-slate-800">

      {/* Role-Based Rendering */}
      {currentRole === 'admin' ? (
        <div className="flex-1 flex overflow-hidden min-h-[calc(100vh-50px)]">
          {/* Sidebar */}
          <AdminSidebar />

          {/* Admin Right Work Area */}
          <main className="flex-1 flex flex-col overflow-y-auto bg-[#f8faf9]">
            <AdminHeader />
            <div className="flex-1">{renderAdminContent()}</div>
          </main>
        </div>
      ) : currentRole === 'shop_owner' ? (
        <main className="flex-1 bg-slate-900/10 flex items-center justify-center p-2 sm:p-4">
          <ShopOwnerApp />
        </main>
      ) : (
        <main className="flex-1 bg-slate-900/10 flex items-center justify-center p-2 sm:p-4">
          <FieldExecutiveApp />
        </main>
      )}

      {/* Simulated WhatsApp Notification Drawer / Popup */}
      <WhatsAppModal />
    </div>
  );
};

export default function App() {
  return (
    <AppStateProvider>
      <MainApp />
    </AppStateProvider>
  );
}
