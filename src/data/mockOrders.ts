export type OrderStatus =
  | 'New'
  | 'Confirmed'
  | 'Processing'
  | 'Packed'
  | 'Dispatched'
  | 'In Transit'
  | 'Delivered'
  | 'Cancelled';

export interface OrderItem {
  productId: string;
  productName: string;
  varietyType: string;
  sku: string;
  image: string;
  packageSize: string;
  quantity: number;
  unit: 'g' | 'kg';
}

export interface Order {
  id: string;
  orderNumber: string;
  shopId: string;
  shopName: string;
  ownerName: string;
  shopLocation: string;
  contactPhone: string;
  deliveryAddress: string;
  orderDate: string;
  items: OrderItem[];
  totalQuantityKg: number;
  totalItemsCount: number;
  status: OrderStatus;
  assignedExecutiveId: string;
  assignedExecutiveName: string;
  lrNumber?: string;
  transporterName?: string;
  dispatchDate?: string;
  expectedDeliveryDate?: string;
  deliveryNotes?: string;
  source: 'Shop Owner App' | 'Field Executive' | 'Admin Portal';
}

export const INITIAL_ORDERS: Order[] = [
  {
    id: 'ord-1025',
    orderNumber: 'ORD-1025',
    shopId: 'shop-01',
    shopName: 'ABC Seeds & Fertilizers',
    ownerName: 'M. Venkat Rao',
    shopLocation: 'Guntur Market Yard',
    contactPhone: '+91 98480 23456',
    deliveryAddress: 'Shop No. 14, Agricultural Market Complex, Guntur, AP - 522004',
    orderDate: '2026-09-22 10:24 AM',
    items: [
      {
        productId: 'prod-01',
        productName: 'Krishna-5 F1 Hybrid Chilli',
        varietyType: 'F1 Hybrid Chilli',
        sku: 'YHS-CHL-K5',
        image: '/seeds/seed_12.jpeg',
        packageSize: '100g Pouch',
        quantity: 8, unit: 'kg'
      },
      {
        productId: 'prod-03',
        productName: 'YH-222 F1 Hybrid Okra',
        varietyType: 'F1 Hybrid Bhendi',
        sku: 'YHS-OKR-222',
        image: '/seeds/seed_07.jpeg',
        packageSize: '500g Pouch',
        quantity: 6, unit: 'kg'
      },
      {
        productId: 'prod-04',
        productName: 'Leon F1 Hybrid Okra',
        varietyType: 'F1 Hybrid Bhendi',
        sku: 'YHS-OKR-LEON',
        image: '/seeds/seed_10.jpeg',
        packageSize: '500g Pouch',
        quantity: 4, unit: 'kg'
      },
      {
        productId: 'prod-05',
        productName: 'Lakshmi Research Dolichos',
        varietyType: 'Research Dolichos Bean',
        sku: 'YHS-DOL-LAK',
        image: '/seeds/seed_04.jpeg',
        packageSize: '1kg Pack',
        quantity: 4, unit: 'kg'
      },
      {
        productId: 'prod-06',
        productName: 'YHS Special Black Gram (మినుము)',
        varietyType: 'High Yielding Pulse Seed',
        sku: 'YHS-PLS-BG01',
        image: '/seeds/seed_01.jpeg',
        packageSize: '5kg Pack',
        quantity: 3, unit: 'kg'
      }
    ],
    totalQuantityKg: 25,
    totalItemsCount: 5,
    status: 'New',
    assignedExecutiveId: 'emp-2',
    assignedExecutiveName: 'Suresh Babu',
    deliveryNotes: 'Urgent delivery for upcoming sowing window',
    source: 'Shop Owner App'
  },
  {
    id: 'ord-1024',
    orderNumber: 'ORD-1024',
    shopId: 'shop-02',
    shopName: 'Sri Sai Agencies',
    ownerName: 'K. Sai Ram',
    shopLocation: 'Nuzvid',
    contactPhone: '+91 98765 43211',
    deliveryAddress: 'Near Clock Tower, Main Road, Nuzvid, Krishna Dt, AP - 521201',
    orderDate: '2026-09-22 09:15 AM',
    items: [
      {
        productId: 'prod-07',
        productName: 'YHS-678 High Yield Maize',
        varietyType: 'Single Cross Hybrid Corn',
        sku: 'YHS-CORN-678',
        image: '/seeds/seed_04.jpeg',
        packageSize: '4kg Pack',
        quantity: 15, unit: 'kg'
      },
      {
        productId: 'prod-08',
        productName: 'YHS-9303 Super Fine Paddy',
        varietyType: 'Hybrid Rice Seed',
        sku: 'YHS-RICE-9303',
        image: '/seeds/seed_16.jpeg',
        packageSize: '10kg Pack',
        quantity: 20, unit: 'kg'
      }
    ],
    totalQuantityKg: 35,
    totalItemsCount: 2,
    status: 'In Transit',
    assignedExecutiveId: 'emp-1',
    assignedExecutiveName: 'Ramesh Kumar',
    lrNumber: 'LR-NVT-99214',
    transporterName: 'Navata Road Transport',
    dispatchDate: '2026-09-22 11:30 AM',
    expectedDeliveryDate: '2026-09-23',
    deliveryNotes: 'Handle moisture-proof seed packs with care',
    source: 'Field Executive'
  },
  {
    id: 'ord-1023',
    orderNumber: 'ORD-1023',
    shopId: 'shop-03',
    shopName: 'Green Agri Seeds',
    ownerName: 'P. Subba Rao',
    shopLocation: 'Guntur',
    contactPhone: '+91 98765 43212',
    deliveryAddress: 'Old Club Road, Kothapet, Guntur, AP - 522001',
    orderDate: '2026-09-21 04:40 PM',
    items: [
      {
        productId: 'prod-01',
        productName: 'Krishna-5 F1 Hybrid Chilli',
        varietyType: 'F1 Hybrid Chilli',
        sku: 'YHS-CHL-K5',
        image: '/seeds/seed_12.jpeg',
        packageSize: '50g Pouch',
        quantity: 12, unit: 'kg'
      },
      {
        productId: 'prod-11',
        productName: 'Swarna F1 Hybrid Tomato',
        varietyType: 'Determinate Red Tomato',
        sku: 'YHS-TOM-SW',
        image: '/seeds/seed_28.jpeg',
        packageSize: '50g Pouch',
        quantity: 8, unit: 'kg'
      }
    ],
    totalQuantityKg: 20,
    totalItemsCount: 2,
    status: 'Packed',
    assignedExecutiveId: 'emp-2',
    assignedExecutiveName: 'Suresh Babu',
    lrNumber: 'LR-VRL-44120',
    transporterName: 'VRL Logistics',
    dispatchDate: '2026-09-22 02:00 PM',
    expectedDeliveryDate: '2026-09-23',
    source: 'Shop Owner App'
  },
  {
    id: 'ord-1022',
    orderNumber: 'ORD-1022',
    shopId: 'shop-04',
    shopName: 'RK Agro Center',
    ownerName: 'R. Krishna Murthy',
    shopLocation: 'Tenali',
    contactPhone: '+91 98765 43213',
    deliveryAddress: 'Bose Road, Near Rythu Bazar, Tenali, Guntur Dt, AP - 522201',
    orderDate: '2026-09-21 11:10 AM',
    items: [
      {
        productId: 'prod-03',
        productName: 'YH-222 F1 Hybrid Okra',
        varietyType: 'F1 Hybrid Bhendi',
        sku: 'YHS-OKR-222',
        image: '/seeds/seed_07.jpeg',
        packageSize: '250g Pouch',
        quantity: 10, unit: 'kg'
      },
      {
        productId: 'prod-06',
        productName: 'YHS Special Black Gram (మినుము)',
        varietyType: 'High Yielding Pulse Seed',
        sku: 'YHS-PLS-BG01',
        image: '/seeds/seed_01.jpeg',
        packageSize: '5kg Pack',
        quantity: 15, unit: 'kg'
      }
    ],
    totalQuantityKg: 25,
    totalItemsCount: 2,
    status: 'Delivered',
    assignedExecutiveId: 'emp-3',
    assignedExecutiveName: 'Vikram Reddy',
    lrNumber: 'LR-KRN-77301',
    transporterName: 'Kranti Road Transport',
    dispatchDate: '2026-09-21 02:00 PM',
    expectedDeliveryDate: '2026-09-22',
    source: 'Field Executive'
  },
  {
    id: 'ord-1021',
    orderNumber: 'ORD-1021',
    shopId: 'shop-05',
    shopName: 'Venkateshwara Seeds',
    ownerName: 'V. Srinivasa Rao',
    shopLocation: 'Vijayawada',
    contactPhone: '+91 98765 43214',
    deliveryAddress: 'Governorpet 5th Cross, Vijayawada, Krishna Dt, AP - 520002',
    orderDate: '2026-09-20 03:20 PM',
    items: [
      {
        productId: 'prod-02',
        productName: 'Divya-27 F1 Hybrid Chilli',
        varietyType: 'F1 Hybrid Chilli',
        sku: 'YHS-CHL-D27',
        image: '/seeds/seed_21.jpeg',
        packageSize: '100g Pouch',
        quantity: 18, unit: 'kg'
      },
      {
        productId: 'prod-05',
        productName: 'Lakshmi Research Dolichos',
        varietyType: 'Research Dolichos Bean',
        sku: 'YHS-DOL-LAK',
        image: '/seeds/seed_02.jpeg',
        packageSize: '5kg Pack',
        quantity: 14, unit: 'kg'
      }
    ],
    totalQuantityKg: 32,
    totalItemsCount: 2,
    status: 'Delivered',
    assignedExecutiveId: 'emp-4',
    assignedExecutiveName: 'Mahesh Yadav',
    lrNumber: 'LR-NVT-88402',
    transporterName: 'Navata Road Transport',
    dispatchDate: '2026-09-20 05:00 PM',
    expectedDeliveryDate: '2026-09-21',
    source: 'Shop Owner App'
  }
];

