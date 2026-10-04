import React, { useEffect, useRef } from 'react';
import L from 'leaflet';
import { Employee } from '../../data/mockEmployees';
import { Shop } from '../../data/mockShops';

interface LiveMapProps {
  employees?: Employee[];
  shops?: Shop[];
  selectedEmployeeId?: string;
  showRoutes?: boolean;
  height?: string;
  center?: [number, number];
  zoom?: number;
}

export const LiveMap: React.FC<LiveMapProps> = ({
  employees = [],
  shops = [],
  selectedEmployeeId,
  showRoutes = true,
  height = '360px',
  center = [16.5062, 80.6480], // Vijayawada / Guntur agricultural hub
  zoom = 10,
}) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);

  useEffect(() => {
    if (!mapContainerRef.current) return;

    // Avoid multiple instantiations
    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        center,
        zoom,
        zoomControl: false,
        attributionControl: true,
      });

      // Add clean, modern tile layer
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution:
          '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      }).addTo(map);

      // Add zoom control top right
      L.control.zoom({ position: 'topright' }).addTo(map);

      mapInstanceRef.current = map;
    }

    const map = mapInstanceRef.current;
    if (!map) return;

    // Clear existing markers/layers other than the tile layer
    map.eachLayer((layer) => {
      if (!(layer instanceof L.TileLayer)) {
        map.removeLayer(layer);
      }
    });

    // Add Shop Markers
    shops.forEach((shop) => {
      const shopIcon = L.divIcon({
        className: 'custom-shop-icon',
        html: `
          <div style="
            background: #0b3b2c;
            color: #ffffff;
            width: 28px;
            height: 28px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
            font-weight: bold;
            box-shadow: 0 4px 10px rgba(11,59,44,0.35);
            border: 2px solid #ffffff;
            cursor: pointer;
          ">
            🏪
          </div>
        `,
        iconSize: [28, 28],
        iconAnchor: [14, 14],
      });

      const marker = L.marker([shop.lat, shop.lng], { icon: shopIcon }).addTo(map);
      marker.bindPopup(`
        <div style="font-family: Inter, sans-serif; padding: 4px;">
          <b style="color: #0b3b2c; font-size: 13px;">${shop.name}</b>
          <div style="font-size: 11px; color: #64748b; margin-top: 2px;">📍 ${shop.location}</div>
          <div style="font-size: 11px; margin-top: 4px;"><b>Stock:</b> ${shop.currentStockBags} Bags</div>
          <div style="font-size: 11px; color: #16a34a; font-weight: 600;">Demand: ${shop.primaryCropDemand}</div>
        </div>
      `);
    });

    // Add Employee Markers
    employees.forEach((emp) => {
      const isSelected = selectedEmployeeId === emp.id;
      const isLive = emp.attendanceStatus === 'Present' || emp.attendanceStatus === 'In Field';

      const empIcon = L.divIcon({
        className: 'custom-emp-icon',
        html: `
          <div style="
            position: relative;
            width: 40px;
            height: 40px;
            cursor: pointer;
          ">
            <div style="
              width: 38px;
              height: 38px;
              border-radius: 50%;
              overflow: hidden;
              border: 3px solid ${isSelected ? '#f59e0b' : isLive ? '#22c55e' : '#94a3b8'};
              box-shadow: 0 4px 12px rgba(0,0,0,0.25);
              background: #ffffff;
            ">
              <img src="${emp.avatar}" style="width: 100%; height: 100%; object-fit: cover;" alt="${emp.name}" />
            </div>
            ${
              isLive
                ? `<span style="
                    position: absolute;
                    bottom: 0px;
                    right: 0px;
                    width: 12px;
                    height: 12px;
                    background: #22c55e;
                    border: 2px solid #ffffff;
                    border-radius: 50%;
                  "></span>`
                : ''
            }
          </div>
        `,
        iconSize: [40, 40],
        iconAnchor: [20, 20],
      });

      const marker = L.marker([emp.lat, emp.lng], { icon: empIcon }).addTo(map);
      marker.bindPopup(`
        <div style="font-family: Inter, sans-serif; padding: 4px; min-width: 150px;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <img src="${emp.avatar}" style="width: 32px; height: 32px; border-radius: 50%; object-fit: cover;" />
            <div>
              <b style="color: #0b3b2c; font-size: 13px;">${emp.name}</b>
              <div style="font-size: 10px; color: #64748b;">${emp.role} (${emp.empId})</div>
            </div>
          </div>
          <div style="margin-top: 8px; font-size: 11px; border-top: 1px solid #e2e8f0; padding-top: 6px;">
            <div>📍 <b>Location:</b> ${emp.location}</div>
            <div>⚡ <b>Status:</b> <span style="color: ${isLive ? '#16a34a' : '#ea580c'}; font-weight: bold;">${emp.attendanceStatus}</span></div>
            <div>⏱️ <b>Last Update:</b> ${emp.lastLocationUpdate}</div>
            <div>🔋 <b>Battery:</b> ${emp.batteryLevel}%</div>
            <div>🚶 <b>Distance:</b> ${emp.distanceCoveredTodayKm} km</div>
          </div>
        </div>
      `);

      // Add route polyline if requested
      if (showRoutes && emp.routeCoordinates && emp.routeCoordinates.length > 1) {
        L.polyline(emp.routeCoordinates, {
          color: isSelected ? '#ea580c' : '#16a34a',
          weight: 4,
          opacity: 0.8,
          dashArray: isSelected ? undefined : '6, 8',
        }).addTo(map);
      }
    });

    // Invalidate map size to make sure tiles load correctly in dynamic containers
    setTimeout(() => {
      map.invalidateSize();
    }, 200);
  }, [employees, shops, selectedEmployeeId, showRoutes, center, zoom]);

  return (
    <div className="relative w-full rounded-2xl overflow-hidden border border-slate-200/80 shadow-inner bg-slate-100" style={{ height }}>
      <div ref={mapContainerRef} className="w-full h-full" />
    </div>
  );
};
