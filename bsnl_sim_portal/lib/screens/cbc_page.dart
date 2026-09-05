import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import 'records_page.dart';

class CbcPage extends StatelessWidget {
  const CbcPage({super.key, required this.auth, this.locationId, this.locationName, this.nested = false});
  final AuthStore auth;
  final int? locationId;
  final String? locationName;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return RecordsPage(
      auth: auth,
      title: 'CBP List',
      path: '/api/cbp',
      locationId: locationId,
      locationName: locationName,
      nested: nested,
      commissionModule: 'cbp',
      fields: const [
        RecordField('date', 'Date', kind: RecordFieldKind.date),
        RecordField('name', 'Name'),
        RecordField('mobile', 'Mobile Number'),
        RecordField('landline', 'Landline No.'),
        RecordField('amount', 'Amount', keyboard: TextInputType.numberWithOptions(decimal: true)),
        RecordField('balance', 'Balance', kind: RecordFieldKind.actualBalance),
        RecordField('commission', 'Commission', kind: RecordFieldKind.commission),
        RecordField('transactionId', 'Transaction ID'),
        RecordField('note', 'Note'),
      ],
    );
  }
}