export interface ShipmentTracking {
  lrNumber: string;
  orderNumber: string;
  shopName: string;
  shopLocation: string;
  transporter: string;
  driverName: string;
  driverPhone: string;
  vehicleNumber: string;
  dispatchDate: string;
  estimatedDelivery: string;
  status: 'Dispatched' | 'In Transit' | 'Out for Delivery' | 'Delivered';
  totalBags: number;
  timeline: {
    title: string;
    location: string;
    timestamp: string;
    completed: boolean;
    current?: boolean;
    description: string;
  }[];
}

export const INITIAL_SHIPMENTS: ShipmentTracking[] = [
  {
    lrNumber: 'LR-NVT-99214',
    orderNumber: 'ORD-1024',
    shopName: 'Sri Sai Agencies',
    shopLocation: 'Nuzvid',
    transporter: 'Navata Road Transport',
    driverName: 'K. Narayana',
    driverPhone: '+91 94401 55219',
    vehicleNumber: 'AP 16 TE 4492',
    dispatchDate: '2026-09-22 11:30 AM',
    estimatedDelivery: '2026-09-23 03:00 PM',
    status: 'In Transit',
    totalBags: 35,
    timeline: [
      {
        title: 'Dispatched from Central Warehouse',
        location: 'Yadvi Processing Plant, Gannavaram Hub',
        timestamp: '2026-09-22 11:30 AM',
        completed: true,
        description: 'Loaded onto Navata vehicle AP 16 TE 4492 with tamper-proof seed seal'
      },
      {
        title: 'Arrived at Transit Hub',
        location: 'Vijayawada Regional Transshipment Center',
        timestamp: '2026-09-22 02:45 PM',
        completed: true,
        description: 'Quality barcode scan completed. Outbound sorting underway.'
      },
      {
        title: 'In Transit to Nuzvid Destination',
        location: 'Nuzvid Highway Corridor',
        timestamp: '2026-09-22 05:10 PM',
        completed: true,
        current: true,
        description: 'Vehicle en route. Driver contact: +91 94401 55219.'
      },
      {
        title: 'Out for Final Delivery',
        location: 'Nuzvid Local Yard',
        timestamp: 'Tomorrow Morning',
        completed: false,
        description: 'Scheduled for direct delivery at Sri Sai Agencies shop front.'
      },
      {
        title: 'Delivered & LR Signed',
        location: 'Sri Sai Agencies, Nuzvid',
        timestamp: 'Pending Delivery',
        completed: false,
        description: 'Digital delivery acknowledgement with OTP confirmation.'
      }
    ]
  },
  {
    lrNumber: 'LR-VRL-44120',
    orderNumber: 'ORD-1023',
    shopName: 'Green Agri Seeds',
    shopLocation: 'Guntur',
    transporter: 'VRL Logistics',
    driverName: 'S. Ramu',
    driverPhone: '+91 97033 11842',
    vehicleNumber: 'KA 25 AB 9981',
    dispatchDate: '2026-09-22 02:00 PM',
    estimatedDelivery: '2026-09-23 11:00 AM',
    status: 'Dispatched',
    totalBags: 20,
    timeline: [
      {
        title: 'Dispatched from Central Warehouse',
        location: 'Yadvi Processing Plant, Gannavaram Hub',
        timestamp: '2026-09-22 02:00 PM',
        completed: true,
        current: true,
        description: 'Consignment booked under VRL Docket #44120'
      },
      {
        title: 'Hub Processing',
        location: 'Guntur VRL Branch Hub',
        timestamp: 'Tonight 10:00 PM',
        completed: false,
        description: 'Consignment sorting for local delivery'
      },
      {
        title: 'Out for Delivery',
        location: 'Guntur Kothapet Division',
        timestamp: 'Tomorrow 09:30 AM',
        completed: false,
        description: 'Local mini-truck dispatch'
      },
      {
        title: 'Delivered',
        location: 'Green Agri Seeds, Guntur',
        timestamp: 'Expected 2026-09-23 11:00 AM',
        completed: false,
        description: 'Consignment handover to shop owner'
      }
    ]
  }
];
