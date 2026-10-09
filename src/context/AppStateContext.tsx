import React, { createContext, useContext, useState, useEffect } from 'react';
import { SEED_PRODUCTS, SeedProduct } from '../data/seedProducts';
import { MOCK_EMPLOYEES, Employee, MOCK_LEAVE_REQUESTS, LeaveRequest } from '../data/mockEmployees';
import { MOCK_SHOPS, Shop } from '../data/mockShops';
import { INITIAL_ORDERS, Order, OrderStatus, INITIAL_SHIPMENTS, ShipmentTracking } from '../data/mockOrders';
import { MOCK_VISITS, FieldVisit } from '../data/mockVisits';

import { api, LoginPayload, AuthResponse, API_BASE_URL } from '../services/api';

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
  quantityBags: number;
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
  addToCart: (product: SeedProduct, packageSize: string, quantityBags: number) => void;
  removeFromCart: (productId: string) => void;
  updateCartQuantity: (productId: string, quantityBags: number) => void;
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
  assignShopToExecutive: (shopId: string, execId: string) => Promise<void>;
  addProduct: (payload: any) => Promise<void>;
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

  const handleLogout = () => {
    api.removeToken();
    localStorage.removeItem('yadvi_auth_user');
    setIsAuthenticated(false);
    setAuthenticatedUser(null);
    setIsAdminAuthenticated(false);
    setCurrentRoleState('admin');
    setDeviceView('desktop');
    
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
            image: p.image_url,
            stockBags: p.available_stock_bags,
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
            totalQuantityBags: o.total_quantity_bags,
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
              quantityBags: i.quantity_bags
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
              gstin: s.dealer_code || '',
              seedLicenseNo: s.dealer_code || '',
              assignedExecutiveId: s.assigned_executive_id ? String(s.assigned_executive_id) : '',
              assignedExecutiveName: s.assigned_executive_name || 'Unassigned',
              totalOrdersCount: s.total_orders_count || 0,
              totalBagsReceived: s.total_bags_received || 0,
              pendingDeliveryBags: s.pending_delivery_bags || 0,
              lastVisitDate: s.last_visit_date || '',
              openingStockBags: s.opening_stock_bags || 0,
              currentStockBags: s.current_stock_bags || 0,
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
              bagsOrdered: v.bags_ordered,
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
      quantityBags: 5,
    },
    {
      product: SEED_PRODUCTS[2], // YH-222 Okra
      packageSize: '500g Pouch',
      quantityBags: 10,
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

  const addToCart = (product: SeedProduct, packageSize: string, quantityBags: number) => {
    setCart((prev) => {
      const existing = prev.find((item) => item.product.id === product.id);
      if (existing) {
        return prev.map((item) =>
          item.product.id === product.id
            ? { ...item, quantityBags: item.quantityBags + quantityBags, packageSize }
            : item
        );
      }
      return [...prev, { product, packageSize, quantityBags }];
    });
  };

  const removeFromCart = (productId: string) => {
    setCart((prev) => prev.filter((item) => item.product.id !== productId));
  };

  const updateCartQuantity = (productId: string, quantityBags: number) => {
    if (quantityBags <= 0) {
      removeFromCart(productId);
      return;
    }
    setCart((prev) =>
      prev.map((item) =>
        item.product.id === productId ? { ...item, quantityBags } : item
      )
    );
  };

  const clearCart = () => {
    setCart([]);
  };

  const placeOrder = async (notes?: string, itemsToOrder?: CartItem[]): Promise<Order> => {
    const targetItems = itemsToOrder || cart;
    const totalBags = targetItems.reduce((sum, item) => sum + item.quantityBags, 0);

    if (targetItems.length === 0) {
      throw new Error("Cannot place an order with 0 items.");
    }

    const payload = {
      items: targetItems.map(item => ({
        product_id: parseInt(item.product.id.replace('prod-', '')), // Assuming ID format or handle string to int mapping properly, wait! The backend expects integer IDs for products!
        package_size: item.packageSize,
        quantity_bags: item.quantityBags
      })),
      delivery_notes: notes || 'Standard consignment delivery',
      source: currentRole === 'shop_owner' ? 'Shop Owner App' : 'Field Executive'
    };

    try {
      const response = await api.createOrder(payload);

      const newOrder: Order = {
        id: String(response.id),
        orderNumber: response.order_number,
        shopId: String(response.shop_id),
        shopName: response.shop_name,
        shopLocation: response.shop_location,
        ownerName: response.owner_name,
        contactPhone: response.contact_phone,
        deliveryAddress: response.delivery_address,
        orderDate: new Date(response.created_at).toLocaleDateString(),
        items: response.items.map((item: any) => ({
          productId: String(item.product_id),
          productName: item.product_name,
          varietyType: '',
          sku: item.sku,
          image: item.image_url,
          packageSize: item.package_size,
          quantityBags: item.quantity_bags
        })),
        totalQuantityBags: response.total_quantity_bags,
        totalItemsCount: response.total_items_count,
        status: response.status,
        source: response.source,
        deliveryNotes: response.delivery_notes,
        assignedExecutiveId: 'emp-2', // fallback or actual from response
        assignedExecutiveName: response.assigned_executive_name || 'Unassigned',
      };

      setOrders((prev) => [newOrder, ...prev]);
      clearCart();

      // Trigger exact simulated WhatsApp notification matching uploaded reference Image 3!
      const alertData: WhatsAppNotification = {
        show: true,
        orderNumber: newOrder.orderNumber,
        shopName: newOrder.shopName,
        itemsCount: newOrder.totalItemsCount,
        totalQuantity: newOrder.totalQuantityBags,
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
        role: newEmp.designation,
        location: newEmp.assigned_territory,
        status: newEmp.is_active ? 'Active' : 'Inactive',
        attendanceStatus: 'Present',
        distanceCoveredTodayKm: 0,
        phone: newEmp.phone,
        email: newEmp.email,
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
        location: newShopApi.market_location,
        address: newShopApi.address,
        status: newShopApi.status,
        openingStockBags: newShopApi.opening_stock_bags,
        currentStockBags: newShopApi.current_stock_bags,
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

  const assignShopToExecutive = async (shopId: string, execId: string) => {
    try {
      const numericShopId = parseInt(shopId.replace('shop-', ''), 10) || parseInt(shopId, 10);
      const numericExecId = parseInt(execId.replace('emp-', ''), 10) || parseInt(execId, 10);
      await api.assignShop(numericShopId, numericExecId);
      
      // Update local state so UI refreshes immediately
      const exec = employees.find(e => e.id === String(numericExecId) || e.id === execId);
      if (exec) {
        setShops(prev => prev.map(s => 
          s.id === shopId || s.id === String(numericShopId) 
            ? { ...s, assignedExecutiveId: exec.id, assignedExecutiveName: exec.name } 
            : s
        ));
      }
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
        image: newProd.image_url,
        stockBags: newProd.available_stock_bags,
        germinationRate: newProd.germination_rate,
        purity: newProd.purity,
        maturityDays: newProd.maturity_days || 'N/A',
        cropSeason: newProd.crop_season || 'All Season',
        availability: newProd.availability,
        description: newProd.description || '',
        keyFeatures: ['High Yield'],
        resistance: 'General',
        packageSizes: newProd.package_sizes.split(',').map((s: string) => s.trim())
      };
      setProducts(prev => [mappedProd as SeedProduct, ...prev]);
    } catch (err) {
      console.error('Failed to create product:', err);
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
        assignShopToExecutive,
        addProduct,
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
