# flutter_stripe references optional Stripe Issuing classes that are absent
# unless push provisioning is enabled. R8 still checks these references.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.google.android.gms.tapandpay.**
-dontwarn kotlinx.parcelize.Parceler$DefaultImpls
-dontwarn kotlinx.parcelize.Parceler
-dontwarn kotlinx.parcelize.Parcelize

# Keep the Stripe SDK used by PaymentSheet in release builds.
-keep class com.stripe.** { *; }
