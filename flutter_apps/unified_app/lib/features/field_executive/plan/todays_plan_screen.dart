import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/fe_service.dart';
import '../../../models/visit_model.dart';
import '../../../models/shop_model.dart';
import '../visits/visit_details_screen.dart';

class TodaysPlanScreen extends StatefulWidget {
  final FeService? feService;
  final VoidCallback? onBack;

  const TodaysPlanScreen({super.key, this.feService, this.onBack});

  @override
  State<TodaysPlanScreen> createState() => TodaysPlanScreenState();
}

class TodaysPlanScreenState extends State<TodaysPlanScreen> {
  late final FeService _feService;
  List<VisitModel> _todayVisits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _feService = widget.feService ?? FeService();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final allVisits = await _feService.getVisits();
      if (!mounted) return;
      setState(() {
        _todayVisits = allVisits.where((v) => v.isToday).toList();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleStartVisit([VisitModel? targetVisit]) async {
    // 1. Determine visit to start
    VisitModel? visit = targetVisit;
    if (visit == null) {
      for (final v in _todayVisits) {
        if (v.status == 'Pending') {
          visit = v;
          break;
        }
      }
    }

    if (visit == null) {
      if (_todayVisits.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No visits planned for today. Tap 'Add Today's Plan' to add a shop first."),
            backgroundColor: Color(0xFF0D4A32),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All planned visits for today are already completed."),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // 2. Check device location services
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device location services are disabled. Please enable GPS in device settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 3. Check and request location permission only when needed
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to start a field visit.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is permanently denied. Please enable it in app settings to start visits.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 4. Permission is available — start active tracking
    await _feService.startDailyGps();

    // 5. Navigate to VisitDetailsScreen
    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VisitDetailsScreen(visit: visit!),
        ),
      );
      if (result == true && mounted) {
        setState(() => _isLoading = true);
        loadData();
      }
    }
  }

  void _showAddPlanDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTodayPlanSheet(
        existingVisits: _todayVisits,
        feService: _feService,
        onSuccess: () {
          setState(() => _isLoading = true);
          loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back',
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text("Today's Plan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D4A32),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              loadData();
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D4A32), Color(0xFF1A7A55)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCountItem('Total', _todayVisits.length, Colors.white),
                            _buildCountItem('Done', _todayVisits.where((v) => v.status == 'Visited').length, Colors.green[200]!),
                            _buildCountItem('Pending', _todayVisits.where((v) => v.status == 'Pending').length, Colors.orange[200]!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Two Clear Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const ValueKey('add_todays_plan_action_button'),
                              onPressed: _showAddPlanDialog,
                              icon: const Icon(Icons.add_task, size: 18),
                              label: const Text("Add Today's Plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D4A32),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const ValueKey('start_visit_action_button'),
                              onPressed: () => _handleStartVisit(),
                              icon: const Icon(Icons.play_circle_fill, size: 18),
                              label: const Text('Start Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0D4A32),
                                side: const BorderSide(color: Color(0xFF0D4A32), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_todayVisits.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.event_busy, size: 56, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No visits planned for today.', style: TextStyle(color: Colors.grey)),
                                SizedBox(height: 6),
                                Text("Tap 'Add Today's Plan' above to schedule shops.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        const Text('Visit Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D4A32))),
                        const SizedBox(height: 12),
                        ..._todayVisits.asMap().entries.map((e) => _buildPlanItem(e.key + 1, e.value)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildCountItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 26)),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }

  Widget _buildPlanItem(int seq, VisitModel v) {
    final bool isVisited = v.status == 'Visited';
    final Color statusColor = isVisited ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: const Color(0xFF0D4A32), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$seq', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.shopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Shop #${v.shopId} • ${v.shopLocation}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  v.purpose,
                  style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (v.notes != null && v.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Notes: "${v.notes}"',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isVisited)
            InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VisitDetailsScreen(visit: v)),
                );
                if (result == true && mounted) {
                  setState(() => _isLoading = true);
                  loadData();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Visited', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else
            ElevatedButton(
              key: ValueKey('start_visit_${v.id}'),
              onPressed: () => _handleStartVisit(v),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D4A32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, size: 16),
                  SizedBox(width: 2),
                  Text('Start Visit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTodayPlanSheet extends StatefulWidget {
  final List<VisitModel> existingVisits;
  final FeService feService;
  final VoidCallback onSuccess;

  const _AddTodayPlanSheet({
    required this.existingVisits,
    required this.feService,
    required this.onSuccess,
  });

  @override
  State<_AddTodayPlanSheet> createState() => _AddTodayPlanSheetState();
}

class _AddTodayPlanSheetState extends State<_AddTodayPlanSheet> {
  List<ShopModel> _availableShops = [];
  bool _isLoadingShops = true;
  String? _shopsError;

  int? _selectedShopId;
  String _selectedPurpose = 'Dealer Audit & Stock Booking';
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  String? _validationError;

  final List<String> _purposeOptions = const [
    'Dealer Audit & Stock Booking',
    'Order Booking & Collection',
    'Stock Inspection & Verification',
    'Product Demonstration',
    'Routine Market Visit',
    'New Dealer Acquisition',
  ];

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchShops() async {
    try {
      final shops = await widget.feService.getShops(allShops: true);
      if (!mounted) return;
      setState(() {
        _availableShops = shops;
        _isLoadingShops = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shopsError = e.toString().replaceAll('Exception: ', '');
        _isLoadingShops = false;
      });
    }
  }

  bool get _isShopAlreadyPlanned {
    if (_selectedShopId == null) return false;
    return widget.existingVisits.any((v) => v.shopId == _selectedShopId);
  }

  Future<void> _submitPlan() async {
    if (_selectedShopId == null) {
      setState(() => _validationError = 'Please select a shop to visit.');
      return;
    }

    if (_isShopAlreadyPlanned) {
      setState(() => _validationError = 'This shop is already in today\'s visit plan.');
      return;
    }

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      await widget.feService.createPlannedVisit(
        shopId: _selectedShopId!,
        purpose: _selectedPurpose,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Shop added to today's plan successfully."),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _validationError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_task, color: Color(0xFF0D4A32)),
                    SizedBox(width: 8),
                    Text(
                      "Add Today's Plan",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D4A32)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            if (_shopsError != null && _availableShops.isEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Failed to load shops: $_shopsError',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _isLoadingShops = true);
                        _fetchShops();
                      },
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
              // Shop Selection
              const Text('Select Shop *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D4A32))),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final selectedShop = _selectedShopId != null
                      ? _availableShops.where((s) => s.id == _selectedShopId).firstOrNull
                      : null;

                  return InkWell(
                    key: const ValueKey('shop_selection_dropdown'),
                    onTap: () => _openShopPicker(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _validationError != null && _selectedShopId == null
                              ? Colors.red
                              : Colors.grey.shade400,
                          width: _validationError != null && _selectedShopId == null ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 20, color: Color(0xFF0D4A32)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: selectedShop != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        selectedShop.shopName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Shop #${selectedShop.id} • ${selectedShop.marketLocation.isNotEmpty ? selectedShop.marketLocation : (selectedShop.city ?? "Active")}${selectedShop.ownerName.isNotEmpty ? " • ${selectedShop.ownerName}" : ""}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  )
                                : Text(
                                    _isLoadingShops
                                        ? 'Loading registered shops...'
                                        : 'Choose from registered shops',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                          ),
                          if (_isLoadingShops)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D4A32)),
                            )
                          else
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF0D4A32)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Duplicate warning indicator
              if (_isShopAlreadyPlanned) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This shop is already in today\'s visit plan. Please select a different shop.',
                          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Purpose Selection
              const Text('Visit Purpose', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D4A32))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const ValueKey('purpose_selection_dropdown'),
                initialValue: _selectedPurpose,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _purposeOptions.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(p, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPurpose = val);
                },
              ),
              const SizedBox(height: 14),

              // Notes
              const Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D4A32))),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('plan_notes_field'),
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  hintText: 'E.g. Discuss new variety stock requirements',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 14),

              // Validation Error Message
              if (_validationError != null) ...[
                Text(
                  _validationError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
              ],

              // Submit Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('save_plan_submit_button'),
                  onPressed: (_isSaving || _isShopAlreadyPlanned) ? null : _submitPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D4A32),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save to Today\'s Plan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _openShopPicker(BuildContext context) async {
    final pickedShop = await showModalBottomSheet<ShopModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShopPickerSheet(
        shops: _availableShops,
        existingVisits: widget.existingVisits,
        selectedShopId: _selectedShopId,
        feService: widget.feService,
      ),
    );

    if (pickedShop != null && mounted) {
      setState(() {
        _selectedShopId = pickedShop.id;
        if (!_availableShops.any((s) => s.id == pickedShop.id)) {
          _availableShops.add(pickedShop);
        }
        _validationError = null;
      });
    }
  }
}

