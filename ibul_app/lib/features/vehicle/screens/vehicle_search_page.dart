import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../widgets/ibul_page_state.dart';
import '../models/vehicle_commerce.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_card.dart';

class VehicleSearchPage extends StatefulWidget {
  const VehicleSearchPage({super.key, this.initial});

  final VehicleSearchQuery? initial;

  @override
  State<VehicleSearchPage> createState() => _VehicleSearchPageState();
}

class _VehicleSearchPageState extends State<VehicleSearchPage> {
  final _text = TextEditingController();
  bool _loading = false;
  String? _error;
  List<VehicleListing> _results = const [];
  bool _sale = false;
  bool _rental = false;
  bool _verified = false;
  bool _tradeIn = false;
  bool _financing = false;
  bool _homeDelivery = false;
  String? _fuel;
  String? _transmission;
  String? _city;
  String? _brand;
  String? _model;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _text.text = initial.text ?? '';
      _sale = initial.saleOnly;
      _rental = initial.rentalOnly;
      _verified = initial.verifiedOnly;
      _tradeIn = initial.tradeIn;
      _financing = initial.financing;
      _homeDelivery = initial.homeDelivery;
      _fuel = initial.fuel;
      _transmission = initial.transmission;
      _city = initial.city;
      _brand = initial.brand;
      _model = initial.model;
    }
    _search();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  VehicleSearchQuery _query() => VehicleSearchQuery(
    text: _text.text.trim().isEmpty ? null : _text.text.trim(),
    brand: _brand,
    model: _model,
    saleOnly: _sale,
    rentalOnly: _rental,
    verifiedOnly: _verified,
    tradeIn: _tradeIn,
    financing: _financing,
    homeDelivery: _homeDelivery,
    fuel: _fuel,
    transmission: _transmission,
    city: _city,
    limit: 40,
  );

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await VehicleService.instance.listings.search(_query());
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Arama başarısız. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        title: const Text('Araç ara', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Filtre',
            icon: const Icon(Icons.tune),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Marka, model, paket…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const IbulPageState.loading()
                : _error != null
                ? IbulPageState.error(title: _error!, onAction: _search)
                : _results.isEmpty
                ? const IbulPageState.empty(
                    icon: Icons.directions_car_outlined,
                    title: 'Sonuç bulunamadı',
                    message: 'Filtreleri daraltmayı deneyin.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        VehicleCard(listing: _results[index], width: 200),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtreler',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SwitchListTile(
                title: const Text('Satılık'),
                value: _sale,
                onChanged: (v) => setState(() => _sale = v),
              ),
              SwitchListTile(
                title: const Text('Kiralık'),
                value: _rental,
                onChanged: (v) => setState(() => _rental = v),
              ),
              SwitchListTile(
                title: const Text('Doğrulanmış araç'),
                value: _verified,
                onChanged: (v) => setState(() => _verified = v),
              ),
              SwitchListTile(
                title: const Text('Takas'),
                value: _tradeIn,
                onChanged: (v) => setState(() => _tradeIn = v),
              ),
              SwitchListTile(
                title: const Text('Finansman'),
                value: _financing,
                onChanged: (v) => setState(() => _financing = v),
              ),
              SwitchListTile(
                title: const Text('Eve teslim'),
                value: _homeDelivery,
                onChanged: (v) => setState(() => _homeDelivery = v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _search();
                  },
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
