/// Quyền giao diện của module Kho (web `GET /capabilities` → `InventoryPermissionsContext`).
/// Chỉ để ẩn/hiện nút; mọi thao tác vẫn được API kiểm tra lại.
class InventoryCapabilities {
  final bool canManage;
  final bool canWriteTransactions;
  final bool canWriteQuality;
  final bool canApproveDocuments;
  final bool canCreateStocktake;
  final bool canApproveStocktake;

  const InventoryCapabilities({
    this.canManage = false,
    this.canWriteTransactions = false,
    this.canWriteQuality = false,
    this.canApproveDocuments = false,
    this.canCreateStocktake = false,
    this.canApproveStocktake = false,
  });

  static const none = InventoryCapabilities();

  factory InventoryCapabilities.fromJson(Map<String, dynamic> json) => InventoryCapabilities(
        canManage: json['canManage'] == true,
        canWriteTransactions: json['canWriteTransactions'] == true,
        canWriteQuality: json['canWriteQuality'] == true,
        canApproveDocuments: json['canApproveDocuments'] == true,
        canCreateStocktake: json['canCreateStocktake'] == true,
        canApproveStocktake: json['canApproveStocktake'] == true,
      );
}
