import 'package:flutter/material.dart';
import '../models/producao.dart';
import 'report_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Producao producao;

  ReviewScreen({required this.producao});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Revisão dos Dados'),
        backgroundColor: Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (context, index) {
          final posNum = index + 1;
          final pos = widget.producao.posicoes[posNum]!;
          return _PositionCard(
            posNum: posNum,
            posicao: pos,
            onChanged: () => setState(() {}),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportScreen(producao: widget.producao),
            ),
          );
        },
        icon: Icon(Icons.check),
        label: Text('Gerar Relatório'),
        backgroundColor: Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _PositionCard extends StatefulWidget {
  final int posNum;
  final Posicao posicao;
  final VoidCallback onChanged;

  _PositionCard({
    required this.posNum,
    required this.posicao,
    required this.onChanged,
  });

  @override
  __PositionCardState createState() => __PositionCardState();
}

class __PositionCardState extends State<_PositionCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final preenchidos = widget.posicao.preenchidos;
    final completo = preenchidos == 16;

    return Card(
      margin: EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            title: Text('Posição ${widget.posNum}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: completo ? Color(0xFF10B981) : Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$preenchidos/16',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () => setState(() => _expandido = !_expandido),
          ),
          if (_expandido
              ? true
              : false)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildBlocoTurnos('Data 1', 0),
                  SizedBox(height: 12),
                  _buildBlocoTurnos('Data 2', 4),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlocoTurnos(String label, int offset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF06B6D4),
          ),
        ),
        SizedBox(height: 6),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: List.generate(4, (i) {
            final turno = offset + i;
            return Row(
              children: [
                Expanded(
                  child: _CampoInput(
                    label: 'T${i + 1} · Romp.',
                    valor: widget.posicao.tempoRompido[turno],
                    onChanged: (v) {
                      widget.posicao.tempoRompido[turno] = v;
                      widget.onChanged();
                    },
                  ),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: _CampoInput(
                    label: 'T${i + 1} · Bobinas',
                    valor: widget.posicao.bobinasCheias[turno],
                    onChanged: (v) {
                      widget.posicao.bobinasCheias[turno] = v;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _CampoInput extends StatelessWidget {
  final String label;
  final String valor;
  final Function(String) onChanged;

  _CampoInput({
    required this.label,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          TextField(
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: valor),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
