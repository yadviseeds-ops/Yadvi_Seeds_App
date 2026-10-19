import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { ShipmentTracking } from '../../data/mockOrders';
import { Truck, Search, CheckCircle2, Clock, MapPin, User, Phone, ChevronRight, X } from 'lucide-react';

export const AdminShipments: React.FC = () => {
  const { shipments } = useAppState();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedShipment, setSelectedShipment] = useState<ShipmentTracking | null>(shipments[0] || null);

  const filteredShipments = shipments.filter((s) => {
    return (
      s.lrNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
      s.orderNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
      s.shopName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      s.transporter.toLowerCase().includes(searchTerm.toLowerCase())
    );
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Shipment & LR Logistics Tracking</h2>
          <p className="text-xs text-slate-500">Live dispatch status, transport dockets, and waypoint progress</p>
        </div>
      </div>

      {/* Grid: Consignment List + Timeline Card */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Shipments List */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-4 space-y-3">
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3 top-2.5 text-slate-400" />
            <input
              type="text"
              placeholder="Search LR Docket or Order ID..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs"
            />
          </div>

          <div className="space-y-2.5 overflow-y-auto max-h-[580px] pr-1">
            {filteredShipments.map((s) => {
              const isSelected = selectedShipment?.lrNumber === s.lrNumber;
              return (
                <div
                  key={s.lrNumber}
                  onClick={() => setSelectedShipment(s)}
                  className={`p-3.5 rounded-xl border transition cursor-pointer ${
                    isSelected
                      ? 'bg-emerald-50 border-emerald-400 shadow-xs'
                      : 'bg-white border-slate-200/80 hover:bg-slate-50'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <span className="font-mono font-bold text-xs text-emerald-800">{s.lrNumber}</span>
                    <span
                      className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                        s.status === 'In Transit'
                          ? 'bg-blue-100 text-blue-800'
                          : s.status === 'Delivered'
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-amber-100 text-amber-800'
                      }`}
                    >
                      {s.status}
                    </span>
                  </div>

                  <div className="font-bold text-xs text-slate-900 mt-1">{s.shopName}</div>
                  <div className="text-[11px] text-slate-500">
                    Order: <b className="text-slate-700">{s.orderNumber}</b> • {s.totalBags} kg
                  </div>

                  <div className="mt-2 pt-2 border-t border-slate-100 flex items-center justify-between text-[10px] text-slate-400">
                    <span>{s.transporter}</span>
                    <span>Est: {s.estimatedDelivery}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Selected Consignment Details & Waypoint Timeline */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/80 shadow-card p-6 flex flex-col">
          {selectedShipment ? (
            <div className="space-y-6">
              {/* Header Box */}
              <div className="bg-gradient-to-r from-emerald-900 to-[#0b3b2c] p-5 rounded-2xl text-white flex flex-wrap items-center justify-between gap-4">
                <div>
                  <div className="text-xs text-emerald-200 uppercase font-semibold tracking-wider">
                    Official Lorry Receipt (LR)
                  </div>
                  <div className="text-2xl font-black font-mono tracking-tight">{selectedShipment.lrNumber}</div>
                  <div className="text-xs text-emerald-100/80 mt-1">
                    Order Ref: <b>{selectedShipment.orderNumber}</b> • {selectedShipment.totalBags} kg Volume
                  </div>
                </div>

                <div className="text-right">
                  <span className="px-3 py-1 rounded-full bg-emerald-500/30 border border-emerald-400/40 text-emerald-200 text-xs font-bold">
                    {selectedShipment.status}
                  </span>
                  <div className="text-[11px] text-emerald-200/80 mt-2 font-mono">
                    Vehicle: {selectedShipment.vehicleNumber}
                  </div>
                </div>
              </div>

              {/* Carrier & Transporter Details */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 bg-slate-50 p-4 rounded-xl border border-slate-200 text-xs">
                <div>
                  <span className="text-slate-400 font-medium block">Transporter Agency</span>
                  <span className="font-bold text-slate-800 text-sm mt-0.5 block">{selectedShipment.transporter}</span>
                </div>
                <div>
                  <span className="text-slate-400 font-medium block">Driver / Contact</span>
                  <span className="font-bold text-slate-800 block mt-0.5">{selectedShipment.driverName}</span>
                  <span className="text-slate-500 font-mono">{selectedShipment.driverPhone}</span>
                </div>
                <div>
                  <span className="text-slate-400 font-medium block">Estimated Delivery</span>
                  <span className="font-bold text-emerald-700 block mt-0.5">{selectedShipment.estimatedDelivery}</span>
                  <span className="text-[10px] text-slate-400">Dispatched: {selectedShipment.dispatchDate}</span>
                </div>
              </div>

              {/* Visual Logistics Tracking Timeline */}
              <div>
                <h3 className="font-bold text-sm text-slate-900 mb-4 flex items-center gap-2">
                  <Clock className="w-4 h-4 text-emerald-700" />
                  <span>Consignment Movement Timeline</span>
                </h3>

                <div className="relative pl-6 space-y-6 before:content-[''] before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
                  {selectedShipment.timeline.map((point, index) => (
                    <div key={index} className="relative">
                      {/* Timeline Dot */}
                      <span
                        className={`absolute -left-6 top-0.5 w-5 h-5 rounded-full flex items-center justify-center text-[10px] ${
                          point.completed
                            ? 'bg-emerald-600 text-white ring-4 ring-emerald-100'
                            : 'bg-slate-200 text-slate-400'
                        }`}
                      >
                        {point.completed ? '✓' : index + 1}
                      </span>

                      <div className="bg-slate-50 p-3 rounded-xl border border-slate-200/80">
                        <div className="flex flex-wrap items-center justify-between gap-1">
                          <h4 className="font-bold text-xs text-slate-900">{point.title}</h4>
                          <span className="text-[10px] text-slate-400 font-mono">{point.timestamp}</span>
                        </div>
                        <div className="text-[11px] text-emerald-700 font-medium mt-0.5 flex items-center gap-1">
                          <MapPin className="w-3 h-3" />
                          <span>{point.location}</span>
                        </div>
                        <p className="text-[11px] text-slate-500 mt-1">{point.description}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-slate-400 py-12">
              <Truck className="w-12 h-12 stroke-1 text-slate-300 mb-2" />
              <p>Select a shipment consignment to inspect LR timeline</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
