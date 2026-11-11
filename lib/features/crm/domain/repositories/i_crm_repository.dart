import '../models/crm_models.dart';

abstract class ICrmRepository {
  Future<CrmStatus?> getCrmStatus();
  Future<CrmDashboard> getCrmDashboard({String period = 'month'});
  Future<List<CrmCustomerSummary>> getCustomers({String? search});
  Future<List<CrmOpportunitySummary>> getOpportunities({String? stage, String? search});
  Future<List<CrmQuoteSummary>> getQuotes({String? status, String? search});
  Future<List<CrmLeadSummary>> getLeads({String? status, String? search});
}
