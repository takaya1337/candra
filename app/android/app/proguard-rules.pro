# Nothing of the app's own is kept by name: R8 renames and removes
# freely. The plugins bring the rules they need with them.

# Take the source file names and line numbers out of what is left.
-renamesourcefileattribute x
-keepattributes !SourceFile,!LineNumberTable

# Fold everything that can be into one package with no name.
-repackageclasses ''
-allowaccessmodification
