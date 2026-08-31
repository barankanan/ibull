import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/runtime_diagnostic_logger.dart';
import '../../../screens/home_lazy_routes.dart';
import '../../../services/ihiz_courier_application_service.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import 'ihiz_courier_apply_steps.dart';
import 'ihiz_courier_apply_validator.dart';
import 'ihiz_courier_apply_widgets.dart';

/// İHIZ kurye başvuru ekranı — gerçek backend (auth + storage + upsert).
class IhizCourierApplyPage extends StatefulWidget {
  const IhizCourierApplyPage({
    super.key,
    this.service,
  });

  final IhizCourierApplicationService? service;

  @override
  State<IhizCourierApplyPage> createState() => _IhizCourierApplyPageState();
}

class _IhizCourierApplyPageState extends State<IhizCourierApplyPage> {
  static const _stepLabels = [
    'Kimlik',
    'Sürücü',
    'Bölge',
    'Belgeler',
    'Ödeme',
  ];

  late final IhizCourierApplicationService _service =
      widget.service ?? IhizCourierApplicationService();

  int _currentStep = 0;
  bool _submitted = false;
  bool _isSubmitting = false;
  String? _submitError;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _tcController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _noteController = TextEditingController();
  final _paymentAccountHolderController = TextEditingController();
  final _paymentIbanController = TextEditingController();
  final _paymentBankNameController = TextEditingController();

  String? _licenseType;
  String? _motorType;
  String? _criminalRecord;
  String? _companyType;
  String? _selectedCity;
  String? _selectedDistrict;

  IhizPickedDocument? _driverFront;
  IhizPickedDocument? _driverBack;
  IhizPickedDocument? _vehicleReg;
  bool _pickingFront = false;
  bool _pickingBack = false;
  bool _pickingVehicle = false;

