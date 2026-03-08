import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// ✅ Save User Information to Firestore (After Registration)
  Future<void> saveUserData(String name, String email, String phone) async {
    String uid = _auth.currentUser!.uid;

    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': Timestamp.now(),
      'role': 'user', // or 'admin' manually for admins
    });
  }

  /// ✅ Save Package Data (For Admin Panel)
  Future<void> addPackage(String name, double price, String imageUrl) async {
    await _db.collection('packages').add({
      'packageName': name,
      'price': price,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
    });
  }

  /// ✅ Get All Packages from Firestore
  Stream<QuerySnapshot> getPackages() {
    return _db.collection('packages').snapshots();
  }

  /// ✅ Create a Booking Record
  Future<String> createBooking(String packageName, double price, String date, String time) async {
    String uid = _auth.currentUser!.uid;

    DocumentReference bookingRef = await _db.collection('bookings').add({
      'userId': uid,
      'packageName': packageName,
      'price': price,
      'date': date,
      'time': time,
      'status': 'Pending',
      'createdAt': Timestamp.now(),
    });

    return bookingRef.id; // Return bookingId to use for car details & payment
  }

  /// ✅ Save Car Details After Booking
  Future<void> saveCarDetails(String bookingId, String length, String height, String licensePlate) async {
    await _db.collection('bookings').doc(bookingId).update({
      'carLength': length,
      'carHeight': height,
      'licensePlate': licensePlate,
    });
  }

  /// ✅ Save Payment Details
  Future<void> savePayment(String bookingId, double amount, String paymentMethod) async {
    String uid = _auth.currentUser!.uid;

    await _db.collection('payments').add({
      'bookingId': bookingId,
      'userId': uid,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'paymentStatus': 'Paid',
      'paidAt': Timestamp.now(),
    });

    /// Update booking status to confirmed/paid
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'Confirmed',
    });
  }

  /// ✅ Get Bookings for the Logged-In User
  Stream<QuerySnapshot> getUserBookings() {
    String uid = _auth.currentUser!.uid;
    return _db.collection('bookings').where('userId', isEqualTo: uid).snapshots();
  }

  /// ✅ Get Payment History
  Stream<QuerySnapshot> getUserPayments() {
    String uid = _auth.currentUser!.uid;
    return _db.collection('payments').where('userId', isEqualTo: uid).snapshots();
  }
}
