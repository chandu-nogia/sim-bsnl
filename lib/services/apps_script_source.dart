/// Paste this into Google Sheet → Extensions → Apps Script, then Deploy → Web app.
const kAppsScriptSource = r'''
const SHEET_NAME = 'SIM Register';
const HEADERS = ['Date','S.No.','Name','Alternate Number','FRC','Type','Mobile Number','SIM No.','SIM Last 6','Status'];

function doGet(e) {
  const p = (e && e.parameter) ? e.parameter : {};
  const action = (p.action || 'list').toLowerCase();
  let out;
  try {
    if (action === 'ping') out = { ok: true, message: 'BSNL SIM portal connected' };
    else if (action === 'list') out = { ok: true, rows: listRows_() };
    else if (action === 'add') out = addRow_(p);
    else if (action === 'update') out = updateRow_(p);
    else if (action === 'delete') out = deleteRow_(p);
    else out = { ok: false, error: 'Unknown action: ' + action };
  } catch (err) {
    out = { ok: false, error: String(err) };
  }
  const body = JSON.stringify(out);
  const cb = p.callback;
  if (cb) {
    return ContentService.createTextOutput(cb + '(' + body + ')')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(body)
    .setMimeType(ContentService.MimeType.JSON);
}

function getSheet_() {
  const ss = SpreadsheetApp.getActive();
  let sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) sh = ss.insertSheet(SHEET_NAME);
  const first = sh.getRange(1, 1, 1, HEADERS.length).getValues()[0];
  if (String(first[0]).trim() !== 'Date') {
    sh.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
    sh.getRange(1, 1, 1, HEADERS.length)
      .setFontWeight('bold')
      .setBackground('#0B3D91')
      .setFontColor('#FFFFFF');
    sh.setFrozenRows(1);
    sh.autoResizeColumns(1, HEADERS.length);
  }
  return sh;
}

function rowValues_(p) {
  return [
    p.date || '',
    p.sno || '',
    p.name || '',
    p.alt || '',
    p.frc || '',
    p.type || '',
    p.mobile || '',
    p.sim || '',
    p.last6 || '',
    p.status || 'Issued',
  ];
}

function parseRowIndex_(p) {
  const row = parseInt(p.rowIndex, 10);
  if (!row || row < 2) throw 'Invalid rowIndex';
  return row;
}

function listRows_() {
  const sh = getSheet_();
  const last = sh.getLastRow();
  if (last < 2) return [];
  const values = sh.getRange(2, 1, last - 1, HEADERS.length).getValues();
  const out = [];
  for (let i = 0; i < values.length; i++) {
    const r = values[i];
    if (String(r[2]).trim() === '' && String(r[6]).trim() === '') continue;
    out.push({
      date: fmt_(r[0]),
      sno: String(r[1]),
      name: String(r[2]),
      alt: String(r[3]),
      frc: String(r[4]),
      type: String(r[5]),
      mobile: String(r[6]),
      sim: String(r[7]),
      last6: String(r[8]),
      status: String(r[9] || 'Issued'),
      rowIndex: i + 2,
    });
  }
  return out;
}

function addRow_(p) {
  const sh = getSheet_();
  sh.appendRow(rowValues_(p));
  return { ok: true, sno: p.sno, name: p.name };
}

function updateRow_(p) {
  const sh = getSheet_();
  const row = parseRowIndex_(p);
  sh.getRange(row, 1, 1, HEADERS.length).setValues([rowValues_(p)]);
  return { ok: true, rowIndex: row, sno: p.sno, name: p.name };
}

function deleteRow_(p) {
  const sh = getSheet_();
  const row = parseRowIndex_(p);
  sh.deleteRow(row);
  return { ok: true, rowIndex: row };
}

function fmt_(v) {
  if (Object.prototype.toString.call(v) === '[object Date]' && !isNaN(v)) {
    return v.getDate() + '/' + (v.getMonth() + 1) + '/' + String(v.getFullYear()).slice(-2);
  }
  return String(v == null ? '' : v);
}
''';
