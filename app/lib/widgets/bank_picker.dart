import 'package:flutter/material.dart';

import '../models/bank.dart';
import '../services/bank_service.dart';
import '../theme/app_theme.dart';

class BankPicker extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final String hintText;

  const BankPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.hintText = 'Selecione o banco',
  });

  @override
  State<BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<BankPicker> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  List<Bank> _banks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BankPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fieldKey.currentState?.didChange(widget.value);
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final banks = await BankService.instance.list();
    if (!mounted) return;
    setState(() {
      _banks = banks;
      _loading = false;
    });
  }

  Future<void> _openPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BankSearchSheet(banks: _banks),
    );
    if (selected == null) return;
    _fieldKey.currentState?.didChange(selected);
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      builder: (state) {
        final value = state.value ?? widget.value;
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _loading ? null : _openPicker,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                isEmpty: false,
                decoration: InputDecoration(
                  hintText: null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.keyboard_arrow_down),
                  errorText: null,
                  enabledBorder: hasError
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.danger),
                        )
                      : null,
                  focusedBorder: hasError
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.danger),
                        )
                      : null,
                ),
                child: Text(
                  value?.isNotEmpty == true ? value! : widget.hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.2,
                    color: value?.isNotEmpty == true
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 6),
              Text(
                state.errorText!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BankSearchSheet extends StatefulWidget {
  final List<Bank> banks;

  const _BankSearchSheet({required this.banks});

  @override
  State<_BankSearchSheet> createState() => _BankSearchSheetState();
}

class _BankSearchSheetState extends State<_BankSearchSheet> {
  final _searchController = TextEditingController();
  late List<Bank> _filtered = widget.banks;

  void _filter(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      if (term.isEmpty) {
        _filtered = widget.banks;
        return;
      }
      _filtered = widget.banks.where((bank) {
        return bank.label.toLowerCase().contains(term) ||
            bank.name.toLowerCase().contains(term) ||
            (bank.code?.toString().contains(term) ?? false);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Selecione o banco',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _filter,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome ou código',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum banco encontrado',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final bank = _filtered[index];
                        return ListTile(
                          title: Text(
                            bank.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, bank.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
