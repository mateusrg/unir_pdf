import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'pdf_merge_service.dart';
import 'pdf_source.dart';
import 'saver.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<PdfSource> _files = [];
  bool _dragging = false;
  bool _processing = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecione os PDFs',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final added = result.files
        .where((pf) => pf.name.toLowerCase().endsWith('.pdf'))
        .map(PdfSource.fromPicker);
    _addUnique(added);
    setState(() {});
  }

  void _addUnique(Iterable<PdfSource> added) {
    final existing = _files.toSet();
    for (final f in added) {
      if (!existing.contains(f)) {
        _files.add(f);
        existing.add(f);
      }
    }
  }

  void _handleDrop(DropDoneDetails details) async {
    final dropped = details.files
        .where((XFile f) => f.name.toLowerCase().endsWith('.pdf'))
        .map(PdfSource.fromXFile)
        .toList();

    setState(() => _files.addAll(dropped));

    // Preenche tamanhos em background e atualiza a UI.
    for (final src in dropped) {
      try {
        final size = await src.readBytes();
        final idx = _files.indexOf(src);
        if (idx >= 0 && _files[idx].sizeBytes == null) {
          _files[idx] = PdfSource(
            name: src.name,
            sizeBytes: size.length,
            read: src.readBytes,
          );
          if (mounted) setState(() {});
        }
      } catch (_) {
        // Ignora: não conseguimos medir agora (ex.: web sem bytes).
      }
    }
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _files.length) return;
    setState(() {
      final item = _files.removeAt(from);
      _files.insert(to, item);
    });
  }

  void _removeAt(int index) {
    setState(() => _files.removeAt(index));
  }

  void _clear() {
    setState(() => _files.clear());
  }

  Future<void> _merge() async {
    if (_files.isEmpty) return;
    setState(() => _processing = true);

    try {
      final result = await PdfMergeService.merge(_files);
      final saved = await saveMergedPdf(
        result.bytes,
        PdfMergeService.defaultOutputName(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Unido: ${result.fileCount} arquivos, ${result.pageCount} páginas.'
                : 'Operação cancelada.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao unir: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unir PDFs'),
        actions: [
          IconButton(
            tooltip: 'Limpar lista',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _files.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: _handleDrop,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDropZone(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildList()),
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropZone() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 150,
      decoration: BoxDecoration(
        color: _dragging
            ? Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: 0.35,
              )
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _dragging
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: _dragging ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickFiles,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              _dragging
                  ? 'Solte os PDFs aqui'
                  : 'Arraste PDFs ou clique para selecionar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Apenas arquivos .pdf',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_files.isEmpty) {
      return const Center(
        child: Text('Nenhum arquivo adicionado ainda.'),
      );
    }
    return Card(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: _files.length,
        onReorder: _move,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (context, index) {
          final item = _files[index];
          return ListTile(
            key: ValueKey('${item.name}-$index'),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text('${index + 1}'),
            ),
            title: Text(item.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(item.sizeLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Subir',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: index == 0 ? null : () => _move(index, index - 1),
                ),
                IconButton(
                  tooltip: 'Descer',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: index == _files.length - 1
                      ? null
                      : () => _move(index, index + 1),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeAt(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return FilledButton.icon(
      onPressed: _processing || _files.length < 2 ? null : _merge,
      icon: _processing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.merge),
      label: Text(
        _processing
            ? 'Unindo...'
            : _files.length < 2
                ? 'Adicione ao menos 2 PDFs'
                : 'Unir ${_files.length} PDFs',
      ),
    );
  }
}