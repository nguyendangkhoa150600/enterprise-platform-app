class HrmFleetVehicle {
  final String id;
  final String plateNo;
  final String name;
  final int seats;
  final String status; // 'ACTIVE' | 'INACTIVE' | 'MAINTENANCE'
  final String? note;

  const HrmFleetVehicle({
    required this.id,
    required this.plateNo,
    required this.name,
    required this.seats,
    required this.status,
    this.note,
  });

  factory HrmFleetVehicle.fromJson(Map<String, dynamic> json) {
    return HrmFleetVehicle(
      id: json['id']?.toString() ?? '',
      plateNo: json['plateNo']?.toString() ?? json['plate_no']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Xe cơ quan',
      seats: (json['seats'] as num?)?.toInt() ?? 5,
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plateNo': plateNo,
    'name': name,
    'seats': seats,
    'status': status,
    'note': note,
  };
}

class HrmFleetDriver {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String? licenseNo;
  final String status; // 'ACTIVE' | 'INACTIVE'

  const HrmFleetDriver({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.licenseNo,
    required this.status,
  });

  factory HrmFleetDriver.fromJson(Map<String, dynamic> json) {
    return HrmFleetDriver(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString(),
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString(),
      licenseNo: json['licenseNo']?.toString() ?? json['license_no']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employeeId': employeeId,
    'employeeName': employeeName,
    'employeeCode': employeeCode,
    'licenseNo': licenseNo,
    'status': status,
  };
}

class HrmFleetBooking {
  final String id;
  final String vehicleId;
  final String vehiclePlateNo;
  final String vehicleName;
  final String driverId;
  final String? driverName;
  final DateTime startAt;
  final DateTime endAt;
  final String? destination;
  final String? purpose;
  final String sourceModule;
  final String sourceType; // 'BUSINESS_TRIP' | 'CUSTOM_REQUEST' | 'WORK_ITEM' | 'CALENDAR_EVENT' | 'INCIDENT'
  final String sourceId;
  final String? sourceLabel;
  final String status; // 'BOOKED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED'

  const HrmFleetBooking({
    required this.id,
    required this.vehicleId,
    required this.vehiclePlateNo,
    required this.vehicleName,
    required this.driverId,
    this.driverName,
    required this.startAt,
    required this.endAt,
    this.destination,
    this.purpose,
    this.sourceModule = 'hrm',
    this.sourceType = 'BUSINESS_TRIP',
    required this.sourceId,
    this.sourceLabel,
    required this.status,
  });

  factory HrmFleetBooking.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback;
    }

    return HrmFleetBooking(
      id: json['id']?.toString() ?? '',
      vehicleId: json['vehicleId']?.toString() ?? json['vehicle_id']?.toString() ?? '',
      vehiclePlateNo: json['vehiclePlateNo']?.toString() ?? json['vehicle_plate_no']?.toString() ?? '',
      vehicleName: json['vehicleName']?.toString() ?? json['vehicle_name']?.toString() ?? 'Xe cơ quan',
      driverId: json['driverId']?.toString() ?? json['driver_id']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? json['driver_name']?.toString(),
      startAt: parseDate(json['startAt'] ?? json['start_at'], DateTime.now()),
      endAt: parseDate(json['endAt'] ?? json['end_at'], DateTime.now().add(const Duration(hours: 4))),
      destination: json['destination']?.toString(),
      purpose: json['purpose']?.toString(),
      sourceModule: json['sourceModule']?.toString() ?? json['source_module']?.toString() ?? 'hrm',
      sourceType: json['sourceType']?.toString() ?? json['source_type']?.toString() ?? 'BUSINESS_TRIP',
      sourceId: json['sourceId']?.toString() ?? json['source_id']?.toString() ?? '',
      sourceLabel: json['sourceLabel']?.toString() ?? json['source_label']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'BOOKED',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'vehiclePlateNo': vehiclePlateNo,
    'vehicleName': vehicleName,
    'driverId': driverId,
    'driverName': driverName,
    'startAt': startAt.toIso8601String(),
    'endAt': endAt.toIso8601String(),
    'destination': destination,
    'purpose': purpose,
    'sourceModule': sourceModule,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'sourceLabel': sourceLabel,
    'status': status,
  };
}
