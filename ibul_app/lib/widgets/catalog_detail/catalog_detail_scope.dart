import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/product_detail_viewmodel.dart';

ProductDetailViewModel? catalogDetailViewModelOf(BuildContext context) {
  try {
    return Provider.of<ProductDetailViewModel>(context);
  } on ProviderNotFoundException {
    return null;
  }
}
