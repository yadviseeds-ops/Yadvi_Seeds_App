import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { Employee } from '../../data/mockEmployees';
import {
  Users,
  UserCheck,
  CalendarOff,
  UserX,
  Search,
  Plus,
  Filter,
  MoreVertical,
  Phone,
  Mail,
  MapPin,
  Clock,
  Battery,
  X
} from 'lucide-react';

export const AdminEmployees: React.FC = () => {
  const { employees, addEmployee, removeEmployee } = useAppState();
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('All');
  const [selectedEmployee, setSelectedEmployee] = useState<Employee | null>(null);
  const [isRemoving, setIsRemoving] = useState<string | number | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  
  // Add Employee Form State
  const [addForm, setAddForm] = useState({
    full_name: '',
    phone: '',
    email: '',
    username: '',
    employee_code: '',
    designation: 'Field Sales Officer',
    assigned_territory: ''
  });

  const filteredEmployees = employees.filter((emp) => {
    const matchesSearch =
      emp.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      emp.empId.toLowerCase().includes(searchTerm.toLowerCase()) ||
      emp.location.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRole = roleFilter === 'All' || emp.role === roleFilter;
    return matchesSearch && matchesRole;
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Title & Page Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Employees</h2>
          <p className="text-xs text-slate-500">Manage your field force and monitor live productivity</p>
        </div>
        <button
          onClick={() => setIsAddModalOpen(true)}
          className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 shadow-sm transition"
        >
          <Plus className="w-4 h-4" />
          Add Employee
        </button>
      </div>

      {/* 4 Summary Stat Cards matching reference screenshot */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Total Employees</div>
            <div className="text-2xl font-black text-slate-900">78</div>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
            <UserCheck className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Active</div>
            <div className="text-2xl font-black text-slate-900">62</div>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-amber-50 text-amber-700 flex items-center justify-center shrink-0">
            <CalendarOff className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">On Leave</div>
            <div className="text-2xl font-black text-slate-900">5</div>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-xl bg-red-50 text-red-700 flex items-center justify-center shrink-0">
            <UserX className="w-5 h-5" />
          </div>
          <div>
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Inactive</div>
            <div className="text-2xl font-black text-slate-900">11</div>
          </div>
        </div>
      </div>

      {/* Search & Filter Toolbar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-card flex flex-wrap items-center justify-between gap-4">
        <div className="relative flex-1 min-w-[240px] max-w-md">
          <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
          <input
            type="text"
            placeholder="Search employee by name, ID or location..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-600 focus:bg-white"
          />
        </div>

        <div className="flex items-center gap-2.5">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold text-slate-700 focus:outline-none"
          >
            <option value="All">All Roles</option>
            <option value="Field Executive">Field Executive</option>
            <option value="Sales Executive">Sales Executive</option>
            <option value="Territory Manager">Territory Manager</option>
          </select>
        </div>
      </div>

      {/* Employees Table matching reference screenshot */}
      <div className="bg-white rounded-2xl border border-slate-200/80 shadow-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="bg-slate-50/70 border-b border-slate-200/80 text-slate-500 font-bold uppercase tracking-wider text-[10px]">
                <th className="py-3.5 px-4">Name</th>
                <th className="py-3.5 px-4">Emp ID</th>
                <th className="py-3.5 px-4">Role</th>
                <th className="py-3.5 px-4">Location</th>
                <th className="py-3.5 px-4">Status</th>
                <th className="py-3.5 px-4 text-center">Distance Today</th>
                <th className="py-3.5 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 text-slate-700">
              {filteredEmployees.map((emp) => (
                <tr
                  key={emp.id}
                  onClick={() => setSelectedEmployee(emp)}
                  className="hover:bg-slate-50/80 transition cursor-pointer"
                >
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-3">
                      <img
                        src={emp.avatar}
                        alt={emp.name}
                        className="w-9 h-9 rounded-full object-cover ring-1 ring-slate-200"
                      />
                      <div>
                        <div className="font-bold text-slate-900 text-xs">{emp.name}</div>
                        <div className="text-[10px] text-slate-400">{emp.phone}</div>
                      </div>
                    </div>
                  </td>
                  <td className="py-3 px-4 font-mono font-bold text-slate-600">{emp.empId}</td>
                  <td className="py-3 px-4 font-medium text-slate-700">{emp.role}</td>
                  <td className="py-3 px-4 font-medium text-slate-600">{emp.location}</td>
                  <td className="py-3 px-4">
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full font-bold text-[10px] ${
                        emp.status === 'Active'
                          ? 'bg-emerald-100 text-emerald-800'
                          : emp.status === 'On Leave'
                          ? 'bg-amber-100 text-amber-900'
                          : 'bg-red-100 text-red-900'
                      }`}
                    >
                      {emp.status}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-center font-mono font-semibold text-slate-900">
                    {emp.distanceCoveredTodayKm > 0 ? `${emp.distanceCoveredTodayKm} km` : '0 km'}
                  </td>
                  <td className="py-3 px-4 text-right space-x-2">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedEmployee(emp);
                      }}
                      className="px-2.5 py-1 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-800 font-bold text-xs"
                    >
                      Details
                    </button>
                    <button
                      onClick={async (e) => {
                        e.stopPropagation();
                        if (window.confirm(`Are you sure you want to remove executive: ${emp.name}?`)) {
                          setIsRemoving(emp.id);
                          try {
                            await removeEmployee(emp.id);
                          } catch (err) {
                            alert("Failed to remove executive.");
                          } finally {
                            setIsRemoving(null);
                          }
                        }
                      }}
                      disabled={isRemoving === emp.id}
                      className="px-2.5 py-1 rounded-lg bg-red-50 hover:bg-red-100 text-red-800 font-bold text-xs disabled:opacity-50"
                    >
                      {isRemoving === emp.id ? 'Removing...' : 'Remove'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination bar matching reference */}
        <div className="p-4 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
          <div>Showing 1 – {filteredEmployees.length} of 78</div>
          <div className="flex items-center gap-1">
            <button className="px-2.5 py-1 rounded-md bg-emerald-700 text-white font-bold text-xs">1</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">2</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">3</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">4</button>
            <button className="px-2.5 py-1 rounded-md hover:bg-slate-100 text-slate-700 font-medium text-xs">5</button>
          </div>
        </div>
      </div>

      {/* Employee Detail Drawer Modal */}
      {selectedEmployee && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full overflow-hidden border border-slate-200 animate-scale-in">
            <div className="bg-[#0b3b2c] p-6 text-white flex items-start justify-between">
              <div className="flex items-center gap-4">
                <img
                  src={selectedEmployee.avatar}
                  alt={selectedEmployee.name}
                  className="w-16 h-16 rounded-2xl object-cover ring-2 ring-emerald-400"
                />
                <div>
                  <h3 className="font-bold text-lg leading-snug">{selectedEmployee.name}</h3>
                  <div className="text-xs text-emerald-200">{selectedEmployee.role} • {selectedEmployee.empId}</div>
                  <div className="text-[11px] text-emerald-100/70 mt-1 flex items-center gap-1.5">
                    <MapPin className="w-3 h-3 text-emerald-400" />
                    <span>Territory: {selectedEmployee.location}</span>
                  </div>
                </div>
              </div>
              <button
                onClick={() => setSelectedEmployee(null)}
                className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4 text-xs text-slate-700">
              <div className="grid grid-cols-2 gap-3 bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                <div>
                  <span className="text-slate-400 font-medium">Check In Today:</span>
                  <div className="font-bold text-slate-900 mt-0.5">{selectedEmployee.checkInTime || 'Not checked in'}</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">Distance Covered:</span>
                  <div className="font-bold text-slate-900 mt-0.5">{selectedEmployee.distanceCoveredTodayKm} km</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">Assigned Shops:</span>
                  <div className="font-bold text-slate-900 mt-0.5">{selectedEmployee.assignedShopsCount} Dealers</div>
                </div>
                <div>
                  <span className="text-slate-400 font-medium">Visits Completed:</span>
                  <div className="font-bold text-emerald-700 mt-0.5">{selectedEmployee.completedVisitsCount} / {selectedEmployee.assignedShopsCount}</div>
                </div>
              </div>

              <div className="space-y-2">
                <div className="flex items-center gap-2 text-slate-600">
                  <Phone className="w-3.5 h-3.5 text-emerald-600" />
                  <span className="font-semibold">{selectedEmployee.phone}</span>
                </div>
                <div className="flex items-center gap-2 text-slate-600">
                  <Mail className="w-3.5 h-3.5 text-emerald-600" />
                  <span>{selectedEmployee.email}</span>
                </div>
                <div className="flex items-center gap-2 text-slate-600">
                  <Battery className="w-3.5 h-3.5 text-emerald-600" />
                  <span>Phone Battery: <b>{selectedEmployee.batteryLevel}%</b> • GPS Updated {selectedEmployee.lastLocationUpdate}</span>
                </div>
              </div>

              <div className="pt-3 border-t border-slate-100 flex justify-end">
                <button
                  onClick={() => setSelectedEmployee(null)}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Add Employee Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full overflow-hidden border border-slate-200">
            <div className="bg-[#0b3b2c] p-5 text-white flex items-center justify-between">
              <h3 className="font-bold text-lg">Add New Employee</h3>
              <button onClick={() => setIsAddModalOpen(false)} className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10">
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <form onSubmit={async (e) => {
              e.preventDefault();
              try {
                await addEmployee(addForm);
                setIsAddModalOpen(false);
                setAddForm({
                  full_name: '', phone: '', email: '', username: '', employee_code: '', designation: 'Field Sales Officer', assigned_territory: ''
                });
                alert('Employee added successfully!');
              } catch (err) {
                alert('Failed to add employee');
              }
            }} className="p-6 space-y-4">
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Full Name</label>
                  <input required value={addForm.full_name} onChange={e => setAddForm({...addForm, full_name: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Phone</label>
                  <input required value={addForm.phone} onChange={e => setAddForm({...addForm, phone: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Email (Optional)</label>
                  <input value={addForm.email} onChange={e => setAddForm({...addForm, email: e.target.value})} type="email" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Username</label>
                  <input required value={addForm.username} onChange={e => setAddForm({...addForm, username: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Employee Code</label>
                  <input required value={addForm.employee_code} onChange={e => setAddForm({...addForm, employee_code: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Territory</label>
                  <input required value={addForm.assigned_territory} onChange={e => setAddForm({...addForm, assigned_territory: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>

              <div className="pt-4 flex justify-end gap-3 border-t border-slate-100">
                <button type="button" onClick={() => setIsAddModalOpen(false)} className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">
                  Cancel
                </button>
                <button type="submit" className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs">
                  Save Employee
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

    </div>
  );
};
