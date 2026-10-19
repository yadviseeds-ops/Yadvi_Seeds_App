import React, { createContext, useContext, useState, useEffect } from 'react';
import { SEED_PRODUCTS, SeedProduct } from '../data/seedProducts';
import { MOCK_EMPLOYEES, Employee, MOCK_LEAVE_REQUESTS, LeaveRequest } from '../data/mockEmployees';
import { MOCK_SHOPS, Shop } from '../data/mockShops';
import { INITIAL_ORDERS, Order, OrderStatus, INITIAL_SHIPMENTS, ShipmentTracking } from '../data/mockOrders';
import { MOCK_VISITS, FieldVisit } from '../data/mockVisits';

import { api, AuthResponse, API_BASE_URL } from '../services/api';
import { logoutFirebase } from '../services/firebase';

export type UserRole = 'admin' | 'shop_owner' | 'field_executive';
export type DeviceView = 'desktop' | 'android' | 'ios';

export interface AuthenticatedUser {
  id: number;
  full_name: string;
  role: string;
  phone?: string;
  metadata?: Record<string, any>;
}

export interface CartItem {
  product: SeedProduct;
  packageSize: string;
  quantity: number;
  unit: 'g' | 'kg';
}

export interface WhatsAppNotification {
  show: boolean;
  orderNumber: string;
  shopName: string;
  itemsCount: number;
  totalQuantity: number;
  timestamp: string;
  status: string;
}

interface AppStateContextType {
  currentRole: UserRole;
  setCurrentRole: (role: UserRole) => void;
  deviceView: DeviceView;
  setDeviceView: (view: DeviceView) => void;
  isAuthenticated: boolean;
  authenticatedUser: AuthenticatedUser | null;
  canSwitchRoles: boolean;
  handleRequestOtp: (username: string, mobile: string) => Promise<void>;
  handleVerifyOtp: (username: string, mobile: string, otp: string) => Promise<void>;
  handleLoginPassword: (username: string, password: string) => Promise<void>;
  handleLoginFirebase: (username: string, mobile: string, firebaseIdToken: string) => Promise<AuthResponse>;
  handleLogout: () => void;
  isAdminAuthenticated: boolean;
  adminPhone: string;
  loginAdmin: (phone: string, otp: string) => boolean;
  logoutAdmin: () => void;
  products: SeedProduct[];
  employees: Employee[];
  shops: Shop[];
  orders: Order[];
  shipments: ShipmentTracking[];
  visits: FieldVisit[];
  leaves: LeaveRequest[];
  cart: CartItem[];
  addToCart: (product: SeedProduct, packageSize: string, quantity: number, unit?: 'g' | 'kg') => void;
  removeFromCart: (productId: string) => void;
  updateCartQuantity: (productId: string, quantity: number, unit?: 'g' | 'kg') => void;
  clearCart: () => void;
  placeOrder: (notes?: string, itemsToOrder?: CartItem[]) => Promise<Order>;
  updateOrderStatus: (orderId: string, status: OrderStatus, lrNumber?: string, transporter?: string) => Promise<void>;
  assignOrderExecutive: (orderId: string, execId: number) => Promise<void>;
  approveLeave: (leaveId: string) => void;
  rejectLeave: (leaveId: string) => void;
  uploadVisitPhoto: (visitId: string, notes?: string, photoUrl?: string) => Promise<void>;
  whatsappAlert: WhatsAppNotification | null;
  dismissWhatsAppAlert: () => void;
  triggerWhatsAppAlert: (alert: WhatsAppNotification) => void;
  activeTab: string;
  setActiveTab: (tab: string) => void;
  selectedOrderForTrack: Order | null;
  setSelectedOrderForTrack: (order: Order | null) => void;
  addEmployee: (payload: any) => Promise<void>;
  addShop: (payload: any) => Promise<void>;
  updateShop: (id: string | number, payload: any) => Promise<void>;
  assignShopToExecutive: (shopId: string, execId: string) => Promise<{ assignedExecutiveId?: string; assignedExecutiveName?: string }>;
  addProduct: (payload: any) => Promise<void>;
  removeEmployee: (id: string | number) => Promise<void>;
  removeShopOwner: (id: string | number) => Promise<void>;
  removeProduct: (id: string | number) => Promise<void>;
}

const AppStateContext = createContext<AppStateContextType | undefined>(undefined);

