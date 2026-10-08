import React, { useState } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { SeedProduct, PRODUCT_CATEGORIES } from '../../data/seedProducts';
import { Search, Filter, ShieldCheck, Sprout, Package, Eye, X, CheckCircle2 } from 'lucide-react';

export const AdminProducts: React.FC = () => {
  const { products, addProduct } = useAppState();
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All Products');
  const [selectedProduct, setSelectedProduct] = useState<SeedProduct | null>(null);
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [addForm, setAddForm] = useState({
    name: '', variety_type: '', sku: '', category: 'Chilli', image_url: 'https://images.unsplash.com/photo-1592652495393-e18e6921b7cb?w=500&q=80', available_stock_bags: 0,
    germination_rate: '85% Min', purity: '98% Min', maturity_days: '', crop_season: '', availability: 'In Stock', description: '',
    resistance_traits: '', package_sizes: '100g, 500g, 1kg'
  });

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
            <span>Warehouse Stock: {products.reduce((acc, p) => acc + (p.stockBags || 0), 0).toLocaleString()} Bags</span>
          </div>
          <button
            onClick={() => setIsAddModalOpen(true)}
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
                src={product.image}
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
                  <span className="font-bold text-slate-900 font-mono text-sm">{product.stockBags} Bags</span>
                </div>
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
                    src={selectedProduct.image}
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
                  defaultValue={selectedProduct.stockBags} 
                  className="w-20 px-2 py-1.5 text-xs border border-slate-300 rounded-md" 
                />
                <button 
                  onClick={async () => {
                    const el = document.getElementById(`stock-${selectedProduct.id}`) as HTMLInputElement;
                    if(el) {
                      try {
                        // Normally call PUT /api/v1/products/{id}/stock here
                        alert('Stock updated to ' + el.value);
                      } catch (e) {
                        alert('Error updating stock');
                      }
                    }
                  }}
                  className="px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-md text-xs"
                >
                  Update Stock
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
            
            <form onSubmit={async (e) => {
              e.preventDefault();
              try {
                await addProduct(addForm);
                setIsAddModalOpen(false);
                setAddForm({
                  name: '', variety_type: '', sku: '', category: 'Chilli', image_url: 'https://images.unsplash.com/photo-1592652495393-e18e6921b7cb?w=500&q=80', available_stock_bags: 0,
                  germination_rate: '85% Min', purity: '98% Min', maturity_days: '', crop_season: '', availability: 'In Stock', description: '',
                  resistance_traits: '', package_sizes: '100g, 500g, 1kg'
                });
                alert('Product added successfully!');
              } catch (err) {
                alert('Failed to add product');
              }
            }} className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Product Name</label>
                  <input required value={addForm.name} onChange={e => setAddForm({...addForm, name: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Variety Type</label>
                  <input required value={addForm.variety_type} onChange={e => setAddForm({...addForm, variety_type: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">SKU Code</label>
                  <input required value={addForm.sku} onChange={e => setAddForm({...addForm, sku: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Category</label>
                  <select required value={addForm.category} onChange={e => setAddForm({...addForm, category: e.target.value})} className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none">
                    {PRODUCT_CATEGORIES.filter(c => c !== 'All Products').map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Package Sizes (comma separated)</label>
                  <input required value={addForm.package_sizes} onChange={e => setAddForm({...addForm, package_sizes: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-slate-500 uppercase">Image URL</label>
                  <input required value={addForm.image_url} onChange={e => setAddForm({...addForm, image_url: e.target.value})} type="text" className="w-full border border-slate-200 rounded-lg p-2 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
                </div>
              </div>

              <div className="pt-4 flex justify-end gap-3 border-t border-slate-100 sticky bottom-0 bg-white">
                <button type="button" onClick={() => setIsAddModalOpen(false)} className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs">Save Product</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
