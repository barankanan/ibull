void main() {
  final path = '/kategori/Bilgisayar%2FElektronik/Tablet';
  final parsed = Uri.tryParse(path);
  print(parsed?.path);
}
