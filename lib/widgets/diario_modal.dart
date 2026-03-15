import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/comunicado.dart';
import '../services/diario_service.dart';

class DiarioModal extends StatefulWidget {
  final Comunicado? comunicadoToEdit;

  const DiarioModal({
    super.key,
    this.comunicadoToEdit,
  });

  @override
  State<DiarioModal> createState() => _DiarioModalState();
}

class _DiarioModalState extends State<DiarioModal> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _selectedDate;
  
  bool _isLoading = false;
  final DiarioService _diarioService = DiarioService();

  @override
  void initState() {
    super.initState();
    if (widget.comunicadoToEdit != null) {
      _titleController.text = widget.comunicadoToEdit!.title;
      _descController.text = widget.comunicadoToEdit!.description;
      _selectedDate = widget.comunicadoToEdit!.date;
    } else {
      _titleController.text = 'Nueva entrada de diario';
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa un título')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final comunicado = Comunicado(
        id: widget.comunicadoToEdit?.id ?? '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        date: _selectedDate,
        // Mantener info de archivo si existiera en caso de edición
        fileUrl: widget.comunicadoToEdit?.fileUrl,
        fileType: widget.comunicadoToEdit?.fileType,
        fileName: widget.comunicadoToEdit?.fileName,
      );

      await _diarioService.saveComunicado(comunicado);
      
      if (mounted) {
        Navigator.pop(context, true); // Retorna true si se guardó correctamente
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: \$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.comunicadoToEdit != null;
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
      height: MediaQuery.of(context).size.height - topPadding,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(isEditing),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildDatePicker(),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _titleController,
                    label: 'Título (obligatorio)',
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _descController,
                    label: 'Tu texto o recuerdo (opcional)',
                    icon: Icons.notes,
                    maxLines: 8,
                  ),
                  // TODO: Opcional añadir botón o placeholder para multimedia más adelante
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_note, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Editar Diario' : 'Nuevo Diario',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Día del suceso', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE d MMMM, y', 'es_ES').format(_selectedDate),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: icon != Icons.notes ? Icon(icon, color: const Color(0xFF6C63FF)) : null,
        filled: true,
        fillColor: const Color(0xFF0F0F1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Guardar Nota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
