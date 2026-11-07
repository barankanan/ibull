import '../../../models/sub_admin.dart';

const String staffStatusActive = 'active';
const String staffStatusInvited = 'invited';
const String staffStatusInactive = 'inactive';

String staffContact(SubAdmin person) {
  final email = person.email?.trim() ?? '';
  if (email.isNotEmpty) return email;
  return person.phone?.trim() ?? '';
}

String staffDisplayName(SubAdmin person) {
  final email = person.email?.trim() ?? '';
  if (email.contains('@')) return email.split('@').first;
  final phone = person.phone?.trim() ?? '';
  if (phone.isNotEmpty) return phone;
  return 'Personel';
}

String staffStatusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case staffStatusActive:
      return 'Aktif';
    case staffStatusInvited:
      return 'Davetli';
    case staffStatusInactive:
      return 'Pasif';
    default:
      return status.trim().isEmpty ? 'Bilinmiyor' : status.trim();
  }
}

bool staffCanBeDeactivated(SubAdmin person) {
  return person.status.trim().toLowerCase() != staffStatusInactive;
}

String nextStaffStatus(SubAdmin person) {
  return staffCanBeDeactivated(person)
      ? staffStatusInactive
      : staffStatusActive;
}

/// The owner must type the person's contact before the row is deleted.
bool canConfirmStaffRemoval({
  required String typed,
  required String contact,
}) {
  final expected = contact.trim();
  if (expected.isEmpty) return false;
  return typed.trim() == expected;
}

List<SubAdmin> filterStaffDirectory({
  required List<SubAdmin> staff,
  required String query,
  required String status,
}) {
  final needle = query.trim().toLowerCase();
  final wanted = status.trim().toLowerCase();
  return staff.where((person) {
    if (wanted.isNotEmpty &&
        wanted != 'all' &&
        person.status.trim().toLowerCase() != wanted) {
      return false;
    }
    if (needle.isEmpty) return true;
    final haystack = '${staffDisplayName(person)} ${staffContact(person)}'
        .toLowerCase();
    return haystack.contains(needle);
  }).toList(growable: false);
}
