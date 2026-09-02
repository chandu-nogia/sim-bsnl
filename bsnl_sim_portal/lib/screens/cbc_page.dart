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
      title: 'CBC List',
      path: '/api/cbc',
      locationId: locationId,
      locationName: locationName,
      nested: nested,
      fields: const [
        RecordField('date', 'Date', kind: RecordFieldKind.date),
        RecordField('name', 'Name'),
        RecordField('mobile', 'Mobile Number', keyboard: TextInputType.phone),
        RecordField('landline', 'Landline No.', keyboard: TextInputType.phone),
        RecordField('amount', 'Amount', keyboard: TextInputType.number),
        RecordField('transactionId', 'Transaction ID'),
      ],
    );
  }
}
