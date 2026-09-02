import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import 'records_page.dart';

class CbcPage extends StatelessWidget {
  const CbcPage({super.key, required this.auth, this.locationId, this.locationName});
  final AuthStore auth;
  final int? locationId;
  final String? locationName;

  @override
  Widget build(BuildContext context) {
    return RecordsPage(
      auth: auth,
      title: 'CBC List',
      path: '/api/cbc',
      locationId: locationId,
      locationName: locationName,
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
