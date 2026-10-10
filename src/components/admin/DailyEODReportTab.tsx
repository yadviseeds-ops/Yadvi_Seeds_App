import React, { useEffect, useState } from 'react';
import { api } from '../../services/api';
import { Calendar, ChevronDown, ChevronUp, FileText, RefreshCw } from 'lucide-react';

interface EODReport {
  id: number;
  executive_id: number;
  executive_name: string;
  report_date: string;
  completed_visits: number;
  pending_visits: number;
  total_bags_ordered: number;
  notes: string | null;
  created_at: string;
}

export const DailyEODReportTab: React.FC = () => {
  const [reports, setReports] = useState<EODReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expandedFEs, setExpandedFEs] = useState<Record<string, boolean>>({});

  const parseDateSafe = (dateStr: string) => {
    const hasTZ = dateStr.endsWith('Z') || /[+-]\d{2}:\d{2}$/.test(dateStr);
    return new Date(hasTZ ? dateStr : `${dateStr}Z`);
  };

  useEffect(() => {
    fetchReports();
  }, []);

  const fetchReports = async (isManualRefresh = false) => {
    if (isManualRefresh) setIsRefreshing(true);
    else setLoading(true);

    try {
      const data = await api.getEodReports();
      setReports(data);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to load EOD reports');
    } finally {
      setLoading(false);
      setIsRefreshing(false);
    }
  };

  const toggleFE = (name: string) => {
    setExpandedFEs(prev => ({ ...prev, [name]: !prev[name] }));
  };

  const [dateFilter, setDateFilter] = useState('');

  if (loading) {
    return <div className="p-8 text-center text-slate-500 font-medium">Loading EOD Reports...</div>;
  }

  if (error) {
    return <div className="p-8 text-center text-red-500 font-medium">{error}</div>;
  }
  
  const filteredReports = dateFilter 
    ? reports.filter(r => parseDateSafe(r.created_at).toISOString().split('T')[0] === dateFilter)
    : reports;

  // Group by FE Name
  const grouped: Record<string, EODReport[]> = {};
  filteredReports.forEach(r => {
    if (!grouped[r.executive_name]) {
      grouped[r.executive_name] = [];
    }
    grouped[r.executive_name].push(r);
  });

  if (Object.keys(grouped).length === 0) {
    return (
      <div className="mt-6">
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-bold text-slate-800">EOD Reports</h3>
          <div className="flex items-center gap-3">
            <button 
              onClick={() => fetchReports(true)}
              disabled={isRefreshing}
              className="p-2 text-slate-600 hover:bg-slate-100 rounded-lg transition disabled:opacity-50"
              title="Refresh Reports"
            >
              <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
            <input 
              type="date" 
              value={dateFilter}
              onChange={(e) => setDateFilter(e.target.value)}
              className="px-3 py-1.5 border border-slate-200 rounded-lg text-sm"
            />
          </div>
        </div>
        <div className="p-12 text-center flex flex-col items-center justify-center bg-white rounded-2xl border border-slate-200 shadow-sm mt-4">
          <FileText className="w-12 h-12 text-slate-300 mb-3" />
          <h3 className="text-lg font-bold text-slate-800">No EOD Reports</h3>
          <p className="text-sm text-slate-500 mt-1">No reports found for the selected criteria.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="mt-6 space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="font-bold text-slate-800">Submitted EOD Reports</h3>
        <div className="flex items-center gap-3">
          <button 
            onClick={() => fetchReports(true)}
            disabled={isRefreshing}
            className="p-2 text-slate-600 hover:bg-slate-100 rounded-lg transition disabled:opacity-50"
            title="Refresh Reports"
          >
            <RefreshCw className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>
          <input 
            type="date" 
            value={dateFilter}
            onChange={(e) => setDateFilter(e.target.value)}
            className="px-3 py-1.5 border border-slate-200 rounded-lg text-sm"
          />
        </div>
      </div>
      
      {Object.entries(grouped).map(([feName, feReports]) => (
        <div key={feName} className="bg-white rounded-2xl border border-slate-200/80 shadow-card overflow-hidden">
          <div
            className="flex items-center justify-between p-4 cursor-pointer hover:bg-slate-50 transition"
            onClick={() => toggleFE(feName)}
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-800 font-bold">
                {feName.substring(0, 2).toUpperCase()}
              </div>
              <div>
                <h4 className="font-bold text-slate-900">{feName}</h4>
                <p className="text-xs text-slate-500">{feReports.length} Reports Submitted</p>
              </div>
            </div>
            {expandedFEs[feName] ? (
              <ChevronUp className="w-5 h-5 text-slate-400" />
            ) : (
              <ChevronDown className="w-5 h-5 text-slate-400" />
            )}
          </div>

          {expandedFEs[feName] && (
            <div className="border-t border-slate-100 p-4 space-y-4 bg-slate-50/50">
              {feReports.map(report => (
                <div key={report.id} className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
                  <div className="flex items-center justify-between mb-3 border-b border-slate-100 pb-3">
                    <div className="flex items-center gap-2">
                      <Calendar className="w-4 h-4 text-emerald-600" />
                      <span className="text-sm font-bold text-slate-800">
                        {parseDateSafe(report.created_at).toLocaleDateString('en-GB')}
                      </span>
                    </div>
                    <span className="text-xs font-mono text-slate-500">
                      {parseDateSafe(report.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>

                  <div className="grid grid-cols-3 gap-4 mb-3">
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400">Completed Visits</div>
                      <div className="text-lg font-black text-slate-800">{report.completed_visits}</div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400">Pending Visits</div>
                      <div className="text-lg font-black text-slate-800">{report.pending_visits}</div>
                    </div>
                    <div>
                      <div className="text-[10px] uppercase font-bold text-slate-400">Total Bags</div>
                      <div className="text-lg font-black text-slate-800">{report.total_bags_ordered}</div>
                    </div>
                  </div>

                  {report.notes && (
                    <div className="bg-slate-50 p-3 rounded-lg border border-slate-100">
                      <div className="text-[10px] uppercase font-bold text-slate-400 mb-1">Notes</div>
                      <p className="text-sm text-slate-700">{report.notes}</p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
};
