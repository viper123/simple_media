# Consumer ProGuard/R8 rules for the simple_media plugin.
# These are automatically merged into the R8 configuration of any app that
# depends on this plugin (see `consumerProguardFiles` in build.gradle), so the
# classes below survive minification/obfuscation in release builds.

# --- Protobuf (DataStore persistence) -------------------------------------
# The last-played item is persisted via a protobuf-lite generated `Preferences`
# message. protobuf-javalite reads/writes the message fields reflectively, so
# the generated classes (message + Builder) must not be stripped or renamed.
-keep class net.hevsoft.androidmedia.Preferences { *; }
-keep class net.hevsoft.androidmedia.Preferences$* { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}

# --- Media3 foreground playback service -----------------------------------
# PlaybackService is referenced by name in the host AndroidManifest and is
# instantiated by the system via the `androidx.media3.session.MediaSessionService`
# intent-filter. Keep it (and its DemoPlaybackService base) intact.
-keep class net.hevsoft.androidmedia.library.PlaybackService { *; }
-keep class net.hevsoft.androidmedia.library.DemoPlaybackService { *; }
