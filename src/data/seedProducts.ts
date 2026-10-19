export interface SeedProduct {
  id: string;
  name: string;
  varietyType: string;
  sku: string;
  category: 'Chilli' | 'Okra' | 'Dolichos' | 'Pulses' | 'Vegetables' | 'Field Crops' | 'Flowers';
  image: string;
  stockKg: number;
  stockBags?: number;
  packageSizes: string[];
  germinationRate: string;
  purity: string;
  maturityDays: string;
  cropSeason: string;
  availability: 'In Stock' | 'Limited Stock' | 'Pre-Booking';
  description: string;
  keyFeatures: string[];
  resistance: string;
}

export const SEED_PRODUCTS: SeedProduct[] = [
  {
    "id": "prod-01",
    "name": "Krishna-5 F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-K5",
    "category": "Chilli",
    "image": "/seeds/seed_12.jpeg",
    "stockKg": 1420,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 70 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "High-yielding pungent hybrid chilli with erect plant habit, deep glossy red fruits, and outstanding heat tolerance.",
    "keyFeatures": [
      "Glossy dark green to deep red fruits",
      "High pungency with firm skin",
      "Prolific bearer with continuous flushes",
      "Outstanding heat tolerance"
    ],
    "resistance": "High tolerance to Leaf Curl Virus (LCV) & Thrips"
  },
  {
    "id": "prod-02",
    "name": "YH-222 F1 Hybrid Okra",
    "varietyType": "F1 Hybrid Bhendi",
    "sku": "YHS-OKR-222",
    "category": "Okra",
    "image": "/seeds/seed_07.jpeg",
    "stockKg": 2150,
    "packageSizes": [
      "100g Pouch",
      "250g Pouch",
      "500g Pouch",
      "1kg Tin"
    ],
    "germinationRate": "90% Min",
    "purity": "99% Min",
    "maturityDays": "42 - 45 Days",
    "cropSeason": "Summer & Kharif",
    "availability": "In Stock",
    "description": "Premium dark-green 5-ridged tender okra with short internodes and heavy branching.",
    "keyFeatures": [
      "Lush dark green 5-ridged pods",
      "Short internodal spacing",
      "Tender, non-spiny, easily hand-picked",
      "Excellent shelf life in transit"
    ],
    "resistance": "Intermediate resistance to YVMV and Enation Leaf Curl Virus (ELCV)"
  },
  {
    "id": "prod-03",
    "name": "Lakshmi Research Dolichos",
    "varietyType": "Research Dolichos Bean",
    "sku": "YHS-DOL-LAK",
    "category": "Dolichos",
    "image": "/seeds/seed_04.jpeg",
    "stockKg": 1200,
    "packageSizes": [
      "500g Pack",
      "1kg Pack",
      "5kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "75 - 85 Days",
    "cropSeason": "Rabi & Late Kharif",
    "availability": "In Stock",
    "description": "Famous pole type Dolichos (Chikkudu) renowned for broad light green fleshy aromatic pods.",
    "keyFeatures": [
      "Broad, flat, fleshy aromatic pods",
      "Profuse flowering clusters",
      "Delicious buttery taste",
      "Sought after across South & Central India"
    ],
    "resistance": "Tolerant to Pod Borer and Rust"
  },
  {
    "id": "prod-04",
    "name": "Black Gram (\u0c2e\u0c3f\u0c28\u0c41\u0c2e\u0c41)",
    "varietyType": "High Yielding Pulse Seed",
    "sku": "YHS-PLS-BG01",
    "category": "Pulses",
    "image": "/seeds/seed_01.jpeg",
    "stockKg": 3400,
    "packageSizes": [
      "2kg Pack",
      "5kg Pack",
      "25kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "70 - 75 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "Selected elite black gram seed with bold black grains and synchronous maturity.",
    "keyFeatures": [
      "Bold, shining black grains",
      "Uniform pods and synchronous maturity",
      "Non-shattering type",
      "High dal recovery percentage"
    ],
    "resistance": "Highly resistant to Mungbean Yellow Mosaic Virus (MYMV)"
  },
  {
    "id": "prod-05",
    "name": "YHS 999 F1 Hybrid Maize",
    "varietyType": "F1 Hybrid Maize",
    "sku": "YHS-MZ-999",
    "category": "Field Crops",
    "image": "/seeds/seed_40.jpeg",
    "stockKg": 1500,
    "packageSizes": [
      "1kg Pack",
      "4kg Pack"
    ],
    "germinationRate": "90% Min",
    "purity": "98% Min",
    "maturityDays": "95 - 105 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "High yielding orange-yellow flint corn with well-filled cobs and strong lodging resistance.",
    "keyFeatures": [
      "Uniform cylindrical cobs",
      "Orange-yellow flint grain",
      "Excellent tip filling",
      "Strong root system"
    ],
    "resistance": "Tolerant to Turcicum Leaf Blight & Downy Mildew"
  },
  {
    "id": "prod-06",
    "name": "Krishna (ABV-04) F1 Hybrid Bajra",
    "varietyType": "F1 Hybrid Bajra",
    "sku": "YHS-BAJ-KRI",
    "category": "Field Crops",
    "image": "/seeds/seed_39.jpeg",
    "stockKg": 1200,
    "packageSizes": [
      "1.5kg Pack",
      "3kg Pack"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "80 - 85 Days",
    "cropSeason": "Kharif & Summer",
    "availability": "In Stock",
    "description": "High yielding dual-purpose pearl millet with compact long earheads and stay-green fodder quality.",
    "keyFeatures": [
      "High tillering ability",
      "Dense long earheads",
      "Bold greyish grains",
      "Nutritious green fodder"
    ],
    "resistance": "High resistance to Downy Mildew"
  },
  {
    "id": "prod-07",
    "name": "Champion F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-CMP",
    "category": "Chilli",
    "image": "/seeds/seed_02.jpeg",
    "stockKg": 1100,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "70 - 75 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Prolific green chilli hybrid with high pungency and uniform straight pods.",
    "keyFeatures": [
      "Dark green glossy straight fruits",
      "High pungency",
      "Continuous fruiting habit",
      "Great shelf life"
    ],
    "resistance": "Tolerant to Anthracnose & Powdery Mildew"
  },
  {
    "id": "prod-08",
    "name": "Amaran F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-AMR",
    "category": "Chilli",
    "image": "/seeds/seed_03.jpeg",
    "stockKg": 950,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "68 - 72 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "Premium red dry chilli hybrid with deep red color value and high capsaicin content.",
    "keyFeatures": [
      "High ASTA color value",
      "Moderate wrinkles on drying",
      "Uniform fruit length",
      "High dry recovery"
    ],
    "resistance": "Tolerant to sucking pests"
  },
  {
    "id": "prod-09",
    "name": "Harsha Research Dolichos",
    "varietyType": "Research Dolichos Bean",
    "sku": "YHS-DOL-HAR",
    "category": "Dolichos",
    "image": "/seeds/seed_05.jpeg",
    "stockKg": 850,
    "packageSizes": [
      "500g Pack",
      "1kg Pack",
      "5kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "75 - 80 Days",
    "cropSeason": "Rabi & Late Kharif",
    "availability": "In Stock",
    "description": "High yielding bush-type field bean producing clusters of tender aromatic pods.",
    "keyFeatures": [
      "Bushy erect growth habit",
      "Early pod initiation",
      "Strong pleasant aroma",
      "Good market preference"
    ],
    "resistance": "Tolerant to Rust and Aphids"
  },
  {
    "id": "prod-10",
    "name": "Chola Research Dolichos",
    "varietyType": "Research Dolichos Bean",
    "sku": "YHS-DOL-CHO",
    "category": "Dolichos",
    "image": "/seeds/seed_06.jpeg",
    "stockKg": 920,
    "packageSizes": [
      "500g Pack",
      "1kg Pack",
      "5kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "70 - 75 Days",
    "cropSeason": "All Season Suitable",
    "availability": "In Stock",
    "description": "Popular flat green podded dolichos variety with exceptional flavor and tenderness.",
    "keyFeatures": [
      "Broad green tender pods",
      "High cluster setting",
      "Delicate flavor",
      "High yield"
    ],
    "resistance": "Tolerant to Pod Borers"
  },
  {
    "id": "prod-11",
    "name": "Siri Research Field Beans",
    "varietyType": "Research Field Beans",
    "sku": "YHS-DOL-SIR",
    "category": "Dolichos",
    "image": "/seeds/seed_08.jpeg",
    "stockKg": 800,
    "packageSizes": [
      "500g Pack",
      "1kg Pack",
      "5kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 70 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "Early flowering photo-insensitive field bean with high market preference.",
    "keyFeatures": [
      "Photo-insensitive variety",
      "Light green fleshy pods",
      "Prolific cluster bearing",
      "Excellent taste"
    ],
    "resistance": "Resistant to Leaf Spot"
  },
  {
    "id": "prod-12",
    "name": "Kanaka-999 F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-K999",
    "category": "Chilli",
    "image": "/seeds/seed_09.jpeg",
    "stockKg": 1050,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 70 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "Dual purpose green and red dry chilli with high yield potential and thrips tolerance.",
    "keyFeatures": [
      "Dual purpose green and dry",
      "Glossy finish with firm skin",
      "Outstanding yield performance",
      "High pungency"
    ],
    "resistance": "Tolerant to Thrips and Mites"
  },
  {
    "id": "prod-13",
    "name": "Leon F1 Hybrid Okra",
    "varietyType": "F1 Hybrid Bhendi",
    "sku": "YHS-OKR-LEON",
    "category": "Okra",
    "image": "/seeds/seed_10.jpeg",
    "stockKg": 1780,
    "packageSizes": [
      "100g Pouch",
      "250g Pouch",
      "500g Pouch"
    ],
    "germinationRate": "92% Min",
    "purity": "99% Min",
    "maturityDays": "40 - 44 Days",
    "cropSeason": "All Round Year",
    "availability": "In Stock",
    "description": "High performance hybrid bhendi engineered for exceptional early yield and dense pod set.",
    "keyFeatures": [
      "Early first harvest",
      "Uniform slim dark green pods",
      "Tender texture",
      "High branching"
    ],
    "resistance": "Strong field tolerance to Yellow Vein Mosaic Virus"
  },
  {
    "id": "prod-14",
    "name": "Surya F1 Hybrid Bitter Gourd",
    "varietyType": "F1 Hybrid Bitter Gourd",
    "sku": "YHS-BG-SUR",
    "category": "Vegetables",
    "image": "/seeds/seed_11.jpeg",
    "stockKg": 640,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "50 - 55 Days",
    "cropSeason": "Summer & Kharif",
    "availability": "In Stock",
    "description": "Dark green spiny hybrid bitter gourd with continuous picking and excellent shelf life.",
    "keyFeatures": [
      "Prickly sharp spines",
      "Dark green fruits 18-20 cm",
      "Continuous bearing habit",
      "High consumer appeal"
    ],
    "resistance": "Tolerant to Downy Mildew"
  },
  {
    "id": "prod-15",
    "name": "YBS-33 Hybrid Bajra",
    "varietyType": "Hybrid Bajra",
    "sku": "YHS-BAJ-YBS33",
    "category": "Field Crops",
    "image": "/seeds/seed_14.jpeg",
    "stockKg": 1850,
    "packageSizes": [
      "1.5kg Pack",
      "3kg Pack"
    ],
    "germinationRate": "90% Min",
    "purity": "98% Min",
    "maturityDays": "82 - 86 Days",
    "cropSeason": "Kharif & Summer",
    "availability": "In Stock",
    "description": "Top performing bajra hybrid with dense grain packing and excellent drought resilience.",
    "keyFeatures": [
      "Heavy compact earheads",
      "High grain yield",
      "Drought tolerance",
      "Nutritious fodder"
    ],
    "resistance": "Resistant to Blast and Downy Mildew"
  },
  {
    "id": "prod-16",
    "name": "Gowrav F1 Hybrid Bottle Gourd",
    "varietyType": "F1 Hybrid Bottle Gourd",
    "sku": "YHS-BGD-GOW",
    "category": "Vegetables",
    "image": "/seeds/seed_15.jpeg",
    "stockKg": 720,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "99% Min",
    "maturityDays": "50 - 55 Days",
    "cropSeason": "Summer & Rainy",
    "availability": "In Stock",
    "description": "Uniform cylindrical light-green bottle gourd with tender pulp and high commercial yield.",
    "keyFeatures": [
      "Straight cylindrical fruits 30-35 cm",
      "Attractive light green shine",
      "Slow seed development",
      "High vine vigor"
    ],
    "resistance": "Tolerant to Anthracnose"
  },
  {
    "id": "prod-17",
    "name": "Ram F1 Hybrid Marigold",
    "varietyType": "F1 Hybrid Marigold",
    "sku": "YHS-FLW-RAM",
    "category": "Flowers",
    "image": "/seeds/seed_16.jpeg",
    "stockKg": 420,
    "packageSizes": [
      "10g Pouch",
      "25g Pouch",
      "50g Pouch"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "55 - 60 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Spectacular bright yellow large globular marigold flowers favored for festival demand.",
    "keyFeatures": [
      "Dense fully double flowers",
      "Bright golden yellow color",
      "Long keeping quality",
      "High flower weight"
    ],
    "resistance": "Tolerant to Alternaria Leaf Spot"
  },
  {
    "id": "prod-18",
    "name": "Karthi Research Bitter Gourd",
    "varietyType": "Research Bitter Gourd",
    "sku": "YHS-BG-KAR",
    "category": "Vegetables",
    "image": "/seeds/seed_17.jpeg",
    "stockKg": 510,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "52 - 58 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Medium-long prickled green fruits with excellent shipping firmness and flavor.",
    "keyFeatures": [
      "Medium long green fruits",
      "Sharp ridges and spines",
      "Uniform picking",
      "Good transit resilience"
    ],
    "resistance": "Tolerant to Powdery Mildew"
  },
  {
    "id": "prod-19",
    "name": "Ruhan F1 Hybrid Bitter Gourd",
    "varietyType": "F1 Hybrid Bitter Gourd",
    "sku": "YHS-BG-RUH",
    "category": "Vegetables",
    "image": "/seeds/seed_18.jpeg",
    "stockKg": 580,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "99% Min",
    "maturityDays": "48 - 52 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Deep green compact bitter gourd with high female flower ratio and heavy early yield.",
    "keyFeatures": [
      "Dark green glossy texture",
      "High female flower proportion",
      "Early maturity",
      "Excellent crispness"
    ],
    "resistance": "Tolerant to Downy Mildew"
  },
  {
    "id": "prod-20",
    "name": "Mega F1 Hybrid Watermelon",
    "varietyType": "F1 Hybrid Watermelon",
    "sku": "YHS-WM-MEG",
    "category": "Vegetables",
    "image": "/seeds/seed_19.jpeg",
    "stockKg": 890,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "90% Min",
    "purity": "99% Min",
    "maturityDays": "75 - 80 Days",
    "cropSeason": "Summer & Spring",
    "availability": "In Stock",
    "description": "Oblong dark rind watermelon with deep red crisp sweet flesh and high TSS 12-13%.",
    "keyFeatures": [
      "Dark blackish green rind",
      "Crisp deep red flesh",
      "High sweetness (Brix 12-13%)",
      "Average fruit 8-12 kg"
    ],
    "resistance": "Tolerant to Fusarium Wilt"
  },
  {
    "id": "prod-21",
    "name": "Panja-36 F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-P36",
    "category": "Chilli",
    "image": "/seeds/seed_20.jpeg",
    "stockKg": 1150,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 70 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "Vigorous branching chilli hybrid with uniform long fruits and exceptional bearing habit.",
    "keyFeatures": [
      "Lush branching canopy",
      "High fruit count per plant",
      "Sharp pungency",
      "Fast red turning"
    ],
    "resistance": "High field resistance to LCV"
  },
  {
    "id": "prod-22",
    "name": "Divya-27 F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-D27",
    "category": "Chilli",
    "image": "/seeds/seed_21.jpeg",
    "stockKg": 890,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "70 - 75 Days",
    "cropSeason": "All Season Suitable",
    "availability": "In Stock",
    "description": "Specialty light-green elongated hybrid chilli highly favored by wholesale vegetable mandis.",
    "keyFeatures": [
      "Attractive parrot green color",
      "Fruit length 11-13 cm",
      "Uniform girth and straight pods",
      "High market acceptance"
    ],
    "resistance": "Tolerant to Powdery Mildew and Anthracnose"
  },
  {
    "id": "prod-23",
    "name": "Chervi-22 F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-C22",
    "category": "Chilli",
    "image": "/seeds/seed_23.jpeg",
    "stockKg": 980,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "68 - 72 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "High pungency hybrid chilli producing uniform attractive straight red fruits.",
    "keyFeatures": [
      "Attractive straight red fruits",
      "High dry recovery",
      "Thick wall skin",
      "Uniform bearing"
    ],
    "resistance": "Tolerant to sucking pests"
  },
  {
    "id": "prod-24",
    "name": "Bheema F1 Hybrid Marigold",
    "varietyType": "F1 Hybrid Marigold",
    "sku": "YHS-FLW-BHM",
    "category": "Flowers",
    "image": "/seeds/seed_25.jpeg",
    "stockKg": 460,
    "packageSizes": [
      "10g Pouch",
      "25g Pouch",
      "50g Pouch"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "55 - 60 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Vibrant orange tight-petaled marigold blooms with strong disease resistance.",
    "keyFeatures": [
      "Deep saffron orange flowers",
      "Dense petal structure",
      "High resistance to rain spoilage",
      "High field weight"
    ],
    "resistance": "Resistant to Foliar Blight"
  },
  {
    "id": "prod-25",
    "name": "Arudhra F1 Hybrid Tomato",
    "varietyType": "F1 Hybrid Tomato",
    "sku": "YHS-TOM-ARD",
    "category": "Vegetables",
    "image": "/seeds/seed_26.jpeg",
    "stockKg": 820,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "90% Min",
    "purity": "99% Min",
    "maturityDays": "60 - 65 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Determinate prolific red tomato with excellent firmness and long distance shipping ability.",
    "keyFeatures": [
      "Determinate strong bush",
      "Square-round 90-100g fruits",
      "Deep red exterior and interior",
      "Thick pericarp"
    ],
    "resistance": "Tolerant to TyLCV and Early Blight"
  },
  {
    "id": "prod-26",
    "name": "Veera F1 Hybrid Tomato",
    "varietyType": "F1 Hybrid Tomato",
    "sku": "YHS-TOM-VER",
    "category": "Vegetables",
    "image": "/seeds/seed_28.jpeg",
    "stockKg": 910,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "90% Min",
    "purity": "99% Min",
    "maturityDays": "65 - 70 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Semi-determinate square-round tomato with thick pericarp and TyLCV tolerance.",
    "keyFeatures": [
      "Semi-determinate vine",
      "Glossy red firm fruits",
      "Superior transport durability",
      "Continuous set"
    ],
    "resistance": "Resistant to Tomato Leaf Curl Virus"
  },
  {
    "id": "prod-27",
    "name": "Kubera F1 Hybrid Watermelon",
    "varietyType": "F1 Hybrid Watermelon",
    "sku": "YHS-WM-KUB",
    "category": "Vegetables",
    "image": "/seeds/seed_31.jpeg",
    "stockKg": 750,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "90% Min",
    "purity": "99% Min",
    "maturityDays": "70 - 75 Days",
    "cropSeason": "Summer & Spring",
    "availability": "In Stock",
    "description": "Striped oblong hybrid watermelon with sweet crisp ruby red flesh and high yield.",
    "keyFeatures": [
      "Green rind with dark stripes",
      "Crisp ruby red texture",
      "Small seeds",
      "Weight 9-11 kg"
    ],
    "resistance": "Tolerant to Anthracnose"
  },
  {
    "id": "prod-28",
    "name": "Sandy F1 Hybrid Ridge Gourd",
    "varietyType": "F1 Hybrid Ridge Gourd",
    "sku": "YHS-RGD-SAN",
    "category": "Vegetables",
    "image": "/seeds/seed_32.jpeg",
    "stockKg": 630,
    "packageSizes": [
      "50g Pouch",
      "100g Pouch",
      "250g Pouch"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "45 - 50 Days",
    "cropSeason": "Rainy & Summer",
    "availability": "In Stock",
    "description": "Deep green straight ridged tender gourd with prolific flushes and tender edible core.",
    "keyFeatures": [
      "Dark green straight fruits 40-45 cm",
      "Prominent sharp ridges",
      "Tender non-fibrous pulp",
      "Early first harvest"
    ],
    "resistance": "Tolerant to Downy Mildew"
  },
  {
    "id": "prod-29",
    "name": "Ganga Research Cowpea",
    "varietyType": "Research Cowpea",
    "sku": "YHS-PLS-GAN",
    "category": "Pulses",
    "image": "/seeds/seed_33.jpeg",
    "stockKg": 1120,
    "packageSizes": [
      "500g Pack",
      "1kg Pack",
      "5kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "50 - 55 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Bushy cowpea producing long light green tender pods and bold nutritious grains.",
    "keyFeatures": [
      "Semi-bush erect habit",
      "Tender light green pods 25-30 cm",
      "Dual purpose vegetable and grain",
      "Heavy yield"
    ],
    "resistance": "Resistant to Cowpea Aphid-borne Mosaic Virus"
  },
  {
    "id": "prod-30",
    "name": "Ram-55 F1 Hybrid Chilli",
    "varietyType": "F1 Hybrid Chilli",
    "sku": "YHS-CHL-R55",
    "category": "Chilli",
    "image": "/seeds/seed_34.jpeg",
    "stockKg": 1020,
    "packageSizes": [
      "10g Packet",
      "50g Pouch",
      "100g Pouch"
    ],
    "germinationRate": "88% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 70 Days",
    "cropSeason": "Kharif & Rabi",
    "availability": "In Stock",
    "description": "Uniform slender green hybrid chilli with dense fruit set and excellent tolerance to heat.",
    "keyFeatures": [
      "Slender dark green fruits",
      "Intense pungency",
      "Tight fruit attachment",
      "Heavy yield in summer"
    ],
    "resistance": "Tolerant to Leaf Curl Virus"
  },
  {
    "id": "prod-31",
    "name": "CSV-41 Fodder Jowar",
    "varietyType": "Fodder Jowar",
    "sku": "YHS-FOD-C41",
    "category": "Field Crops",
    "image": "/seeds/seed_35.jpeg",
    "stockKg": 2800,
    "packageSizes": [
      "3kg Pack",
      "5kg Pack",
      "25kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 75 Days",
    "cropSeason": "Kharif & Summer",
    "availability": "In Stock",
    "description": "Single-cut highly palatable juicy sweet fodder sorghum with high dry matter and milk yield booster.",
    "keyFeatures": [
      "Juicy sweet stems (Brix 9-10%)",
      "Broad lush green leaves",
      "High digestible dry matter",
      "Boosts dairy milk yield"
    ],
    "resistance": "Tolerant to Foliar Diseases and Shoot Fly"
  },
  {
    "id": "prod-32",
    "name": "CSV-32 Fodder Jowar",
    "varietyType": "Fodder Jowar",
    "sku": "YHS-FOD-C32",
    "category": "Field Crops",
    "image": "/seeds/seed_37.jpeg",
    "stockKg": 2500,
    "packageSizes": [
      "3kg Pack",
      "5kg Pack",
      "25kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "65 - 75 Days",
    "cropSeason": "Kharif & Summer",
    "availability": "In Stock",
    "description": "Multi-cut lush forage sorghum with thin stems, broad leaves, and high protein for dairy cattle.",
    "keyFeatures": [
      "Rapid regeneration after cuts",
      "Thin non-lodging tillers",
      "High crude protein",
      "Low HCN safe for cattle"
    ],
    "resistance": "High resistance to Anthracnose & Leaf Blight"
  },
  {
    "id": "prod-33",
    "name": "Chaya Research Cluster Bean",
    "varietyType": "Research Cluster Bean",
    "sku": "YHS-PLS-CHY",
    "category": "Pulses",
    "image": "/seeds/seed_38.jpeg",
    "stockKg": 1340,
    "packageSizes": [
      "500g Pack",
      "1kg Pack",
      "5kg Pack"
    ],
    "germinationRate": "85% Min",
    "purity": "98% Min",
    "maturityDays": "45 - 50 Days",
    "cropSeason": "All Seasons",
    "availability": "In Stock",
    "description": "Prolific cluster bean with tender non-fibrous dark green pods and excellent branching.",
    "keyFeatures": [
      "Dense cluster bearing",
      "Tender stringless pods",
      "High gum content",
      "Drought tolerant"
    ],
    "resistance": "Tolerant to Bacterial Blight & Powdery Mildew"
  }
];

export const PRODUCT_CATEGORIES = [
  'All Products',
  'Chilli',
  'Okra',
  'Dolichos',
  'Pulses',
  'Vegetables',
  'Field Crops',
  'Flowers'
] as const;