  final Set<String> _invalidFields = <String>{};
  final Set<int> _invalidSteps = <int>{};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _tcController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _taxNumberController.dispose();
    _availabilityController.dispose();
    _noteController.dispose();
    _paymentAccountHolderController.dispose();
    _paymentIbanController.dispose();
    _paymentBankNameController.dispose();
    super.dispose();
  }

  String get _fullName =>
      '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
          .trim();

  bool _hasError(String key) => _invalidFields.contains(key);

  String? _errorText(String key, String text) =>
      _hasError(key) ? text : null;

  void _clearField(String key) {
    if (!_invalidFields.contains(key)) return;
    setState(() => _invalidFields.remove(key));
  }

  void _clearFieldSilent(String key) {
    _invalidFields.remove(key);
  }

  void _setStepResult(int step, Set<String> invalid, String warning) {
    setState(() {
      _invalidFields.removeWhere((k) => _stepForField(k) == step);
      _invalidFields.addAll(invalid);
      if (invalid.isEmpty) {
        _invalidSteps.remove(step);
      } else {
        _invalidSteps.add(step);
        _submitError = warning;
      }
    });
  }

  int? _stepForField(String key) {
    const s0 = {
      'first_name',
      'last_name',
      'phone',
      'tc_number',
      'birth_date',
      'email',
      'password',
    };
    const s1 = {
      'license_type',
      'motor_type',
      'criminal_record',
      'company_type',
      'tax_number',
    };
    const s2 = {'city', 'district', 'availability', 'note'};
    const s3 = {
      'driver_license_front',
      'driver_license_back',
      'vehicle_registration',
    };
    const s4 = {
      'payment_account_holder',
      'payment_bank_name',
      'payment_iban',
    };
    if (s0.contains(key)) return 0;
    if (s1.contains(key)) return 1;
    if (s2.contains(key)) return 2;
    if (s3.contains(key)) return 3;
    if (s4.contains(key)) return 4;
    return null;
  }

  bool _validateStep(int step) {
    late Set<String> invalid;
    late String warning;
    switch (step) {
      case 0:
        invalid = IhizCourierApplyValidator.validateStepOne(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          phone: _phoneController.text,
          tcNumber: _tcController.text,
          birthDate: _birthDateController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        warning = 'Kimlik kartındaki zorunlu alanları doldurun.';
        break;
      case 1:
        invalid = IhizCourierApplyValidator.validateStepTwo(
          licenseType: _licenseType,
          motorType: _motorType,
          criminalRecord: _criminalRecord,
          companyType: _companyType,
          taxNumber: _taxNumberController.text,
        );
        warning = 'Sürücü ve şirket kartındaki zorunlu alanları doldurun.';
        break;
      case 2:
        invalid = IhizCourierApplyValidator.validateStepThree(
          city: _selectedCity ?? '',
          district: _selectedDistrict ?? '',
          availability: _availabilityController.text,
          note: _noteController.text,
        );
        warning = 'Bölge kartındaki zorunlu alanları doldurun.';
        break;
      case 3:
        invalid = IhizCourierApplyValidator.validateStepFour(
          hasDriverFront: _driverFront != null,
          hasDriverBack: _driverBack != null,
          hasVehicleRegistration: _vehicleReg != null,
        );
        warning = 'Belge kartındaki zorunlu alanları tamamlayın.';
        break;
      default:
        invalid = IhizCourierApplyValidator.validateStepFive(
          paymentAccountHolder: _paymentAccountHolderController.text,
          paymentBankName: _paymentBankNameController.text,
          paymentIban: _paymentIbanController.text,
        );
        warning = 'Ödeme kartındaki zorunlu alanları doldurun.';
    }
    _setStepResult(step, invalid, warning);
    return invalid.isEmpty;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18),
    );
    if (picked == null) return;
    final text =
        '${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}';
    setState(() {
      _birthDateController.text = text;
      _clearFieldSilent('birth_date');
    });
  }

  Future<void> _pickDocument(IhizApplyDocumentSlot slot) async {
    final picking = switch (slot) {
      IhizApplyDocumentSlot.driverLicenseFront => _pickingFront,
      IhizApplyDocumentSlot.driverLicenseBack => _pickingBack,
      IhizApplyDocumentSlot.vehicleRegistration => _pickingVehicle,
    };
    if (picking) return;

    setState(() {
      switch (slot) {
        case IhizApplyDocumentSlot.driverLicenseFront:
          _pickingFront = true;
        case IhizApplyDocumentSlot.driverLicenseBack:
          _pickingBack = true;
        case IhizApplyDocumentSlot.vehicleRegistration:
          _pickingVehicle = true;
      }
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (!_service.isAllowedDocumentName(picked.name, slot)) {
        _showMessage(
          slot == IhizApplyDocumentSlot.vehicleRegistration
              ? 'Desteklenmeyen dosya türü. Lütfen JPG, PNG, WEBP veya PDF seçin.'
              : 'Ehliyet için sadece görsel yüklenebilir (JPG, PNG, WEBP).',
        );
        return;
      }
      final bytes = await _resolveBytes(picked);
      if (bytes == null || bytes.isEmpty) {
        _showMessage('Dosya okunamadı. Tekrar deneyin.');
        return;
      }
      if (bytes.lengthInBytes > IhizCourierApplicationService.maxDocumentBytes) {
        _showMessage('Dosya boyutu en fazla 10MB olabilir.');
        return;
      }
      setState(() {
        final doc = IhizPickedDocument(name: picked.name, bytes: bytes);
        switch (slot) {
          case IhizApplyDocumentSlot.driverLicenseFront:
            _driverFront = doc;
            _invalidFields.remove('driver_license_front');
          case IhizApplyDocumentSlot.driverLicenseBack:
            _driverBack = doc;
            _invalidFields.remove('driver_license_back');
          case IhizApplyDocumentSlot.vehicleRegistration:
            _vehicleReg = doc;
            _invalidFields.remove('vehicle_registration');
        }
      });
    } catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'IhizApply',
        error,
        stackTrace,
        context: 'pickDocument',
      );
      _showMessage('Belge seçilirken hata oluştu. Tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() {
          switch (slot) {
            case IhizApplyDocumentSlot.driverLicenseFront:
              _pickingFront = false;
            case IhizApplyDocumentSlot.driverLicenseBack:
              _pickingBack = false;
            case IhizApplyDocumentSlot.vehicleRegistration:
              _pickingVehicle = false;
          }
        });
      }
    }
  }

  Future<Uint8List?> _resolveBytes(PlatformFile picked) async {
    if (picked.bytes != null && picked.bytes!.isNotEmpty) return picked.bytes;
    final stream = picked.readStream;
    if (stream == null) return null;
    final all = <int>[];
    await for (final chunk in stream) {
      all.addAll(chunk);
      if (all.length > IhizCourierApplicationService.maxDocumentBytes) break;
    }
    if (all.isEmpty) return null;
    return Uint8List.fromList(all);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    for (var i = 0; i <= 4; i++) {
      if (!_validateStep(i)) {
        setState(() => _currentStep = i);
        return;
      }
    }
    final front = _driverFront;
    final back = _driverBack;
    final vehicle = _vehicleReg;
    if (front == null || back == null || vehicle == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await _service.submitApplication(
        IhizCourierApplicationSubmitInput(
          fullName: _fullName,
          phone: _phoneController.text,
          tcNumber: _tcController.text,
          birthDate: _birthDateController.text,
          licenseType: _licenseType ?? '',
          motorType: _motorType ?? '',
          criminalRecord: _criminalRecord ?? '',
          companyType: _companyType ?? '',
          taxNumber: _taxNumberController.text,
          city: _selectedCity ?? '',
          district: _selectedDistrict ?? '',
          availability: _availabilityController.text,
          email: _emailController.text,
          password: _passwordController.text,
          note: _noteController.text,
          paymentAccountHolder: _paymentAccountHolderController.text,
          paymentBankName: _paymentBankNameController.text,
          paymentIban: _paymentIbanController.text,
          driverLicenseFront: front,
          driverLicenseBack: back,
          vehicleRegistration: vehicle,
        ),
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = _service.normalizeSubmissionError(error);
      });
      _showMessage(_submitError!);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goNext() {
    if (!_validateStep(_currentStep)) return;
    setState(() {
      _submitError = null;
      _currentStep = (_currentStep + 1).clamp(0, 4);
    });
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  Future<void> _openLogin() async {
    await HomeLazyRoutes.openLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = IhizBrand.isMobile(width);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      backgroundColor: IhizBrand.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: IhizBrand.ink,
        elevation: 0,
        title: const Text(
          'Kurye Başvurusu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: _submitted
              ? SingleChildScrollView(
                  padding: EdgeInsets.all(mobile ? 16 : 28),
                  child: IhizApplySuccessView(
                    onLogin: () => unawaited(_openLogin()),
                    onDone: () => Navigator.of(context).maybePop(),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          mobile ? 16 : 28,
                          16,
                          mobile ? 16 : 28,
                          16,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 920),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const IhizSectionHeader(
                                  eyebrow: 'İHIZ',
                                  title: 'Kurye başvuru formu',
                                  subtitle:
                                      'Bilgilerinizi adım adım tamamlayın. Belgeler güvenli şekilde kaydedilir.',
                                ),
                                const SizedBox(height: 18),
                                IhizApplyStepIndicator(
                                  currentStep: _currentStep,
                                  labels: _stepLabels,
                                  invalidSteps: _invalidSteps,
                                ),
                                const SizedBox(height: 18),
                                if (_submitError != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      _submitError!,
                                      style: TextStyle(
                                        color: Colors.red.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Container(
                                  padding: EdgeInsets.all(mobile ? 14 : 20),
                                  decoration: BoxDecoration(
                                    color: IhizBrand.surfaceAlt,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: IhizBrand.line),
                                  ),
                                  child: IhizCourierApplyStepBody(
                                    step: _currentStep,
                                    hasError: _hasError,
                                    errorText: _errorText,
                                    clearField: _clearField,
                                    firstNameController: _firstNameController,
                                    lastNameController: _lastNameController,
                                    phoneController: _phoneController,
                                    tcController: _tcController,
                                    birthDateController: _birthDateController,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    taxNumberController: _taxNumberController,
                                    availabilityController:
                                        _availabilityController,
                                    noteController: _noteController,
                                    paymentAccountHolderController:
                                        _paymentAccountHolderController,
                                    paymentBankNameController:
                                        _paymentBankNameController,
                                    paymentIbanController:
                                        _paymentIbanController,
                                    licenseType: _licenseType,
                                    motorType: _motorType,
                                    criminalRecord: _criminalRecord,
                                    companyType: _companyType,
                                    selectedCity: _selectedCity,
                                    selectedDistrict: _selectedDistrict,
                                    driverFront: _driverFront,
                                    driverBack: _driverBack,
                                    vehicleReg: _vehicleReg,
                                    pickingFront: _pickingFront,
                                    pickingBack: _pickingBack,
                                    pickingVehicle: _pickingVehicle,
                                    onPickBirthDate: () =>
                                        unawaited(_pickBirthDate()),
                                    onLicenseChanged: (v) {
                                      setState(() {
                                        _licenseType = v;
                                        _clearFieldSilent('license_type');
                                      });
                                    },
                                    onMotorChanged: (v) {
                                      setState(() {
                                        _motorType = v;
                                        _clearFieldSilent('motor_type');
                                      });
                                    },
                                    onCriminalChanged: (v) {
                                      setState(() {
                                        _criminalRecord = v;
                                        _clearFieldSilent('criminal_record');
                                      });
                                    },
                                    onCompanyChanged: (v) {
                                      setState(() {
                                        _companyType = v;
                                        if (v == 'Şirketim yok') {
                                          _taxNumberController.clear();
                                          _invalidFields.remove('tax_number');
                                        }
                                        _clearFieldSilent('company_type');
                                      });
                                    },
                                    onCityChanged: (v) {
                                      setState(() {
                                        _selectedCity = v;
                                        _selectedDistrict = null;
                                        _clearFieldSilent('city');
                                        _invalidFields.remove('district');
                                      });
                                    },
                                    onDistrictChanged: (v) {
                                      setState(() {
                                        _selectedDistrict = v;
                                        _clearFieldSilent('district');
                                      });
                                    },
                                    onPickDocument: (slot) =>
                                        unawaited(_pickDocument(slot)),
                                    onRemoveDocument: (slot) {
                                      setState(() {
                                        switch (slot) {
                                          case IhizApplyDocumentSlot
                                                .driverLicenseFront:
                                            _driverFront = null;
                                          case IhizApplyDocumentSlot
                                                .driverLicenseBack:
                                            _driverBack = null;
                                          case IhizApplyDocumentSlot
                                                .vehicleRegistration:
                                            _vehicleReg = null;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    IhizApplyNavBar(
                      mobile: mobile,
                      currentStep: _currentStep,
                      isSubmitting: _isSubmitting,
                      onBack: _goBack,
                      onNext: _goNext,
                      onSubmit: () => unawaited(_submit()),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