class _ShopPickerSheet extends StatefulWidget {
  final List<ShopModel> shops;
  final List<VisitModel> existingVisits;
  final int? selectedShopId;
  final FeService? feService;

  const _ShopPickerSheet({
    required this.shops,
    required this.existingVisits,
    this.selectedShopId,
    this.feService,
  });

  @override
  State<_ShopPickerSheet> createState() => _ShopPickerSheetState();
}

class _ShopPickerSheetState extends State<_ShopPickerSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late List<ShopModel> _shops;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _shops = List<ShopModel>.from(widget.shops);
    if (_shops.isEmpty && widget.feService != null) {
      _fetchShops();
    }
  }

  Future<void> _fetchShops() async {
    if (widget.feService == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final fetched = await widget.feService!.getShops(allShops: true);
      if (mounted) {
        setState(() {
          _shops = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase().trim();
    final filteredShops = _shops.where((s) {
      if (query.isEmpty) return true;
      final name = s.shopName.toLowerCase();
      final owner = s.ownerName.toLowerCase();
      final city = (s.city ?? '').toLowerCase();
      final loc = s.marketLocation.toLowerCase();
      final phone = s.phone.toLowerCase();
      final idStr = s.id.toString();
      return name.contains(query) ||
          owner.contains(query) ||
          city.contains(query) ||
          loc.contains(query) ||
          phone.contains(query) ||
          idStr.contains(query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: Color(0xFF0D4A32), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Choose Registered Shop',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0D4A32)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('shop_picker_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by shop name, ID, owner, city...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0D4A32)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF6F8F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Shop Count Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isLoading
                      ? 'Loading active registered shops...'
                      : '${filteredShops.length} active registered shops',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Text('Reset Search', style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Shop Content Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0D4A32)),
                        SizedBox(height: 12),
                        Text('Loading registered shops...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 10),
                              Text(
                                'Failed to load shops: $_errorMessage',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _fetchShops,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D4A32),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _shops.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.storefront_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No active registered shops available',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Shops registered through the Admin module will appear here for Today\'s Plan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (widget.feService != null) ...[
                                    const SizedBox(height: 14),
                                    OutlinedButton.icon(
                                      onPressed: _fetchShops,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Refresh'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : filteredShops.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No registered shops match "$_searchQuery"',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Try clearing search to see all available shops.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 14),
                                      ElevatedButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0D4A32),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Clear Search'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: filteredShops.length,
                                separatorBuilder: (_, index) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final s = filteredShops[index];
                                  final isAlreadyPlanned = widget.existingVisits.any((v) => v.shopId == s.id);
                                  final isSelected = widget.selectedShopId == s.id;
                                  final locationLabel = s.marketLocation.isNotEmpty
                                      ? s.marketLocation
                                      : (s.city?.isNotEmpty == true ? s.city! : 'Active');

                                  return Material(
                                    color: isSelected
                                        ? const Color(0xFFE8F5E9)
                                        : (isAlreadyPlanned ? const Color(0xFFFAFAFA) : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      key: ValueKey('shop_picker_item_${s.id}'),
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        Navigator.pop(context, s);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF0D4A32)
                                                : (isAlreadyPlanned ? Colors.grey.shade200 : Colors.grey.shade300),
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF0D4A32)
                                                    : (isAlreadyPlanned ? Colors.grey.shade200 : const Color(0xFFE8F5E9)),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.storefront_outlined,
                                                  size: 20,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : (isAlreadyPlanned ? Colors.grey : const Color(0xFF0D4A32)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${s.shopName} ($locationLabel)${isAlreadyPlanned ? ' [Already in Plan]' : ''}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isAlreadyPlanned ? Colors.grey.shade600 : Colors.black87,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Shop #${s.id} • ${s.ownerName.isNotEmpty ? s.ownerName : "Registered Owner"}${s.phone.isNotEmpty ? " • ${s.phone}" : ""}',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                  ),
                                                  if (s.address.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      s.address,
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (isAlreadyPlanned)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.orange.shade200),
                                                ),
                                                child: Text(
                                                  'In Plan',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade800,
                                                  ),
                                                ),
                                              )
                                            else if (isSelected)
                                              const Icon(Icons.check_circle, color: Color(0xFF0D4A32), size: 20)
                                            else
                                              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      ),
    );
  }
}
