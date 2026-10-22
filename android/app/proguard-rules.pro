# Equipment Station — R8 / ProGuard rules.
#
# The google_mlkit_text_recognition plugin's TextRecognizer.initialize()
# references option classes for four non-Latin scripts. Those classes live
# in separate ML Kit artifacts (text-recognition-chinese, -devanagari,
# -japanese, -korean) that this app does not depend on — the station only
# reads Latin-script serial plates. The references are dead code paths for
# us, so tell R8 to ignore the missing classes instead of failing the
# release build. (If a non-Latin script is ever needed, add the matching
# ML Kit artifact dependency instead of these rules.)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
