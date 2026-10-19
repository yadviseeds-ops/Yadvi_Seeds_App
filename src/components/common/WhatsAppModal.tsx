import React from 'react';
import { useAppState } from '../../context/AppStateContext';
import { X, CheckCheck, ArrowLeft, Video, Phone, MoreVertical, Paperclip, Mic, Send } from 'lucide-react';

export const WhatsAppModal: React.FC = () => {
  const { whatsappAlert, dismissWhatsAppAlert, setActiveTab, setCurrentRole } = useAppState();

  if (!whatsappAlert || !whatsappAlert.show) return null;

  const handleOpenOrderInAdmin = () => {
    setCurrentRole('admin');
    setActiveTab('orders');
    dismissWhatsAppAlert();
  };

  return (
    <div className="fixed bottom-5 right-5 z-50 animate-bounce-short drop-shadow-2xl">
      {/* WhatsApp Message Preview Frame */}
      <div className="w-80 sm:w-96 rounded-2xl overflow-hidden border border-emerald-700/30 bg-[#efeae2] shadow-2xl flex flex-col font-sans">
        {/* WhatsApp App Bar */}
        <div className="bg-[#075e54] text-white px-3 py-2.5 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <button
              onClick={dismissWhatsAppAlert}
              className="text-white/80 hover:text-white p-0.5 rounded-full"
            >
              <ArrowLeft className="w-4 h-4" />
            </button>
            <div className="w-8 h-8 rounded-full bg-emerald-100 flex items-center justify-center font-bold text-emerald-800 text-xs border border-white/20">
              YS
            </div>
            <div>
              <div className="font-semibold text-sm leading-tight">Admin WhatsApp</div>
              <div className="text-[10px] text-emerald-100/90 leading-none">Online • Bot Alert</div>
            </div>
          </div>
          <div className="flex items-center gap-2 text-white/80">
            <Video className="w-4 h-4 cursor-pointer hover:text-white" />
            <Phone className="w-4 h-4 cursor-pointer hover:text-white" />
            <MoreVertical className="w-4 h-4 cursor-pointer hover:text-white" />
            <button
              onClick={dismissWhatsAppAlert}
              className="text-white/80 hover:text-white ml-1 p-0.5"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* WhatsApp Chat Body with Background Pattern */}
        <div
          className="p-4 flex flex-col space-y-3 bg-[#efeae2] min-h-[210px] relative"
          style={{
            backgroundImage: 'radial-gradient(#cfd8dc 1px, transparent 1px)',
            backgroundSize: '16px 16px',
          }}
        >
          <div className="self-center bg-amber-100/80 text-amber-900 text-[10px] px-2.5 py-1 rounded-md shadow-xs text-center border border-amber-200">
            🔒 Messages and calls are end-to-end encrypted.
          </div>

          {/* Incoming Order Notification Bubble - Matches Image 3 exactly! */}
          <div className="self-start max-w-[90%] bg-[#d9fdd3] text-slate-800 p-3.5 rounded-2xl rounded-tl-xs shadow-md border border-[#c4eabf] relative text-xs">
            <div className="flex items-center gap-1.5 font-bold text-emerald-900 mb-1.5 text-sm">
              <span>📦</span>
              <span>New Order Received</span>
            </div>

            <div className="space-y-1 font-mono text-[11px] text-slate-700 bg-white/70 p-2.5 rounded-lg border border-emerald-200/60">
              <div className="flex justify-between">
                <span className="font-semibold text-slate-600">Shop:</span>
                <span className="font-bold text-slate-900">{whatsappAlert.shopName}</span>
              </div>
              <div className="flex justify-between">
                <span className="font-semibold text-slate-600">Order ID:</span>
                <span className="font-bold text-emerald-700">{whatsappAlert.orderNumber}</span>
              </div>
              <div className="flex justify-between">
                <span className="font-semibold text-slate-600">Items:</span>
                <span className="font-bold text-slate-900">{whatsappAlert.itemsCount}</span>
              </div>
              <div className="flex justify-between">
                <span className="font-semibold text-slate-600">Total Quantity:</span>
                <span className="font-bold text-slate-900">{whatsappAlert.totalQuantity} kg</span>
              </div>
              <div className="flex justify-between pt-1 border-t border-slate-200">
                <span className="font-semibold text-slate-600">Status:</span>
                <span className="inline-flex items-center px-1.5 py-0.2 bg-emerald-600 text-white rounded text-[10px] font-bold">
                  {whatsappAlert.status}
                </span>
              </div>
            </div>

            {/* Timestamp & Double Checkmarks */}
            <div className="flex items-center justify-end gap-1 text-[10px] text-slate-500 mt-1.5">
              <span>{whatsappAlert.timestamp}</span>
              <CheckCheck className="w-3.5 h-3.5 text-[#53bdeb]" />
            </div>
          </div>

          {/* Quick Action Button to Admin Portal */}
          <div className="pt-2">
            <button
              onClick={handleOpenOrderInAdmin}
              className="w-full py-2 px-3 bg-[#075e54] hover:bg-[#128c7e] text-white font-semibold rounded-lg shadow text-xs flex items-center justify-center gap-2 transition"
            >
              <span>View in Admin Orders</span>
              <span className="text-emerald-200 text-[10px]">→</span>
            </button>
          </div>
        </div>

        {/* Mock Input Bar */}
        <div className="bg-[#f0f2f5] p-2 flex items-center gap-2 border-t border-slate-200">
          <Paperclip className="w-4 h-4 text-slate-500" />
          <div className="flex-1 bg-white rounded-full py-1 px-3 text-[11px] text-slate-400 border border-slate-200">
            Type a message...
          </div>
          <Mic className="w-4 h-4 text-slate-500" />
        </div>
      </div>
    </div>
  );
};
