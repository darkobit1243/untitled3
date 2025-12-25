import 'package:flutter/material.dart';

import '../../theme/app_ui.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_section_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../utils/auth_flow/input_formatters.dart';
import 'auth_error_banner.dart';

class AuthRegistrationFormView extends StatelessWidget {
  const AuthRegistrationFormView({
    super.key,
    required this.isSender,
    required this.scrollController,
    required this.error,
    required this.isLoading,
    required this.onBack,
    required this.onSubmit,
    required this.onAnyFieldChanged,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.passwordController,
    required this.passwordConfirmController,
    required this.phoneController,
    required this.carrierVehicleTypeController,
    required this.carrierVehiclePlateController,
    required this.carrierServiceAreaController,
    required this.kFirstName,
    required this.kLastName,
    required this.kEmail,
    required this.kPassword,
    required this.kPasswordConfirm,
    required this.kPhone,
    required this.kVehicleType,
    required this.kVehiclePlate,
    required this.firstNameFocus,
    required this.lastNameFocus,
    required this.emailFocus,
    required this.passwordFocus,
    required this.passwordConfirmFocus,
    required this.phoneFocus,
    required this.vehicleTypeFocus,
    required this.vehiclePlateFocus,
    required this.phoneHint,
  });

  final bool isSender;
  final ScrollController scrollController;
  final String? error;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final VoidCallback onAnyFieldChanged;

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final TextEditingController phoneController;

  final TextEditingController carrierVehicleTypeController;
  final TextEditingController carrierVehiclePlateController;
  final TextEditingController carrierServiceAreaController;

  final GlobalKey kFirstName;
  final GlobalKey kLastName;
  final GlobalKey kEmail;
  final GlobalKey kPassword;
  final GlobalKey kPasswordConfirm;
  final GlobalKey kPhone;
  final GlobalKey kVehicleType;
  final GlobalKey kVehiclePlate;

  final FocusNode firstNameFocus;
  final FocusNode lastNameFocus;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final FocusNode passwordConfirmFocus;
  final FocusNode phoneFocus;
  final FocusNode vehicleTypeFocus;
  final FocusNode vehiclePlateFocus;

  final String phoneHint;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                label: const Text('Geri'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSender ? 'Gönderici Kaydı' : 'Taşıyıcı Kaydı',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSender
                    ? 'Paket göndermek için hızlıca bir hesap oluştur.'
                    : 'Yolculuklarında kargo taşıyıp gelir elde etmek için kayıt ol.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (error != null) AuthErrorBanner(message: error!),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: kFirstName,
                      child: AppTextField(
                        label: 'İsim',
                        controller: firstNameController,
                        hintText: 'Adınız (örn: Ahmet Can)',
                        prefixIcon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: const [TrNameFormatter()],
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: firstNameFocus,
                        nextFocusNode: lastNameFocus,
                        onChanged: (_) => onAnyFieldChanged(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: kLastName,
                      child: AppTextField(
                        label: 'Soyad',
                        controller: lastNameController,
                        hintText: 'Soyadınız',
                        prefixIcon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: const [TrNameFormatter()],
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: lastNameFocus,
                        nextFocusNode: emailFocus,
                        onChanged: (_) => onAnyFieldChanged(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: kEmail,
                      child: AppTextField(
                        label: 'E-posta',
                        controller: emailController,
                        hintText: 'ornek@eposta.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: emailFocus,
                        nextFocusNode: passwordFocus,
                        onChanged: (_) => onAnyFieldChanged(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: kPassword,
                      child: AppTextField(
                        label: 'Şifre',
                        controller: passwordController,
                        hintText: 'En az 6 karakter',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: passwordFocus,
                        nextFocusNode: passwordConfirmFocus,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Container(
                      key: kPasswordConfirm,
                      child: AppTextField(
                        label: 'Şifre (Tekrar)',
                        controller: passwordConfirmController,
                        hintText: 'Şifreni tekrar gir',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        focusNode: passwordConfirmFocus,
                        nextFocusNode: phoneFocus,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Container(
                      key: kPhone,
                      child: AppTextField(
                        label: 'Telefon',
                        controller: phoneController,
                        hintText: phoneHint,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [TrPhoneHyphenFormatter()],
                        enabled: !isLoading,
                        textInputAction: TextInputAction.done,
                        focusNode: phoneFocus,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (!isSender) ...[
                      Container(
                        key: kVehicleType,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              label: 'Araç Tipi',
                              controller: carrierVehicleTypeController,
                              hintText: 'Otomobil, panelvan, kamyonet vb.',
                              prefixIcon: Icons.local_shipping_outlined,
                              enabled: !isLoading,
                              textInputAction: TextInputAction.next,
                              focusNode: vehicleTypeFocus,
                              nextFocusNode: vehiclePlateFocus,
                            ),
                            const SizedBox(height: AppSpace.md),
                            Container(
                              key: kVehiclePlate,
                              child: AppTextField(
                                label: 'Araç Plakası',
                                controller: carrierVehiclePlateController,
                                hintText: '34ABC34',
                                prefixIcon: Icons.badge_outlined,
                                textCapitalization: TextCapitalization.characters,
                                enabled: !isLoading,
                                textInputAction: TextInputAction.next,
                                focusNode: vehiclePlateFocus,
                              ),
                            ),
                            const SizedBox(height: AppSpace.md),
                            AppTextField(
                              label: 'Servis Bölgesi',
                              controller: carrierServiceAreaController,
                              hintText: 'Çalıştığınız şehir / gece rotası',
                              prefixIcon: Icons.public,
                              enabled: !isLoading,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    AppButton.primary(
                      label: 'Kayıt Ol',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : onSubmit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
