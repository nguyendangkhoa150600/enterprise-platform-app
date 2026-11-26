// Logic của `components/rcsi/attribute-editor.tsx` (web): mã, chuyển dòng, kiểm tra.
import 'package:flutter_test/flutter_test.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/logic/rcsi_attribute_rows.dart';
import 'package:power_quality_analysis/features/procedure/rcsi/domain/rcsi_flow_models.dart';

void main() {
  group('attributeCodeFrom', () {
    test('bỏ dấu tiếng Việt, gạch dưới thay khoảng trắng', () {
      expect(attributeCodeFrom('Giá trị báo giá'), 'gia_tri_bao_gia');
      expect(attributeCodeFrom('Đơn vị đề xuất'), 'don_vi_de_xuat');
      expect(attributeCodeFrom('  Số tiền (VNĐ)  '), 'so_tien_vnd');
    });

    test('không bắt đầu bằng chữ thì thêm tt_', () {
      expect(attributeCodeFrom('2 lần'), 'tt_2_lan');
      expect(attributeCodeFrom(''), 'tt_');
    });

    test('cắt tối đa 60 ký tự', () {
      expect(attributeCodeFrom('a' * 80).length, 60);
      expect(attributeCodeFrom('1${'a' * 80}').length, 60);
    });
  });

  test('dòng ⇄ định nghĩa: lựa chọn sinh mã, trùng thì thêm hậu tố; entryStepKeys rỗng bỏ đi', () {
    const saved = [
      ProcedureAttributeDefinition(
        id: 'a1',
        code: 'loai_kh',
        name: 'Loại KH',
        type: 'select',
        required: true,
        options: [ProcedureAttributeOption(code: 'moi', label: 'Mới')],
        entryStepKeys: ['B1'],
      ),
    ];
    final rows = attributeRowsFrom(saved);
    expect(rows.single.locked, isTrue);
    expect(rows.single.optionsText, 'Mới');

    final edited = [
      rows.single.copyWith(optionsText: 'Khách hàng mới\n\n Khách hàng mới \nKhách hàng cũ', entryStepKeys: const []),
      RcsiAttributeRow.blank(1).copyWith(name: ' Ghi chú ', type: 'text', optionsText: 'bỏ qua'),
    ];
    final result = attributeDefinitionsFrom(edited);
    expect(result[0].options!.map((item) => item.code), ['khach_hang_moi', 'khach_hang_moi_2', 'khach_hang_cu']);
    expect(result[0].entryStepKeys, isNull);
    expect(result[1].code, 'tt_2');
    expect(result[1].name, 'Ghi chú');
    expect(result[1].options, isNull);
    expect(result[1].id, '');
  });

  group('validateAttributeRows', () {
    RcsiAttributeRow row(String code, {String name = 'Tên', String type = 'text', String options = ''}) =>
        RcsiAttributeRow.blank(0).copyWith(code: code, name: name, type: type, optionsText: options);

    test('thứ tự lỗi như web', () {
      expect(validateAttributeRows([row('a', name: '  ')])!.key, endsWith('name_required'));
      expect(validateAttributeRows([row('1a')])!.key, endsWith('code_invalid'));
      expect(validateAttributeRows([row('Ma'), row('ma')])!.key, endsWith('code_duplicate'));
      expect(validateAttributeRows([row('ma', type: 'select', options: ' \n ')])!.args['name'], 'Tên');
      expect(validateAttributeRows([row('ma', type: 'select', options: 'A')]), isNull);
      expect(validateAttributeRows(const []), isNull);
    });
  });

  test('addEntryStepKey giữ thứ tự bước', () {
    expect(addEntryStepKey(['B3'], 'B1', ['B1', 'B2', 'B3']), ['B1', 'B3']);
  });
}
