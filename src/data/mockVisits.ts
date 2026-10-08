export interface FieldVisit {
  id: string;
  executiveId: string;
  executiveName: string;
  shopId: string;
  shopName: string;
  shopAddress: string;
  shopLocation?: string;
  shopOwnerName?: string;
  shopTerritory?: string;
  shopCity?: string;
  shopPhotoUrlProfile?: string;
  shopOwnerPhotoUrl?: string;
  shopContact: string;
  distanceKm: number;
  scheduledTime: string;
  visitedAt?: string;
  status: 'Visited' | 'Pending' | 'Missed';
  purpose: 'Stock Audit & Order Booking' | 'Payment & Outstanding Followup' | 'New Seed Variety Demo' | 'Routine Relationship Visit';
  notes?: string;
  photoUrl?: string;
  photoLat?: number;
  photoLng?: number;
  orderCollectedNumber?: string;
  bagsOrdered?: number;
  farmerFeedback?: string;
}

export const MOCK_VISITS: FieldVisit[] = [
  {
    id: 'visit-01',
    executiveId: 'emp-1',
    executiveName: 'Ramesh Kumar',
    shopId: 'shop-02',
    shopName: 'Sri Sai Agencies',
    shopAddress: 'Near Clock Tower, Main Road, Nuzvid',
    shopContact: '+91 98765 43211',
    distanceKm: 1.2,
    scheduledTime: '09:30 AM',
    visitedAt: '09:40 AM',
    status: 'Visited',
    purpose: 'Stock Audit & Order Booking',
    notes: 'Shop owner expressed huge demand for YHS-678 Maize ahead of monsoon showers. Stock audited: 420 bags intact.',
    photoUrl: '/seeds/seed_04.jpeg',
    orderCollectedNumber: 'ORD-1024',
    bagsOrdered: 35,
    farmerFeedback: 'Farmers requesting larger 25kg packaging for commercial growers'
  },
  {
    id: 'visit-02',
    executiveId: 'emp-2',
    executiveName: 'Suresh Babu',
    shopId: 'shop-01',
    shopName: 'ABC Seeds & Fertilizers',
    shopAddress: 'Shop No. 14, Agricultural Market Complex, Guntur',
    shopContact: '+91 98480 23456',
    distanceKm: 2.8,
    scheduledTime: '10:00 AM',
    visitedAt: '10:15 AM',
    status: 'Visited',
    purpose: 'New Seed Variety Demo',
    notes: 'Demonstrated Krishna-5 Chilli sample packets. High interest in disease tolerance. Placed fresh bulk order.',
    photoUrl: '/seeds/seed_12.jpeg',
    orderCollectedNumber: 'ORD-1025',
    bagsOrdered: 25,
    farmerFeedback: 'Positive feedback on germination rates of previous batch'
  },
  {
    id: 'visit-03',
    executiveId: 'emp-3',
    executiveName: 'Vikram Reddy',
    shopId: 'shop-04',
    shopName: 'RK Agro Center',
    shopAddress: 'Bose Road, Tenali',
    shopContact: '+91 98765 43213',
    distanceKm: 0.9,
    scheduledTime: '11:30 AM',
    visitedAt: '11:45 AM',
    status: 'Visited',
    purpose: 'Stock Audit & Order Booking',
    notes: 'Stock verified for YH-222 Bhendi and Black Gram. Consignment delivered yesterday is in good condition.',
    photoUrl: '/seeds/seed_07.jpeg',
    orderCollectedNumber: 'ORD-1022',
    bagsOrdered: 25,
    farmerFeedback: 'Paddy growers asking for YHS-9303'
  },
  {
    id: 'visit-04',
    executiveId: 'emp-1',
    executiveName: 'Ramesh Kumar',
    shopId: 'shop-07',
    shopName: 'Srinivasa Traders',
    shopAddress: 'Powerpet Main Road, Eluru',
    shopContact: '+91 98765 43216',
    distanceKm: 4.5,
    scheduledTime: '02:30 PM',
    visitedAt: '02:40 PM',
    status: 'Visited',
    purpose: 'Stock Audit & Order Booking',
    notes: 'Reviewing current shelf space and marketing posters display.'
  },
  {
    id: 'visit-05',
    executiveId: 'emp-2',
    executiveName: 'Suresh Babu',
    shopId: 'shop-03',
    shopName: 'Green Agri Seeds',
    shopAddress: 'Old Club Road, Kothapet, Guntur',
    shopContact: '+91 98765 43212',
    distanceKm: 3.2,
    scheduledTime: '04:00 PM',
    status: 'Pending',
    purpose: 'Routine Relationship Visit',
    notes: 'Verify order dispatch status and take retailer feedback.'
  }
];
