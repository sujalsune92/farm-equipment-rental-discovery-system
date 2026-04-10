import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';

final _sb = Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = AppConstants.roleFarmer,
  }) async {
    const safeRole = AppConstants.roleFarmer;
    final res = await _sb.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      throw const AuthException(
        'Please check your email to confirm signup.',
        code: 'email_confirmation_required',
      );
    }
    final uid = user.id;
    final profile = {
      'id': uid, 'name': name, 'email': email, 'phone': phone, 'role': safeRole,
    };
    // Upsert in case the trigger already created a row
    await _sb.from('users').upsert(profile);
    return UserModel.fromMap({...profile, 'created_at': DateTime.now().toIso8601String()});
  }

  Future<UserModel?> login({required String email, required String password}) async {
    await _sb.auth.signInWithPassword(email: email, password: password);
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return null;
    return getUser(uid);
  }

  Future<UserModel?> getUser(String uid) async {
    final row = await _sb.from('users').select().eq('id', uid).maybeSingle();
    return row != null ? UserModel.fromMap(row) : null;
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _sb.from('users').update(data).eq('id', uid);
  }

  Future<void> resetPassword(String email) async {
    await _sb.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async => _sb.auth.signOut();

  User? get currentUser => _sb.auth.currentUser;
  Stream<AuthState> get authStateChanges => _sb.auth.onAuthStateChange;
}

