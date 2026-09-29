import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/formatters/currency_formatter.dart';
import '../../data/models/prosthetic_case_data.dart';

/// One-page PDF summary of a prosthetic case — the `[🖨]` action on the
/// case detail screen. Handed to `Printing.layoutPdf`/`sharePdf`, which
/// covers both "print" and "export" via the platform's own dialog.
///
/// Uses the bundled Inter font rather than the `pdf` package's Helvetica
/// default: Helvetica (base14, ASCII-only) can't render "€" or "—", which
/// this document needs for every currency amount.
Future<Uint8List> buildProstheticCasePdf(ProstheticCaseData c) async {
  final dateFmt = DateFormat('dd/MM/yyyy');
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Dossier prothétique',
              style: const pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(c.patientReference,
                style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            _section('Informations cliniques', [
              ('Statut', c.status.label),
              ('Praticien', c.practitionerName),
              ('Type d\'empreinte', c.impressionType.label),
              ('Type de travail', c.workType.label),
              ('Date d\'empreinte', dateFmt.format(c.impressionDate)),
              if (c.laboratoryName != null) ('Laboratoire', c.laboratoryName!),
              if (c.sentToLabDate != null)
                ('Envoyé le', dateFmt.format(c.sentToLabDate!)),
              if (c.returnedFromLabDate != null)
                ('Reçu le', dateFmt.format(c.returnedFromLabDate!)),
              if (c.plannedPlacementDate != null)
                ('Pose prévue', dateFmt.format(c.plannedPlacementDate!)),
              if (c.actualPlacementDate != null)
                ('Posé le', dateFmt.format(c.actualPlacementDate!)),
              if (c.priority != null) ('Priorité', c.priority!),
            ]),
            pw.SizedBox(height: 20),
            _section('Administratif & paiement', [
              ('Acompte demandé', c.depositRequested ? 'Oui' : 'Non'),
              ('Acompte reçu', c.depositReceived ? 'Oui' : 'Non'),
              if (c.depositAmount != null)
                (
                  'Montant de l\'acompte',
                  AppCurrencyFormatter.eur(c.depositAmount!)
                ),
              (
                'Paiement final effectué',
                c.finalPaymentCompleted ? 'Oui' : 'Non'
              ),
              if (c.remainingBalance != null)
                (
                  'Solde restant',
                  AppCurrencyFormatter.eur(c.remainingBalance!)
                ),
            ]),
            if (c.notes != null && c.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _section('Remarques', [('', c.notes!)]),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())} — SteryMed',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

pw.Widget _section(String title, List<(String, String)> rows) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: const pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      ),
      pw.SizedBox(height: 8),
      for (final (label, value) in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: label.isEmpty
              ? pw.Text(value, style: const pw.TextStyle(fontSize: 11))
              : pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 160,
                      child: pw.Text(label,
                          style: const pw.TextStyle(fontSize: 11)),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        value,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
    ],
  );
}
