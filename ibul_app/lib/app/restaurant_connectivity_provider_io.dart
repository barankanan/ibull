import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../services/restaurant_offline/restaurant_connectivity_service.dart';

List<SingleChildWidget> buildRestaurantConnectivityProviders() => [
  ChangeNotifierProvider.value(value: RestaurantConnectivityService.instance),
];
