import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/turkiye_location_data.dart';
import '../../../services/ihiz_courier_application_service.dart';
import 'ihiz_courier_apply_validator.dart';
import 'ihiz_courier_apply_widgets.dart';

class IhizCourierApplyStepBody extends StatelessWidget {
  const IhizCourierApplyStepBody({
    super.key,
    required this.step,
    required this.hasError,
    required this.errorText,
    required this.clearField,
    required this.firstNameController,
    required this.lastNameController,
    required this.phoneController,
    required this.tcController,
    required this.birthDateController,
    required this.emailController,
    required this.passwordController,
    required this.taxNumberController,
    required this.availabilityController,
    required this.noteController,
    required this.paymentAccountHolderController,
    required this.paymentBankNameController,
    required this.paymentIbanController,
    required this.licenseType,
    required this.motorType,
    required this.criminalRecord,
    required this.companyType,
    required this.selectedCity,
    required this.selectedDistrict,
    required this.driverFront,
    required this.driverBack,
    required this.vehicleReg,
    required this.pickingFront,
    required this.pickingBack,
    required this.pickingVehicle,
    required this.onPickBirthDate,
    required this.onLicenseChanged,
    required this.onMotorChanged,
    required this.onCriminalChanged,
    required this.onCompanyChanged,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.onPickDocument,
    required this.onRemoveDocument,
  });

  final int step;
  final bool Function(String key) hasError;
  final String? Function(String key, String text) errorText;
  final void Function(String key) clearField;

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController phoneController;
  final TextEditingController tcController;
  final TextEditingController birthDateController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController taxNumberController;
  final TextEditingController availabilityController;
  final TextEditingController noteController;
  final TextEditingController paymentAccountHolderController;
  final TextEditingController paymentBankNameController;
  final TextEditingController paymentIbanController;

  final String? licenseType;
  final String? motorType;
  final String? criminalRecord;
  final String? companyType;
  final String? selectedCity;
  final String? selectedDistrict;

  final IhizPickedDocument? driverFront;
  final IhizPickedDocument? driverBack;
  final IhizPickedDocument? vehicleReg;
  final bool pickingFront;
  final bool pickingBack;
  final bool pickingVehicle;

  final VoidCallback onPickBirthDate;
  final ValueChanged<String?> onLicenseChanged;
  final ValueChanged<String?> onMotorChanged;
  final ValueChanged<String?> onCriminalChanged;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<IhizApplyDocumentSlot> onPickDocument;
  final ValueChanged<IhizApplyDocumentSlot> onRemoveDocument;

