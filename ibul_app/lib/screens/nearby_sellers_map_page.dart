import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/product_model.dart';

class NearbySellersMapPage extends StatefulWidget {
  final Product product;

  const NearbySellersMapPage({super.key, required this.product});

  @override
  State<NearbySellersMapPage> createState() => _NearbySellersMapPageState();
}

class _NearbySellersMapPageState extends State<NearbySellersMapPage>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  AnimationController? _animationController;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Antakya / Hatay Center
  static const LatLng _initialPosition = LatLng(36.2025, 36.1605);

  List<Map<String, dynamic>> _sellers = [];
  bool _isLoading = true;
  int _selectedSellerIndex = 0;

  // Live location
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isFollowingUser = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fetchStores();
    _checkLocationPermissionAndStart();
  }

  Future<void> _checkLocationPermissionAndStart() async {
    if (kIsWeb) {
      try {
        Position? position;
        try {
          // Force get position with timeout and LOWER accuracy for Web
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 20),
          );
        } catch (e) {
          debugPrint('Primary location fetch failed: $e');
          // Try last known position as fallback
          position = await Geolocator.getLastKnownPosition();
        }

        if (mounted && position != null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          setState(() {
            _userLocation = LatLng(position!.latitude, position.longitude);
            // On Web, auto-center immediately when location is found
            _mapController.move(_userLocation!, 15.0);
          });
          _startLiveLocationUpdates();
        } else if (mounted) {
          // Fallback to initial position if absolutely no location found
          _mapController.move(_initialPosition, 14.0);
        }
      } catch (e) {
        debugPrint('Web Location Error: $e');

        // Show specific error only if permission is explicitly denied
        if (e is PermissionDeniedException && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni verilmedi. Harita varsayılan konumda açılıyor.',
              ),
            ),
          );
        } else if (mounted) {
          // Show explicit error message in console for debugging
          print('Konum Hatası: $e');
        }

        if (mounted) {
          _mapController.move(_initialPosition, 14.0);
        }
      }
      return;
    }

    // Mobile Logic (Existing)
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Get initial position
    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        // Also center map on mobile
        if (_userLocation != null) {
          _mapController.move(_userLocation!, 15.0);
        }
      });
    }

    _startLiveLocationUpdates();
  }

  void _startLiveLocationUpdates() {
    if (kIsWeb) {
      // Web: Polling for live location
      Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 3),
          );

          if (mounted) {
            setState(() {
              _userLocation = LatLng(position.latitude, position.longitude);
              if (_isFollowingUser && _userLocation != null) {
                _animatedMapMove(_userLocation!, _mapController.camera.zoom);
              }
            });
          }
        } catch (_) {}
      });
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (mounted) {
              final newLocation = LatLng(position.latitude, position.longitude);
              setState(() {
                _userLocation = newLocation;
              });

              if (_isFollowingUser) {
                _animatedMapMove(newLocation, _mapController.camera.zoom);
              }
            }
          },
        );
  }

  Future<void> _fetchStores() async {
    try {
      final response = await _supabase
          .from('stores')
          .select(
            'seller_id, business_name, logo_url, store_lat, store_lng, latitude, longitude, rating, is_store_open',
          );

      if (mounted) {
        final List<Map<String, dynamic>> loadedStores = [];

        for (var store in response) {
          final lat = store['store_lat'] ?? store['latitude'];
          final lng = store['store_lng'] ?? store['longitude'];

          // Only show stores with valid location data
          if (lat != null && lng != null) {
            loadedStores.add({
              'id': store['seller_id'],
              'name': store['business_name'] ?? 'Mağaza',
              'logo': store['logo_url'],
              'rating': (store['rating'] ?? 0.0).toString(),
              'distance': '1.2km', // Distance calculation can be added here
              'location': LatLng(
                double.parse(lat.toString()),
                double.parse(lng.toString()),
              ),
              'price': widget.product.price,
              'stock': 'Stokta var',
              'deliveryTime': store['is_store_open'] == true
                  ? 'Açık'
                  : 'Kapalı',
              'isOpen': store['is_store_open'] == true,
            });
          }
        }

        setState(() {
          _sellers = loadedStores;
          _isLoading = false;
        });

        // Debug Log
        debugPrint('Haritaya eklenen mağaza sayısı: ${_sellers.length}');
      }
    } catch (e) {
      debugPrint('Error fetching stores for map: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (_animationController == null || !mounted) return;

    if (_animationController!.isAnimating) {
      _animationController!.stop();
    }

    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOut,
    );

    void listener() {
      if (mounted && _animationController!.isAnimating) {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      }
    }

    _animationController!.addListener(listener);

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _animationController?.removeListener(listener);
        _animationController?.removeStatusListener(statusListener);
      }
    }

    animation.addStatusListener(statusListener);
    _animationController!.forward(from: 0);
  }

  void _onSellerSelected(int index) {
    if (_selectedSellerIndex == index) return;

    setState(() {
      _selectedSellerIndex = index;
      _isFollowingUser = false; // Stop following user when selecting a seller
    });
    final seller = _sellers[index];
    final location = seller['location'] as LatLng;

    _animatedMapMove(location, 16.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 14.0,
              minZoom: 12.0,
              maxZoom: 18.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _isFollowingUser = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ibul.app',
              ),
              MarkerLayer(
                markers: _sellers.map((seller) {
                  final location = seller['location'] as LatLng;
                  final isSelected =
                      _sellers.indexOf(seller) == _selectedSellerIndex;

                  return Marker(
                    point: location,
                    width: 50,
                    height: 50,
                    child: GestureDetector(
                      onTap: () => _onSellerSelected(_sellers.indexOf(seller)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child:
                              seller['logo'] != null &&
                                  seller['logo'].toString().startsWith('http')
                              ? ClipOval(
                                  child: Image.network(
                                    seller['logo'],
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Text(
                                          seller['name'] != null &&
                                                  seller['name'].isNotEmpty
                                              ? seller['name'][0]
                                              : '?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.primary,
                                          ),
                                        ),
                                  ),
                                )
                              : Text(
                                  seller['name'] != null &&
                                          seller['name'].isNotEmpty
                                      ? seller['name'][0]
                                      : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Top Header with Product Info
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Back button and title
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.arrow_back_ios, size: 20),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Bu Ürünü Satan Mağazalar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),

                    // Product Info Card
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: widget.product.images.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      widget.product.images[0],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.image, size: 30),
                                    ),
                                  )
                                : const Icon(Icons.image, size: 30),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      widget.product.price,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_sellers.length} Satıcı',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // My Location Button
          Positioned(
            right: 16,
            bottom: 200, // Adjusted to be above the carousel
            child: FloatingActionButton.small(
              heroTag: 'my_location_nearby',
              onPressed: () async {
                if (_userLocation == null) {
                  await _checkLocationPermissionAndStart();
                }

                if (_userLocation != null) {
                  setState(() {
                    _isFollowingUser = true;
                  });
                  _animatedMapMove(_userLocation!, 15.0);
                }
              },
              backgroundColor: Colors.white,
              child: Icon(
                Icons.my_location,
                color: _isFollowingUser ? Colors.blue : Colors.grey,
              ),
            ),
          ),

          // Bottom Seller Cards
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Seller Cards Carousel
                    SizedBox(
                      height: 160,
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 0.9),
                        onPageChanged: (index) {
                          _onSellerSelected(index);
                        },
                        itemCount: _sellers.length,
                        itemBuilder: (context, index) {
                          final seller = _sellers[index];
                          final isSelected = _selectedSellerIndex == index;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isSelected
                                              ? AppColors.primary
                                              : Colors.black)
                                          .withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child:
                                            seller['logo'] != null &&
                                                seller['logo']
                                                    .toString()
                                                    .startsWith('http')
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  seller['logo'],
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Text(
                                                seller['name'][0],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            seller['name'],
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                seller['rating'],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.location_on,
                                                color: Colors.grey,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                seller['distance'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          seller['price'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              seller['stock'],
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        // Navigate to store or add to cart
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: const Text(
                                        'Mağazaya Git',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
