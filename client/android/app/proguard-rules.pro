# R8/Proguard rules — Flutter release 빌드에서 reflection 기반 클래스가
# strip되는 걸 막는다.

# WorkManager 내부 Room DB impl을 reflection으로 instantiate한다.
# 이게 R8에 의해 잘리면 'NoSuchMethodException: WorkDatabase_Impl.<init>'.
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-dontwarn androidx.work.**

# androidx.startup도 reflection으로 Initializer를 로드한다.
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }

# Room DB는 일반적으로 Impl/Companion이 reflection 대상.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**

# Firebase / Firestore에서 reflection 으로 모델 클래스를 인스턴스화.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# 일반적인 Flutter plugin 패턴 보호.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
