import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { Shop } from '../../data/mockShops';
import { Building2, Store, Search, Plus, MapPin, Phone, Mail, FileText, CheckCircle2, X } from 'lucide-react';

export const AdminShopOwners: React.FC = () => {
  const { shops, employees, addShop, assignShopToExecutive } = useAppState();
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedShop, setSelectedShop] = useState<Shop | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [assignExecId, setAssignExecId] = useState<string>('');

  const [addForm, setAddForm] = useState({
    owner_name: '', phone: '', email: '', username: '', shop_name: '', dealer_code: '', market_location: '', address: '', primary_demand_crop: ''
  });

  const filteredShops = shops.filter((s) => {
    const matchesSearch =
      (s.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (s.location || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (s.phone || '').includes(searchTerm);
    const matchesStatus = statusFilter === 'All' || s.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Page Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Shop Owners & Dealers</h2>
          <p className="text-xs text-slate-500">Authorized Yadvi Hybrid Seeds distribution partner network</p>
        </div>
        <button
          onClick={() => setIsAddModalOpen(true)}
          className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 shadow-sm transition"
        >
          <Plus className="w-4 h-4" />
          Add Shop Owner
        </button>
      </div>

      {/* 3 Summary Cards matching reference screenshot */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-blue-50 text-blue-700 flex items-center justify-center shrink-0">
            <Building2 className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Total Shop Owners</div>
            <div className="text-2xl font-black text-slate-900">348</div>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Active</div>
            <div className="text-2xl font-black text-slate-900">320</div>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-red-50 text-red-700 flex items-center justify-center shrink-0">
            <Store className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Inactive</div>
            <div className="text-2xl font-black text-slate-900">28</div>
          </div>
        </div>
      </div>

      {/* Search Toolbar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex flex-wrap items-center justify-between gap-4">
        <div className="relative flex-1 min-w-[240px] max-w-md">
          <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
          <input
            type="text"
            placeholder="Search shop owner by shop name, town, or mobile..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-600 focus:bg-white"
          />
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setStatusFilter('All')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold ${
              statusFilter === 'All' ? 'bg-emerald-800 text-white' : 'bg-slate-100 text-slate-700'
            }`}
          >
            All
          </button>
          <button
            onClick={() => setStatusFilter('Active')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold ${
              statusFilter === 'Active' ? 'bg-emerald-800 text-white' : 'bg-slate-100 text-slate-700'
            }`}
          >
            Active
          </button>
          <button
            onClick={() => setStatusFilter('Inactive')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold ${
              statusFilter === 'Inactive' ? 'bg-emerald-800 text-white' : 'bg-slate-100 text-slate-700'
            }`}
          >
            Inactive
          </button>
        </div>
      </div>

      {/* Shop Owners Table matching reference screenshot */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="bg-slate-50/70 border-b border-slate-200/80 text-slate-500 font-bold uppercase tracking-wider text-[10px]">
                <th className="py-3.5 px-4">Shop Owner / Shop Name</th>
                <th className="py-3.5 px-4">Location</th>
                <th className="py-3.5 px-4">Contact Phone</th>
                <th className="py-3.5 px-4">Status</th>
                <th className="py-3.5 px-4 text-center">Stock (Bags)</th>
                <th className="py-3.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {filteredShops.map((shop) => (
                <tr
                  key={shop.id}
                  onClick={() => setSelectedShop(shop)}
                  className="hover:bg-slate-50/80 transition cursor-pointer"
                >
                  <td className="py-3 px-4">
                    <div className="font-bold text-slate-900 text-xs">{shop.name}</div>
                    <div className="text-[10px] text-slate-400">Prop: {shop.ownerName}</div>
                    {shop.assignedExecutiveName && shop.assignedExecutiveName !== 'Unassigned' && (
                      <div className="text-[10px] text-emerald-700 font-bold mt-0.5">Assigned FE: {shop.assignedExecutiveName}</div>
                    )}
                  </td>
                  <td className="py-3 px-4 font-medium text-slate-700">{shop.location}</td>
                  <td className="py-3 px-4 font-mono font-medium text-slate-600">{shop.phone}</td>
                  <td className="py-3 px-4">
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full font-bold text-[10px] ${
                        shop.status === 'Active'
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-red-100 text-red-900'
                      }`}
                    >
                      {shop.status}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-center font-mono font-bold text-emerald-800">
                    {shop.currentStockBags} Bags
                  </td>
                  <td className="py-3 px-4 text-right">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedShop(shop);
                      }}
                      className="px-2.5 py-1 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-800 font-bold text-xs"
                    >
                      Details
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination bar matching reference */}
        <div className="p-4 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
          <div>Showing 1 – {filteredShops.length} of 348</div>
          <div className="flex items-center gap-1">
            <button className="px-2.5 py-1 rounded-md bg-emerald-700 text-white font-bold text-xs">1</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">2</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">3</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">4</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">5</button>
          </div>
        </div>
      </div>

      {/* Shop Detail Modal */}
      {selectedShop && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full overflow-hidden border border-slate-200 animate-scale-in">
            <div className="bg-[#0b3b2c] p-6 text-white flex items-start justify-between">
              <div>
                <h3 className="font-bold text-lg">{selectedShop.name}</h3>
                <div className="text-xs text-emerald-200">Proprietor: {selectedShop.ownerName}</div>
                <div className="text-[11px] text-emerald-100/70 mt-1">📍 {selectedShop.address}</div>
              </div>
              <button
                onClick={() => setSelectedShop(null)}
                className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs text-slate-700">
              <div className="grid grid-cols-2 gap-3 bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <div>
                  <span className="text-slate-400 font-medium">Seed License:</span>
                  <div className="font-mono font-bold text-slate-900 mt-0.5">{selectedShop.seedLicenseNo}</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">GSTIN:</span>
                  <div className="font-mono font-bold text-slate-900 mt-0.5">{selectedShop.gstin}</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">Current Stock on Shelf:</span>
                  <div className="font-bold text-emerald-700 mt-0.5">{selectedShop.currentStockBags} Bags</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">Assigned Officer:</span>
                  <div className="font-bold text-slate-900 mt-0.5">{selectedShop.assignedExecutiveName}</div>
                </div>
              </div>

              <div>
                <span className="font-bold text-slate-800 block mb-1">Primary Seed Demand:</span>
                <span className="px-3 py-1 rounded-lg bg-emerald-50 text-emerald-800 font-semibold inline-block">
                  {selectedShop.primaryCropDemand}
                </span>
              </div>

              <div className="pt-3 flex items-center gap-2">
                <select
                  value={assignExecId}
                  onChange={(e) => setAssignExecId(e.target.value)}
                  className="flex-1 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg text-xs"
                >
                  <option value="">Assign to Executive...</option>
                  {employees.filter(e => e.role?.includes('Field') || e.role?.includes('Sales')).map(e => (
                    <option key={e.id} value={e.id}>{e.name} ({e.empId}) - {e.role}</option>
                  ))}
                </select>
                <button
                  onClick={async () => {
                    if(!assignExecId) return;
                    try {
                      await assignShopToExecutive(selectedShop.id, assignExecId);
                      alert('Assigned successfully!');
                    } catch (e) {
                      alert('Failed to assign');
                    }
                  }}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-xs font-bold"
                >
                  Assign
                </button>
              </div>

              <div className="pt-3 border-t border-slate-100 flex justify-end">
                <button
                  onClick={() => setSelectedShop(null)}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-xl text-xs"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Add Shop Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full overflow-hidden border border-slate-200">
            <div className="bg-[#0b3b2c] p-5 text-white flex items-center justify-between">
              <h3 className="font-bold text-lg">Add New Shop Owner</h3>
              <button onClick={() => setIsAddModalOpen(false)} className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10">
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <form onSubmit={async (e) => {
              e.preventDefault();
              try {
                await addShop(addForm);
                setIsAddModalOpen(false);
                setAddForm({owner_name: '', phone: '', email: '', username: '', shop_name: '', dealer_code: '', market_location: '', address: '', primary_demand_crop: ''});
                alert('Shop added successfully!');
              } catch (err) {
                alert('Failed to add shop');
              }
            }} className="p-6 space-y-4">
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Owner Name</label>
                  <input required value={addForm.owner_name} onChange={e => setAddForm({...addForm, owner_name: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Phone</label>
                  <input required value={addForm.phone} onChange={e => setAddForm({...addForm, phone: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Username</label>
                  <input required value={addForm.username} onChange={e => setAddForm({...addForm, username: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Shop Name</label>
                  <input required value={addForm.shop_name} onChange={e => setAddForm({...addForm, shop_name: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Dealer Code</label>
                  <input required value={addForm.dealer_code} onChange={e => setAddForm({...addForm, dealer_code: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Market Location</label>
                  <input required value={addForm.market_location} onChange={e => setAddForm({...addForm, market_location: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-[11px] font-bold text-slate-500 uppercase">Address</label>
                <input required value={addForm.address} onChange={e => setAddForm({...addForm, address: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
              </div>

              <div className="pt-4 flex justify-end gap-3 border-t border-slate-100">
                <button type="button" onClick={() => setIsAddModalOpen(false)} className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs">Save Shop</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
