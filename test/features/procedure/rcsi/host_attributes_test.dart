// Port 1:1 `components/rcsi/host-attributes.spec.ts` (web).
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/procedure_host_attributes.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/vietnamese_text.dart';

void main() {
  group('procedure-host-attributes', () {
    test('tra mã không phân biệt hoa thường', () {
      expect(lookupHostAttribute(' So_Ngay_Nghi ')?.fieldLabel, 'số ngày nghỉ');
    });
    test('mã lạ hoặc rỗng trả null', () {
      expect(lookupHostAttribute('gia_tri_bao_gia'), isNull);
      expect(lookupHostAttribute(''), isNull);
      expect(lookupHostAttribute(null), isNull);
      expect(hostAttributeSourceLabel('khac'), isNull);
    });
    test('tạo nhãn nguồn', () {
      expect(hostAttributeSourceLabel('so_tien'), 'Lấy từ đơn HRM: số tiền');
    });
    test('mã không trùng và đủ 21 mã', () {
      expect(procedureHostAttributes.map((i) => i.code).toSet().length, procedureHostAttributes.length);
      expect(procedureHostAttributes, hasLength(21));
    });
    test('gom nhóm theo loại đơn', () {
      final groups = groupHostAttributesByKind();
      expect(groups.fold<int>(0, (n, g) => n + g.items.length), procedureHostAttributes.length);
      expect(groups[0].kind, 'leave');
    });
  });

  group('chữ tiếng Việt', () {
    test('bỏ dấu', () {
      expect(foldVietnamese('  Trưởng Phòng Đào tạo '), 'truong phong dao tao');
    });
    test('so sánh theo bảng chữ cái tiếng Việt', () {
      final names = ['Đội', 'Dương', 'Ánh', 'Ăn', 'An', 'Bình'];
      stableSort<String>(names, compareVietnamese);
      expect(names, ['An', 'Ánh', 'Ăn', 'Bình', 'Dương', 'Đội']);
    });
  });
}
