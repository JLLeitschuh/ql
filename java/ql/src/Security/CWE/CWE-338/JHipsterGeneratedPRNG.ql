/**
 * @name Detect JHipster Generator Vulnnerability CVE-2019-16303
 * @description Detector for the CVE-2019-16303 vulnerability that existed in the JHipster code generator.
 * @kind problem
 * @problem.severity error
 * @precision very-high
 * @id java/jhipster-prng
 * @tags security
 *       external/cwe/cwe-338
 */

import java
import semmle.code.java.frameworks.apache.Lang

private class PredictableApacheRandomStringUtilsMethod extends Method {
  PredictableApacheRandomStringUtilsMethod() {
    this.getDeclaringType() instanceof TypeApacheRandomStringUtils
  }
}

private class PredictableApacheRandomStringUtilsMethodAccess extends MethodAccess {
  PredictableApacheRandomStringUtilsMethodAccess() {
    this.getMethod() instanceof PredictableApacheRandomStringUtilsMethod and
    // The one valid use of this type that uses SecureRandom as a source of data.
    not this.getMethod().getName() = "random"
  }
}

private class VulnerableJHipsterRandomUtilClass extends Class {
  VulnerableJHipsterRandomUtilClass() { getName() = "RandomUtil" }
}

private class VulnerableJHipsterRandomUtilMethod extends Method {
  VulnerableJHipsterRandomUtilMethod() {
    this.getDeclaringType() instanceof VulnerableJHipsterRandomUtilClass and
    this.getName().matches("generate%") and
    this.getReturnType() instanceof TypeString and
    exists(ReturnStmt s, PredictableApacheRandomStringUtilsMethodAccess access |
      s = this.getBody().(SingletonBlock).getStmt()
    |
      s.getResult() = access
    )
  }
}

from VulnerableJHipsterRandomUtilMethod the_method
select the_method,
  "RandomUtil was generated by JHipster Generator version vulnerable to CVE-2019-16303"