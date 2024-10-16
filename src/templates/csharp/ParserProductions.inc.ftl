[#-- This template contains the core logic for generating the various parser routines. --]

[#import "CommonUtils.inc.ftl" as CU]

[#var nodeNumbering = 0]
[#var NODE_USES_PARSER = settings.nodeUsesParser]
[#var NODE_PREFIX = grammar.nodePrefix]
[#var currentProduction]

[#macro Productions]
// ===================================================================
// Start of methods for BNF Productions
// This code is generated by the ParserProductions.inc.ftl template.
// ===================================================================
[#list grammar.parserProductions as production]
  [@CU.firstSetVar production.expansion/]
   [#if !production.onlyForLookahead]
    [#set currentProduction = production]
    [@ParserProduction production/]
   [/#if]
[/#list]
[#if settings.faultTolerant]
  [@BuildRecoverRoutines /]
[/#if]
[/#macro]

[#macro ParserProduction production]
        ${production.leadingComments}
        // ${production.location}
        ${globals.startProduction()}${globals.translateModifiers(production.accessModifier)} ${globals.translateType(production.returnType)} Parse${production.name}([#if production.parameterList?has_content]${globals.translateParameters(production.parameterList)}[/#if]) {
            var prevProduction = _currentlyParsedProduction;
            _currentlyParsedProduction = "${production.name}";
${BuildCode(production.expansion, 12)}
        }
        // end of Parse${production.name}${globals.endProduction()}

[/#macro]

[#macro BuildCode expansion indent]
[#var is=""?right_pad(indent)]
[#-- ${is}// DBG > BuildCode ${indent} ${expansion.simpleName} --]
  [#if expansion.simpleName != "ExpansionSequence" && expansion.simpleName != "ExpansionWithParentheses"]
${is}// Code for ${expansion.simpleName} specified at ${expansion.location}
  [/#if]
     [@CU.HandleLexicalStateChange expansion false indent; indent]
      [#if settings.faultTolerant && expansion.requiresRecoverMethod && !expansion.possiblyEmpty]
${is}if (_pendingRecovery) {
${is}    ${expansion.recoverMethodName}()
${is}}
      [/#if]
       [@TreeBuildingAndRecovery expansion indent/]
     [/@CU.HandleLexicalStateChange]
[#-- ${is}// DBG < BuildCode ${indent} ${expansion.simpleName} --]
[/#macro]

[#macro TreeBuildingAndRecovery expansion indent]
[#-- This macro handles both tree building AND recovery. It doesn't seem right.
     It should probably be two macros. Also, it is too darned big. --]
[#var is=""?right_pad(indent)]
[#-- ${is}// DBG > TreeBuildingAndRecovery ${indent} --]
    [#var nodeVarName,
          nodeTypeName,
          production,
          treeNodeBehavior,
          treeNodeLHS,
          buildTreeNode=false,
          closeCondition = "true",
          javaCodePrologue = null,
          parseExceptionVar = CU.newVarName("parseException"),
          callStackSizeVar = CU.newVarName("callStackSize"),
          canRecover = settings.faultTolerant && expansion.tolerantParsing && expansion.simpleName != "Terminal"
    ]
    [#set treeNodeBehavior = expansion.treeNodeBehavior]
    [#if treeNodeBehavior?? && expansion.treeNodeBehavior.LHS??]
          [#set treeNodeLHS = expansion.treeNodeBehavior.LHS]
    [/#if]
    [#if expansion.parent.simpleName = "BNFProduction"]
      [#set production = expansion.parent]
      [#set javaCodePrologue = production.javaCode]
    [/#if]
    [#if settings.treeBuildingEnabled]
      [#set buildTreeNode = (treeNodeBehavior?is_null && production?? && !settings.nodeDefaultVoid)
                        || (treeNodeBehavior?? && !treeNodeBehavior.neverInstantiated)]
    [/#if]
    [#if !buildTreeNode && !canRecover]
${globals.translateCodeBlock(javaCodePrologue, indent)}[#rt]
${BuildExpansionCode(expansion, indent)}[#t]
    [#else]
     [#-- buildTreeNode || canRecover --]
     [#if buildTreeNode]
       [#if production??]
       [#set nodeVarName = "thisProduction"] 
       [#-- this is so that (potentially deeply nested) code blocks can easily reference the production node.
         Instead could be a currentProduction.name with the first char lower-cased, maybe, but I don't think so. Also,
         I didn't change CURRENT_NODE to refer to this because it would affect TBA nodes below the top level, but if
         CURRENT_NODE is meant to refer to the current production, then it probably should be changed.  I suspect that
         uses of CURRENT_NODE are all at the top level now anyway and the need to reference the current node just built is relatively
         rare and could use peek(). --]
       [#else]
       [#set nodeNumbering = nodeNumbering +1]
       [#set nodeVarName = currentProduction.name + nodeNumbering] 
       [/#if]
       ${globals.pushNodeVariableName(nodeVarName)!}
       [#set nodeTypeName = nodeClassName(treeNodeBehavior)]      
       [#if !treeNodeBehavior?? && !production?is_null]
         [#if settings.smartNodeCreation]
            [#set treeNodeBehavior = {"name" : production.name, "condition" : "1", "gtNode" : true, "void" :false, "initialShorthand" : " > "}]
         [#else]
            [#set treeNodeBehavior = {"name" : production.name, "condition" : null, "gtNode" : false, "void" : false}]
         [/#if]
      [/#if]
      [#if treeNodeBehavior.condition?has_content]
         [#set closeCondition = globals.translateString(treeNodeBehavior.condition)]
         [#if treeNodeBehavior.gtNode]
            [#set closeCondition = "NodeArity" + treeNodeBehavior.initialShorthand + closeCondition]
         [/#if]
      [/#if]
      [@createNode treeNodeBehavior nodeVarName indent /]
      [/#if]
         [#-- I put this here for the hypertechnical reason
              that I want the initial code block to be able to
              reference CURRENT_NODE. --]
${globals.translateCodeBlock(javaCodePrologue, indent)}
${is}ParseException ${parseExceptionVar} = null;
${is}var ${callStackSizeVar} = ParsingStack.Count;
${is}try {
[#-- ${is}    pass  # in case there's nothing else in the try clause! --]
[#-- ${is}    # nested code starts, passing indent of ${indent + 4} --]
${BuildExpansionCode(expansion, indent + 4)}[#t]
[#-- ${is}    # nested code ends --]
${is}}
${is}catch (ParseException e) {
${is}    ${parseExceptionVar} = e;
            [#if !canRecover]
              [#if settings.faultTolerant]
${is}    if (IsTolerant) _pendingRecovery = true;
              [/#if]
${is}    throw;
            [#else]
${is}    if (!IsTolerant) throw;
${is}    _pendingRecovery = true;
         ${expansion.customErrorRecoveryBlock!}
             [#if !production?is_null && production.returnType != "void"]
                [#var rt = production.returnType]
                [#-- We need a return statement here or the code won't compile! --]
                [#if rt = "int" || rt="char" || rt=="byte" || rt="short" || rt="long" || rt="float"|| rt="double"]
${is}       return 0;
                [#else]
${is}       return null;
                [/#if]
             [/#if]
          [/#if]
${is}}
${is}finally {
${is}    RestoreCallStack(${callStackSizeVar});
[#if buildTreeNode]
${is}    if (${nodeVarName} != null) {
${is}        if (${parseExceptionVar} == null) {
${is}            CloseNodeScope(${nodeVarName}, ${closeCondition});
  [#if treeNodeLHS??]
${is}             try {
${is}                 ${treeNodeLHS} = (${nodeTypeName}) PeekNode();
${is}             } catch (Exception) {
${is}                  ${treeNodeLHS} = null;
${is}             }
  [/#if]
  [#list grammar.closeNodeHooksByClass[nodeClassName(treeNodeBehavior)]! as hook]
${is}            ${hook}(${nodeVarName});
  [/#list]
${is}        }
${is}        else {
    [#if settings.faultTolerant]
${is}            CloseNodeScope(${nodeVarName}, true);
${is}            ${nodeVarName}.dirty = true;
    [#else]
${is}            ClearNodeScope();
    [/#if]
                ${globals.popNodeVariableName()!}
${is}        }
[/#if]
${is}        _currentlyParsedProduction = prevProduction;
${is}    }
${is}}
[/#if]
[#-- ${is}// DBG < TreeBuildingAndRecovery ${indent} --]
[/#macro]

[#--  Boilerplate code to create the node variable --]
[#macro createNode treeNodeBehavior nodeVarName indent]
[#var is=""?right_pad(indent)]
   [#var nodeName = nodeClassName(treeNodeBehavior)]
${is}${nodeName} ${nodeVarName} = null;
${is}if (BuildTree) {
${is}    ${nodeVarName} = new ${nodeName}([#if settings.nodeUsesParser]this[#else]tokenSource[/#if]);
${is}    OpenNodeScope(${nodeVarName});
${is}}
[/#macro]

[#function nodeClassName treeNodeBehavior]
   [#if treeNodeBehavior?? && treeNodeBehavior.nodeName??]
      [#return NODE_PREFIX + treeNodeBehavior.nodeName]
   [/#if]
   [#return NODE_PREFIX + currentProduction.name]
[/#function]


[#macro BuildExpansionCode expansion indent]
[#var is=""?right_pad(indent)]
[#var classname=expansion.simpleName]
[#-- ${is}// DBG > BuildExpansionCode ${indent} ${classname} --]
    [#var prevLexicalStateVar = CU.newVarName("previousLexicalState")]
    [#if classname = "ExpansionWithParentheses"]
${BuildExpansionCode(expansion.nestedExpansion, indent)}[#t]
    [#elseif classname = "CodeBlock"]
${globals.translateCodeBlock(expansion, indent)}
    [#elseif classname = "Failure"]
       [@BuildCodeFailure expansion indent /]
    [#elseif classname = "TokenTypeActivation"]
       [@BuildCodeTokenTypeActivation expansion indent /]
    [#elseif classname = "ExpansionSequence"]
       [@BuildCodeSequence expansion indent /]
    [#elseif classname = "NonTerminal"]
       [@BuildCodeNonTerminal expansion indent /]
    [#elseif classname = "Terminal"]
       [@BuildCodeTerminal expansion indent /]
    [#elseif classname = "TryBlock"]
       [@BuildCodeTryBlock expansion indent /]
    [#elseif classname = "AttemptBlock"]
       [@BuildCodeAttemptBlock expansion indent /]
    [#elseif classname = "ZeroOrOne"]
       [@BuildCodeZeroOrOne expansion indent /]
    [#elseif classname = "ZeroOrMore"]
       [@BuildCodeZeroOrMore expansion indent /]
    [#elseif classname = "OneOrMore"]
        [@BuildCodeOneOrMore expansion indent /]
    [#elseif classname = "ExpansionChoice"]
        [@BuildCodeChoice expansion indent /]
    [#elseif classname = "Assertion"]
        [@BuildAssertionCode expansion indent /]
    [/#if]
[#-- ${is}// DBG < BuildExpansionCode ${indent} ${classname} --]
[/#macro]

[#macro BuildCodeFailure fail indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeFailure ${indent} --]
    [#if fail.code?is_null]
      [#if fail.exp??]
${is}Fail("Failure: " + ${fail.exp});
      [#else]
${is}Fail("Failure");
      [/#if]
    [#else]
${globals.translateCodeBlock(fail.code, indent)}
    [/#if]
[#-- ${is}// DBG < BuildCodeFailure ${indent} --]
[/#macro]

[#macro BuildCodeTokenTypeActivation activation indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeTokenTypeActivation ${indent} --]
[#if activation.deactivate]
${is}DeactivateTokenTypes(
[#else]
${is}ActivateTokenTypes(
[/#if]
[#list activation.tokenNames as name]
${is}    ${name}[#if name_has_next],[/#if]
[/#list]
${is});
[#-- ${is}// DBG < BuildCodeTokenTypeActivation ${indent} --]
[/#macro]

[#macro BuildCodeSequence expansion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeSequence ${indent} --]
  [#list expansion.units as subexp]
${BuildCode(subexp, indent)}
  [/#list]
[#-- ${is}// DBG < BuildCodeSequence ${indent} --]
[/#macro]

[#macro BuildCodeTerminal terminal indent]
[#var regexp =terminal.regexp]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeRegexp ${indent} --]
   [#var LHS = ""]
   [#if terminal.lhs??][#set LHS = terminal.lhs + " = "][/#if]
   [#if !settings.faultTolerant]
${is}${LHS}ConsumeToken(TokenType.${regexp.label});
   [#else]
       [#var tolerant = terminal.tolerantParsing?string("true", "false")]
       [#var followSetVarName = terminal.followSetVarName]
       [#if terminal.followSet.incomplete]
         [#set followSetVarName = "followSet" + CU.newID()]
${is}HashSet<TokenType> ${followSetVarName} = null;
${is}if (OuterFollowSet != null) {
${is}    ${followSetVarName} = ${terminal.followSetVarName}.Clone();
${is}    ${followSetVarName}.AddAll(OuterFollowSet);
${is}}
       [/#if]
${is}${LHS}ConsumeToken(${CU.TT}${regexp.label}, ${tolerant}, ${followSetVarName});
   [/#if]
   [#if !terminal.childName?is_null]
${is}if (BuildTree) {
${is}    Node child = PeekNode();
${is}    string name = "${terminal.childName}";
    [#if terminal.multipleChildren]
${is}    ${globals.currentNodeVariableName}.AddToNamedChildList(name, child);
    [#else]
${is}    ${globals.currentNodeVariableName}.SetNamedChild(name, child);
    [/#if]
${is}}
   [/#if]

[#-- ${is}// DBG < BuildCodeRegexp ${indent} --]
[/#macro]

[#macro BuildCodeTryBlock tryblock indent]
[#var is = ""?right_pad(indent)]
${is}// DBG > BuildCodeTryBlock ${indent}
${is}try:
${BuildCode(tryblock.nestedExpansion, indent + 4)}
   [#list tryblock.catchBlocks as catchBlock]
   # TODO verify indentation
${is}${catchBlock}
   [/#list]
   # TODO verify indentation
${is}${tryblock.finallyBlock!}
${is}// DBG < BuildCodeTryBlock ${indent}
[/#macro]


[#macro BuildCodeAttemptBlock attemptBlock indent]
[#var is = ""?right_pad(indent)]
${is}// DBG > BuildCodeAttemptBlock ${indent}
${is}try {
${is}    StashParseState();
${BuildCode(attemptBlock.nestedExpansion, indent + 4)}
${is}    PopParseState();
${is}}
${is}catch (ParseException) {
${is}    RestoreStashedParseState();
${BuildCode(attemptBlock.recoveryExpansion, indent + 4)}
${is}}
${is}// DBG < BuildCodeAttemptBlock ${indent}
[/#macro]

[#macro BuildCodeNonTerminal nonterminal indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeNonTerminal ${indent} ${nonterminal.production.name} --]
   [#var production = nonterminal.production]
${is}PushOntoCallStack("${nonterminal.containingProduction.name}", "${nonterminal.inputSource?j_string}", ${nonterminal.beginLine}, ${nonterminal.beginColumn});
   [#var followSet = nonterminal.followSet]
   [#if !followSet.incomplete]
      [#if !nonterminal.beforeLexicalStateSwitch]
${is}OuterFollowSet = ${nonterminal.followSetVarName};
      [#else]
${is}OuterFollowSet = null;
      [/#if]
   [#else]
     [#if !followSet.isEmpty()]
${is}if (OuterFollowSet != null) {
${is}    var newFollowSet = new HashSet<TokenType>(${nonterminal.followSetVarName});
${is}    newFollowSet.UnionWith(OuterFollowSet);
${is}    OuterFollowSet = newFollowSet;
${is}}
     [/#if]
   [/#if]
${is}try {
   [#if !nonterminal.LHS?is_null && production.returnType != "void"]
${is}    ${nonterminal.LHS} =
   [/#if]
${is}    Parse${nonterminal.name}(${globals.translateNonterminalArgs(nonterminal.args)});
   [#if !nonterminal.LHS?is_null && production.returnType = "void"]
${is}    try {
${is}        ${nonterminal.LHS} = PeekNode();
${is}    }
${is}    catch (Exception) {
${is}        ${nonterminal.LHS} = null;
${is}    }
   [/#if]
   [#if !nonterminal.childName?is_null]
${is}    if (BuildTree) {
${is}        Node child = PeekNode();
${is}        String name = "${nonterminal.childName}";
    [#if nonterminal.multipleChildren]
${is}        ${globals.currentNodeVariableName}.AddToNamedChildList(name, child);
    [#else]
${is}        ${globals.currentNodeVariableName}.SetNamedChild(name, child);
    [/#if]
${is}    }
   [/#if]
${is}}
${is}finally {
${is}    PopCallStack();
${is}}
[#-- ${is}// DBG < BuildCodeNonTerminal ${indent} ${nonterminal.production.name} --]
[/#macro]


[#macro BuildCodeZeroOrOne zoo indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeZeroOrOne ${indent} ${zoo.nestedExpansion.class.simpleName} --]
    [#if zoo.nestedExpansion.class.simpleName = "ExpansionChoice"]
${BuildCode(zoo.nestedExpansion, indent)}
    [#else]
${is}if (${ExpansionCondition(zoo.nestedExpansion)}) {
${BuildCode(zoo.nestedExpansion, indent + 4)}
${is}}
    [/#if]
[#-- ${is}// DBG < BuildCodeZeroOrOne ${indent} ${zoo.nestedExpansion.class.simpleName} --]
[/#macro]

[#var inFirstVarName = "", inFirstIndex =0]

[#macro BuildCodeOneOrMore oom indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeOneOrMore ${indent} --]
[#var nestedExp=oom.nestedExpansion, prevInFirstVarName = inFirstVarName/]
   [#if nestedExp.simpleName = "ExpansionChoice"]
     [#set inFirstVarName = "inFirst" + inFirstIndex, inFirstIndex = inFirstIndex +1 /]
${is}var ${inFirstVarName} = true;
   [/#if]
${is}while (true) {
${RecoveryLoop(oom, indent + 4)}
      [#if nestedExp.simpleName = "ExpansionChoice"]
${is}    ${inFirstVarName} = false;
      [#else]
${is}    if (!(${ExpansionCondition(oom.nestedExpansion)})) break;
      [/#if]
${is}}
   [#set inFirstVarName = prevInFirstVarName /]
[#-- ${is}// DBG < BuildCodeOneOrMore ${indent} --]
[/#macro]

[#macro BuildCodeZeroOrMore zom indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeZeroOrMore ${indent} --]
${is}while (true) {
       [#if zom.nestedExpansion.class.simpleName != "ExpansionChoice"]
${is}    if (!(${ExpansionCondition(zom.nestedExpansion)})) break;
       [/#if]
       [@RecoveryLoop zom indent + 4 /]
${is}}
[#-- ${is}// DBG < BuildCodeZeroOrMore ${indent} --]
[/#macro]

[#macro RecoveryLoop loopExpansion indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > RecoveryLoop ${indent} --]
[#if !settings.faultTolerant || !loopExpansion.requiresRecoverMethod]
${BuildCode(loopExpansion.nestedExpansion, indent)}
[#else]
[#var initialTokenVarName = "initialToken" + CU.newID()]
${is}${initialTokenVarName} = LastConsumedToken;
${is}try {
${BuildCode(loopExpansion.nestedExpansion, indent + 4)}
${is}}
${is}catch (ParseException pe) {
${is}    if (!IsTolerant) throw;
${is}    if (debugFaultTolerant) {
${is}        // logger.info('Handling exception. Last consumed token: %s at: %s', lastConsumedToken.image, lastConsumedToken.location)
${is}    }
${is}    if (${initialTokenVarName} == LastConsumedToken) {
${is}        LastConsumedToken = NextToken(LastConsumedToken);
${is}        // We have to skip a token in this spot or
${is}        // we'll be stuck in an infinite loop!
${is}        LastConsumedToken.skipped = true;
${is}        if (debugFaultTolerant) {
${is}            // logger.info('Skipping token %s at: %s', lastConsumedToken.image, lastConsumedToken.location)
${is}        }
${is}    }
${is}    if (debugFaultTolerant) {
${is}        // logger.info('Repeat re-sync for expansion at: ${loopExpansion.location?j_string}');
${is}    }
${is}    ${loopExpansion.recoverMethodName}();
${is}    if (pendingRecovery) throw;
   [/#if]
[#-- ${is}// DBG < RecoveryLoop ${indent} --]
[/#macro]

[#macro BuildCodeChoice choice indent]
[#var is = ""?right_pad(indent)]
[#-- ${is}// DBG > BuildCodeChoice ${indent} --]
   [#list choice.choices as expansion]
${is}${(expansion_index=0)?string("if", "else if")} (${ExpansionCondition(expansion)}) {
${BuildCode(expansion, indent + 4)}
${is}}
   [/#list]
   [#if choice.parent.simpleName == "ZeroOrMore"]
${is}else {
${is}    break;
${is}}
   [#elseif choice.parent.simpleName = "OneOrMore"]
${is}else if (${inFirstVarName}) {
${is}    PushOntoCallStack("${currentProduction.name}", "${choice.inputSource?j_string}", ${choice.beginLine}, ${choice.beginColumn});
${is}    throw new ParseException(this, ${choice.firstSetVarName});
${is}}
${is}else {
${is}    break;
${is}}
   [#elseif choice.parent.simpleName != "ZeroOrOne"]
${is}else {
${is}    PushOntoCallStack("${currentProduction.name}", "${choice.inputSource?j_string}", ${choice.beginLine}, ${choice.beginColumn});
${is}    throw new ParseException(this, ${choice.firstSetVarName});
${is}}
   [/#if]
[#-- ${is}// DBG < BuildCodeChoice ${indent} --]
[/#macro]

[#--
     Macro to generate the condition for entering an expansion
     including the default single-token lookahead
--]
[#macro ExpansionCondition expansion]
[#if expansion.requiresPredicateMethod]${ScanAheadCondition(expansion)}[#else]${SingleTokenCondition(expansion)}[/#if][#t]
[/#macro]


[#-- Generates code for when we need a scanahead --]
[#macro ScanAheadCondition expansion]
[#if expansion.lookahead?? && expansion.lookahead.LHS??](${expansion.lookahead.LHS} = [/#if][#if expansion.hasSemanticLookahead && !expansion.lookahead.semanticLookaheadNested](${globals.translateExpression(expansion.semanticLookahead)}) && [/#if]${expansion.predicateMethodName}()[#if expansion.lookahead?? && expansion.lookahead.LHS??])[/#if][#t]
[/#macro]


[#-- Generates code for when we don't need any scanahead routine --]
[#macro SingleTokenCondition expansion]
   [#if expansion.hasSemanticLookahead](${globals.translateExpression(expansion.semanticLookahead)}) && [/#if][#t]
   [#if expansion.firstSet.tokenNames?size = 0 || expansion.lookaheadAmount ==0 || expansion.minimumSize=0]true[#elseif expansion.firstSet.tokenNames?size < 5][#list expansion.firstSet.tokenNames as name](NextTokenType == TokenType.${name})[#if name_has_next] || [/#if][/#list][#t][#else](${expansion.firstSetVarName}.Contains(NextTokenType))[/#if][#t]
[/#macro]

[#macro BuildAssertionCode assertion indent]
[#var is = ""?right_pad(indent)]
[#var optionalPart = ""]
[#if assertion.messageExpression??]
  [#set optionalPart = " + " + globals.translateExpression(assertion.messageExpression)]
[/#if]
   [#var assertionMessage = "Assertion at: " + assertion.location?j_string + " failed. "]
   [#if assertion.assertionExpression??]
${is}if (!(${globals.translateExpression(assertion.assertionExpression)})) {
${is}    Fail("${assertionMessage}"${optionalPart});
${is}}
   [/#if]
   [#if assertion.expansion??]
${is}if ([#if !assertion.expansionNegated]![/#if]${assertion.expansion.scanRoutineName}()) {
${is}    Fail("${assertionMessage}"${optionalPart});
${is}}
   [/#if]
[/#macro]


[#--
   Macro to build routines that scan up to the start of an expansion
   as part of a recovery routine
--]
[#macro BuildRecoverRoutines]
   [#list grammar.expansionsNeedingRecoverMethod as expansion]
    def ${expansion.recoverMethodName}(self):
        Token initialToken = LastConsumedToken;
        IList<Token> skippedTokens = new List<Token>();
        bool success = false;

        while (LastConsumedToken.Type != TokenType.EOF) {
[#if expansion.simpleName = "OneOrMore" || expansion.simpleName = "ZeroOrMore"]
            if (${ExpansionCondition(expansion.nestedExpansion)}) {
[#else]
            if (${ExpansionCondition(expansion)}) {
[/#if]
                success = true;
                break;
            }
            [#if expansion.simpleName = "ZeroOrMore" || expansion.simpleName = "OneOrMore"]
               [#var followingExpansion = expansion.followingExpansion]
               [#list 1..1000000 as unused]
                [#if followingExpansion?is_null][#break][/#if]
                [#if followingExpansion.maximumSize >0]
                 [#if followingExpansion.simpleName = "OneOrMore" || followingExpansion.simpleName = "ZeroOrOne" || followingExpansion.simpleName = "ZeroOrMore"]
                if (${ExpansionCondition(followingExpansion.nestedExpansion)}):
                 [#else]
                if (${ExpansionCondition(followingExpansion)}):
                 [/#if]
                    success = true;
                    break;
                }
                [/#if]
                [#if !followingExpansion.possiblyEmpty][#break][/#if]
                [#if followingExpansion.followingExpansion?is_null]
                if (OuterFollowSet != null) {
                    if (OuterFollowSet.Contains(NextTokenType)) {
                        success = true;
                        break;
                    }
                }
                 [#break/]
                [/#if]
                [#set followingExpansion = followingExpansion.followingExpansion]
               [/#list]
             [/#if]
            LastConsumedToken = NextToken(LastConsumedToken);
            skippedTokens.AddLastConsumedToken);
        if (!success && skippedTokens.Count > 0) {
             LastConsumedToken = initialToken;
        }
        if (success && skippedTokens.Count > 0) {
            iv = InvalidNode(self);
            foreach (var tok in skippedTokens) {
                iv.AddChild(tok);
            }
            if (debugFaultTolerant) {
                // logger.info('Skipping %s tokens starting at: %s', len(skippedTokens), skippedTokens[0].location)
            }
            PushNode(iv);
        pendingRecovery = !success;

   [/#list]
[/#macro]
