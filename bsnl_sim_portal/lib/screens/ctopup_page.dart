import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import 'records_page.dart';

class CtopupPage extends StatelessWidget {
  const CtopupPage({super.key, required this.auth, this.locationId, this.locationName, this.nested = false});
  final AuthStore auth;
  final int? locationId;
  final String? locationName;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return RecordsPage(
      auth: auth,
      title: 'C-TopUp',
      path: '/api/ctopup',
      locationId: locationId,
      locationName: locationName,
      nested: nested,
      commissionModule: 'ctopup',
      fields: const [
        RecordField('date', 'Date', kind: RecordFieldKind.date),
        RecordField('name', 'Name'),
        RecordField('number', 'Mobile Number'),
        RecordField('type', 'Type', kind: RecordFieldKind.choice, options: [
          'Recharge',
          'Activation',
          'Replacement',
          'Port',
          'Other',
        ]),
        RecordField('amount', 'Amount', keyboard: TextInputType.numberWithOptions(decimal: true)),
        RecordField('balance', 'BSNL remaining (optional)', kind: RecordFieldKind.actualBalance),
        RecordField('commission', 'Commission', kind: RecordFieldKind.commission),
        RecordField('transactionId', 'Txn / Reference'),
        RecordField('status', 'Status of payment', kind: RecordFieldKind.choice, options: [
          'Pending',
          'Paid',
          'Failed',
        ]),
        RecordField('note', 'Remark / Notes'),
      ],
    );
  }
}
