import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';

class ProductService {
  final _col = FirebaseFirestore.instance.collection('products');

  Stream<List<Product>> watchAll() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Product.fromDoc).toList());

  Future<void> add(Product p) =>
      _col.add({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  Future<void> update(Product p) => _col.doc(p.id).update(p.toMap());

  Future<void> delete(String id) => _col.doc(id).delete();
}