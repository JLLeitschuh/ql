/**
 * @name Temporary directory local information disclosure (file creation via inherently insecure method)
 * @description Creating a temporary file in the system shared temporary directory, using a method that always creates it world-readable, may disclose its contents to other users.
 * @kind problem
 * @problem.severity warning
 * @precision very-high
 * @id java/local-temp-file-or-directory-information-disclosure-insecure-method
 * @tags security
 *       external/cwe/cwe-200
 *       external/cwe/cwe-732
 */

import java
import TempDirUtils

abstract class MethodAccessInsecureFileCreation extends MethodAccess {
  /**
   * Gets the type of entity created (e.g. `file`, `directory`, ...).
   */
  abstract string getFileSystemEntityType();
}

/**
 * An insecure call to `java.io.File::createTempFile`.
 */
class MethodAccessInsecureFileCreateTempFile extends MethodAccessInsecureFileCreation {
  MethodAccessInsecureFileCreateTempFile() {
    this.getMethod() instanceof MethodFileCreateTempFile and
    (
      // `File.createTempFile(string, string)` always uses the default temporary directory
      this.getNumArgument() = 2
      or
      // The default temporary directory is used when the last argument of `File.createTempFile(string, string, File)` is `null`
      getArgument(2) instanceof NullLiteral
    )
  }

  override string getFileSystemType() { result = "file" }
}

class MethodGuavaFilesCreateTempFile extends Method {
  MethodGuavaFilesCreateTempFile() {
    getDeclaringType().hasQualifiedName("com.google.common.io", "Files") and
    hasName("createTempDir")
  }
}

class MethodAccessInsecureGuavaFilesCreateTempFile extends MethodAccessInsecureFileCreation {
  MethodAccessInsecureGuavaFilesCreateTempFile() {
    getMethod() instanceof MethodGuavaFilesCreateTempFile
  }

  override string getFileSystemType() { result = "directory" }
}

from MethodAccessInsecureFileCreation methodAccess
select methodAccess,
  "Local information disclosure vulnerability due to use of " + methodAccess.getFileSystemType() +
    " readable by other local users."
