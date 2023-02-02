[#var classname = filename[0..(filename?length -6)]]
/* Generated by: ${generated_by}. Do not edit. ${grammar.copyrightBlurb}
  * Generated Code for ${classname} Token subclass
  * by the ASTToken.java.ftl template
  */

[#var package = grammar.nodePackage]
[#if explicitPackageName??][#set package = explicitPackageName][/#if]

package ${package};

[#if package != grammar.parserPackage]
import ${grammar.parserPackage}.*;
[/#if]

[#if package != grammar.parserPackage]
import ${grammar.parserPackage}.*;
[/#if]

import ${grammar.parserPackage}.Token.TokenType;
import static ${grammar.parserPackage}.Token.TokenType.*;

public class ${classname} extends ${superclass} {
    public ${classname}(TokenType type, ${grammar.lexerClassName} tokenSource, int beginOffset, int endOffset) {
        super(type, tokenSource, beginOffset, endOffset);
    }
}