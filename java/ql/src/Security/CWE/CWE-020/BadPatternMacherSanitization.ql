/**
 * @name Potential XSS filter bypass
 * @description Building Log4j log entries from user-controlled data may allow
 *              attackers to inject malicious code through JNDI lookups when
 *              using Log4J versions vulnerable to CVE-2021-44228.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id java/log4j-injection
 * @tags security
 *       external/cwe/cwe-020
 *       external/cwe/cwe-074
 *       external/cwe/cwe-400
 *       external/cwe/cwe-502
 */

import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.ExternalFlow
import DataFlow::PathGraph

class TypePattern extends Class {
    TypePattern() {
        this.hasQualifiedName("java.util.regex", "Pattern")
    }
}

class MethodPatternCompile extends Method {
    MethodPatternCompile() {
        this.getDeclaringType() instanceof TypePattern and
        this.hasName("compile")
    }
}

class PaternMatchingTaintConfiguration extends TaintTracking::Configuration {
    PaternMatchingTaintConfiguration() { this = "PaternMatchingTaintConfiguration" }
    
    override predicate isSource(DataFlow::Node node) {
        node.asExpr() = any(MethodAccess ma |
            ma.getMethod() instanceof MethodPatternCompile and
            DataFlow::localExprFlow(any(CompileTimeConstantExpr c | c.getStringValue() = "javascript:") , ma.getArgument(0))
        )
    }

    override predicate isAdditionalTaintStep(DataFlow::Node start, DataFlow::Node end) {
        end.asExpr() = any (MethodAccess ma |
            ma.getMethod().hasName(["matcher"]) and
            ma.getQualifier() = start.asExpr()
        )
    }
    
    override predicate isSink(DataFlow::Node node) {
        node.asExpr() = any(MethodAccess ma |
            ma.getMethod().hasName("replaceAll") and
            DataFlow::localExprFlow(any(CompileTimeConstantExpr c | c.getStringValue() = "") , ma.getArgument(0))
        )
    }
}

from PaternMatchingTaintConfiguration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "This $@ flows to a pattern entry.", source.getNode(), "user-provided value"
