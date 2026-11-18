import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/repositories/catalog_repository.dart';
import '../domain/services/catalog_service.dart';
import '../domain/services/report_service.dart';
import '../domain/services/transaction_service.dart';

class HesabServices {
  HesabServices(Database database)
    : catalog = CatalogService(CatalogRepository(database)),
      transactions = TransactionService(database),
      reports = ReportService(database);

  final CatalogService catalog;
  final TransactionService transactions;
  final ReportService reports;
}
