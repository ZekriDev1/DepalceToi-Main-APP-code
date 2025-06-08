import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'en';
  
  late SharedPreferences _prefs;
  String _currentLanguage = _defaultLanguage;

  final Map<String, Map<String, String>> _translations = {
    'en': {
      // Common
      'app_name': 'DeplaceToi',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'save': 'Save',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'edit': 'Edit',
      'submit': 'Submit',
      'skip': 'Skip',
      'next': 'Next',
      'back': 'Back',
      'done': 'Done',
      'retry': 'Retry',
      'close': 'Close',
      'search': 'Search',
      'no_results': 'No results found',
      'required_field': 'This field is required',

      // Auth
      'login': 'Login',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'forgot_password': 'Forgot Password?',
      'reset_password': 'Reset Password',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'sign_out': 'Sign Out',
      'welcome_back': 'Welcome Back',
      'create_account': 'Create Account',
      'already_have_account': 'Already have an account?',
      'dont_have_account': 'Don\'t have an account?',
      'invalid_email': 'Invalid email address',
      'password_mismatch': 'Passwords do not match',
      'password_requirements': 'Password must be at least 6 characters',

      // Profile
      'profile': 'Profile',
      'edit_profile': 'Edit Profile',
      'name': 'Name',
      'phone': 'Phone',
      'address': 'Address',
      'bio': 'Bio',
      'change_photo': 'Change Photo',
      'remove_photo': 'Remove Photo',
      'update_profile': 'Update Profile',
      'profile_updated': 'Profile updated successfully',

      // Driver
      'driver_screen': 'Driver Mode',
      'online': 'Online',
      'offline': 'Offline',
      'you_are_offline': 'You are offline',
      'toggle_switch': 'Toggle the switch to go online',
      'complete_verification': 'Complete Driver Verification',
      'verification_pending': 'Verification Pending',
      'verification_approved': 'Verification Approved',
      'verification_rejected': 'Verification Rejected',
      'upload_id_card': 'Upload ID Card',
      'upload_license': 'Upload License',
      'id_number': 'ID Number',
      'license_number': 'License Number',
      'verification_submitted': 'Verification submitted successfully',
      'verification_error': 'Error submitting verification',

      // Rider
      'rider_screen': 'Rider Mode',
      'request_ride': 'Request Ride',
      'cancel_ride': 'Cancel Ride',
      'ride_status': 'Ride Status',
      'pickup_location': 'Pickup Location',
      'destination': 'Destination',
      'fare': 'Fare',
      'estimated_time': 'Estimated Time',
      'driver_details': 'Driver Details',
      'track_ride': 'Track Ride',
      'ride_completed': 'Ride Completed',
      'rate_ride': 'Rate Ride',
      'ride_cancelled': 'Ride Cancelled',

      // Settings
      'settings': 'Settings',
      'language_settings': 'Language Settings',
      'notifications': 'Notifications',
      'privacy': 'Privacy',
      'help': 'Help',
      'about': 'About',
      'terms': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',
      'version': 'Version',
      'logout': 'Logout',

      // Ratings
      'ratings': 'Ratings',
      'your_rating': 'Your Rating',
      'average_rating': 'Average Rating',
      'no_ratings': 'No ratings yet',
      'add_comment': 'Add a comment (optional)',
      'submit_rating': 'Submit Rating',
      'rating_submitted': 'Rating submitted successfully',
      'rating_error': 'Error submitting rating',

      // Navigation
      'start_navigation': 'Start Navigation',
      'end_navigation': 'End Navigation',
      'following_route': 'Following route to destination...',
      'share_ride': 'Share Ride Details',
      'refresh': 'Refresh',
    },
    'fr': {
      // Common
      'app_name': 'DeplaceToi',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'submit': 'Soumettre',
      'skip': 'Passer',
      'next': 'Suivant',
      'back': 'Retour',
      'done': 'Terminé',
      'retry': 'Réessayer',
      'close': 'Fermer',
      'search': 'Rechercher',
      'no_results': 'Aucun résultat trouvé',
      'required_field': 'Ce champ est obligatoire',

      // Auth
      'login': 'Connexion',
      'register': 'Inscription',
      'email': 'Email',
      'password': 'Mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'forgot_password': 'Mot de passe oublié ?',
      'reset_password': 'Réinitialiser le mot de passe',
      'sign_in': 'Se connecter',
      'sign_up': 'S\'inscrire',
      'sign_out': 'Se déconnecter',
      'welcome_back': 'Bienvenue',
      'create_account': 'Créer un compte',
      'already_have_account': 'Vous avez déjà un compte ?',
      'dont_have_account': 'Vous n\'avez pas de compte ?',
      'invalid_email': 'Adresse email invalide',
      'password_mismatch': 'Les mots de passe ne correspondent pas',
      'password_requirements': 'Le mot de passe doit contenir au moins 6 caractères',

      // Profile
      'profile': 'Profil',
      'edit_profile': 'Modifier le profil',
      'name': 'Nom',
      'phone': 'Téléphone',
      'address': 'Adresse',
      'bio': 'Bio',
      'change_photo': 'Changer la photo',
      'remove_photo': 'Supprimer la photo',
      'update_profile': 'Mettre à jour le profil',
      'profile_updated': 'Profil mis à jour avec succès',

      // Driver
      'driver_screen': 'Mode Conducteur',
      'online': 'En ligne',
      'offline': 'Hors ligne',
      'you_are_offline': 'Vous êtes hors ligne',
      'toggle_switch': 'Activez le bouton pour être en ligne',
      'complete_verification': 'Compléter la vérification',
      'verification_pending': 'Vérification en attente',
      'verification_approved': 'Vérification approuvée',
      'verification_rejected': 'Vérification rejetée',
      'upload_id_card': 'Télécharger la carte d\'identité',
      'upload_license': 'Télécharger le permis',
      'id_number': 'Numéro d\'identité',
      'license_number': 'Numéro de permis',
      'verification_submitted': 'Vérification soumise avec succès',
      'verification_error': 'Erreur lors de la soumission de la vérification',

      // Rider
      'rider_screen': 'Mode Passager',
      'request_ride': 'Demander un trajet',
      'cancel_ride': 'Annuler le trajet',
      'ride_status': 'Statut du trajet',
      'pickup_location': 'Point de départ',
      'destination': 'Destination',
      'fare': 'Prix',
      'estimated_time': 'Temps estimé',
      'driver_details': 'Détails du conducteur',
      'track_ride': 'Suivre le trajet',
      'ride_completed': 'Trajet terminé',
      'rate_ride': 'Évaluer le trajet',
      'ride_cancelled': 'Trajet annulé',

      // Settings
      'settings': 'Paramètres',
      'language_settings': 'Paramètres de langue',
      'notifications': 'Notifications',
      'privacy': 'Confidentialité',
      'help': 'Aide',
      'about': 'À propos',
      'terms': 'Conditions d\'utilisation',
      'privacy_policy': 'Politique de confidentialité',
      'version': 'Version',
      'logout': 'Déconnexion',

      // Ratings
      'ratings': 'Évaluations',
      'your_rating': 'Votre évaluation',
      'average_rating': 'Note moyenne',
      'no_ratings': 'Pas encore d\'évaluations',
      'add_comment': 'Ajouter un commentaire (optionnel)',
      'submit_rating': 'Soumettre l\'évaluation',
      'rating_submitted': 'Évaluation soumise avec succès',
      'rating_error': 'Erreur lors de la soumission de l\'évaluation',

      // Navigation
      'start_navigation': 'Démarrer la navigation',
      'end_navigation': 'Terminer la navigation',
      'following_route': 'Suivi de l\'itinéraire vers la destination...',
      'share_ride': 'Partager les détails du trajet',
      'refresh': 'Actualiser',
    },
    'ar': {
      // Common
      'app_name': 'دبلاس تو',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجاح',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'delete': 'حذف',
      'edit': 'تعديل',
      'submit': 'إرسال',
      'skip': 'تخطي',
      'next': 'التالي',
      'back': 'رجوع',
      'done': 'تم',
      'retry': 'إعادة المحاولة',
      'close': 'إغلاق',
      'search': 'بحث',
      'no_results': 'لا توجد نتائج',
      'required_field': 'هذا الحقل مطلوب',

      // Auth
      'login': 'تسجيل الدخول',
      'register': 'تسجيل',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirm_password': 'تأكيد كلمة المرور',
      'forgot_password': 'نسيت كلمة المرور؟',
      'reset_password': 'إعادة تعيين كلمة المرور',
      'sign_in': 'تسجيل الدخول',
      'sign_up': 'إنشاء حساب',
      'sign_out': 'تسجيل الخروج',
      'welcome_back': 'مرحباً بعودتك',
      'create_account': 'إنشاء حساب',
      'already_have_account': 'لديك حساب بالفعل؟',
      'dont_have_account': 'ليس لديك حساب؟',
      'invalid_email': 'بريد إلكتروني غير صالح',
      'password_mismatch': 'كلمات المرور غير متطابقة',
      'password_requirements': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',

      // Profile
      'profile': 'الملف الشخصي',
      'edit_profile': 'تعديل الملف الشخصي',
      'name': 'الاسم',
      'phone': 'الهاتف',
      'address': 'العنوان',
      'bio': 'نبذة',
      'change_photo': 'تغيير الصورة',
      'remove_photo': 'حذف الصورة',
      'update_profile': 'تحديث الملف الشخصي',
      'profile_updated': 'تم تحديث الملف الشخصي بنجاح',

      // Driver
      'driver_screen': 'وضع السائق',
      'online': 'متصل',
      'offline': 'غير متصل',
      'you_are_offline': 'أنت غير متصل',
      'toggle_switch': 'قم بتفعيل الزر للاتصال',
      'complete_verification': 'إكمال التحقق',
      'verification_pending': 'التحقق قيد الانتظار',
      'verification_approved': 'تمت الموافقة على التحقق',
      'verification_rejected': 'تم رفض التحقق',
      'upload_id_card': 'تحميل بطاقة الهوية',
      'upload_license': 'تحميل رخصة القيادة',
      'id_number': 'رقم الهوية',
      'license_number': 'رقم الرخصة',
      'verification_submitted': 'تم تقديم التحقق بنجاح',
      'verification_error': 'خطأ في تقديم التحقق',

      // Rider
      'rider_screen': 'وضع الراكب',
      'request_ride': 'طلب رحلة',
      'cancel_ride': 'إلغاء الرحلة',
      'ride_status': 'حالة الرحلة',
      'pickup_location': 'موقع الانطلاق',
      'destination': 'الوجهة',
      'fare': 'السعر',
      'estimated_time': 'الوقت المقدر',
      'driver_details': 'تفاصيل السائق',
      'track_ride': 'تتبع الرحلة',
      'ride_completed': 'اكتملت الرحلة',
      'rate_ride': 'تقييم الرحلة',
      'ride_cancelled': 'تم إلغاء الرحلة',

      // Settings
      'settings': 'الإعدادات',
      'language_settings': 'إعدادات اللغة',
      'notifications': 'الإشعارات',
      'privacy': 'الخصوصية',
      'help': 'المساعدة',
      'about': 'حول',
      'terms': 'شروط الخدمة',
      'privacy_policy': 'سياسة الخصوصية',
      'version': 'الإصدار',
      'logout': 'تسجيل الخروج',

      // Ratings
      'ratings': 'التقييمات',
      'your_rating': 'تقييمك',
      'average_rating': 'متوسط التقييم',
      'no_ratings': 'لا توجد تقييمات بعد',
      'add_comment': 'أضف تعليقاً (اختياري)',
      'submit_rating': 'إرسال التقييم',
      'rating_submitted': 'تم إرسال التقييم بنجاح',
      'rating_error': 'خطأ في إرسال التقييم',

      // Navigation
      'start_navigation': 'بدء الملاحة',
      'end_navigation': 'إنهاء الملاحة',
      'following_route': 'تتبع المسار إلى الوجهة...',
      'share_ride': 'مشاركة تفاصيل الرحلة',
      'refresh': 'تحديث',
    },
  };

  LanguageService() {
    _loadLanguage();
  }

  String get currentLanguage => _currentLanguage;

  Future<void> _loadLanguage() async {
    _prefs = await SharedPreferences.getInstance();
    _currentLanguage = _prefs.getString(_languageKey) ?? _defaultLanguage;
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    if (_translations.containsKey(languageCode)) {
      _currentLanguage = languageCode;
      await _prefs.setString(_languageKey, languageCode);
      notifyListeners();
    }
  }

  String translate(String key) {
    return _translations[_currentLanguage]?[key] ?? 
           _translations[_defaultLanguage]?[key] ?? 
           key;
  }
} 