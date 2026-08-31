import '../models/sim_entry.dart';

String iccid(int n) => '899159604459149${n.toString().padLeft(4, '0')}';
String last6(int n) => n == 50 ? '459149' : '4900${n.toString().padLeft(2, '0')}';

final List<SimEntry> seedEntries = [
  e('21/8/26', 1, 'Baldev Singh Poonia', '', '1', SimType.cymn, '9461425901', 50),
  e('21/8/26', 2, 'Vijay Kumar Bajaj', '', '1', SimType.cymn, '9530202975', 51),
  e('21/8/26', 3, 'Bhim Raj', '', '1', SimType.cymn, '9462097966', 52),
  e('25/8/26', 4, 'Moti Lal', '9694838598', '1', SimType.cymn, '9461395438', 53),
  e('25/8/26', 5, 'Toda Ram Saini', '', '1', SimType.cymn, '9461995329', 54),
  e('25/8/26', 6, 'Rajendra Hadawal', '', '1', SimType.mnp, '7340216729', 55),
  e('25/8/26', 8, 'Shyam Lal', '', '', SimType.swap, '9784886599', 56),
  e('25/8/26', 9, 'Sohan Lal', '9462082437', '', SimType.cymn, '6377830060', 57),
  e('26/8/26', 10, 'Pradeep Kumar', '', '1', SimType.mnp, '9636278348', 58),
  e('26/8/26', 11, 'Rakesh Kumar', '', '1', SimType.mnp, '8696640961', 59),
  e('26/8/26', 12, 'Vishal', '', '1', SimType.cymn, '8764279697', 60),
  e('27/8/26', 13, 'Suresh Jat', '', '2', SimType.cymn, '9468838193', 61),
  e('27/8/26', 14, 'Ramesh Saini', '', '1', SimType.cymn, '9462168189', 62),
  e('27/8/26', 15, 'Jagdish Prasad', '', '2', SimType.cymn, '7597147590', 63),
  e('27/8/26', 16, 'Kailash Verma', '', '2', SimType.cymn, '9468894918', 64),
  e('27/8/26', 17, 'Sawarmal Sen', '', '2', SimType.cymn, '7597277321', 65),
  e('27/8/26', 18, 'Bantesh Kumar', '', '1', SimType.cymn, '9468807179', 66),
  e('27/8/26', 19, 'Sher Singh', '', '2', SimType.cymn, '8764972374', 67),
  e('29/8/26', 20, 'Damodar', '8764838467', '', SimType.cymn, '8764838467', 68),
  e('29/8/26', 21, 'Rajendra Prasad Kulhariya', '', '', SimType.postpaid, '9460134738', 69),
];

SimEntry e(
  String date,
  int sno,
  String name,
  String alt,
  String frc,
  SimType type,
  String mobile,
  int n,
) {
  return SimEntry(
    date: date,
    sno: sno,
    name: name,
    altNumber: alt,
    frc: frc,
    type: type,
    mobile: mobile,
    simNo: iccid(n),
    simLast6: last6(n),
  );
}
