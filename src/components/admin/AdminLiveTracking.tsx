import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { LiveMap } from '../common/LiveMap';
import { MapPin, Navigation, Battery, ShieldAlert, CheckCircle, Clock } from 'lucide-react';

export const AdminLiveTracking: React.FC = () => {
  const { employees, shops } = useAppState();
  const [selectedEmpId, setSelectedEmpId] = useState<string>(employees[0]?.id || '');
  const [filter, setFilter] = useState<'All' | 'In Field' | 'In Transit' | 'Pending'>('All');

  const selectedEmployee = employees.find((e) => e.id === selectedEmpId) || employees[0];

  const filteredEmployees = employees.filter((emp) => {
    if (filter === 'All') return true;
    if (filter === 'In Field') return emp.attendanceStatus === 'Present' || emp.attendanceStatus === 'In Field';
    if (filter === 'In Transit') return emp.distanceCoveredTodayKm > 10;
    if (filter === 'Pending') return emp.attendanceStatus === 'Absent' || emp.attendanceStatus === 'On Leave';
    return true;
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Page Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Field Tracking</h2>
          <p className="text-xs text-slate-500">Live GPS tracking and movement routes of field executives</p>
        </div>

        {/* Live Status indicator */}
        <div className="flex items-center gap-2 px-3 py-1.5 bg-emerald-50 text-emerald-800 border border-emerald-200 rounded-xl text-xs font-semibold">
          <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-ping" />
          <span>Real-time GPS Sync Active</span>
        </div>
      </div>

      {/* Grid: Map (2/3) + Executive List Panel (1/3) matching reference screenshot */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Map View */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200/80 shadow-card p-4 flex flex-col">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <MapPin className="w-4 h-4 text-emerald-700" />
              <span className="font-bold text-xs text-slate-800">
                Route Track: <b className="text-emerald-800">{selectedEmployee?.name}</b> ({selectedEmployee?.location})
              </span>
            </div>
            <div className="text-[11px] text-slate-400 font-mono">
              Lat: {selectedEmployee?.lat.toFixed(4)}, Lng: {selectedEmployee?.lng.toFixed(4)}
            </div>
          </div>

          <div className="flex-1 min-h-[440px]">
            <LiveMap
              employees={employees}
              shops={shops}
              selectedEmployeeId={selectedEmpId}
              showRoutes={true}
              height="450px"
              center={[selectedEmployee.lat, selectedEmployee.lng]}
              zoom={12}
            />
          </div>

          <div className="mt-3 pt-3 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3 text-xs text-slate-500">
            <div className="flex items-center gap-3">
              <span className="flex items-center gap-1.5 font-medium">
                <span className="w-3 h-1 bg-emerald-600 rounded" />
                Tracked GPS Route
              </span>
              <span className="flex items-center gap-1.5 font-medium">
                <span>🏪</span>
                Shop Owner Waypoint
              </span>
            </div>
            <div>Updated: {selectedEmployee.lastLocationUpdate}</div>
          </div>
        </div>

        {/* Right Sidebar: Today's Field Executives List */}
        <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card p-5 flex flex-col">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-bold text-slate-900 text-sm">Today's Field Executives</h3>
            <span className="text-xs font-bold text-emerald-700">{filteredEmployees.length} Total</span>
          </div>

          {/* Filter Pills */}
          <div className="flex items-center gap-1.5 mb-3 overflow-x-auto pb-1 text-xs">
            {(['All', 'In Field', 'In Transit', 'Pending'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setFilter(tab)}
                className={`px-2.5 py-1 rounded-lg font-semibold text-[11px] whitespace-nowrap transition ${
                  filter === tab
                    ? 'bg-emerald-700 text-white'
                    : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>

          {/* Executives List */}
          <div className="space-y-2.5 overflow-y-auto max-h-[460px] pr-1">
            {filteredEmployees.map((emp) => {
              const isSelected = emp.id === selectedEmpId;
              return (
                <div
                  key={emp.id}
                  onClick={() => setSelectedEmpId(emp.id)}
                  className={`p-3 rounded-xl border transition cursor-pointer ${
                    isSelected
                      ? 'bg-emerald-50/80 border-emerald-400 shadow-sm'
                      : 'bg-white border-slate-200/80 hover:bg-slate-50'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                      <img
                        src={emp.avatar}
                        alt={emp.name}
                        className="w-8 h-8 rounded-full object-cover ring-1 ring-slate-200"
                      />
                      <div>
                        <div className="font-bold text-xs text-slate-900">{emp.name}</div>
                        <div className="text-[10px] text-slate-400 font-medium">{emp.location}</div>
                      </div>
                    </div>

                    <div className="text-right">
                      <div className="font-mono font-bold text-xs text-slate-800">
                        {emp.distanceCoveredTodayKm} km
                      </div>
                      <span
                        className={`inline-flex items-center px-1.5 py-0.2 rounded text-[9px] font-bold mt-0.5 ${
                          emp.attendanceStatus === 'Present' || emp.attendanceStatus === 'In Field'
                            ? 'bg-emerald-100 text-emerald-800'
                            : emp.attendanceStatus === 'In Office'
                            ? 'bg-blue-100 text-blue-800'
                            : 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {emp.attendanceStatus}
                      </span>
                    </div>
                  </div>

                  <div className="mt-2 pt-2 border-t border-slate-100 flex items-center justify-between text-[10px] text-slate-500 font-medium">
                    <div className="flex items-center gap-1">
                      <Battery className="w-3 h-3 text-emerald-600" />
                      <span>{emp.batteryLevel}% Battery</span>
                    </div>
                    <div className="flex items-center gap-1">
                      <Clock className="w-3 h-3 text-slate-400" />
                      <span>{emp.lastLocationUpdate}</span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
