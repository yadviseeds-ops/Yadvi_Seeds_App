export interface Shop {
  id: string;
  name: string;
  ownerName: string;
  phone: string;
  email: string;
  location: string;
  address: string;
  lat: number;
  lng: number;
  status: 'Active' | 'Inactive';
  gstin: string;
  seedLicenseNo: string;
  assignedExecutiveId: string;
  assignedExecutiveName: string;
  totalOrdersCount: number;
  totalKgReceived?: number;
  pendingDeliveryKg?: number;
  openingStockKg?: number;
  currentStockKg?: number;
  totalBagsReceived?: number;
  pendingDeliveryBags?: number;
  openingStockBags?: number;
  currentStockBags?: number;
  lastVisitDate: string;
  primaryCropDemand: string;
}

export const MOCK_SHOPS: Shop[] = [
  {
    id: 'shop-01',
    name: 'ABC Seeds & Fertilizers',
    ownerName: 'M. Venkat Rao',
    phone: '+91 98480 23456',
    email: 'abcseeds.guntur@gmail.com',
    location: 'Guntur Market Yard',
    address: 'Shop No. 14, Agricultural Market Complex, Guntur, AP - 522004',
    lat: 16.3050,
    lng: 80.4410,
    status: 'Active',
    gstin: '37AABCU9603R1ZM',
    seedLicenseNo: 'AP/GNT/SEED/2022/441',
    assignedExecutiveId: 'emp-2',
    assignedExecutiveName: 'Suresh Babu',
    totalOrdersCount: 28,
    totalKgReceived: 820, totalBagsReceived: 820,
    pendingDeliveryKg: 45, pendingDeliveryBags: 45,
    lastVisitDate: '2026-09-21',
    openingStockKg: 450, openingStockBags: 450,
    currentStockKg: 380, currentStockBags: 380,
    primaryCropDemand: 'Chilli, Cotton, Okra'
  },
  {
    id: 'shop-02',
    name: 'Sri Sai Agencies',
    ownerName: 'K. Sai Ram',
    phone: '+91 98765 43211',
    email: 'srisai.nuzvid@gmail.com',
    location: 'Nuzvid',
    address: 'Near Clock Tower, Main Road, Nuzvid, Krishna Dt, AP - 521201',
    lat: 16.7865,
    lng: 80.8490,
    status: 'Active',
    gstin: '37ABCPR8812K1Z9',
    seedLicenseNo: 'AP/KRI/SEED/2021/119',
    assignedExecutiveId: 'emp-1',
    assignedExecutiveName: 'Ramesh Kumar',
    totalOrdersCount: 34,
    totalKgReceived: 1250, totalBagsReceived: 1250,
    pendingDeliveryKg: 60, pendingDeliveryBags: 60,
    lastVisitDate: '2026-09-22',
    openingStockKg: 500, openingStockBags: 500,
    currentStockKg: 420, currentStockBags: 420,
    primaryCropDemand: 'Maize, Pulses, Okra'
  },
  {
    id: 'shop-03',
    name: 'Green Agri Seeds',
    ownerName: 'P. Subba Rao',
    phone: '+91 98765 43212',
    email: 'greenagri.guntur@gmail.com',
    location: 'Guntur',
    address: 'Old Club Road, Kothapet, Guntur, AP - 522001',
    lat: 16.3110,
    lng: 80.4350,
    status: 'Active',
    gstin: '37DEFGH4412L1Z2',
    seedLicenseNo: 'AP/GNT/SEED/2020/552',
    assignedExecutiveId: 'emp-2',
    assignedExecutiveName: 'Suresh Babu',
    totalOrdersCount: 19,
    totalKgReceived: 690, totalBagsReceived: 690,
    pendingDeliveryKg: 20, pendingDeliveryBags: 20,
    lastVisitDate: '2026-09-20',
    openingStockKg: 300, openingStockBags: 300,
    currentStockKg: 180, currentStockBags: 180,
    primaryCropDemand: 'Chilli, Tomato, Bhendi'
  },
  {
    id: 'shop-04',
    name: 'RK Agro Center',
    ownerName: 'R. Krishna Murthy',
    phone: '+91 98765 43213',
    email: 'rkagro.tenali@gmail.com',
    location: 'Tenali',
    address: 'Bose Road, Near Rythu Bazar, Tenali, Guntur Dt, AP - 522201',
    lat: 16.2415,
    lng: 80.6430,
    status: 'Active',
    gstin: '37IJKLM7731M1Z8',
    seedLicenseNo: 'AP/GNT/SEED/2021/334',
    assignedExecutiveId: 'emp-3',
    assignedExecutiveName: 'Vikram Reddy',
    totalOrdersCount: 22,
    totalKgReceived: 780, totalBagsReceived: 780,
    pendingDeliveryKg: 35, pendingDeliveryBags: 35,
    lastVisitDate: '2026-09-22',
    openingStockKg: 400, openingStockBags: 400,
    currentStockKg: 210, currentStockBags: 210,
    primaryCropDemand: 'Paddy, Black Gram, Maize'
  },
  {
    id: 'shop-05',
    name: 'Venkateshwara Seeds',
    ownerName: 'V. Srinivasa Rao',
    phone: '+91 98765 43214',
    email: 'venkateshwaraseeds.vja@gmail.com',
    location: 'Vijayawada',
    address: 'Governorpet 5th Cross, Vijayawada, Krishna Dt, AP - 520002',
    lat: 16.5120,
    lng: 80.6380,
    status: 'Active',
    gstin: '37NOPQR1192N1Z4',
    seedLicenseNo: 'AP/KRI/SEED/2023/812',
    assignedExecutiveId: 'emp-4',
    assignedExecutiveName: 'Mahesh Yadav',
    totalOrdersCount: 41,
    totalKgReceived: 1600, totalBagsReceived: 1600,
    pendingDeliveryKg: 80, pendingDeliveryBags: 80,
    lastVisitDate: '2026-09-18',
    openingStockKg: 200, openingStockBags: 200,
    currentStockKg: 80, currentStockBags: 80,
    primaryCropDemand: 'Hybrid Chilli, Dolichos'
  },
  {
    id: 'shop-06',
    name: 'Bharat Seeds Store',
    ownerName: 'B. Appa Rao',
    phone: '+91 98765 43215',
    email: 'bharatseeds.nsp@gmail.com',
    location: 'Narasaraopet',
    address: 'Station Road, Narasaraopet, Palnadu Dt, AP - 522601',
    lat: 16.2340,
    lng: 80.0510,
    status: 'Inactive',
    gstin: '37STUVW8821P1Z7',
    seedLicenseNo: 'AP/PAL/SEED/2019/092',
    assignedExecutiveId: 'emp-2',
    assignedExecutiveName: 'Suresh Babu',
    totalOrdersCount: 12,
    totalKgReceived: 420, totalBagsReceived: 420,
    pendingDeliveryKg: 0, pendingDeliveryBags: 0,
    lastVisitDate: '2026-08-30',
    openingStockKg: 600, openingStockBags: 600,
    currentStockKg: 420, currentStockBags: 420,
    primaryCropDemand: 'Groundnut, Cotton'
  },
  {
    id: 'shop-07',
    name: 'Srinivasa Traders',
    ownerName: 'S. Satyanarayana',
    phone: '+91 98765 43216',
    email: 'srinivasatraders.eluru@gmail.com',
    location: 'Eluru',
    address: 'Powerpet Main Road, Eluru, West Godavari Dt, AP - 534002',
    lat: 16.7150,
    lng: 81.1010,
    status: 'Active',
    gstin: '37WXYZA4419Q1Z1',
    seedLicenseNo: 'AP/WG/SEED/2022/671',
    assignedExecutiveId: 'emp-7',
    assignedExecutiveName: 'Anil Varma',
    totalOrdersCount: 30,
    totalKgReceived: 980, totalBagsReceived: 980,
    pendingDeliveryKg: 50, pendingDeliveryBags: 50,
    lastVisitDate: '2026-09-21',
    openingStockKg: 350, openingStockBags: 350,
    currentStockKg: 240, currentStockBags: 240,
    primaryCropDemand: 'Paddy, Maize, Black Gram'
  }
];