// ─────────────────────────────────────────────────────────────────────────────
// StorageService
// ─────────────────────────────────────────────────────────────────────────────
class StorageService {
  Future<List<String>> uploadEquipmentImages(List<File> images, String listingId) async {
    final List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      final path = 'listings/$listingId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final bytes = await images[i].readAsBytes();
      await _sb.storage
          .from(AppConstants.equipmentBucket)
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      urls.add(_sb.storage.from(AppConstants.equipmentBucket).getPublicUrl(path));
    }
    return urls;
  }

  Future<String> uploadProfileImage(File image, String userId) async {
    final path = 'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await image.readAsBytes();
    await _sb.storage
        .from(AppConstants.profileBucket)
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _sb.storage.from(AppConstants.profileBucket).getPublicUrl(path);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ListingService
// ─────────────────────────────────────────────────────────────────────────────
class ListingService {
  final _storage = StorageService();

  Future<String> createListing(EquipmentListing listing) async {
    final row = await _sb.from('listings').insert(listing.toMap()).select().single();
    return row['id'] as String;
  }

  Future<void> updateListing(String id, Map<String, dynamic> data) async {
    await _sb.from('listings').update(data).eq('id', id);
  }

  Stream<List<EquipmentListing>> getOwnerListings(String ownerId) {
    return _sb
        .from('listings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(EquipmentListing.fromMap).toList());
  }

  /// Search listings near [lat]/[lng] within [radiusKm]
  Future<List<EquipmentListing>> searchListings({
    required double lat,
    required double lng,
    required double radiusKm,
    String? type,
    double? maxPrice,
    double? minPrice,
    bool? insuranceOnly,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _sb.from('listings').select().eq('is_active', true);
    if (type != null && type.isNotEmpty) query = query.eq('type', type);
    if (maxPrice != null) query = query.lte('price_per_day', maxPrice);
    if (minPrice != null) query = query.gte('price_per_day', minPrice);
    if (insuranceOnly == true) query = query.eq('insurance_available', true);

    final rows = await query;
    final listings = (rows as List).map((r) => EquipmentListing.fromMap(r)).toList();

    final filtered = listings.where((l) {
      final d = _haversineKm(lat, lng, l.latitude, l.longitude);
      l.distanceKm = d;
      return d <= radiusKm;
    }).toList();

    // Date availability check
    List<EquipmentListing> available = filtered;
    if (startDate != null && endDate != null) {
      final bookingRows = await _sb
          .from('bookings')
          .select('listing_id, start_date, end_date, status')
          .neq('status', 'Declined');
      final bookings = (bookingRows as List).map((r) => BookingModel(
            id: '', listingId: r['listing_id'], listingName: '', listingType: '',
            listingImageUrl: '', farmerId: '', farmerName: '', farmerPhone: '',
            ownerId: '', ownerName: '',
            startDate: DateTime.parse(r['start_date']),
            endDate: DateTime.parse(r['end_date']),
            pricePerDay: 0, totalPrice: 0,
            status: r['status'], createdAt: DateTime.now(),
          )).toList();
      available = filtered.where((l) => l.isAvailableFor(startDate, endDate, bookings)).toList();
    }

    available.sort((a, b) {
      final d = (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0);
      return d != 0 ? d : b.averageRating.compareTo(a.averageRating);
    });
    return available;
  }

  Future<EquipmentListing?> getListing(String id) async {
    final row = await _sb.from('listings').select().eq('id', id).maybeSingle();
    return row != null ? EquipmentListing.fromMap(row) : null;
  }

  Future<List<String>> uploadImages(List<File> images, String listingId) =>
      _storage.uploadEquipmentImages(images, listingId);

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BookingService — fixed method names: updateStatus() & markCompleted()
// ─────────────────────────────────────────────────────────────────────────────
class BookingService {
  Future<String> createBooking(BookingModel booking) async {
    final row = await _sb.from('bookings').insert(booking.toMap()).select().single();
    return row['id'] as String;
  }

  Stream<List<BookingModel>> getFarmerBookings(String farmerId) {
    return _sb
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(BookingModel.fromMap).toList());
  }

  Stream<List<BookingModel>> getOwnerBookings(String ownerId) {
    return _sb
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(BookingModel.fromMap).toList());
  }

  /// Update booking status — called updateStatus() in Supabase version
  Future<void> updateStatus(
    String bookingId, {
    required String status,
    String? declineReason,
    DateTime? estimatedReturn,
    String? paymentStatus,
  }) async {
    try {
      final rows = await _sb.from('bookings').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        if (declineReason != null) 'decline_reason': declineReason,
        if (estimatedReturn != null) 'estimated_return': estimatedReturn.toIso8601String(),
        if (paymentStatus != null) 'payment_status': paymentStatus,
      }).eq('id', bookingId).select().maybeSingle();

      if (rows == null) {
        throw Exception('Update failed: no booking found or no permission.');
      }
    } on PostgrestException catch (e) {
      throw Exception('Booking update failed: ${e.message}');
    }
  }

  /// Convenience wrapper
  Future<void> markCompleted(String bookingId) => updateStatus(bookingId, status: AppConstants.statusCompleted);

  Future<bool> hasConflict(String listingId, DateTime start, DateTime end) async {
    final rows = await _sb
        .from('bookings')
        .select('id, start_date, end_date, start_time, end_time, duration_type, status')
        .eq('listing_id', listingId)
        .neq('status', 'Declined');
    for (final r in rows as List) {
      final status = (r['status'] ?? 'Pending') as String;
      if (status == AppConstants.statusDeclined) continue;
      final dur = r['duration_type'] ?? 'full_day';
      if (dur == 'hourly' || r['start_time'] != null || r['end_time'] != null) {
        final existingStart = DateTime.parse(r['start_time'] as String);
        final existingEnd = DateTime.parse(r['end_time'] as String);
        if (!(end.isBefore(existingStart) || start.isAfter(existingEnd))) return true;
      } else {
        final existingStart = DateTime.parse(r['start_date'] as String);
        final existingEnd = DateTime.parse(r['end_date'] as String);
        if (!(end.isBefore(existingStart) || start.isAfter(existingEnd))) return true;
      }
    }
    return false;
  }

  Future<void> cancelBooking(String bookingId, {required String cancelledBy, String? reason}) async {
    await _sb.from('bookings').update({
      'status': AppConstants.statusDeclined,
      'cancelled_by': cancelledBy,
      'cancel_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<void> rescheduleBooking(String bookingId, {
    required DateTime start,
    required DateTime end,
    DateTime? startTime,
    DateTime? endTime,
    String durationType = 'full_day',
  }) async {
    await _sb.from('bookings').update({
      'start_date': start.toIso8601String().split('T').first,
      'end_date': end.toIso8601String().split('T').first,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_type': durationType,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReviewService
// ─────────────────────────────────────────────────────────────────────────────
class ReviewService {
  Future<void> submitReview(ReviewModel review) async {
    await _sb.from('reviews').insert(review.toMap());
    try {
      await _sb.rpc('update_owner_rating',   params: {'owner_uuid':   review.ownerId});
      await _sb.rpc('update_listing_rating', params: {'listing_uuid': review.listingId});
    } catch (_) {} // RPCs may not exist yet in dev
  }

  Stream<List<ReviewModel>> getListingReviews(String listingId) {
    return _sb
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('listing_id', listingId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ReviewModel.fromMap).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  Future<void> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? referenceId,
  }) async {
    await _sb.from('notifications').insert({
      'user_id': userId, 'title': title, 'body': body,
      'type': type, 'reference_id': referenceId, 'is_read': false,
    });
  }

  Stream<List<AppNotification>> getNotifications(String userId) {
    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  Stream<int> unreadCount(String userId) {
    return _sb
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }

  Future<void> markRead(String id) async {
    await _sb.from('notifications').update({'is_read': true}).eq('id', id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WorkerConnectivityService
// ─────────────────────────────────────────────────────────────────────────────
class WorkerConnectivityService {
  bool _containsText(String source, String query) {
    return source.toLowerCase().contains(query.toLowerCase());
  }

  bool _matchesSkillSet(List<String> skills, String query) {
    final tokens = query
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return true;
    final normalized = skills.map((s) => s.toLowerCase()).toList();
    return tokens.any((token) => normalized.any((s) => s.contains(token)));
  }

  Stream<List<WorkerJobPost>> streamOpenJobs({
    String? village,
    String? skill,
    double? workerLat,
    double? workerLng,
    double? maxDistanceKm,
  }) {
    return _sb.from('worker_job_posts').stream(primaryKey: ['id']).order('created_at', ascending: false).map((rows) {
      var jobs = rows.map(WorkerJobPost.fromMap).where((j) => j.status == 'open').toList();
      if (village != null && village.trim().isNotEmpty) {
        final v = village.trim();
        jobs = jobs.where((j) => _containsText(j.village, v)).toList();
      }
      if (skill != null && skill.trim().isNotEmpty) {
        final s = skill.trim();
        jobs = jobs.where((j) {
          return _matchesSkillSet(j.requiredSkills, s) ||
              _containsText(j.title, s) ||
              _containsText(j.description, s);
        }).toList();
      }

      if (workerLat != null && workerLng != null) {
        for (final j in jobs) {
          if (j.latitude != null && j.longitude != null) {
            j.distanceKm = _haversineKm(workerLat, workerLng, j.latitude!, j.longitude!);
          }
        }
        if (maxDistanceKm != null) {
          jobs = jobs.where((j) => j.distanceKm != null && j.distanceKm! <= maxDistanceKm).toList();
        }
        jobs.sort((a, b) {
          final da = a.distanceKm ?? 999999;
          final db = b.distanceKm ?? 999999;
          return da.compareTo(db);
        });
      }
      return jobs;
    });
  }

  Stream<List<WorkerJobPost>> streamJobsByFarmer(
    String farmerId, {
    String? village,
    String? skill,
  }) {
    return _sb
        .from('worker_job_posts')
        .stream(primaryKey: ['id'])
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false)
        .map((rows) {
          var jobs = rows.map(WorkerJobPost.fromMap).toList();
          if (village != null && village.trim().isNotEmpty) {
            final v = village.trim();
            jobs = jobs.where((j) => _containsText(j.village, v)).toList();
          }
          if (skill != null && skill.trim().isNotEmpty) {
            final s = skill.trim();
            jobs = jobs.where((j) {
              return _matchesSkillSet(j.requiredSkills, s) ||
                  _containsText(j.title, s) ||
                  _containsText(j.description, s);
            }).toList();
          }
          return jobs;
        });
  }

  Future<String> createJob(WorkerJobPost job) async {
    final row = await _sb.from('worker_job_posts').insert(job.toMap()).select().single();
    return row['id'] as String;
  }

  Future<void> updateJobStatus(String jobId, String status) async {
    await _sb.from('worker_job_posts').update({'status': status}).eq('id', jobId);
  }

  Future<WorkerProfile?> getMyWorkerProfile(String uid) async {
    final row = await _sb.from('worker_profiles').select().eq('user_id', uid).maybeSingle();
    return row != null ? WorkerProfile.fromMap(row) : null;
  }

  Future<void> upsertWorkerProfile(WorkerProfile profile) async {
    await _sb.from('worker_profiles').upsert(profile.toMap());
  }

  Stream<List<WorkerProfile>> streamWorkers({String? village, String? skill}) {
    return _sb.from('worker_profiles').stream(primaryKey: ['user_id']).order('updated_at', ascending: false).map((rows) {
      var workers = rows.map(WorkerProfile.fromMap).where((w) => w.isAvailable).toList();
      if (village != null && village.trim().isNotEmpty) {
        final v = village.trim();
        workers = workers.where((w) => _containsText(w.village, v)).toList();
      }
      if (skill == null || skill.trim().isEmpty) return workers;
      final s = skill.trim();
      return workers.where((w) {
        return _matchesSkillSet(w.skills, s) || _containsText(w.primaryWorkType, s);
      }).toList();
    });
  }

  Future<void> applyForJob({
    required String jobId,
    required String workerId,
    required String workerName,
    String? note,
  }) async {
    await _sb.from('worker_applications').upsert({
      'job_id': jobId,
      'worker_id': workerId,
      'worker_name': workerName,
      'status': 'applied',
      'note': note,
    });
  }

  Stream<List<WorkerApplication>> streamApplicationsForJob(String jobId) {
    return _sb
        .from('worker_applications')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(WorkerApplication.fromMap).toList());
  }

  Stream<List<WorkerApplication>> streamApplicationsByWorker(String workerId) {
    return _sb
        .from('worker_applications')
        .stream(primaryKey: ['id'])
        .eq('worker_id', workerId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(WorkerApplication.fromMap).toList());
  }

  Stream<List<WorkerJobPost>> streamAppliedJobsByWorker(String workerId) {
    return streamApplicationsByWorker(workerId).asyncMap((apps) async {
      if (apps.isEmpty) return <WorkerJobPost>[];
      final jobIds = apps.map((a) => a.jobId).toSet().toList();
      final rows = await _sb.from('worker_job_posts').select().inFilter('id', jobIds);
      final jobs = (rows as List).map((r) => WorkerJobPost.fromMap(r)).toList();
      final statusByJob = <String, String>{
        for (final a in apps) a.jobId: a.status,
      };
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final j in jobs) {
        final appStatus = statusByJob[j.id];
        if (appStatus != null) {
          j.distanceKm = null;
        }
      }
      return jobs;
    });
  }

  Future<void> updateApplicationStatus(String applicationId, String status) async {
    await _sb.from('worker_applications').update({'status': status}).eq('id', applicationId);
  }

  Stream<List<WorkerMessage>> streamMessages(String jobId) {
    return _sb
        .from('worker_messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(WorkerMessage.fromMap).toList());
  }

  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String receiverId,
    required String body,
  }) async {
    await _sb.from('worker_messages').insert({
      'job_id': jobId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'body': body.trim(),
    });
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────────────────────────────────────
class LocationService {
  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      final p = (await placemarkFromCoordinates(lat, lng)).first;
      return '${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}'.trim();
    } catch (_) { return null; }
  }
}
