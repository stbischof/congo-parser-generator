/* Generated by: ${generated_by}. Do not edit. ${grammar.copyrightBlurb}
 * Generated Code for TokenType  
 * by the TokenType.java.ftl template
 */
[#if grammar.parserPackage?has_content]
package ${grammar.parserPackage};
[/#if]

public enum TokenType 
[#if grammar.treeBuildingEnabled]
   implements Node.NodeType
[/#if]
{
     [#list grammar.lexerData.regularExpressions as regexp]
       ${regexp.label},
     [/#list]
     [#list grammar.extraTokenNames as extraToken]
       ${extraToken},
     [/#list]
     INVALID
}