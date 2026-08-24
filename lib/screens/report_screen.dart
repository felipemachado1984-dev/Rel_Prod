import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/producao.dart';

class ReportScreen extends StatelessWidget {
  final Producao producao;

  ReportScreen({required this.producao});

  Future<void> _exportarPDF(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              pw.Container(
                width: double.infinity,
                padding: pw EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Relatório de Produção',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        )),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Text('🏭 Máquina ${producao.maquina}',
                            style: pw.TextStyle(color: PdfColors.white)),
                        pw.SizedBox(width: 16),
                        pw.Text('📅 ${producao.data}',
                            style: pw.TextStyle(color: PdfColors.white)),
                        pw.SizedBox(width: 16),
                        pw.Text('👤 ${producao.operador}',
                            style: pw.TextStyle(color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Tabela
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      'Campo', 'T1', 'T2', 'T3', 'T4',
                      'T1', 'T2', 'T3', 'T4'
                    ].map((h) => pw.Padding(
                      padding: pw EdgeInsets.all(4),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          )),
                    )).toList(),
                  ),
                  // Dados
                  for (int i = 1; i <= 6; i++) ...[
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: pw EdgeInsets.all(4),
                          child: pw.Text('Posição $i',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                        for (int j = 0; j < 8; j++)
                          pw.Padding(padding: pw EdgeInsets.all(4)),
                      ],
                    ),
                    // Tempo rompido
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw EdgeInsets.all(4),
                          child: pw.Text('Tempo rompido (min)',
                              style: pw.TextStyle(fontSize: 9)),
                        ),
                        ...producao.posicoes[i]!.tempoRompido.map((v) =>
                          pw.Padding(
                            padding: pw EdgeInsets.all(4),
                            child: pw.Text(v.isEmpty ? '—' : v,
                                style: pw.TextStyle(fontSize: 10)),
                          )),
                      ],
                    ),
                    // Bobinas
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw EdgeInsets.all(4),
                          child: pw.Text('Bobinas Cheias',
                              style: pw.TextStyle(fontSize: 9)),
                        ),
                        ...producao.posicoes[i]!.bobinasCheias.map((v) =>
                          pw.Padding(
                            padding: pw EdgeInsets.all(4),
                            child: pw.Text(v.isEmpty ? '—' : v,
                                style: pw.TextStyle(fontSize: 10)),
                          )),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/relatorio-maq${producao.maquina}.pdf');
    await file.writeAsBytes(await pdf.save());

    Share.shareXFiles([XFile(file.path)],
        text: 'Relatório de Produção - Máquina ${producao.maquina}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Relatório'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Relatório de Produção',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        children: [
                          Text('🏭 Máquina ${producao.maquina}',
                              style: TextStyle(color: Colors.white)),
                          Text('📅 ${producao.data}',
                              style: TextStyle(color: Colors.white)),
                          Text('👤 ${producao.operador}',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Tabela
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: [
                      DataColumn(label: Text('Campo')),
                      DataColumn(label: Text('T1')),
                      DataColumn(label: Text('T2')),
                      DataColumn(label: Text('T3')),
                      DataColumn(label: Text('T4')),
                      DataColumn(label: Text('T1')),
                      DataColumn(label: Text('T2')),
                      DataColumn(label: Text('T3')),
                      DataColumn(label: Text('T4')),
                    ],
                    rows: [
                      for (int i = 1; i <= 6; i++) ...[
                        DataRow(
                          cells: [
                            DataCell(Text('Posição $i',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                            for (int j = 0; j < 8; j++)
                              DataCell(Text('')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(Text('Tempo rompido',
                                style: TextStyle(fontSize: 11))),
                            ...producao.posicoes[i]!.tempoRompido
                                .map((v) => DataCell(Text(v.isEmpty ? '—' : v))),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(Text('Bobinas Cheias',
                                style: TextStyle(fontSize: 11))),
                            ...producao.posicoes[i]!.bobinasCheias
                                .map((v) => DataCell(Text(v.isEmpty ? '—' : v))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportarPDF(context),
        icon: Icon(Icons.picture_as_pdf),
        label: Text('Exportar PDF'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
    );
  }
}
