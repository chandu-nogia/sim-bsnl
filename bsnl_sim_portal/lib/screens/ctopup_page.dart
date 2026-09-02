import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import 'records_page.dart';

class CtopupPage extends StatelessWidget {
  const CtopupPage({super.key, required this.auth, this.locationId, this.locationName});
  final AuthStore auth;
  final int? locationId;
  final String? locationName;

  @override
  Widget build(BuildContext context) {
    return RecordsPage(
      auth: auth,
      title: 'CTopup',
      path: '/api/ctopup',
      locationId: locationId,
      locationName: locationName,
      fields: const [
        RecordField('date', 'Date', kind: RecordFieldKind.date),
        RecordField('name', 'Name'),
        RecordField('number', 'Number', keyboard: TextInputType.phone),
        RecordField('amount', 'Amount', keyboard: TextInputType.number),
        RecordField('status', 'Status of payment', kind: RecordFieldKind.choice, options: [
          'Pending',
          'Paid',
          'Failed',
        ]),
      ],
    );
  }
}
