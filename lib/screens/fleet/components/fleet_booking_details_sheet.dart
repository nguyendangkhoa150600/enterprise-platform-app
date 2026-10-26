import 'package:flutter/material.dart';
import '../../../core/i18n/app_i18n.dart';
import 'package:intl/intl.dart';
import '../../../models/hrm_fleet_models.dart';

Widget buildFleetDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

void showFleetBookingDetailsSheet({
  required BuildContext context,
  required HrmFleetBooking booking,
}) {
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('fleet.booking.detail_title'.tr(args: {'id': booking.id}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(booking.sourceLabel ?? 'fleet.booking.default_source'.tr(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          const Divider(height: 24),
          buildFleetDetailRow('fleet.booking.vehicle'.tr(), '${booking.vehicleName} (${booking.vehiclePlateNo})'),
          buildFleetDetailRow('fleet.booking.driver'.tr(), booking.driverName ?? 'fleet.booking.unassigned'.tr()),
          buildFleetDetailRow('fleet.booking.departure'.tr(), dateFormat.format(booking.startAt)),
          buildFleetDetailRow('fleet.booking.expected_return'.tr(), dateFormat.format(booking.endAt)),
          buildFleetDetailRow('fleet.booking.destination'.tr(), booking.destination ?? '—'),
          buildFleetDetailRow('fleet.booking.purpose'.tr(), booking.purpose ?? '—'),
          buildFleetDetailRow('common.status'.tr(), booking.status == 'BOOKED' ? 'fleet.booking.scheduled'.tr() : booking.status),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text('common.close'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );
}
