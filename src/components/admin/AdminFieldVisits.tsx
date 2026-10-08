import React, { useState, useEffect } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { FieldVisit } from '../../data/mockVisits';
import { CheckCircle2, Clock, MapPin, Image as ImageIcon, X } from 'lucide-react';

export const AdminFieldVisits: React.FC = () => {
  const { visits } = useAppState();
  const [selectedVisit, setSelectedVisit] = useState<FieldVisit | null>(null);
  const [statusFilter, setStatusFilter] = useState<string>('All');
  const [dateFilter, setDateFilter] = useState<string>('Today');

  // We could implement a real refresh interval here to fetch data from API.
  // But AppStateContext currently handles fetching when mounting/switching.
  // We'll rely on its context data.

  const filteredVisits = visits.filter((v) => {
    // Status Filter
    if (statusFilter !== 'All' && v.status !== statusFilter) return false;
    
    // Date Filter
    if (v.scheduledTime) {
      const scheduledDate = new Date(v.scheduledTime);
      const today = new Date();
      if (dateFilter === 'Today') {
        if (
          scheduledDate.getDate() !== today.getDate() ||
          scheduledDate.getMonth() !== today.getMonth() ||
          scheduledDate.getFullYear() !== today.getFullYear()
        ) {
          return false;
        }
      } else if (dateFilter === 'Yesterday') {
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        if (
          scheduledDate.getDate() !== yesterday.getDate() ||
          scheduledDate.getMonth() !== yesterday.getMonth() ||
          scheduledDate.getFullYear() !== yesterday.getFullYear()
        ) {
          return false;
        }
      }
    }
    return true;
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Field Visits</h2>
          <p className="text-xs text-slate-500">Monitor Field Executive visits, visit status and uploaded visit proof.</p>
        </div>

        <div className="flex items-center gap-4">
          {/* Date Pills */}
          <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl text-xs">
            {(['Today', 'Yesterday', 'All Dates'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setDateFilter(tab)}
                className={`px-3 py-1.5 rounded-lg font-bold transition ${
                  dateFilter === tab ? 'bg-white text-emerald-800 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>

          {/* Filter Pills */}
          <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl text-xs">
            {(['All', 'Visited', 'Pending'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setStatusFilter(tab)}
                className={`px-3 py-1.5 rounded-lg font-bold transition ${
                  statusFilter === tab ? 'bg-white text-emerald-800 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* DEBUG UI */}
      <div className="mb-4 p-4 bg-slate-800 text-green-400 font-mono text-xs rounded-lg">
        DEBUG INFO: Total Visits fetched: {visits.length} | Filtered Visits: {filteredVisits.length}
        <br/>
        {visits.length > 0 && (
          <div>
            First Visit Scheduled: {visits[0].scheduledTime} | Status: {visits[0].status} | 
            Today Date: {new Date().getDate()} | Scheduled Date (local): {new Date(visits[0].scheduledTime).getDate()}
          </div>
        )}
      </div>

      {/* Empty State */}
      {filteredVisits.length === 0 && (
        <div className="bg-white p-10 rounded-2xl border border-slate-200 text-center">
          <div className="mx-auto w-16 h-16 bg-slate-50 rounded-full flex items-center justify-center mb-4">
            <Clock className="w-8 h-8 text-slate-400" />
          </div>
          <h3 className="text-lg font-bold text-slate-900 mb-1">
            {statusFilter === 'Pending' ? 'No visits completed yet today.' : 'No field visits recorded today.'}
          </h3>
          <p className="text-sm text-slate-500">Adjust the filters to see more results.</p>
        </div>
      )}

      {/* Visits Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filteredVisits.map((visit) => (
          <div
            key={visit.id}
            onClick={() => setSelectedVisit(visit)}
            className="bg-white rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition p-5 flex flex-col justify-between cursor-pointer"
          >
            <div>
              <div className="flex items-center justify-between">
                <h3 className="font-bold text-slate-900 text-sm">{visit.shopName}</h3>
                <span
                  className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                    visit.status === 'Visited'
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-orange-100 text-orange-800'
                  }`}
                >
                  {visit.status}
                </span>
              </div>
              <div className="text-xs text-slate-500 flex items-center gap-1 mt-1">
                <MapPin className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                <span className="truncate">{visit.shopLocation || visit.shopAddress || 'No Address'}</span>
              </div>

              <div className="mt-3 bg-slate-50 p-2.5 rounded-xl border border-slate-100 text-xs">
                <div className="text-[10px] text-slate-400 font-medium">Field Executive</div>
                <div className="font-bold text-slate-800">{visit.executiveName}</div>
              </div>

              {visit.status === 'Visited' ? (
                <div className="mt-3 text-xs space-y-1.5">
                  <div className="flex justify-between items-center text-slate-600">
                    <span className="text-[10px] text-slate-400">Visited At</span>
                    <span className="font-bold text-slate-800">{visit.visitedAt ? new Date(visit.visitedAt).toLocaleString() : 'N/A'}</span>
                  </div>
                  {visit.photoLat && visit.photoLng && (
                    <div className="flex justify-between items-center text-slate-600">
                      <span className="text-[10px] text-slate-400">GPS</span>
                      <span className="font-mono text-slate-700">{visit.photoLat.toString().substring(0, 8)}, {visit.photoLng.toString().substring(0, 8)}</span>
                    </div>
                  )}
                  {visit.photoUrl ? (
                    <div className="h-20 mt-2 bg-slate-100 rounded border border-slate-200 overflow-hidden flex items-center justify-center">
                      <img src={visit.photoUrl} alt="Thumbnail" className="h-full object-cover w-full" />
                    </div>
                  ) : (
                    <div className="text-slate-400 italic text-[10px] mt-2 text-center bg-slate-50 p-2 rounded">
                      Visit completed, photo proof unavailable.
                    </div>
                  )}
                </div>
              ) : (
                <div className="mt-3 text-xs space-y-1.5">
                  <div className="flex justify-between items-center text-slate-600">
                    <span className="text-[10px] text-slate-400">Scheduled</span>
                    <span className="font-bold text-slate-800">{visit.scheduledTime ? new Date(visit.scheduledTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'N/A'}</span>
                  </div>
                  <div className="text-slate-400 italic text-[10px] text-center bg-slate-50 p-2 rounded mt-2">
                    Photo: Not uploaded yet
                  </div>
                </div>
              )}
              
              {visit.notes && (
                <div className="mt-3 border-t border-slate-100 pt-3">
                  <span className="text-[10px] text-slate-400 block mb-1">Notes</span>
                  <p className="text-xs text-slate-600 italic line-clamp-2">"{visit.notes}"</p>
                </div>
              )}
            </div>

            <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-end text-xs">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setSelectedVisit(visit);
                }}
                className="px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs"
              >
                Inspect
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Visit Detail Modal with Actual Photo */}
      {selectedVisit && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full overflow-hidden border border-slate-200 animate-scale-in">
            <div className="bg-[#0b3b2c] p-5 text-white flex items-center justify-between">
              <div>
                <h3 className="font-bold text-base">FIELD VISIT PROOF</h3>
                <div className="text-xs text-emerald-200">{selectedVisit.shopName}</div>
              </div>
              <button
                onClick={() => setSelectedVisit(null)}
                className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs text-slate-700">
              <div className="grid grid-cols-2 gap-3 bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <div>
                  <span className="text-slate-400 font-medium">Status:</span>
                  <div className="font-bold text-slate-900 mt-0.5 uppercase">{selectedVisit.status}</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">Field Executive:</span>
                  <div className="font-bold text-slate-900 mt-0.5">{selectedVisit.executiveName}</div>
                </div>
                <div className="col-span-2">
                  <span className="text-slate-400 font-medium">Visited At:</span>
                  <div className="font-mono font-bold text-emerald-700 mt-0.5">
                    {selectedVisit.visitedAt ? new Date(selectedVisit.visitedAt).toLocaleString() : 'N/A'}
                  </div>
                </div>
              </div>

              {selectedVisit.status === 'Visited' && (
                <>
                  <div className="mt-4 mb-2">
                    {selectedVisit.photoUrl ? (
                      <div className="bg-slate-100 rounded-xl overflow-hidden border border-slate-200 flex items-center justify-center">
                        <img
                          src={selectedVisit.photoUrl}
                          alt="Real Visit Verification"
                          className="max-h-64 object-contain"
                        />
                      </div>
                    ) : (
                      <div className="h-32 bg-slate-100 rounded-xl border border-slate-200 flex items-center justify-center">
                        <span className="text-slate-400 font-medium">No visit photo uploaded</span>
                      </div>
                    )}
                  </div>

                  <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 space-y-3">
                    <h4 className="font-bold text-slate-800 border-b border-slate-200 pb-2 mb-2">Location & Metadata</h4>
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <span className="text-slate-400 block mb-0.5">Latitude:</span>
                        <span className="font-mono font-bold">{selectedVisit.photoLat || 'N/A'}</span>
                      </div>
                      <div>
                        <span className="text-slate-400 block mb-0.5">Longitude:</span>
                        <span className="font-mono font-bold">{selectedVisit.photoLng || 'N/A'}</span>
                      </div>
                      <div className="col-span-2">
                        <span className="text-slate-400 block mb-0.5">Timestamp:</span>
                        <span className="font-bold text-slate-800">{selectedVisit.visitedAt ? new Date(selectedVisit.visitedAt).toLocaleString() : 'N/A'}</span>
                      </div>
                    </div>
                  </div>
                </>
              )}

              <div>
                <span className="font-bold text-slate-800 block mb-1">Notes:</span>
                <p className="bg-slate-50 p-3 rounded-xl border border-slate-200 text-slate-600 leading-relaxed">
                  {selectedVisit.notes || 'No notes logged.'}
                </p>
              </div>

              <div className="pt-4 flex justify-end">
                <button
                  onClick={() => setSelectedVisit(null)}
                  className="px-5 py-2 bg-slate-900 hover:bg-slate-800 text-white font-bold rounded-xl text-xs transition"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