export const AppStateProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Backend Authentication & RBAC state with persistence
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    const token = localStorage.getItem('yadvi_auth_token');
    return !!token && token !== 'null' && token !== 'undefined';
  });

  const [authenticatedUser, setAuthenticatedUser] = useState<AuthenticatedUser | null>(() => {
    const saved = localStorage.getItem('yadvi_auth_user');
    try {
      return saved ? JSON.parse(saved) : null;
    } catch (e) {
      return null;
    }
  });

  const [currentRole, setCurrentRoleState] = useState<UserRole>(() => {
    const saved = localStorage.getItem('yadvi_auth_user');
    if (saved) {
      try {
        const u = JSON.parse(saved);
        if (u.role === 'administrator') return 'admin';
        if (u.role === 'field_executive') return 'field_executive';
        if (u.role === 'shop_owner') return 'shop_owner';
      } catch (e) { }
    }
    return 'admin';
  });

  const [deviceView, setDeviceView] = useState<DeviceView>(() => {
    return currentRole === 'admin' ? 'desktop' : 'android';
  });

  const [isAdminAuthenticated, setIsAdminAuthenticated] = useState<boolean>(() => {
    return authenticatedUser?.role === 'administrator';
  });

  const [adminPhone, setAdminPhone] = useState<string>('+91 98765 43210');
  const [activeTab, setActiveTab] = useState<string>('dashboard');

  const canSwitchRoles = authenticatedUser?.role === 'administrator';

  // Role switching controller - enforces requirement #3
  const setCurrentRole = (role: UserRole) => {
    if (!canSwitchRoles && authenticatedUser) {
      console.warn("Unauthorized role switch attempt prevented: Only Administrators can switch roles.");
      return;
    }
    setCurrentRoleState(role);
  };

  const handleRequestOtp = async (username: string, mobile: string) => {
    await api.requestOtp(username, mobile);
  };

  const handleVerifyOtp = async (username: string, mobile: string, otp: string) => {
    const response = await api.verifyOtp(username, mobile, otp);
    const mappedRole: UserRole = response.role === 'administrator' ? 'admin' : (response.role as UserRole);

    const userObj: AuthenticatedUser = {
      id: response.user_id,
      full_name: response.full_name,
      role: response.role,
      metadata: response.metadata,
    };

    setAuthenticatedUser(userObj);
    localStorage.setItem('yadvi_auth_user', JSON.stringify(userObj));
    setIsAuthenticated(true);
    setIsAdminAuthenticated(response.role === 'administrator');
    setCurrentRoleState(mappedRole);

    if (mappedRole === 'admin') {
      setDeviceView('desktop');
    } else {
      setDeviceView('android');
    }
  };

  const handleLoginPassword = async (username: string, password: string) => {
    const response = await api.loginWithPassword(username, password);
    const mappedRole: UserRole = response.role === 'administrator' ? 'admin' : (response.role as UserRole);

    const userObj: AuthenticatedUser = {
      id: response.user_id,
      full_name: response.full_name,
      role: response.role,
      metadata: response.metadata,
    };

    setAuthenticatedUser(userObj);
    localStorage.setItem('yadvi_auth_user', JSON.stringify(userObj));
    setIsAuthenticated(true);
    setIsAdminAuthenticated(response.role === 'administrator');
    setCurrentRoleState(mappedRole);

    if (mappedRole === 'admin') {
      setDeviceView('desktop');
    } else {
      setDeviceView('android');
    }
  };

  const handleLoginFirebase = async (username: string, mobile: string, firebaseIdToken: string): Promise<AuthResponse> => {
    try {
      const response = await api.loginWithFirebase(username, mobile, firebaseIdToken);

      // Strict role verification: only administrator may access this portal
      if (response.role !== 'administrator') {
        api.removeToken();
        await logoutFirebase();
        throw new Error(`Unauthorized role (${response.role}). Administrator privileges are required to access this portal.`);
      }

      const userObj: AuthenticatedUser = {
        id: response.user_id,
        full_name: response.full_name,
        role: response.role,
        phone: mobile,
        metadata: response.metadata,
      };

      setAuthenticatedUser(userObj);
      localStorage.setItem('yadvi_auth_user', JSON.stringify(userObj));
      setIsAuthenticated(true);
      setIsAdminAuthenticated(true);
      setCurrentRoleState('admin');
      setDeviceView('desktop');

      return response;
    } catch (err) {
      api.removeToken();
      localStorage.removeItem('yadvi_auth_user');
      setIsAuthenticated(false);
      setAuthenticatedUser(null);
      setIsAdminAuthenticated(false);
      await logoutFirebase();
      throw err;
    }
  };

  const handleLogout = async () => {
    api.removeToken();
    localStorage.removeItem('yadvi_auth_user');
    setIsAuthenticated(false);
    setAuthenticatedUser(null);
    setIsAdminAuthenticated(false);
    setCurrentRoleState('admin');
    setDeviceView('desktop');
    await logoutFirebase();

    // Explicitly prevent back button navigation to authenticated state
    window.history.pushState(null, '', window.location.href);
    window.onpopstate = function () {
      window.history.go(1);
    };
  };

  const [products, setProducts] = useState<any[]>(SEED_PRODUCTS);
  const [employees, setEmployees] = useState<any[]>(MOCK_EMPLOYEES);
  const [shops, setShops] = useState<any[]>(MOCK_SHOPS);
  const [orders, setOrders] = useState<any[]>(INITIAL_ORDERS);
  const [shipments, setShipments] = useState<any[]>(INITIAL_SHIPMENTS);
  const [visits, setVisits] = useState<any[]>([]);
  const [leaves, setLeaves] = useState<any[]>(MOCK_LEAVE_REQUESTS);

  const resolveProductImageUrl = (url?: string) => {
    if (!url) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    const baseUrl = API_BASE_URL.replace('/api/v1', '');
    return `${baseUrl}${url.startsWith('/') ? '' : '/'}${url}`;
  };

  // Fetch data from API based on role
  useEffect(() => {
    if (isAuthenticated) {
      api.getProducts().then(data => {
        if (data && data.length) {
          setProducts(data.map((p: any) => ({
            id: String(p.id),
            name: p.name,
            varietyType: p.variety_type,
            sku: p.sku,
            category: p.category,
            image: resolveProductImageUrl(p.image_url),
            stockKg: p.available_stock_kg ?? p.available_stock_bags ?? 0,
            stockBags: p.available_stock_kg ?? p.available_stock_bags ?? 0,
            germinationRate: p.germination_rate,
            purity: p.purity,
            maturityDays: p.maturity_days,
            cropSeason: p.crop_season,
            availability: p.availability,
            description: p.description,
            packageSizes: p.package_sizes ? p.package_sizes.split(',').map((s: string) => s.trim()) : [],
          })));
        }
      }).catch(console.error);

      api.getOrders().then(data => {
        if (data && data.length) {
          setOrders(data.map((o: any) => ({
            id: String(o.id),
            orderNumber: o.order_number,
            shopId: String(o.shop_id),
            shopName: o.shop_name,
            shopLocation: o.shop_location,
            ownerName: o.owner_name,
            contactPhone: o.contact_phone,
            deliveryAddress: o.delivery_address,
            orderDate: o.created_at,
            totalQuantityKg: o.total_quantity_kg ?? 0,
            totalItemsCount: o.total_items_count,
            status: o.status,
            source: o.source,
            deliveryNotes: o.delivery_notes,
            assignedExecutiveName: o.assigned_executive_name,
            lrNumber: o.lr_number,
            transporterName: o.transporter_name,
            dispatchDate: o.status === 'Dispatched' ? o.created_at : undefined,
            items: (o.items || []).map((i: any) => ({
              productId: String(i.product_id),
              productName: i.product_name,
              sku: i.sku,
              image: i.image_url,
              packageSize: i.package_size,
              quantity: i.quantity ?? 0,
              unit: i.unit || 'kg',
            }))
          })));
        }
      }).catch(console.error);

      if (currentRole === 'admin') {
        api.getEmployees().then(data => {
          if (data && data.length) {
            setEmployees(data.map((e: any) => ({
              id: String(e.id),
              empId: e.employee_code,
              name: e.full_name,
              role: e.designation,
              phone: e.phone,
              email: e.email,
              location: e.assigned_territory,
              lat: e.current_lat || 0,
              lng: e.current_lng || 0,
              status: e.is_active ? 'Active' : 'Inactive',
              attendanceStatus: e.attendance_status,
              distanceCoveredTodayKm: e.distance_covered_km,
              batteryLevel: e.battery_level,
              lastLocationUpdate: e.last_location_update
            })));
          }
        }).catch(console.error);

        // Assume API format needs mapping for shops if we had a full shop implementation
        // For now, if getShops returns something, map it minimally
        api.getShops().then(data => {
          if (data && data.length) {
            // Simplified mapping, assuming basic fields exist
            setShops(data.map((s: any) => ({
              id: String(s.id),
              name: s.shop_name || '',
              ownerName: s.owner_name || s.user?.full_name || '',
              phone: s.phone || s.user?.phone || '',
              email: s.email || s.user?.email || '',
              location: s.market_location || '',
              address: s.address || '',
              status: s.status || 'Active',
              lat: s.lat || 0,
              lng: s.lng || 0,
              gstin: s.gstin || '',
              seedLicenseNo: s.seed_license_no || '',
              assignedExecutiveId: s.assigned_executive_id ? String(s.assigned_executive_id) : '',
              assignedExecutiveName: s.assigned_executive_name || 'Unassigned',
              totalOrdersCount: s.total_orders_count || 0,
              totalKgReceived: s.total_kg_received || s.total_bags_received || 0,
              pendingDeliveryKg: s.pending_delivery_kg || s.pending_delivery_bags || 0,
              totalBagsReceived: s.total_bags_received || 0,
              pendingDeliveryBags: s.pending_delivery_bags || 0,
              lastVisitDate: s.last_visit_date || '',
              openingStockKg: s.opening_stock_kg ?? s.opening_stock_bags ?? 0,
              currentStockKg: s.current_stock_kg ?? s.current_stock_bags ?? 0,
              openingStockBags: s.opening_stock_kg ?? s.opening_stock_bags ?? 0,
              currentStockBags: s.current_stock_kg ?? s.current_stock_bags ?? 0,
              primaryCropDemand: s.primary_demand_crop || ''
            })));
          }
        }).catch(console.error);

        // Connect to WebSocket for live tracking
        const token = localStorage.getItem('yadvi_auth_token');
        if (token && token !== 'null' && token !== 'undefined') {
          const wsBaseUrl = API_BASE_URL.replace('http://', 'ws://').replace('https://', 'wss://');
          const wsUrl = `${wsBaseUrl}/ws/live-tracking?token=${token}`;
          const ws = new WebSocket(wsUrl);

          ws.onopen = () => {
            console.log("Admin connected to live tracking WebSocket.");
          };

          ws.onmessage = (event) => {
            try {
              const payload = JSON.parse(event.data);
              if (payload.type === 'LOCATION_UPDATE' && payload.data) {
                setEmployees(prev => prev.map(emp => {
                  if (emp.id === String(payload.data.employee_id)) {
                    return {
                      ...emp,
                      lat: payload.data.lat,
                      lng: payload.data.lng,
                      batteryLevel: payload.data.battery,
                      lastLocationUpdate: new Date(payload.data.last_update).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                    };
                  }
                  return emp;
                }));
              } else if (payload.type === 'DELIVERY_STATUS_CHANGED' && payload.data) {
                setOrders(prev => prev.map(order => {
                  if (order.id === String(payload.data.order_id)) {
                    return { ...order, status: payload.data.status };
                  }
                  return order;
                }));
                setShipments(prev => prev.map(ship => {
                  if (ship.lrNumber === payload.data.lr_number) {
                    return { ...ship, status: payload.data.status };
                  }
                  return ship;
                }));
              }
            } catch (err) {
              console.error("Error parsing WebSocket message:", err);
            }
          };

          ws.onclose = () => {
            console.log("Live tracking WebSocket closed.");
          };

          // We will clean this up later in the useEffect
          (window as any).yadviWs = ws;
        }
      }

      if (currentRole === 'admin' || currentRole === 'field_executive') {
        api.getVisits().then(data => {
          console.log("FETCHED VISITS FROM API:", data);
          if (data && Array.isArray(data)) {
            const sanitizeDate = (dt: string | undefined) => {
              if (!dt) return undefined;
              let cleaned = dt.includes('.') ? dt.split('.')[0] : dt;
              return cleaned.endsWith('Z') ? cleaned : `${cleaned}Z`;
            };

            const mapped = data.map((v: any) => ({
              id: String(v.id),
              shopName: v.shop_name,
              shopLocation: v.shop_location,
              shopOwnerName: v.shop_owner_name,
              shopTerritory: v.shop_territory,
              shopCity: v.shop_city,
              shopAddress: v.shop_address,
              shopPhotoUrlProfile: v.shop_photo_url_profile ? (v.shop_photo_url_profile.startsWith('http') ? v.shop_photo_url_profile : `${API_BASE_URL.replace('/api/v1', '')}${v.shop_photo_url_profile}`) : undefined,
              shopOwnerPhotoUrl: v.shop_owner_photo_url ? (v.shop_owner_photo_url.startsWith('http') ? v.shop_owner_photo_url : `${API_BASE_URL.replace('/api/v1', '')}${v.shop_owner_photo_url}`) : undefined,
              shopContact: v.shop_phone,
              executiveName: v.executive_name,
              purpose: v.purpose,
              status: v.status,
              visitedAt: sanitizeDate(v.visited_at),
              notes: v.notes,
              quantityBookedKg: v.quantity_booked_kg ?? v.bags_ordered ?? 0,
              bagsOrdered: v.quantity_booked_kg ?? v.bags_ordered ?? 0,
              photoUrl: v.photo_url ? (v.photo_url.startsWith('http') ? v.photo_url : `${API_BASE_URL.replace('/api/v1', '')}${v.photo_url}`) : undefined,
              photoLat: v.photo_lat,
              photoLng: v.photo_lng,
              scheduledTime: sanitizeDate(v.scheduled_date)
            }));
            console.log("MAPPED VISITS:", mapped);
            setVisits(mapped);
          } else {
            console.log("DATA NOT AN ARRAY:", data);
            alert("API returned non-array data: " + JSON.stringify(data));
          }
        }).catch(err => {
          console.error("FAILED TO FETCH VISITS:", err);
          alert("Failed to fetch REAL visits. Currently showing Mock Data. Error: " + err.message);
        });
      }

      if (currentRole === 'admin' || currentRole === 'shop_owner' || currentRole === 'field_executive') {
        api.getShipments().then(data => {
          if (data && data.length) {
            setShipments(data.map((s: any) => ({
              lrNumber: s.lr_number,
              orderNumber: s.order_number || '', // Assuming backend returns this or we need to join
              shopName: s.shop_name || '',
              shopLocation: s.current_location || '',
              transporter: s.transporter_name,
              driverName: s.driver_name,
              driverPhone: s.driver_phone,
              vehicleNumber: s.vehicle_number,
              dispatchDate: s.dispatch_date,
              estimatedDelivery: s.estimated_delivery,
              status: s.status,
              totalKg: s.total_bags || 0,
              totalBags: s.total_bags || 0,
              timeline: [] // We can populate timeline if backend provides it
            })));
          }
        }).catch(console.error);
      }

      return () => {
        if ((window as any).yadviWs) {
           (window as any).yadviWs.close();
           (window as any).yadviWs = null;
        }
      };
    }
  }, [isAuthenticated, currentRole]);
  const [cart, setCart] = useState<CartItem[]>([
    {
      product: SEED_PRODUCTS[0], // Krishna-5 Chilli
      packageSize: '100g Pouch',
      quantity: 5,
      unit: 'kg',
    },
    {
      product: SEED_PRODUCTS[1], // YH-222 Okra
      packageSize: '500g Pouch',
      quantity: 10,
      unit: 'kg',
    }
  ]);

  const [selectedOrderForTrack, setSelectedOrderForTrack] = useState<Order | null>(INITIAL_ORDERS[1]);

  const [whatsappAlert, setWhatsappAlert] = useState<WhatsAppNotification | null>({
    show: false,
    orderNumber: 'ORD-1025',
    shopName: 'ABC Seeds',
    itemsCount: 5,
    totalQuantity: 25,
    timestamp: '10:24 AM',
    status: 'New',
  });

  // Automatically adjust device view when role switches
  useEffect(() => {
    if (currentRole === 'admin') {
      setDeviceView('desktop');
    } else {
      if (deviceView === 'desktop') {
        setDeviceView('android');
      }
    }
  }, [currentRole]);

  const loginAdmin = (phone: string, otp: string) => {
    // Verified authorized mock login (e.g. 6-digit OTP)
    if (phone.trim().length >= 10 && (otp === '123456' || otp.length === 6)) {
      setIsAdminAuthenticated(true);
      setAdminPhone(phone);
      return true;
    }
    return false;
  };

  const logoutAdmin = () => {
    setIsAdminAuthenticated(false);
  };

  const addToCart = (product: SeedProduct, packageSize: string, quantity: number, unit: 'g' | 'kg' = 'kg') => {
    if (quantity <= 0) return;
    setCart((prev) => {
      const existing = prev.find((item) => item.product.id === product.id && item.unit === unit);
      if (existing) {
        return prev.map((item) =>
          item.product.id === product.id && item.unit === unit
            ? { ...item, quantity: item.quantity + quantity, packageSize }
            : item
        );
      }
      return [...prev, { product, packageSize, quantity, unit }];
    });
  };

  const removeFromCart = (productId: string) => {
    setCart((prev) => prev.filter((item) => item.product.id !== productId));
  };

  const updateCartQuantity = (productId: string, quantity: number, unit?: 'g' | 'kg') => {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    setCart((prev) =>
      prev.map((item) =>
        item.product.id === productId ? {
          ...item,
          quantity,
          unit: unit || item.unit,
        } : item
      )
    );
  };

  const clearCart = () => {
    setCart([]);
  };

  const placeOrder = async (notes?: string, itemsToOrder?: CartItem[]): Promise<Order> => {
    const targetItems = itemsToOrder || cart;

    if (targetItems.length === 0) {
      throw new Error("Cannot place an order with 0 items.");
    }

    // Verify all quantities are positive
    for (const item of targetItems) {
      if (!item.quantity || item.quantity <= 0) {
        throw new Error(`Quantity for ${item.product.name} must be greater than zero.`);
      }
    }

    const payload = {
      items: targetItems.map(item => ({
        product_id: parseInt(item.product.id.replace('prod-', '')),
        package_size: item.packageSize,
        quantity: item.quantity,
        unit: item.unit || 'kg',
      })),
      delivery_notes: notes || 'Standard consignment delivery',
      source: currentRole === 'shop_owner' ? 'Shop Owner App' : 'Field Executive'
    };

    try {
      const response = await api.createOrder(payload);

      const totalKg = response.total_quantity_kg ?? 0;
      const newOrder: Order = {
        id: String(response.id),
        orderNumber: response.order_number,
        shopId: String(response.shop_id),
        shopName: response.shop_name,
        shopLocation: response.shop_location,
        ownerName: response.owner_name,
        contactPhone: response.contact_phone,
        deliveryAddress: response.delivery_address,
        orderDate: response.created_at,
        items: response.items.map((item: any) => ({
          productId: String(item.product_id),
          productName: item.product_name,
          varietyType: '',
          sku: item.sku,
          image: item.image_url,
          packageSize: item.package_size,
          quantity: item.quantity ?? 0,
          unit: item.unit || 'kg',
        })),
        totalQuantityKg: totalKg,
        totalItemsCount: response.total_items_count,
        status: response.status,
        source: response.source,
        deliveryNotes: response.delivery_notes,
        assignedExecutiveId: 'emp-2',
        assignedExecutiveName: response.assigned_executive_name || 'Unassigned',
      };

      setOrders((prev) => [newOrder, ...prev]);
      clearCart();

      const alertData: WhatsAppNotification = {
        show: true,
        orderNumber: newOrder.orderNumber,
        shopName: newOrder.shopName,
        itemsCount: newOrder.totalItemsCount,
        totalQuantity: newOrder.totalQuantityKg,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        status: 'New',
      };
      setWhatsappAlert(alertData);

      return newOrder;
    } catch (err) {
      console.error('Failed to place order:', err);
      throw err;
    }
  };

  const updateOrderStatus = async (
    orderId: string,
    status: OrderStatus,
    lrNumber?: string,
    transporter?: string
  ) => {
    try {
      const numericId = orderId.replace('ord-', '');
      await api.updateOrderStatus(numericId, {
        status,
        lr_number: lrNumber,
        transporter_name: transporter
      });

      setOrders((prev) =>
        prev.map((ord) => {
          if (ord.id === orderId || ord.id === numericId) {
            const updated = { ...ord, status };
            if (lrNumber) updated.lrNumber = lrNumber;
            if (transporter) updated.transporterName = transporter;
            if (status === 'Dispatched') {
              updated.dispatchDate = new Date().toLocaleDateString('en-GB') + ' ' + new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
              updated.expectedDeliveryDate = 'Within 48 Hours';
            }
            return updated;
          }
          return ord;
        })
      );

      // If dispatched, also add/update shipment tracking entry
      if (status === 'Dispatched' && lrNumber) {
        const order = orders.find((o) => o.id === orderId || o.id === numericId);
        if (order) {
          const newShipment: ShipmentTracking = {
            lrNumber,
            orderNumber: order.orderNumber,
            shopName: order.shopName,
            shopLocation: order.shopLocation,
            transporter: transporter || 'Navata Road Transport',
            driverName: 'R. Koteswara Rao',
            driverPhone: '+91 94402 88123',
            vehicleNumber: 'AP 16 TZ 5519',
            dispatchDate: new Date().toLocaleDateString('en-GB') + ' Today',
            estimatedDelivery: 'Tomorrow Evening',
            status: 'Dispatched',
            totalBags: order.totalQuantityBags,
            timeline: [
              {
                title: 'Dispatched from Central Warehouse',
                location: 'Yadvi Processing Plant, Gannavaram Hub',
                timestamp: 'Just Now',
                completed: true,
                current: true,
                description: `Dispatched with LR #${lrNumber} via ${transporter || 'Navata Road Transport'}`
              }
            ]
          };
          setShipments((prev) => [newShipment, ...prev.filter((s) => s.orderNumber !== order.orderNumber)]);
        }
      }
    } catch (err) {
      console.error('Failed to update order status:', err);
    }
  };

  const assignOrderExecutive = async (orderId: string, execId: number) => {
    try {
      const numericId = orderId.replace('ord-', '');
      const response = await api.assignOrderExecutive(numericId, execId);

      setOrders((prev) =>
        prev.map((ord) => {
          if (ord.id === orderId || ord.id === numericId) {
            return {
              ...ord,
              assignedExecutiveId: String(execId),
              assignedExecutiveName: response.assigned_executive_name,
              status: response.status
            };
          }
          return ord;
        })
      );
    } catch (err) {
      console.error('Failed to assign order executive:', err);
      throw err;
    }
  };

  const approveLeave = (leaveId: string) => {
    setLeaves((prev) =>
      prev.map((item) => (item.id === leaveId ? { ...item, status: 'Approved' } : item))
    );
  };

  const rejectLeave = (leaveId: string) => {
    setLeaves((prev) =>
      prev.map((item) => (item.id === leaveId ? { ...item, status: 'Rejected' } : item))
    );
  };

  const uploadVisitPhoto = async (visitId: string, notes?: string, photoUrl?: string) => {
    try {
      const numericId = visitId.replace('visit-', '');
      // Example call matching the new API shape, passing arbitrary lat/lng
      await api.uploadVisitPhoto(numericId, 16.5062, 80.6480, photoUrl || 'https://example.com/photo.jpg', notes);

      const timeNow = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      setVisits((prev) =>
        prev.map((v) =>
          (v.id === visitId || v.id === numericId)
            ? { ...v, status: 'Visited', visitedAt: timeNow, notes: notes || v.notes, photoUrl: photoUrl || 'https://example.com/photo.jpg' }
            : v
        )
      );
    } catch (err) {
      console.error('Failed to upload visit photo:', err);
    }
  };

  const dismissWhatsAppAlert = () => {
    setWhatsappAlert(null);
  };

  const triggerWhatsAppAlert = (alert: WhatsAppNotification) => {
    setWhatsappAlert(alert);
  };

  const addEmployee = async (payload: any) => {
    try {
      const newEmp = await api.createEmployee(payload);
      const mappedEmp = {
        id: `emp-${newEmp.id}`,
        name: newEmp.full_name,
        empId: newEmp.employee_code,
        role: newEmp.designation || 'Field Sales Officer',
        location: newEmp.assigned_territory || 'Unassigned',
        status: newEmp.is_active ? 'Active' : 'Inactive',
        attendanceStatus: 'Present',
        distanceCoveredTodayKm: 0,
        phone: newEmp.phone,
        email: newEmp.email || '',
        batteryLevel: 100,
        lastLocationUpdate: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        lat: 16.5,
        lng: 80.6,
        assignedShopsCount: 0,
        completedVisitsCount: 0
      };
      setEmployees(prev => [mappedEmp as Employee, ...prev]);
    } catch (err) {
      console.error('Failed to create employee:', err);
      throw err;
    }
  };

  const addShop = async (payload: any) => {
    try {
      const newShopApi = await api.createShop(payload);
      const mappedShop = {
        id: `shop-${newShopApi.id}`,
        name: newShopApi.shop_name,
        ownerName: newShopApi.owner_name,
        phone: newShopApi.phone,
        email: newShopApi.email || '',
        location: newShopApi.market_location || 'Unspecified',
        address: newShopApi.address,
        status: newShopApi.status || 'Active',
        openingStockBags: newShopApi.opening_stock_bags || 0,
        currentStockBags: newShopApi.current_stock_bags || 0,
        primaryCropDemand: newShopApi.primary_demand_crop || 'Mixed',
        lat: newShopApi.lat || 16.5062,
        lng: newShopApi.lng || 80.6480,
      };
      setShops(prev => [mappedShop as Shop, ...prev]);
    } catch (err) {
      console.error('Failed to create shop:', err);
      throw err;
    }
  };

  const updateShop = async (id: string | number, payload: any) => {
    try {
      const numericId = typeof id === 'string' ? parseInt(id.replace('shop-', ''), 10) : id;
      const updatedShopApi = await api.updateShop(numericId, payload);
      setShops(prev => prev.map(s => {
        if (s.id === String(id) || s.id === `shop-${numericId}` || s.id === String(numericId)) {
          return {
            ...s,
            name: updatedShopApi.shop_name || s.name,
            ownerName: updatedShopApi.owner_name || s.ownerName,
            phone: updatedShopApi.phone || s.phone,
            email: updatedShopApi.email || s.email,
            location: updatedShopApi.market_location || s.location,
            address: updatedShopApi.address || s.address,
            primaryCropDemand: updatedShopApi.primary_demand_crop || s.primaryCropDemand,
            status: updatedShopApi.status || s.status,
          };
        }
        return s;
      }));
    } catch (err) {
      console.error('Failed to update shop:', err);
      throw err;
    }
  };

  const assignShopToExecutive = async (shopId: string, execId: string) => {
    try {
      const numericShopId = parseInt(shopId.replace('shop-', ''), 10) || parseInt(shopId, 10);
      const isUnassign = !execId || execId === 'unassign' || execId === '';
      const numericExecId = isUnassign ? null : (parseInt(execId.replace('emp-', ''), 10) || parseInt(execId, 10));
      const res = await api.assignShop(numericShopId, numericExecId);

      let assignedId: string = '';
      let assignedName: string = 'Unassigned';

      if (numericExecId) {
        const exec = employees.find(e => e.id === String(numericExecId) || e.id === execId);
        assignedId = String(numericExecId);
        assignedName = res?.assigned_executive_name || exec?.name || 'Assigned';
      }

      setShops(prev => prev.map(s =>
        s.id === shopId || s.id === String(numericShopId)
          ? { ...s, assignedExecutiveId: assignedId, assignedExecutiveName: assignedName }
          : s
      ));

      return { assignedExecutiveId: assignedId, assignedExecutiveName: assignedName };
    } catch (err) {
      console.error('Failed to assign shop:', err);
      throw err;
    }
  };

  const addProduct = async (payload: any) => {
    try {
      const newProd = await api.createProduct(payload);
      const mappedProd = {
        id: `prod-${newProd.id}`,
        name: newProd.name,
        varietyType: newProd.variety_type,
        sku: newProd.sku,
        category: newProd.category,
        stockKg: newProd.available_stock_kg ?? newProd.available_stock_bags ?? 0,
        stockBags: newProd.available_stock_kg ?? newProd.available_stock_bags ?? 0,
        germinationRate: newProd.germination_rate || '85% Min',
        purity: newProd.purity || '98% Min',
        maturityDays: newProd.maturity_days || 'N/A',
        cropSeason: newProd.crop_season || 'All Season',
        availability: newProd.availability || 'In Stock',
        description: newProd.description || '',
        keyFeatures: ['High Yield'],
        resistance: newProd.resistance_traits || 'General',
        packageSizes: newProd.package_sizes ? newProd.package_sizes.split(',').map((s: string) => s.trim()) : ['100g', '500g', '1kg']
      };
      setProducts(prev => [mappedProd as SeedProduct, ...prev]);
    } catch (err) {
      console.error('Failed to create product:', err);
      throw err;
    }
  };

  const removeEmployee = async (id: string | number) => {
    try {
      // The id in state is likely formatted as 'emp-X' or a number. We need the numeric ID.
      const numId = typeof id === 'string' ? parseInt(id.replace('emp-', '')) : id;
      await api.removeEmployee(numId);
      setEmployees(prev => prev.filter(e => e.id !== id && e.id !== numId));
    } catch (err) {
      console.error('Failed to remove employee:', err);
      throw err;
    }
  };

  const removeShopOwner = async (id: string | number) => {
    try {
      const numId = typeof id === 'string' ? parseInt(id.replace('shop-', '')) : id;
      await api.removeShopOwner(numId);
      setShops(prev => prev.filter(s => s.id !== id && s.id !== numId));
    } catch (err) {
      console.error('Failed to remove shop owner:', err);
      throw err;
    }
  };

  const removeProduct = async (id: string | number) => {
    try {
      const numId = typeof id === 'string' ? parseInt(id.replace('prod-', '')) : id;
      await api.removeProduct(numId);
      setProducts(prev => prev.filter(p => p.id !== id && p.id !== numId));
    } catch (err) {
      console.error('Failed to remove product:', err);
      throw err;
    }
  };

  return (
    <AppStateContext.Provider
      value={{
        currentRole,
        setCurrentRole,
        deviceView,
        setDeviceView,
        isAuthenticated,
        authenticatedUser,
        canSwitchRoles,
        handleRequestOtp,
        handleVerifyOtp,
        handleLoginPassword,
        handleLoginFirebase,
        handleLogout,
        isAdminAuthenticated,
        adminPhone,
        loginAdmin,
        logoutAdmin,
        products,
        employees,
        shops,
        orders,
        shipments,
        visits,
        leaves,
        cart,
        addToCart,
        removeFromCart,
        updateCartQuantity,
        clearCart,
        placeOrder,
        updateOrderStatus,
        assignOrderExecutive,
        approveLeave,
        rejectLeave,
        uploadVisitPhoto,
        whatsappAlert,
        dismissWhatsAppAlert,
        triggerWhatsAppAlert,
        activeTab,
        setActiveTab,
        selectedOrderForTrack,
        setSelectedOrderForTrack,
        addEmployee,
        addShop,
        updateShop,
        assignShopToExecutive,
        addProduct,
        removeEmployee,
        removeShopOwner,
        removeProduct,
      }}
    >
      {children}
    </AppStateContext.Provider>
  );
};

export const useAppState = () => {
  const context = useContext(AppStateContext);
  if (!context) {
    throw new Error('useAppState must be used within an AppStateProvider');
  }
  return context;
};