  @override
  Widget build(BuildContext context) {
    switch (step) {
      case 0:
        return IhizApplyFieldGrid(
          children: [
            IhizApplyTextField(
              label: 'Ad',
              hint: 'Adınız',
              controller: firstNameController,
              hasError: hasError('first_name'),
              errorText: errorText('first_name', 'Ad zorunlu'),
              onChanged: (_) => clearField('first_name'),
            ),
            IhizApplyTextField(
              label: 'Soyad',
              hint: 'Soyadınız',
              controller: lastNameController,
              hasError: hasError('last_name'),
              errorText: errorText('last_name', 'Soyad zorunlu'),
              onChanged: (_) => clearField('last_name'),
            ),
            IhizApplyTextField(
              label: 'Telefon',
              hint: '05xxxxxxxxx',
              controller: phoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              maxLength: 11,
              hasError: hasError('phone'),
              errorText: errorText('phone', 'Telefon 11 haneli olmalı'),
              onChanged: (_) => clearField('phone'),
            ),
            IhizApplyTextField(
              label: 'TC Kimlik Numarası',
              hint: '11 haneli kimlik numarası',
              controller: tcController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              maxLength: 11,
              hasError: hasError('tc_number'),
              errorText: errorText('tc_number', 'TC kimlik no 11 haneli olmalı'),
              onChanged: (_) => clearField('tc_number'),
            ),
            IhizApplyTextField(
              label: 'Doğum Tarihi',
              hint: 'GG / AA / YYYY',
              controller: birthDateController,
              readOnly: true,
              onTap: onPickBirthDate,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
              hasError: hasError('birth_date'),
              errorText: errorText('birth_date', 'Geçerli doğum tarihi gerekli'),
            ),
            IhizApplyTextField(
              label: 'E-posta',
              hint: 'ornek@email.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              hasError: hasError('email'),
              errorText: errorText('email', 'Geçerli e-posta girin'),
              onChanged: (_) => clearField('email'),
            ),
            IhizApplyTextField(
              label: 'Şifre',
              hint: 'En az 6 karakter',
              controller: passwordController,
              obscureText: true,
              hasError: hasError('password'),
              errorText: errorText('password', 'Şifre en az 6 karakter olmalı'),
              onChanged: (_) => clearField('password'),
            ),
          ],
        );
      case 1:
        return IhizApplyFieldGrid(
          children: [
            IhizApplySelectField(
              label: 'Ehliyet Türü',
              hint: 'Ehliyet türü seçin',
              value: licenseType,
              items: IhizCourierApplyValidator.licenseOptions,
              onChanged: onLicenseChanged,
              hasError: hasError('license_type'),
              errorText: errorText('license_type', 'Ehliyet türü zorunlu'),
            ),
            IhizApplySelectField(
              label: 'Motorsiklet Türü',
              hint: 'Motor türü seçin',
              value: motorType,
              items: IhizCourierApplyValidator.motorOptions,
              onChanged: onMotorChanged,
              hasError: hasError('motor_type'),
              errorText: errorText('motor_type', 'Motosiklet türü zorunlu'),
            ),
            IhizApplySelectField(
              label: 'Adli Sicil Kaydı',
              hint: 'Durum seçin',
              value: criminalRecord,
              items: IhizCourierApplyValidator.criminalRecordOptions,
              onChanged: onCriminalChanged,
              hasError: hasError('criminal_record'),
              errorText:
                  errorText('criminal_record', 'Adli sicil seçimi zorunlu'),
            ),
            IhizApplySelectField(
              label: 'Şirket Türü',
              hint: 'Şirket türü seçin',
              value: companyType,
              items: IhizCourierApplyValidator.companyOptions,
              onChanged: onCompanyChanged,
              hasError: hasError('company_type'),
              errorText: errorText('company_type', 'Şirket türü zorunlu'),
            ),
            if (companyType != null && companyType != 'Şirketim yok')
              IhizApplyTextField(
                label: 'Vergi Numarası',
                hint: '10 haneli vergi no',
                controller: taxNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                maxLength: 10,
                hasError: hasError('tax_number'),
                errorText: errorText('tax_number', 'Vergi no 10 haneli olmalı'),
                onChanged: (_) => clearField('tax_number'),
              ),
          ],
        );
      case 2:
        final districts = selectedCity == null
            ? const <String>[]
            : TurkiyeLocationData.districtsForProvince(selectedCity!);
        return IhizApplyFieldGrid(
          children: [
            IhizApplySelectField(
              label: 'İl',
              hint: 'İl seçin',
              value: selectedCity,
              items: TurkiyeLocationData.provinces,
              onChanged: onCityChanged,
              hasError: hasError('city'),
              errorText: errorText('city', 'İl zorunlu'),
            ),
            IhizApplySelectField(
              label: 'İlçe',
              hint: 'İlçe seçin',
              value: selectedDistrict,
              items: districts,
              onChanged: onDistrictChanged,
              hasError: hasError('district'),
              errorText: errorText('district', 'İlçe zorunlu'),
            ),
            IhizApplyTextField(
              label: 'Müsaitlik',
              hint: 'Örn. Hafta içi 18:00–23:00',
              controller: availabilityController,
              hasError: hasError('availability'),
              errorText: errorText('availability', 'Müsaitlik zorunlu'),
              onChanged: (_) => clearField('availability'),
            ),
            IhizApplyTextField(
              label: 'Not',
              hint: 'Kısa bir başvuru notu',
              controller: noteController,
              maxLines: 3,
              hasError: hasError('note'),
              errorText: errorText('note', 'Not zorunlu'),
              onChanged: (_) => clearField('note'),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            IhizApplyDocumentCard(
              title: 'Ehliyet Ön Yüz',
              subtitle: 'JPG, PNG veya WEBP (max 10MB)',
              document: driverFront,
              isPicking: pickingFront,
              hasError: hasError('driver_license_front'),
              onPick: () =>
                  onPickDocument(IhizApplyDocumentSlot.driverLicenseFront),
              onRemove: () =>
                  onRemoveDocument(IhizApplyDocumentSlot.driverLicenseFront),
            ),
            const SizedBox(height: 12),
            IhizApplyDocumentCard(
              title: 'Ehliyet Arka Yüz',
              subtitle: 'JPG, PNG veya WEBP (max 10MB)',
              document: driverBack,
              isPicking: pickingBack,
              hasError: hasError('driver_license_back'),
              onPick: () =>
                  onPickDocument(IhizApplyDocumentSlot.driverLicenseBack),
              onRemove: () =>
                  onRemoveDocument(IhizApplyDocumentSlot.driverLicenseBack),
            ),
            const SizedBox(height: 12),
            IhizApplyDocumentCard(
              title: 'Araç Ruhsatı',
              subtitle: 'JPG, PNG, WEBP veya PDF (max 10MB)',
              document: vehicleReg,
              isPicking: pickingVehicle,
              hasError: hasError('vehicle_registration'),
              onPick: () =>
                  onPickDocument(IhizApplyDocumentSlot.vehicleRegistration),
              onRemove: () =>
                  onRemoveDocument(IhizApplyDocumentSlot.vehicleRegistration),
            ),
          ],
        );
      default:
        return IhizApplyFieldGrid(
          children: [
            IhizApplyTextField(
              label: 'Hesap Sahibi',
              hint: 'IBAN hesap sahibi',
              controller: paymentAccountHolderController,
              hasError: hasError('payment_account_holder'),
              errorText: errorText(
                'payment_account_holder',
                'Hesap sahibi zorunlu',
              ),
              onChanged: (_) => clearField('payment_account_holder'),
            ),
            IhizApplyTextField(
              label: 'Banka Adı',
              hint: 'Banka adı',
              controller: paymentBankNameController,
              hasError: hasError('payment_bank_name'),
              errorText: errorText('payment_bank_name', 'Banka adı zorunlu'),
              onChanged: (_) => clearField('payment_bank_name'),
            ),
            IhizApplyTextField(
              label: 'IBAN',
              hint: 'TRxx xxxx xxxx xxxx xxxx xxxx xx',
              controller: paymentIbanController,
              hasError: hasError('payment_iban'),
              errorText: errorText(
                'payment_iban',
                'Geçerli TR IBAN girin (TR + 24 rakam)',
              ),
              onChanged: (_) => clearField('payment_iban'),
            ),
          ],
        );
    }
  }
}
