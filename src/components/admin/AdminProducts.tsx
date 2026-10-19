import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { SeedProduct, PRODUCT_CATEGORIES } from '../../data/seedProducts';
import { Search, Filter, ShieldCheck, Sprout, Package, Eye, X, CheckCircle2, Upload, Trash2 } from 'lucide-react';
import { api, API_BASE_URL } from '../../services/api';

const resolveProductImageUrl = (url?: string) => {
  if (!url) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  const baseUrl = API_BASE_URL.replace('/api/v1', '');
  return `${baseUrl}${url.startsWith('/') ? '' : '/'}${url}`;
};

export const AdminProducts: React.FC = () => {
  const { products, addProduct, removeProduct } = useAppState();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All Products');
  const [selectedProduct, setSelectedProduct] = useState<SeedProduct | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isRemoving, setIsRemoving] = useState<string | number | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const [imagePreviewUrl, setImagePreviewUrl] = useState<string | null>(null);
  const [addError, setAddError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const [addForm, setAddForm] = useState({
    name: '',
    variety_type: '',
    sku: '',
    category: 'Chilli',
    image_url: '',
    available_stock_kg: 0,
    available_stock_bags: 0,
    germination_rate: '85% Min',
    purity: '98% Min',
    maturity_days: '',
    crop_season: '',
    availability: 'In Stock',
    description: '',
    resistance_traits: '',
    package_sizes: '100g, 500g, 1kg'
  });

  const handleOpenAddModal = () => {
    setAddError(null);
    setImagePreviewUrl(null);
    setAddForm({
      name: '',
      variety_type: '',
      sku: '',
      category: 'Chilli',
      image_url: '',
      available_stock_kg: 0,
      available_stock_bags: 0,
      germination_rate: '85% Min',
      purity: '98% Min',
      maturity_days: '',
      crop_season: '',
      availability: 'In Stock',
      description: '',
      resistance_traits: '',
      package_sizes: '100g, 500g, 1kg'
    });
    setIsAddModalOpen(true);
  };

  const handleImageFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate extension
    const validExtensions = ['jpg', 'jpeg', 'png', 'webp'];
    const ext = file.name.split('.').pop()?.toLowerCase();
    if (!ext || !validExtensions.includes(ext)) {
      setAddError('Invalid image format. Only JPEG, PNG, and WebP images are permitted.');
      return;
    }

    // Validate size (5MB)
    if (file.size > 5 * 1024 * 1024) {
      setAddError('File size exceeds the 5MB limit. Please select a smaller image.');
      return;
    }

    setAddError(null);
    const localBlob = URL.createObjectURL(file);
    setImagePreviewUrl(localBlob);
    setIsUploading(true);

    try {
      const res = await api.uploadProductImage(file);
      setAddForm(prev => ({ ...prev, image_url: res.image_url }));
    } catch (err: any) {
      setImagePreviewUrl(null);
      setAddForm(prev => ({ ...prev, image_url: '' }));
      setAddError(err?.message || 'Product image upload failed. Please try again.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleRemoveImage = () => {
    setImagePreviewUrl(null);
    setAddForm(prev => ({ ...prev, image_url: '' }));
  };

  const handleAddProductSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAddError(null);

    // Mandatory validation
    if (!addForm.name || !addForm.name.trim()) {
      setAddError('Product Name is mandatory. Please fill it.');
      return;
    }
    if (!addForm.variety_type || !addForm.variety_type.trim()) {
      setAddError('Variety Type is mandatory. Please fill it.');
      return;
    }
    if (!addForm.category || !addForm.category.trim()) {
      setAddError('Category is mandatory. Please fill it.');
      return;
    }
    if (!addForm.image_url || !addForm.image_url.trim()) {
      setAddError('Product Image is mandatory. Please select an image.');
      return;
    }
    if (!addForm.package_sizes || !addForm.package_sizes.trim()) {
      setAddError('Package Sizes is mandatory. Please fill it.');
      return;
    }

    setIsSubmitting(true);
    try {
      await addProduct({
        name: addForm.name.trim(),
        variety_type: addForm.variety_type.trim(),
        sku: addForm.sku.trim() || undefined,
        category: addForm.category.trim(),
        image_url: addForm.image_url.trim(),
        available_stock_kg: Number(addForm.available_stock_kg) || 0,
        available_stock_bags: Number(addForm.available_stock_kg) || 0,
        germination_rate: addForm.germination_rate.trim() || '85% Min',
        purity: addForm.purity.trim() || '98% Min',
        maturity_days: addForm.maturity_days.trim() || undefined,
        crop_season: addForm.crop_season.trim() || undefined,
        availability: addForm.availability.trim() || 'In Stock',
        description: addForm.description.trim() || undefined,
        resistance_traits: addForm.resistance_traits.trim() || undefined,
        package_sizes: addForm.package_sizes.trim() || '100g, 500g, 1kg'
      });
      setIsAddModalOpen(false);
      setImagePreviewUrl(null);
      setAddForm({
        name: '', variety_type: '', sku: '', category: 'Chilli', image_url: '', available_stock_kg: 0, available_stock_bags: 0,
        germination_rate: '85% Min', purity: '98% Min', maturity_days: '', crop_season: '', availability: 'In Stock', description: '',
        resistance_traits: '', package_sizes: '100g, 500g, 1kg'
      });
      alert('Product added successfully!');
    } catch (err: any) {
      setAddError(err?.message || 'Failed to add product');
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredProducts = products.filter((p) => {
    const matchesCategory = selectedCategory === 'All Products' || p.category === selectedCategory;
    const matchesSearch =
      p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      p.sku.toLowerCase().includes(searchTerm.toLowerCase()) ||
      p.description.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  return (
    <div className="p-6 space-y-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-black text-slate-900 tracking-tight">Seed Product Catalogue</h2>
          <p className="text-xs text-slate-500">Official Yadvi Hybrid Seeds inventory specifications & variety details</p>
        </div>

        <div className="flex items-center gap-3">
          <div className="px-3.5 py-1.5 bg-emerald-50 border border-emerald-200 rounded-xl text-xs font-bold text-emerald-900 flex items-center gap-2">
            <Package className="w-4 h-4 text-emerald-700" />
            <span>Warehouse Stock: {products.reduce((acc, p) => acc + (p.stockKg ?? p.stockBags ?? 0), 0).toLocaleString()} kg</span>
          </div>
          <button
            onClick={handleOpenAddModal}
            className="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 shadow-sm transition"
          >
            <Sprout className="w-4 h-4" />
            Add Product
          </button>
        </div>
      </div>

      {/* Category Pills & Search Toolbar */}
      <div className="space-y-3">
        {/* Category filters */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1 text-xs">
          {PRODUCT_CATEGORIES.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-3.5 py-1.5 rounded-xl font-semibold transition whitespace-nowrap ${
                selectedCategory === cat
                  ? 'bg-emerald-800 text-white shadow-sm'
                  : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Search */}
        <div className="relative max-w-md">
          <Search className="w-4 h-4 absolute left-3.5 top-3 text-slate-400" />
          <input
            type="text"
            placeholder="Search variety, SKU or crop..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-600 shadow-xs"
          />
        </div>
      </div>

      {/* Products Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5">
        {filteredProducts.map((product) => (
          <div
            key={product.id}
            onClick={() => setSelectedProduct(product)}
            className="bg-white rounded-2xl border border-slate-200/80 shadow-card hover:shadow-card-hover transition overflow-hidden flex flex-col group cursor-pointer"
          >
            {/* Packet Image Container with Clean Background */}
            <div className="relative h-60 bg-gradient-to-b from-slate-100 to-slate-200/60 p-4 flex items-center justify-center overflow-hidden">
              <img
                src={resolveProductImageUrl(product.image)}
                alt={product.name}
                className="max-h-full max-w-full object-contain drop-shadow-lg group-hover:scale-105 transition duration-300"
              />
              <span className="absolute top-3 left-3 px-2 py-0.5 rounded-md bg-white/90 backdrop-blur-xs text-[10px] font-bold text-slate-800 shadow-xs border border-slate-200">
                {product.category}
              </span>
              <span className="absolute top-3 right-3 px-2 py-0.5 rounded-md bg-emerald-600 text-white text-[10px] font-bold shadow-xs">
                {product.availability}
              </span>
            </div>

            {/* Product Meta */}
            <div className="p-4 flex-1 flex flex-col justify-between">
              <div>
                <div className="text-[10px] font-mono font-bold text-emerald-700 uppercase tracking-wider">
                  {product.sku}
                </div>
                <h3 className="font-bold text-sm text-slate-900 leading-snug mt-0.5 group-hover:text-emerald-700 transition">
                  {product.name}
                </h3>
                <p className="text-[11px] text-slate-500 line-clamp-2 mt-1 leading-relaxed">
                  {product.description}
                </p>
              </div>

              <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between text-xs">
                <div>
                  <span className="text-[10px] text-slate-400 block font-medium">Available Stock</span>
                  <span className="font-bold text-slate-900 font-mono text-sm">{product.stockKg ?? product.stockBags ?? 0} kg</span>
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setSelectedProduct(product);
                    }}
                    className="px-3 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-800 text-[11px] font-bold transition flex items-center gap-1"
                  >
                    <Eye className="w-3.5 h-3.5" />
                    <span>Specs</span>
                  </button>
                  <button
                    onClick={async (e) => {
                      e.stopPropagation();
                      if (window.confirm(`Are you sure you want to remove ${product.name}?`)) {
                        setIsRemoving(product.id);
                        try {
                          await removeProduct(product.id);
                        } catch (err) {
                          alert("Failed to remove product.");
                        } finally {
                          setIsRemoving(null);
                        }
                      }
                    }}
                    disabled={isRemoving === product.id}
                    className="p-1.5 rounded-lg bg-red-50 hover:bg-red-100 text-red-800 transition disabled:opacity-50"
                    title="Remove Product"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Product Detail Modal */}
      {selectedProduct && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl shadow-2xl max-w-2xl w-full overflow-hidden border border-slate-200 animate-scale-in">
            <div className="bg-[#0b3b2c] p-5 text-white flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Sprout className="w-5 h-5 text-emerald-400" />
                <h3 className="font-bold text-base">{selectedProduct.name}</h3>
              </div>
              <button
                onClick={() => setSelectedProduct(null)}
                className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 overflow-y-auto max-h-[75vh] space-y-5 text-xs text-slate-700">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Packet Image Display */}
                <div className="bg-slate-100 rounded-2xl p-4 flex items-center justify-center h-64 border border-slate-200">
                  <img
                    src={resolveProductImageUrl(selectedProduct.image)}
                    alt={selectedProduct.name}
                    className="max-h-full max-w-full object-contain drop-shadow-xl"
                  />
                </div>

                {/* Key Technical Specs */}
                <div className="space-y-3">
                  <div className="bg-slate-50 p-3 rounded-xl border border-slate-200 space-y-2">
                    <div className="flex justify-between">
                      <span className="text-slate-500">SKU Code:</span>
                      <span className="font-mono font-bold text-slate-900">{selectedProduct.sku}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Category:</span>
                      <span className="font-bold text-emerald-800">{selectedProduct.category}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Maturity Days:</span>
                      <span className="font-bold text-slate-900">{selectedProduct.maturityDays}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Germination Rate:</span>
                      <span className="font-bold text-emerald-700">{selectedProduct.germinationRate}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Physical Purity:</span>
                      <span className="font-bold text-slate-900">{selectedProduct.purity}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-500">Crop Season:</span>
                      <span className="font-bold text-slate-900">{selectedProduct.cropSeason}</span>
                    </div>
                  </div>

                  <div>
                    <span className="font-bold text-slate-900 block mb-1">Standard Packaging Sizes:</span>
                    <div className="flex flex-wrap gap-1.5">
                      {selectedProduct.packageSizes.map((size) => (
                        <span key={size} className="px-2.5 py-1 rounded-md bg-emerald-50 border border-emerald-200 text-emerald-800 font-semibold text-[11px]">
                          {size}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Description */}
              <div>
                <h4 className="font-bold text-slate-900 mb-1">Agronomic Description</h4>
                <p className="text-slate-600 leading-relaxed bg-slate-50 p-3 rounded-xl border border-slate-200">
                  {selectedProduct.description}
                </p>
              </div>

              {/* Key Features */}
              <div>
                <h4 className="font-bold text-slate-900 mb-1.5">Key Performance Features</h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  {selectedProduct.keyFeatures.map((feat, i) => (
                    <div key={i} className="flex items-start gap-2 bg-slate-50 p-2 rounded-lg">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0 mt-0.5" />
                      <span className="text-slate-700">{feat}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Disease Resistance */}
              <div className="bg-amber-50/70 border border-amber-200 p-3 rounded-xl text-amber-900">
                <span className="font-bold block mb-0.5">Field Disease & Pest Tolerance:</span>
                <span>{selectedProduct.resistance}</span>
              </div>
            </div>

            <div className="p-4 bg-slate-50 border-t border-slate-200 flex justify-between items-center">
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  id={`stock-${selectedProduct.id}`}
                  defaultValue={selectedProduct.stockKg ?? selectedProduct.stockBags ?? 0}
                  className="w-24 px-2 py-1.5 text-xs border border-slate-300 rounded-md"
                />
                <button
                  onClick={async () => {
                    const el = document.getElementById(`stock-${selectedProduct.id}`) as HTMLInputElement;
                    if(el) {
                      try {
                        const prodId = parseInt(selectedProduct.id.replace('prod-', ''));
                        const val = parseFloat(el.value) || 0;
                        await api.updateStock(prodId, { available_stock_kg: val, available_stock_bags: val });
                        alert('Stock updated to ' + val + ' kg');
                      } catch (e) {
                        alert('Error updating stock');
                      }
                    }
                  }}
                  className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-md text-xs"
                >
                  Update Stock (kg)
                </button>
              </div>
              <button
                onClick={() => setSelectedProduct(null)}
                className="px-5 py-2 bg-emerald-800 hover:bg-emerald-900 text-white font-bold rounded-xl text-xs"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Product Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/40 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-3xl shadow-2xl max-w-lg w-full overflow-hidden border border-slate-200">
            <div className="bg-[#0b3b2c] p-5 text-white flex items-center justify-between">
              <h3 className="font-bold text-lg">Add New Product</h3>
              <button onClick={() => setIsAddModalOpen(false)} className="p-1 rounded-full text-white/70 hover:text-white hover:bg-white/10">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddProductSubmit} className="p-6 space-y-4 max-h-[75vh] overflow-y-auto" noValidate>
              {addError && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-3.5 py-2.5 rounded-xl text-xs font-semibold flex items-center justify-between">
                  <span>{addError}</span>
                  <button type="button" onClick={() => setAddError(null)} className="text-red-500 hover:text-red-700 font-bold text-sm ml-2">×</button>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">
                    Product Name <span className="text-red-500 font-bold">*</span>
                  </label>
                  <input
                    value={addForm.name}
                    onChange={e => setAddForm({...addForm, name: e.target.value})}
                    type="text"
                    placeholder="e.g. Krishna-5 F1 Hybrid Chilli"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">
                    Variety Type <span className="text-red-500 font-bold">*</span>
                  </label>
                  <input
                    value={addForm.variety_type}
                    onChange={e => setAddForm({...addForm, variety_type: e.target.value})}
                    type="text"
                    placeholder="e.g. F1 Hybrid"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">
                    SKU Code (Optional)
                  </label>
                  <input
                    value={addForm.sku}
                    onChange={e => setAddForm({...addForm, sku: e.target.value})}
                    type="text"
                    placeholder="Auto-generated if left blank"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">
                    Category <span className="text-red-500 font-bold">*</span>
                  </label>
                  <select
                    value={addForm.category}
                    onChange={e => setAddForm({...addForm, category: e.target.value})}
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  >
                    {PRODUCT_CATEGORIES.filter(c => c !== 'All Products').map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Product Image Upload Section */}
              <div className="space-y-1.5 p-3.5 bg-slate-50 border border-slate-200 rounded-xl">
                <label className="text-[11px] font-bold text-slate-700 uppercase flex items-center justify-between">
                  <span>Product Image <span className="text-red-500 font-bold">*</span></span>
                  <span className="text-[10px] text-slate-400 font-normal">Formats: JPG, PNG, WebP (Max 5MB)</span>
                </label>

                <div className="flex flex-col sm:flex-row items-center gap-4 pt-1">
                  {(imagePreviewUrl || addForm.image_url) ? (
                    <div className="relative w-24 h-24 rounded-xl border border-slate-300 bg-white p-1 overflow-hidden shrink-0 shadow-xs">
                      <img
                        src={imagePreviewUrl || resolveProductImageUrl(addForm.image_url)}
                        alt="Product Preview"
                        className="w-full h-full object-contain"
                      />
                      <button
                        type="button"
                        onClick={handleRemoveImage}
                        title="Remove image"
                        className="absolute top-1 right-1 bg-red-600 hover:bg-red-700 text-white p-1 rounded-full shadow transition"
                      >
                        <X className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  ) : (
                    <div className="w-24 h-24 rounded-xl border-2 border-dashed border-slate-300 bg-slate-100 flex flex-col items-center justify-center text-slate-400 shrink-0">
                      <Package className="w-6 h-6 mb-1" />
                      <span className="text-[9px] font-semibold">No Image</span>
                    </div>
                  )}

                  <div className="flex-1 space-y-2">
                    <label className="inline-flex items-center justify-center gap-2 px-4 py-2.5 border border-emerald-600 text-emerald-800 bg-emerald-50 hover:bg-emerald-100 rounded-xl cursor-pointer text-xs font-bold transition shadow-xs">
                      <Upload className="w-4 h-4 text-emerald-700" />
                      <span>{isUploading ? 'Uploading to Server...' : ((imagePreviewUrl || addForm.image_url) ? 'Choose Different Image' : 'Choose Image from Device')}</span>
                      <input
                        type="file"
                        accept=".jpg,.jpeg,.png,.webp"
                        className="hidden"
                        onChange={handleImageFileChange}
                        disabled={isUploading}
                      />
                    </label>
                    <p className="text-[10px] text-slate-500">
                      {(imagePreviewUrl || addForm.image_url) ? '✓ Image uploaded and ready to save with product record.' : 'Please select a seed packet or product image from your device.'}
                    </p>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">
                    Package Sizes <span className="text-red-500 font-bold">*</span>
                  </label>
                  <input
                    value={addForm.package_sizes}
                    onChange={e => setAddForm({...addForm, package_sizes: e.target.value})}
                    type="text"
                    placeholder="e.g. 100g, 500g, 1kg"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">Available Stock (kg)</label>
                  <input
                    value={addForm.available_stock_kg}
                    onChange={e => setAddForm({...addForm, available_stock_kg: parseFloat(e.target.value) || 0, available_stock_bags: parseFloat(e.target.value) || 0})}
                    type="number"
                    min="0"
                    step="0.5"
                    placeholder="0"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">Maturity Days (Optional)</label>
                  <input
                    value={addForm.maturity_days}
                    onChange={e => setAddForm({...addForm, maturity_days: e.target.value})}
                    type="text"
                    placeholder="e.g. 65 - 70 Days"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-600 uppercase">Crop Season (Optional)</label>
                  <input
                    value={addForm.crop_season}
                    onChange={e => setAddForm({...addForm, crop_season: e.target.value})}
                    type="text"
                    placeholder="e.g. Kharif & Rabi"
                    className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-[11px] font-bold text-slate-600 uppercase">Description (Optional)</label>
                <textarea
                  value={addForm.description}
                  onChange={e => setAddForm({...addForm, description: e.target.value})}
                  rows={2}
                  placeholder="Agronomic description and variety characteristics..."
                  className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
                />
              </div>

              <div className="pt-4 flex justify-end gap-3 border-t border-slate-100 sticky bottom-0 bg-white">
                <button
                  type="button"
                  onClick={() => setIsAddModalOpen(false)}
                  disabled={isSubmitting || isUploading}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || isUploading}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs disabled:opacity-50"
                >
                  {isSubmitting ? 'Saving...' : 'Save Product'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
