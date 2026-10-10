import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String title;
  final String platform;
  final String condition;
  final String region;
  final bool hasBox;
  final double price;
  final int stock;
  final String description;
  final List<String> imageUrls;

  Product({
    this.id = '',
    required this.title,
    required this.platform,
    required this.condition,
    required this.region,
    required this.hasBox,
    required this.price,
    required this.stock,
    this.description = '',
    this.imageUrls = const [],
  });

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Product(
      id: doc.id,
      title: d['title'] ?? '',
      platform: d['platform'] ?? 'PS5',
      condition: d['condition'] ?? 'new',
      region: d['region'] ?? 'Asia',
      hasBox: d['hasBox'] ?? true,
      price: (d['price'] ?? 0).toDouble(),
      stock: (d['stock'] ?? 0).toInt(),
      description: d['description'] ?? '',
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'platform': platform,
        'condition': condition,
        'region': region,
        'hasBox': hasBox,
        'price': price,
        'stock': stock,
        'description': description,
        'imageUrls': imageUrls,
      };
}