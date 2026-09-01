import 'package:flutter/material.dart';

import '../state/auth_store.dart';
import 'records_page.dart';

class CtopupPage extends StatelessWidget {
  const CtopupPage({super.key, required this.auth});
  final AuthStore auth;

  @override
  Widget build(BuildContext context) {
    return RecordsPage(
      auth: auth,
      title: 'CTopup',
      path: '/api/ctopup',
      fields: const [
        RecordField('name', 'Name'),
        RecordField('number', 'Number', keyboard: TextInputType.phone),
        RecordField('amount', 'Amount', keyboard: TextInputType.number),
        RecordField('status', 'Status of payment'),
      ],
    );
  }
}
