import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class GeneralMapPage extends StatefulWidget {
	const GeneralMapPage({Key? key}) : super(key: key);

	@override
	State<GeneralMapPage> createState() => _GeneralMapPageState();
}

class _GeneralMapPageState extends State<GeneralMapPage> {
	final MapController _mapController = MapController();
	final TextEditingController _searchController = TextEditingController();
	int _selectedBusinessIndex = 0;

	final List<Map<String, dynamic>> _businesses = [
		{
			'id': 1,
			'name': 'Arçelik',
			'logo': 'A',
			'rating': '8.2',
			'distance': '50m',
			'location': const LatLng(36.2025, 36.1605),
		},
		{
			'id': 2,
			'name': 'LC Waikiki',
			'logo': 'LC',
			'rating': '9.1',
			'distance': '250m',
			'location': const LatLng(36.2040, 36.1585),
		},
		{
			'id': 3,
			'name': 'Turk Telekom',
			'logo': 'T',
			'rating': '7.6',
			'distance': '300m',
			'location': const LatLng(36.2010, 36.1620),
		},
	];

	void _animateToBusiness(int index) {
	  setState(() {
		_selectedBusinessIndex = index;
	  });
	  final business = _businesses[index];
	  _mapController.move(business['location'], 16.0);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppColors.background,
			body: SafeArea(
				child: Column(
					children: [
						// Header
						Container(
							padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
							decoration: BoxDecoration(
								color: AppColors.primary,
								borderRadius: const BorderRadius.only(
									bottomLeft: Radius.circular(24),
									bottomRight: Radius.circular(24),
								),
							),
							child: Row(
								children: [
									Expanded(
										child: TextField(
											controller: _searchController,
											decoration: InputDecoration(
												hintText: 'Mağaza ara',
												hintStyle: const TextStyle(color: Colors.white70),
												filled: true,
												fillColor: Colors.white.withOpacity(0.15),
												prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
												contentPadding: const EdgeInsets.symmetric(vertical: 10),
												border: OutlineInputBorder(
													borderRadius: BorderRadius.circular(12),
													borderSide: BorderSide.none,
												),
												isDense: true,
											),
											style: const TextStyle(fontSize: 12, color: Colors.white),
										),
									),
									const SizedBox(width: 12),
									Container(
										width: 40,
										height: 38,
										decoration: BoxDecoration(
											color: Colors.white,
											borderRadius: BorderRadius.circular(10),
										),
										child: const Icon(
											Icons.filter_list,
											color: Colors.purple,
											size: 20,
										),
									),
								],
							),
						),
						// Store cards
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
							child: SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: _businesses.map((business) {
										final index = _businesses.indexOf(business);
										final isSelected = _selectedBusinessIndex == index;
										return GestureDetector(
											onTap: () => _animateToBusiness(index),
											child: Container(
												width: 160,
												margin: const EdgeInsets.only(right: 12),
												padding: const EdgeInsets.all(10),
												decoration: BoxDecoration(
													color: Colors.white,
													borderRadius: BorderRadius.circular(16),
													border: Border.all(
														color: isSelected ? Colors.purple : Colors.grey.shade300,
														width: isSelected ? 2 : 1,
													),
													boxShadow: [
														BoxShadow(
															color: (isSelected ? Colors.purple : Colors.black).withOpacity(0.08),
															blurRadius: 6,
															offset: const Offset(0, 2),
														),
													],
												),
												child: Row(
													children: [
														Container(
															width: 32,
															height: 32,
															decoration: BoxDecoration(
																color: Colors.purple.withOpacity(0.1),
																borderRadius: BorderRadius.circular(8),
															),
															child: Center(
																child: Text(
																	business['logo'],
																	style: const TextStyle(
																		fontWeight: FontWeight.bold,
																		fontSize: 16,
																		color: Colors.purple,
																	),
																),
															),
														),
														const SizedBox(width: 10),
														Expanded(
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	Text(
																		business['name'],
																		style: const TextStyle(
																			fontSize: 13,
																			fontWeight: FontWeight.bold,
																			color: Colors.black87,
																		),
																		maxLines: 1,
																		overflow: TextOverflow.ellipsis,
																	),
																	const SizedBox(height: 4),
																	Row(
																		children: [
																			Icon(Icons.star, color: Colors.amber, size: 13),
																			const SizedBox(width: 3),
																			Text(
																				business['rating'],
																				style: const TextStyle(
																					fontSize: 11,
																					fontWeight: FontWeight.w600,
																				),
																			),
																			const SizedBox(width: 8),
																			Icon(Icons.location_on, color: Colors.grey, size: 13),
																			const SizedBox(width: 3),
																			Text(
																				business['distance'],
																				style: TextStyle(
																					fontSize: 11,
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
											),
										);
									}).toList(),
								),
							),
						),
						// Map widget
						Flexible(
							child: FlutterMap(
								mapController: _mapController,
								options: MapOptions(
									initialCenter: LatLng(36.2025, 36.1605),
									initialZoom: 13.0,
								),
								children: [
									TileLayer(
										urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
										subdomains: ['a', 'b', 'c'],
									),
									MarkerLayer(
										markers: _businesses.map<Marker>((business) {
											return Marker(
												point: business['location'],
												width: 40.0,
												height: 40.0,
												child: Container(
													child: Icon(
														Icons.location_on,
														color: Colors.red,
														size: 30.0,
													),
												),
											);
										}).toList(),
									),
								],
							),
						),
					],
				),
			),
		);
	  }
}
