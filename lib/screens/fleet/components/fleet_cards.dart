import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../models/hrm_fleet_models.dart';

String getVietnameseWeekday(DateTime dt) {
  switch (dt.weekday) {
    case DateTime.monday:
      return 'fleet.weekday.mon'.tr();
    case DateTime.tuesday:
      return 'fleet.weekday.tue'.tr();
    case DateTime.wednesday:
      return 'fleet.weekday.wed'.tr();
    case DateTime.thursday:
      return 'fleet.weekday.thu'.tr();
    case DateTime.friday:
      return 'fleet.weekday.fri'.tr();
    case DateTime.saturday:
      return 'fleet.weekday.sat'.tr();
    case DateTime.sunday:
    default:
      return 'fleet.weekday.sun'.tr();
  }
}

bool isBookingOnDay(HrmFleetBooking b, DateTime day) {
  final startDay = DateTime(b.startAt.year, b.startAt.month, b.startAt.day);
  final endDay = DateTime(b.endAt.year, b.endAt.month, b.endAt.day);
  final targetDay = DateTime(day.year, day.month, day.day);
  return (targetDay.isAtSameMomentAs(startDay) || targetDay.isAfter(startDay)) &&
      (targetDay.isAtSameMomentAs(endDay) || targetDay.isBefore(endDay));
}

bool isBookingForVehicle(HrmFleetBooking b, HrmFleetVehicle v) {
  if (b.vehicleId.isNotEmpty && b.vehicleId == v.id) return true;
  if (b.vehiclePlateNo.isNotEmpty &&
      b.vehiclePlateNo.replaceAll('.', '').replaceAll('-', '').toLowerCase() ==
          v.plateNo.replaceAll('.', '').replaceAll('-', '').toLowerCase()) {
    return true;
  }
  return false;
}

class FleetTimelineMatrix extends StatelessWidget {
  final List<HrmFleetVehicle> vehicles;
  final List<HrmFleetBooking> bookings;
  final DateTime timelineStartDate;
  final int selectedSpanDays;
  final void Function(HrmFleetBooking b) onTapBooking;

  const FleetTimelineMatrix({
    super.key,
    required this.vehicles,
    required this.bookings,
    required this.timelineStartDate,
    required this.selectedSpanDays,
    required this.onTapBooking,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text('fleet.schedule.no_match_filter'.tr(), style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysList = List.generate(selectedSpanDays, (i) => timelineStartDate.add(Duration(days: i)));

    const double vehicleColWidth = 110.0;
    const double dayColWidth = 66.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER ROW
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
              ),
              child: Row(
                children: [
                  // Vehicle Header Column
                  Container(
                    width: vehicleColWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'fleet.timeline.vehicle_col'.tr(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(width: 1, height: 38, color: const Color(0xFFE2E8F0)),
                  // Day Columns
                  ...daysList.map((day) {
                    final isToday = day.isAtSameMomentAs(today);
                    return Container(
                      width: dayColWidth,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFFEFF6FF) : Colors.transparent,
                        border: Border(
                          right: const BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: isToday ? const BorderSide(color: Color(0xFF2563EB), width: 2) : BorderSide.none,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            getVietnameseWeekday(day),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                              color: isToday ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${day.day}/${day.month}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isToday ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // VEHICLE ROWS
            ...vehicles.map((v) {
              return Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Vehicle Info Cell
                    Container(
                      width: vehicleColWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            v.name,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'fleet.vehicle.plate_seats'.tr(args: {'plate': v.plateNo, 'seats': v.seats}),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 50, color: const Color(0xFFE2E8F0)),
                    // Day Schedule Cells
                    ...daysList.map((day) {
                      final dayBookings = bookings.where((b) => isBookingForVehicle(b, v) && isBookingOnDay(b, day)).toList();
                      final isToday = day.isAtSameMomentAs(today);

                      Widget cellContent;
                      if (dayBookings.isEmpty) {
                        cellContent = Container(
                          width: dayColWidth,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? const Color(0xFFF8FAFC) : Colors.white,
                            border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                        );
                      } else {
                        final b = dayBookings.first;
                        final isConfirmed = b.status == 'IN_PROGRESS' || b.status == 'COMPLETED';
                        final cellBg = isConfirmed ? const Color(0xFFF97316) : const Color(0xFFFEF3C7);
                        final cellBorder = isConfirmed ? const Color(0xFFEA580C) : const Color(0xFFF59E0B);
                        final textColor = isConfirmed ? Colors.white : const Color(0xFF92400E);

                        cellContent = InkWell(
                          onTap: () => onTapBooking(b),
                          child: Container(
                            width: dayColWidth,
                            height: 50,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isToday ? const Color(0xFFF8FAFC) : Colors.white,
                              border: const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: double.infinity,
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              decoration: BoxDecoration(
                                color: cellBg,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: cellBorder, width: 0.8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                b.purpose?.trim().isNotEmpty == true
                                    ? b.purpose!
                                    : (b.destination?.trim().isNotEmpty == true ? b.destination! : (isConfirmed ? 'fleet.booking.approved'.tr() : 'fleet.booking.reserved'.tr())),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  height: 1.1,
                                ),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      }
                      return cellContent;
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class FleetVehicleCard extends StatelessWidget {
  final HrmFleetVehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const FleetVehicleCard({
    super.key,
    required this.vehicle,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = vehicle.status == 'ACTIVE';
    final subtitleParts = <String>[
      vehicle.plateNo,
      'fleet.vehicle.seats_count'.tr(args: {'seats': vehicle.seats}),
      if (vehicle.note != null && vehicle.note!.trim().isNotEmpty) vehicle.note!.trim(),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          vehicle.name,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAvailable ? 'fleet.status.in_use'.tr() : 'fleet.status.out_of_use'.tr(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitleParts.join(' · '),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                  label: Text('fleet.action.edit'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onToggleStatus,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isAvailable ? 'fleet.status.out_of_use'.tr() : 'fleet.action.reactivate'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAvailable ? const Color(0xFF475569) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FleetDriverCard extends StatelessWidget {
  final HrmFleetDriver driver;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;

  const FleetDriverCard({
    super.key,
    required this.driver,
    required this.onEdit,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = driver.status == 'ACTIVE';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    driver.employeeName?.isNotEmpty == true ? driver.employeeName![0].toUpperCase() : 'T',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          driver.employeeName ?? 'fleet.driver.default_name'.tr(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAvailable ? 'fleet.status.in_use'.tr() : 'fleet.status.out_of_use'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'fleet.driver.code_license'.tr(args: {'code': driver.employeeCode ?? "—", 'license': driver.licenseNo ?? "—"}),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF334155)),
                  label: Text('fleet.action.edit'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onToggleStatus,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isAvailable ? 'fleet.status.out_of_use'.tr() : 'fleet.action.reactivate'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAvailable ? const Color(0xFF475569) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
