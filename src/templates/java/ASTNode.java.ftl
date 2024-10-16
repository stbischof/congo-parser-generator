[#var classname = filename[0..(filename?length -6)]]
 /* Generated by: ${generated_by}. Do not edit. ${settings.copyrightBlurb}
  * Generated Code for ${classname} AST Node type
  * by the ASTNode.java.ftl template
  */

package ${settings.nodePackage};

import ${settings.parserPackage}.*;

[#if settings.rootAPIPackage?has_content]
import ${settings.rootAPIPackage}.Node;
[/#if]

[#if isInterface]

public interface ${classname} extends Node {}

[#else]

import ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType;
import static ${settings.parserPackage}.${settings.baseTokenClassName}.TokenType.*;

[#if isAbstract]abstract[/#if]
public class ${classname} extends ${settings.baseNodeClassName} {}
[/#if]
