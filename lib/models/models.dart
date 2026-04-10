// ─────────────────────────────────────────────────────────────────────────────
// Models — Supabase edition (snake_case Postgres columns)
// ─────────────────────────────────────────────────────────────────────────────

// ── UserModel ────────────────────────────────────────────────────────────────
class UserModel {
  final String id;           // UUID — use .id everywhere (NOT .uid)
  final String name;
  final String email;
  final String phone;
  final String role;         // farmer
  final String? profileImageUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final List<String> skills;
  final String? currentJob;
  final int pastExperienceYears;
  final String? experienceDetails;
  final String? gender;
  final String? bio;
  final double averageRating;
  final int totalReviews;
  final DateTime createdAt;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl,
    this.address,
    this.latitude,
    this.longitude,
    this.skills = const [],
    this.currentJob,
    this.pastExperienceYears = 0,
    this.experienceDetails,
    this.gender,
    this.bio,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    required this.createdAt,
    this.isVerified = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
        id: m['id'] as String,
        name: m['name'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        role: m['role'] ?? 'farmer',
        profileImageUrl: m['profile_image_url'],
        address: m['address'],
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        skills: List<String>.from(m['skills'] ?? const []),
        currentJob: m['current_job'],
        pastExperienceYears: (m['past_experience_years'] as num?)?.toInt() ?? 0,
        experienceDetails: m['experience_details'],
        gender: m['gender'],
        bio: m['bio'],
        averageRating: (m['average_rating'] as num?)?.toDouble() ?? 0.0,
        totalReviews: m['total_reviews'] ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
        isVerified: m['is_verified'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'profile_image_url': profileImageUrl,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'skills': skills,
        'current_job': currentJob,
        'past_experience_years': pastExperienceYears,
        'experience_details': experienceDetails,
        'gender': gender,
        'bio': bio,
        'average_rating': averageRating,
        'total_reviews': totalReviews,
        'is_verified': isVerified,
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? profileImageUrl,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? skills,
    String? currentJob,
    int? pastExperienceYears,
    String? experienceDetails,
    String? gender,
    String? bio,
    double? averageRating,
    int? totalReviews,
    DateTime? createdAt,
    bool? isVerified,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      skills: skills ?? this.skills,
      currentJob: currentJob ?? this.currentJob,
      pastExperienceYears: pastExperienceYears ?? this.pastExperienceYears,
      experienceDetails: experienceDetails ?? this.experienceDetails,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

// ── EquipmentListing ──────────────────────────────────────────────────────────
// NOTE: Uses latitude/longitude doubles — NO GeoPoint (that was Firebase)
class EquipmentListing {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final double ownerRating;
  final String name;
  final String description;
  final String type;
  final double pricePerDay;
  final double? hourlyRate;
  final double? halfDayRate;
  final double? fullDayRate;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final String address;
  final bool insuranceAvailable;
  final double securityDepositRequired;
  final Map<String, dynamic>? packagePricing;
  final bool isActive;
  final double averageRating;
  final int totalBookings;
  final DateTime createdAt;
  double? distanceKm;

  EquipmentListing({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.ownerRating,
    required this.name,
    required this.description,
    required this.type,
    required this.pricePerDay,
    this.hourlyRate,
    this.halfDayRate,
    this.fullDayRate,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.insuranceAvailable = false,
    this.securityDepositRequired = 0,
    this.packagePricing,
    this.isActive = true,
    this.averageRating = 0.0,
    this.totalBookings = 0,
    required this.createdAt,
    this.distanceKm,
  });

  factory EquipmentListing.fromMap(Map<String, dynamic> m) => EquipmentListing(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        ownerName: m['owner_name'] ?? '',
        ownerPhone: m['owner_phone'] ?? '',
        ownerRating: (m['owner_rating'] as num?)?.toDouble() ?? 0.0,
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        type: m['type'] ?? '',
        pricePerDay: (m['price_per_day'] as num).toDouble(),
        hourlyRate: (m['hourly_rate'] as num?)?.toDouble(),
        halfDayRate: (m['half_day_rate'] as num?)?.toDouble(),
        fullDayRate: (m['full_day_rate'] as num?)?.toDouble(),
        imageUrls: List<String>.from(m['image_urls'] ?? []),
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        address: m['address'] ?? '',
        insuranceAvailable: m['insurance_available'] ?? false,
        securityDepositRequired: (m['security_deposit_required'] as num?)?.toDouble() ?? 0,
        packagePricing: m['package_pricing'] as Map<String, dynamic>?,
        isActive: m['is_active'] ?? true,
        averageRating: (m['average_rating'] as num?)?.toDouble() ?? 0.0,
        totalBookings: m['total_bookings'] ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'owner_rating': ownerRating,
        'name': name,
        'description': description,
        'type': type,
        'price_per_day': pricePerDay,
        'hourly_rate': hourlyRate,
        'half_day_rate': halfDayRate,
        'full_day_rate': fullDayRate,
        'image_urls': imageUrls,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'insurance_available': insuranceAvailable,
        'security_deposit_required': securityDepositRequired,
        'package_pricing': packagePricing,
        'is_active': isActive,
        'average_rating': averageRating,
        'total_bookings': totalBookings,
      };

  /// Check availability against a list of existing non-declined bookings
  bool isAvailableFor(DateTime start, DateTime end, List<BookingModel> bookings) {
    final relevant = bookings.where((b) => b.listingId == id);
    for (final b in relevant) {
      if (!(end.isBefore(b.startDate) || start.isAfter(b.endDate))) {
        return false;
      }
    }
    return true;
  }
}

// ── BookingModel ──────────────────────────────────────────────────────────────
class BookingModel {
  final String id;
  final String listingId;
  final String listingName;
  final String listingType;
  final String listingImageUrl;
  final String farmerId;
  final String farmerName;
  final String farmerPhone;
  final String ownerId;
  final String ownerName;
  final DateTime startDate;
  final DateTime endDate;
  final double pricePerDay;
  final double totalPrice;
  final String status;
  final String durationType;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool insuranceOpted;
  final double securityDeposit;
  final String paymentStatus;
  final String? invoiceUrl;
  final DateTime? estimatedReturn;
  final double? distanceKm;
  final double? costEstimate;
  final String? cancelledBy;
  final String? cancelReason;
  final String? rescheduledFromBookingId;
  final String? usageDetails;
  final String? declineReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookingModel({
    required this.id,
    required this.listingId,
    required this.listingName,
    required this.listingType,
    required this.listingImageUrl,
    required this.farmerId,
    required this.farmerName,
    required this.farmerPhone,
    required this.ownerId,
    required this.ownerName,
    required this.startDate,
    required this.endDate,
    required this.pricePerDay,
    required this.totalPrice,
    required this.status,
    this.durationType = 'full_day',
    this.startTime,
    this.endTime,
    this.insuranceOpted = false,
    this.securityDeposit = 0,
    this.paymentStatus = 'pending',
    this.invoiceUrl,
    this.estimatedReturn,
    this.distanceKm,
    this.costEstimate,
    this.cancelledBy,
    this.cancelReason,
    this.rescheduledFromBookingId,
    this.usageDetails,
    this.declineReason,
    required this.createdAt,
    this.updatedAt,
  });

  int get durationDays => endDate.difference(startDate).inDays + 1;

  factory BookingModel.fromMap(Map<String, dynamic> m) => BookingModel(
        id: m['id'] as String,
        listingId: m['listing_id'] as String,
        listingName: m['listing_name'] ?? '',
        listingType: m['listing_type'] ?? '',
        listingImageUrl: m['listing_image_url'] ?? '',
        farmerId: m['farmer_id'] as String,
        farmerName: m['farmer_name'] ?? '',
        farmerPhone: m['farmer_phone'] ?? '',
        ownerId: m['owner_id'] as String,
        ownerName: m['owner_name'] ?? '',
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: DateTime.parse(m['end_date'] as String),
        pricePerDay: (m['price_per_day'] as num).toDouble(),
        totalPrice: (m['total_price'] as num).toDouble(),
        status: m['status'] ?? 'Pending',
        durationType: m['duration_type'] ?? 'full_day',
        startTime: m['start_time'] != null ? DateTime.parse(m['start_time'] as String) : null,
        endTime: m['end_time'] != null ? DateTime.parse(m['end_time'] as String) : null,
        insuranceOpted: m['insurance_opted'] ?? false,
        securityDeposit: (m['security_deposit'] as num?)?.toDouble() ?? 0,
        paymentStatus: m['payment_status'] ?? 'pending',
        invoiceUrl: m['invoice_url'],
        estimatedReturn: m['estimated_return'] != null ? DateTime.parse(m['estimated_return'] as String) : null,
        distanceKm: (m['distance_km'] as num?)?.toDouble(),
        costEstimate: (m['cost_estimate'] as num?)?.toDouble(),
        cancelledBy: m['cancelled_by'],
        cancelReason: m['cancel_reason'],
        rescheduledFromBookingId: m['rescheduled_from_booking_id'],
        usageDetails: m['usage_details'],
        declineReason: m['decline_reason'],
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null ? DateTime.parse(m['updated_at'] as String) : null,
      );

  Map<String, dynamic> toMap() => {
        'listing_id': listingId,
        'listing_name': listingName,
        'listing_type': listingType,
        'listing_image_url': listingImageUrl,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'farmer_phone': farmerPhone,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
        'price_per_day': pricePerDay,
        'total_price': totalPrice,
        'status': status,
        'duration_type': durationType,
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'insurance_opted': insuranceOpted,
        'security_deposit': securityDeposit,
        'payment_status': paymentStatus,
        'invoice_url': invoiceUrl,
        'estimated_return': estimatedReturn?.toIso8601String(),
        'distance_km': distanceKm,
        'cost_estimate': costEstimate,
        'cancelled_by': cancelledBy,
        'cancel_reason': cancelReason,
        'rescheduled_from_booking_id': rescheduledFromBookingId,
        'usage_details': usageDetails,
        'decline_reason': declineReason,
      };

  BookingModel copyWith({
    String? id,
    String? listingId,
    String? listingName,
    String? listingType,
    String? listingImageUrl,
    String? farmerId,
    String? farmerName,
    String? farmerPhone,
    String? ownerId,
    String? ownerName,
    DateTime? startDate,
    DateTime? endDate,
    double? pricePerDay,
    double? totalPrice,
    String? status,
    String? durationType,
    DateTime? startTime,
    DateTime? endTime,
    bool? insuranceOpted,
    double? securityDeposit,
    String? paymentStatus,
    String? invoiceUrl,
    DateTime? estimatedReturn,
    double? distanceKm,
    double? costEstimate,
    String? cancelledBy,
    String? cancelReason,
    String? rescheduledFromBookingId,
    String? usageDetails,
    String? declineReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listingName: listingName ?? this.listingName,
      listingType: listingType ?? this.listingType,
      listingImageUrl: listingImageUrl ?? this.listingImageUrl,
      farmerId: farmerId ?? this.farmerId,
      farmerName: farmerName ?? this.farmerName,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      durationType: durationType ?? this.durationType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      insuranceOpted: insuranceOpted ?? this.insuranceOpted,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      estimatedReturn: estimatedReturn ?? this.estimatedReturn,
      distanceKm: distanceKm ?? this.distanceKm,
      costEstimate: costEstimate ?? this.costEstimate,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelReason: cancelReason ?? this.cancelReason,
      rescheduledFromBookingId: rescheduledFromBookingId ?? this.rescheduledFromBookingId,
      usageDetails: usageDetails ?? this.usageDetails,
      declineReason: declineReason ?? this.declineReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ── ReviewModel ───────────────────────────────────────────────────────────────
class ReviewModel {
  final String id;
  final String bookingId;
  final String listingId;
  final String farmerId;
  final String farmerName;
  final String ownerId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.listingId,
    required this.farmerId,
    required this.farmerName,
    required this.ownerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> m) => ReviewModel(
        id: m['id'] as String,
        bookingId: m['booking_id'] as String,
        listingId: m['listing_id'] as String,
        farmerId: m['farmer_id'] as String,
        farmerName: m['farmer_name'] ?? '',
        ownerId: m['owner_id'] as String,
        rating: (m['rating'] as num).toDouble(),
        comment: m['comment'] ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'booking_id': bookingId,
        'listing_id': listingId,
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'owner_id': ownerId,
        'rating': rating,
        'comment': comment,
      };
}

// ── AppNotification ───────────────────────────────────────────────────────────
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: m['title'] ?? '',
        body: m['body'] ?? '',
        type: m['type'] ?? '',
        referenceId: m['reference_id'],
        isRead: m['is_read'] ?? false,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'reference_id': referenceId,
        'is_read': isRead,
      };
}

// ── WorkerProfile ────────────────────────────────────────────────────────────
class WorkerProfile {
  final String userId;
  final String fullName;
  final String phone;
  final List<String> skills;
  final String village;
  final double? latitude;
  final double? longitude;
  final double hourlyRate;
  final int experienceYears;
  final String primaryWorkType;
  final double preferredRadiusKm;
  final bool identityVerified;
  final bool isAvailable;
  final String bio;
  final DateTime updatedAt;

  WorkerProfile({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.skills,
    required this.village,
    this.latitude,
    this.longitude,
    required this.hourlyRate,
    this.experienceYears = 0,
    this.primaryWorkType = 'General Farm Work',
    this.preferredRadiusKm = 25,
    this.identityVerified = false,
    required this.isAvailable,
    required this.bio,
    required this.updatedAt,
  });

  factory WorkerProfile.fromMap(Map<String, dynamic> m) => WorkerProfile(
        userId: m['user_id'] as String,
        fullName: m['full_name'] ?? '',
        phone: m['phone'] ?? '',
        skills: List<String>.from(m['skills'] ?? const []),
        village: m['village'] ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        hourlyRate: (m['hourly_rate'] as num?)?.toDouble() ?? 0,
        experienceYears: m['experience_years'] ?? 0,
        primaryWorkType: m['primary_work_type'] ?? 'General Farm Work',
        preferredRadiusKm: (m['preferred_radius_km'] as num?)?.toDouble() ?? 25,
        identityVerified: m['identity_verified'] ?? false,
        isAvailable: m['is_available'] ?? true,
        bio: m['bio'] ?? '',
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'full_name': fullName,
        'phone': phone,
        'skills': skills,
        'village': village,
        'latitude': latitude,
        'longitude': longitude,
        'hourly_rate': hourlyRate,
        'experience_years': experienceYears,
        'primary_work_type': primaryWorkType,
        'preferred_radius_km': preferredRadiusKm,
        'identity_verified': identityVerified,
        'is_available': isAvailable,
        'bio': bio,
      };
}

// ── WorkerJobPost ────────────────────────────────────────────────────────────
class WorkerJobPost {
  final String id;
  final String farmerId;
  final String farmerName;
  final String title;
  final String description;
  final String village;
  final double? latitude;
  final double? longitude;
  final String workDate;
  final String wageType;
  final double wageAmount;
  final List<String> requiredSkills;
  final String status;
  final DateTime createdAt;
  double? distanceKm;

  WorkerJobPost({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    required this.title,
    required this.description,
    required this.village,
    this.latitude,
    this.longitude,
    required this.workDate,
    required this.wageType,
    required this.wageAmount,
    required this.requiredSkills,
    required this.status,
    required this.createdAt,
    this.distanceKm,
  });

  factory WorkerJobPost.fromMap(Map<String, dynamic> m) => WorkerJobPost(
        id: m['id'] as String,
        farmerId: m['farmer_id'] as String,
        farmerName: m['farmer_name'] ?? '',
        title: m['title'] ?? '',
        description: m['description'] ?? '',
        village: m['village'] ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        workDate: m['work_date'] ?? '',
        wageType: m['wage_type'] ?? 'day',
        wageAmount: (m['wage_amount'] as num?)?.toDouble() ?? 0,
        requiredSkills: List<String>.from(m['required_skills'] ?? const []),
        status: m['status'] ?? 'open',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'farmer_id': farmerId,
        'farmer_name': farmerName,
        'title': title,
        'description': description,
        'village': village,
        'latitude': latitude,
        'longitude': longitude,
        'work_date': workDate,
        'wage_type': wageType,
        'wage_amount': wageAmount,
        'required_skills': requiredSkills,
        'status': status,
      };
}

// ── WorkerApplication ────────────────────────────────────────────────────────
class WorkerApplication {
  final String id;
  final String jobId;
  final String workerId;
  final String workerName;
  final String status;
  final String? note;
  final DateTime createdAt;

  WorkerApplication({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory WorkerApplication.fromMap(Map<String, dynamic> m) => WorkerApplication(
        id: m['id'] as String,
        jobId: m['job_id'] as String,
        workerId: m['worker_id'] as String,
        workerName: m['worker_name'] ?? '',
        status: m['status'] ?? 'applied',
        note: m['note'],
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'job_id': jobId,
        'worker_id': workerId,
        'worker_name': workerName,
        'status': status,
        'note': note,
      };
}

// ── WorkerMessage ────────────────────────────────────────────────────────────
class WorkerMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String receiverId;
  final String body;
  final DateTime createdAt;

  WorkerMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.createdAt,
  });

  factory WorkerMessage.fromMap(Map<String, dynamic> m) => WorkerMessage(
        id: m['id'] as String,
        jobId: m['job_id'] as String,
        senderId: m['sender_id'] as String,
        receiverId: m['receiver_id'] as String,
        body: m['body'] ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'job_id': jobId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'body': body,
      };
}
