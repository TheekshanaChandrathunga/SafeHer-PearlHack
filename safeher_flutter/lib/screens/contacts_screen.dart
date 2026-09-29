import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/firebase_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  void _showForm(BuildContext context, {EmergencyContact? existing}) {
    final nameCtl = TextEditingController(text: existing?.name);
    final phoneCtl = TextEditingController(text: existing?.phone);
    final relCtl = TextEditingController(text: existing?.relationship);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Phone number')),
            TextField(controller: relCtl, decoration: const InputDecoration(labelText: 'Relationship')),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () {
                if (nameCtl.text.trim().isEmpty || phoneCtl.text.trim().isEmpty) return;
                final contact = EmergencyContact(
                  id: existing?.id ?? '',
                  name: nameCtl.text.trim(),
                  phone: phoneCtl.text.trim(),
                  relationship: relCtl.text.trim().isEmpty ? 'Contact' : relCtl.text.trim(),
                );
                if (existing == null) {
                  FirebaseService.instance.addContact(contact);
                } else {
                  FirebaseService.instance.updateContact(contact);
                }
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add Contact' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Emergency Contacts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                TextButton.icon(
                  onPressed: () => _showForm(context),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmergencyContact>>(
              stream: FirebaseService.instance.watchContacts(),
              builder: (context, snap) {
                final contacts = snap.data ?? [];
                if (contacts.isEmpty) {
                  return const Center(child: Text('No contacts added yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: contacts.length,
                  itemBuilder: (ctx, i) {
                    final c = contacts[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                        title: Text(c.name),
                        subtitle: Text('${c.phone} • ${c.relationship}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showForm(context, existing: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => FirebaseService.instance.deleteContact(c.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
