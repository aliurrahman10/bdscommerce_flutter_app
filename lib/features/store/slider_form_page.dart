import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_theme.dart';
import '../../core/state/workspace_controller.dart';

class SliderFormPage extends StatefulWidget {
  const SliderFormPage({super.key, this.slider});

  final Map<String, dynamic>? slider;

  @override
  State<SliderFormPage> createState() => _SliderFormPageState();
}

class _SliderFormPageState extends State<SliderFormPage> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _buttonText = TextEditingController();
  final _buttonLink = TextEditingController();
  final _textColor = TextEditingController(text: '#FFFFFF');
  final _buttonColor = TextEditingController(text: '#F97316');
  String _alignment = 'center';
  bool _active = true;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.slider;
    if (s != null) {
      _name.text = s['name']?.toString() ?? '';
      _title.text = s['title']?.toString() ?? '';
      _description.text = s['description']?.toString() ?? '';
      _buttonText.text = s['button_text']?.toString() ?? '';
      _buttonLink.text = s['button_link']?.toString() ?? '';
      _textColor.text = s['text_color']?.toString() ?? '#FFFFFF';
      _buttonColor.text = s['button_background_color']?.toString() ?? '#F97316';
      _alignment = s['text_alignment']?.toString() ?? 'center';
      _active = s['status']?.toString() != 'inactive';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _description.dispose();
    _buttonText.dispose();
    _buttonLink.dispose();
    _textColor.dispose();
    _buttonColor.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;
    setState(() => _image = image);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slider name is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final workspace = context.read<WorkspaceController>();
      final token = workspace.activeStoreToken!;
      final data = {
        'name': _name.text.trim(),
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'button_text': _buttonText.text.trim(),
        'button_link': _buttonLink.text.trim(),
        'text_color': _textColor.text.trim(),
        'button_background_color': _buttonColor.text.trim(),
        'text_alignment': _alignment,
        'status': _active ? 'active' : 'inactive',
      };
      Map<String, dynamic> result;
      if (widget.slider == null) {
        result = await workspace.storeApi.createSlider(token, data);
      } else {
        result = await workspace.storeApi.updateSlider(token, int.parse(widget.slider!['id'].toString()), data);
      }
      final slider = (result['slider'] as Map<String, dynamic>?) ?? widget.slider;
      if (_image != null && slider != null) {
        await workspace.storeApi.uploadSliderImage(token, int.parse(slider['id'].toString()), _image!.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slider saved.')));
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oldImage = widget.slider?['image_url']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.slider == null ? 'Add Slider' : 'Edit Slider')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save Slider')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 170,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppTheme.primary.withOpacity(.08)),
              clipBehavior: Clip.antiAlias,
              child: _image != null
                  ? Image.file(File(_image!.path), fit: BoxFit.cover)
                  : oldImage.isNotEmpty
                      ? Image.network(oldImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)))
                      : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.image_outlined, size: 42), SizedBox(height: 8), Text('Tap to select slider image')])) ,
            ),
          ),
          const SizedBox(height: 16),
          _Input(controller: _name, label: 'Slider name'),
          _Input(controller: _title, label: 'Title'),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          ),
          _Input(controller: _buttonText, label: 'Button text'),
          _Input(controller: _buttonLink, label: 'Button link'),
          Row(children: [Expanded(child: _Input(controller: _textColor, label: 'Text color')), const SizedBox(width: 10), Expanded(child: _Input(controller: _buttonColor, label: 'Button color'))]),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _alignment,
            decoration: const InputDecoration(labelText: 'Text alignment'),
            items: const ['left', 'center', 'right'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => _alignment = value ?? _alignment),
          ),
          const SizedBox(height: 8),
          SwitchListTile(value: _active, onChanged: (value) => setState(() => _active = value), title: const Text('Active')),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
      );
}
