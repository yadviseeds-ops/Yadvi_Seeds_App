import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { Order, OrderStatus } from '../../data/mockOrders';
import {
  ShoppingCart,
  Search,
  CheckCircle,
  Truck,
  Package,
  Clock,
  ChevronRight,
  Eye,
  X,
  FileText,
  Building,
  User,
  Phone,
  MapPin,
  Send
} from 'lucide-react';

export const AdminOrders: React.FC = () => {
  const { orders, employees, updateOrderStatus, assignOrderExecutive, triggerWhatsAppAlert } = useAppState();
  const [statusFilter, setStatusFilter] = useState<string>('All');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [selectedExecutive, setSelectedExecutive] = useState('');

  // Dispatch form states for modal
  const [lrInput, setLrInput] = useState('LR-NVT-88910');
  const [transporterInput, setTransporterInput] = useState('Navata Road Transport');

  const filteredOrders = orders.filter((ord) => {
    const matchesStatus = statusFilter === 'All' || ord.status === statusFilter;
    const matchesSearch =
      ord.orderNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
      ord.shopName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      ord.shopLocation.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesStatus && matchesSearch;
  });

  const handleAdvanceStatus = async (order: Order) => {
    const sequence: Record<OrderStatus, OrderStatus> = {
      New: 'Confirmed',
      Confirmed: 'Processing',
      Processing: 'Packed',
      Packed: 'Dispatched',
      Dispatched: 'In Transit',
      'In Transit': 'Delivered',
      Delivered: 'Delivered',
      Cancelled: 'Cancelled',
    };

    const nextStatus = sequence[order.status];
    if (nextStatus === 'Dispatched') {
      await updateOrderStatus(order.id, 'Dispatched', lrInput, transporterInput);
    } else {
      await updateOrderStatus(order.id, nextStatus);
    }

    // Refresh selected modal
    const updated = orders.find((o) => o.id === order.id);
    if (updated) {
      setSelectedOrder({ ...updated, status: nextStatus });
    }
  };

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Order Management Workflow</h2>
          <p className="text-xs text-slate-500">Track and advance seed consignments across multi-stage logistics</p>
        </div>

        <div className="flex items-center gap-2">
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
            className="px-3.5 py-1.5 bg-emerald-100 text-emerald-900 border border-emerald-300 rounded-xl text-xs font-bold hover:bg-emerald-200 transition flex items-center gap-1.5"
          >
            <span>📱 Test WhatsApp Notification</span>
          </button>
        </div>
      </div>

      {/* Filter Tabs & Search */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs">
          {(['All', 'New', 'Confirmed', 'Processing', 'Packed', 'Dispatched', 'In Transit', 'Delivered'] as const).map(
            (tab) => {
              const count = orders.filter((o) => (tab === 'All' ? true : o.status === tab)).length;
              return (
                <button
                  key={tab}
                  onClick={() => setStatusFilter(tab)}
                  className={`px-3 py-1.5 rounded-xl font-semibold transition whitespace-nowrap flex items-center gap-1.5 ${
                    statusFilter === tab
                      ? 'bg-emerald-800 text-white shadow-sm'
                      : 'bg-slate-50 text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <span>{tab}</span>
                  {count > 0 && (
                    <span
                      className={`px-1.5 py-0.2 rounded-full text-[10px] font-bold ${
                        statusFilter === tab ? 'bg-white text-emerald-900' : 'bg-slate-200 text-slate-700'
                      }`}
                    >
                      {count}
                    </span>
                  )}
                </button>
              );
            }
          )}
        </div>

        <div className="relative min-w-[220px]">
          <Search className="w-4 h-4 absolute left-3.5 top-2.5 text-slate-400" />
          <input
            type="text"
            placeholder="Search Order ID, Shop..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-9 pr-4 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-600"
          />
        </div>
      </div>

      {/* Orders Table */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="bg-slate-50/70 border-b border-slate-200/80 text-slate-500 font-bold uppercase tracking-wider text-[10px]">
                <th className="py-3.5 px-4">Order ID & Date</th>
                <th className="py-3.5 px-4">Shop / Distributor</th>
                <th className="py-3.5 px-4 text-center">Items</th>
                <th className="py-3.5 px-4 text-center">Total Bags</th>
                <th className="py-3.5 px-4">Assigned Exec</th>
                <th className="py-3.5 px-4">LR / Transporter</th>
                <th className="py-3.5 px-4">Status</th>
                <th className="py-3.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {filteredOrders.map((ord) => (
                <tr
                  key={ord.id}
                  onClick={() => setSelectedOrder(ord)}
                  className="hover:bg-slate-50/80 transition cursor-pointer"
                >
                  <td className="py-3.5 px-4">
                    <div className="font-mono font-black text-emerald-800 text-xs">{ord.orderNumber}</div>
                    <div className="text-[10px] text-slate-400">{ord.orderDate}</div>
                  </td>
                  <td className="py-3.5 px-4">
                    <div className="font-bold text-slate-900">{ord.shopName}</div>
                    <div className="text-[10px] text-slate-400">📍 {ord.shopLocation}</div>
                  </td>
                  <td className="py-3.5 px-4 text-center font-mono font-medium">{ord.totalItemsCount}</td>
                  <td className="py-3.5 px-4 text-center">
                    <span className="font-mono font-black text-slate-900 px-2 py-0.5 bg-slate-100 rounded-md">
                      {ord.totalQuantityBags} Bags
                    </span>
                  </td>
                  <td className="py-3.5 px-4">
                    <div className="font-medium text-slate-800">{ord.assignedExecutiveName}</div>
                    <div className="text-[10px] text-slate-400">Source: {ord.source}</div>
                  </td>
                  <td className="py-3.5 px-4">
                    {ord.lrNumber ? (
                      <div>
                        <div className="font-mono font-bold text-blue-700">{ord.lrNumber}</div>
                        <div className="text-[10px] text-slate-400">{ord.transporterName}</div>
                      </div>
                    ) : (
                      <span className="text-slate-400 italic text-[11px]">Pending Dispatch</span>
                    )}
                  </td>
                  <td className="py-3.5 px-4">
                    <span
                      className={`inline-flex items-center px-2.5 py-1 rounded-full font-bold text-[10px] ${
                        ord.status === 'New'
                          ? 'bg-amber-100 text-amber-900 animate-pulse border border-amber-300'
                          : ord.status === 'Confirmed'
                          ? 'bg-blue-100 text-blue-900'
                          : ord.status === 'Processing'
                          ? 'bg-purple-100 text-purple-900'
                          : ord.status === 'Packed'
                          ? 'bg-indigo-100 text-indigo-900'
                          : ord.status === 'Dispatched' || ord.status === 'In Transit'
                          ? 'bg-cyan-100 text-cyan-900'
                          : ord.status === 'Delivered'
                          ? 'bg-emerald-100 text-emerald-900'
                          : 'bg-red-100 text-red-900'
                      }`}
                    >
                      {ord.status}
                    </span>
                  </td>
                  <td className="py-3.5 px-4 text-right">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedOrder(ord);
                      }}
                      className="px-3 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-800 text-[11px] font-bold transition inline-flex items-center gap-1"
                    >
                      <span>Manage</span>
                      <ChevronRight className="w-3.5 h-3.5" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Order Detail & Status Progression Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl max-w-2xl w-full overflow-hidden border border-slate-200 animate-scale-in">
            {/* Modal Header */}
            <div className="bg-[#0b3b2c] p-6 text-white flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-lg font-black">{selectedOrder.orderNumber}</span>
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-white text-emerald-900">
                    {selectedOrder.status}
                  </span>
                </div>
                <div className="text-xs text-emerald-200 mt-1">Booked on: {selectedOrder.orderDate}</div>
              </div>
              <button
                onClick={() => setSelectedOrder(null)}
                className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-5 text-xs text-slate-700 max-h-[75vh] overflow-y-auto">
              {/* Shop info card */}
              <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 grid grid-cols-2 gap-4">
                <div>
                  <div className="text-slate-400 font-medium">Dealer Shop:</div>
                  <div className="font-bold text-slate-900 text-sm mt-0.5">{selectedOrder.shopName}</div>
                  <div className="text-slate-500 mt-0.5">Proprietor: {selectedOrder.ownerName}</div>
                  <div className="text-slate-500">{selectedOrder.contactPhone}</div>
                </div>
                <div>
                  <div className="text-slate-400 font-medium">Destination Address:</div>
                  <div className="text-slate-700 mt-0.5 leading-relaxed">{selectedOrder.deliveryAddress}</div>
                  <div className="text-emerald-700 font-semibold mt-1">Field Exec: {selectedOrder.assignedExecutiveName}</div>
                </div>
              </div>

              {/* Products in this order with Real Yadvi Packet Thumbnails */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <h4 className="font-bold text-slate-900 text-sm">Seed Products ({selectedOrder.items.length})</h4>
                  <span className="font-mono font-bold text-emerald-800 bg-emerald-50 px-2 py-0.5 rounded">
                    Total Volume: {selectedOrder.totalQuantityBags} Bags
                  </span>
                </div>

                <div className="space-y-2">
                  {selectedOrder.items.map((item, idx) => (
                    <div
                      key={idx}
                      className="flex items-center justify-between p-3 bg-white rounded-xl border border-slate-200 shadow-xs"
                    >
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-lg bg-slate-100 p-1 flex items-center justify-center shrink-0 border border-slate-200">
                          <img src={item.image} alt={item.productName} className="max-h-full object-contain" />
                        </div>
                        <div>
                          <div className="font-bold text-slate-900">{item.productName}</div>
                          <div className="text-[10px] text-slate-400 font-mono">
                            SKU: {item.sku} • Pkg: {item.packageSize}
                          </div>
                        </div>
                      </div>

                      <div className="text-right">
                        <div className="text-[10px] text-slate-400 font-medium">Quantity</div>
                        <div className="font-mono font-bold text-slate-900 text-sm">{item.quantityBags} Bags</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Status Advancement Section */}
              <div className="p-4 bg-emerald-50/70 rounded-2xl border border-emerald-200 space-y-3">
                <div className="font-bold text-emerald-950 flex items-center gap-2">
                  <Clock className="w-4 h-4 text-emerald-700" />
                  <span>Advance Order Status</span>
                </div>

                {selectedOrder.status === 'Packed' && (
                  <div className="grid grid-cols-2 gap-3 bg-white p-3 rounded-xl border border-emerald-200">
                    <div>
                      <label className="block text-[10px] font-bold text-slate-600 mb-1">Transporter Name</label>
                      <input
                        type="text"
                        value={transporterInput}
                        onChange={(e) => setTransporterInput(e.target.value)}
                        className="w-full px-2.5 py-1.5 border border-slate-300 rounded-lg text-xs"
                      />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-slate-600 mb-1">LR Number</label>
                      <input
                        type="text"
                        value={lrInput}
                        onChange={(e) => setLrInput(e.target.value)}
                        className="w-full px-2.5 py-1.5 border border-slate-300 rounded-lg text-xs font-mono"
                      />
                    </div>
                  </div>
                )}

                <div className="flex flex-wrap items-center gap-2 pt-1">
                  {selectedOrder.status === 'New' && (
                    <div className="flex flex-col gap-2 w-full mb-2 bg-white p-3 rounded-xl border border-emerald-200">
                      <label className="text-[10px] font-bold text-slate-600">Assign Field Executive</label>
                      <select 
                        className="w-full px-2.5 py-1.5 border border-slate-300 rounded-lg text-xs"
                        value={selectedExecutive}
                        onChange={(e) => setSelectedExecutive(e.target.value)}
                      >
                        <option value="">Select Field Executive</option>
                        {employees.map(emp => (
                          <option key={emp.id} value={emp.id}>{emp.name}</option>
                        ))}
                      </select>
                      <button
                        onClick={async () => {
                          if (selectedExecutive) {
                            await assignOrderExecutive(selectedOrder.id, parseInt(selectedExecutive));
                            // Refresh modal data
                            const updated = orders.find((o) => o.id === selectedOrder.id);
                            if (updated) {
                              setSelectedOrder({ ...updated, status: 'Confirmed', assignedExecutiveId: selectedExecutive, assignedExecutiveName: employees.find(e => String(e.id) === selectedExecutive)?.name || '' });
                            }
                          } else {
                            alert("Please select a field executive first");
                          }
                        }}
                        className="px-4 py-2 mt-1 bg-emerald-700 hover:bg-emerald-800 text-white font-bold rounded-xl text-xs transition"
                      >
                        ✓ Assign & Confirm Order
                      </button>
                    </div>
                  )}
                  {selectedOrder.status === 'Confirmed' && (
                    <button
                      onClick={() => handleAdvanceStatus(selectedOrder)}
                      className="px-4 py-2 bg-purple-700 hover:bg-purple-800 text-white font-bold rounded-xl text-xs transition"
                    >
                      ⚙️ Send to Warehouse Processing
                    </button>
                  )}
                  {selectedOrder.status === 'Processing' && (
                    <button
                      onClick={() => handleAdvanceStatus(selectedOrder)}
                      className="px-4 py-2 bg-indigo-700 hover:bg-indigo-800 text-white font-bold rounded-xl text-xs transition"
                    >
                      📦 Mark as Seed Packed & Sealed
                    </button>
                  )}
                  {selectedOrder.status === 'Packed' && (
                    <button
                      onClick={() => handleAdvanceStatus(selectedOrder)}
                      className="px-4 py-2 bg-emerald-800 hover:bg-emerald-900 text-white font-bold rounded-xl text-xs transition flex items-center gap-1.5"
                    >
                      <Truck className="w-3.5 h-3.5" />
                      <span>Generate LR & Dispatch Consignment</span>
                    </button>
                  )}
                  {selectedOrder.status === 'Dispatched' && (
                    <button
                      onClick={() => handleAdvanceStatus(selectedOrder)}
                      className="px-4 py-2 bg-cyan-700 hover:bg-cyan-800 text-white font-bold rounded-xl text-xs transition"
                    >
                      🚚 Mark In Transit
                    </button>
                  )}
                  {selectedOrder.status === 'In Transit' && (
                    <button
                      onClick={() => handleAdvanceStatus(selectedOrder)}
                      className="px-4 py-2 bg-emerald-700 hover:bg-emerald-800 text-white font-bold rounded-xl text-xs transition flex items-center gap-1.5"
                    >
                      <CheckCircle className="w-3.5 h-3.5" />
                      <span>Confirm Delivery & Close Order</span>
                    </button>
                  )}
                  {selectedOrder.status === 'Delivered' && (
                    <div className="flex items-center gap-2 text-emerald-800 font-bold">
                      <CheckCircle className="w-4 h-4 text-emerald-600" />
                      <span>Order Completed & Delivered Successfully</span>
                    </div>
                  )}
                </div>
              </div>
            </div>

            <div className="p-4 bg-slate-50 border-t border-slate-200 flex justify-end">
              <button
                onClick={() => setSelectedOrder(null)}
                className="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 font-bold rounded-xl text-xs"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
