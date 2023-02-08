/* Generated by: ${generated_by}. ${filename} ${grammar.copyrightBlurb} */

[#var tokenCount=grammar.lexerData.tokenCount]

package ${grammar.parserPackage};

import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.BitSet;
import java.util.Collections;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.Iterator;
import java.util.ListIterator;
import java.util.Map;
import java.util.concurrent.CancellationException;
import ${grammar.parserPackage}.${grammar.lexerClassName}.LexicalState;
import ${grammar.parserPackage}.Token.TokenType;
import static ${grammar.parserPackage}.Token.TokenType.*;
[#if grammar.rootAPIPackage?has_content]
   import ${grammar.rootAPIPackage}.ParseException;
   import ${grammar.rootAPIPackage}.TokenSource;
   import ${grammar.rootAPIPackage}.NonTerminalCall;
   import ${grammar.rootAPIPackage}.Node;
[/#if]   
[#if grammar.faultTolerant]
  [#if grammar.rootAPIPackage?has_content]
     import ${grammar.rootAPIPackage}.InvalidNode;
     import ${grammar.rootAPIPackage}.ParsingProblem;
  [#else]
     import ${grammar.nodePackage}.InvalidNode;
  [/#if]
[/#if]

[#if grammar.treeBuildingEnabled]
  [#list grammar.nodeNames as node]
    [#if node?index_of('.')>0]
      import ${node};
    [#else]
      import ${grammar.nodePackage}.${grammar.nodePrefix}${node};
    [/#if]
  [/#list]
[/#if]

public class ${grammar.parserClassName} {

static final int UNLIMITED = Integer.MAX_VALUE;    
// The last token successfully "consumed"
Token lastConsumedToken;
private TokenType nextTokenType;
private Token currentLookaheadToken;
private int remainingLookahead;
private boolean hitFailure, passedPredicate;
private String currentlyParsedProduction, currentLookaheadProduction;
private int lookaheadRoutineNesting, passedPredicateThreshold = -1;
EnumSet<TokenType> outerFollowSet;

[#if grammar.legacyGlitchyLookahead]
   private boolean legacyGlitchyLookahead = true;
[#else]
   private boolean legacyGlitchyLookahead = false;
[/#if]

private final Token DUMMY_START_TOKEN = new Token();
private boolean cancelled;
public void cancel() {cancelled = true;}
public boolean isCancelled() {return cancelled;}
  /** Generated Lexer. */
  public ${grammar.lexerClassName} token_source;
  
  public void setInputSource(String inputSource) {
      token_source.setInputSource(inputSource);
  }
  
  String getInputSource() {
      return token_source.getInputSource();
  }
  
 //=================================
 // Generated constructors
 //=================================

   public ${grammar.parserClassName}(String inputSource, CharSequence content) {
       this(new ${grammar.lexerClassName}(inputSource, content));
      [#if grammar.lexerUsesParser]
      token_source.parser = this;
      [/#if]
  }

  public ${grammar.parserClassName}(CharSequence content) {
    this("input", content);
  }

  /**
   * @param inputSource just the name of the input source (typically the filename) that 
   * will be used in error messages and so on.
   * @param path The location (typically the filename) from which to get the input to parse
   */
  public ${grammar.parserClassName}(String inputSource, Path path) throws IOException {
    this(inputSource, TokenSource.stringFromBytes(Files.readAllBytes(path)));
  }

  public ${grammar.parserClassName}(String inputSource, Path path, Charset charset) throws IOException {
    this(inputSource, TokenSource.stringFromBytes(Files.readAllBytes(path), charset));
  }

  /**
   * @param path The location (typically the filename) from which to get the input to parse
   */
  public ${grammar.parserClassName}(Path path) throws IOException {
    this(path.toString(), path);
  }

  /** Constructor with user supplied Lexer. */
  public ${grammar.parserClassName}(${grammar.lexerClassName} lexer) {
    token_source = lexer;
      [#if grammar.lexerUsesParser]
      token_source.parser = this;
      [/#if]
      lastConsumedToken = DUMMY_START_TOKEN;
      lastConsumedToken.setTokenSource(lexer);
  }

  // If the next token is cached, it returns that
  // Otherwise, it goes to the token_source, i.e. the Lexer.
  final private Token nextToken(final Token tok) {
    Token result = token_source.getNextToken(tok);
    while (result.isUnparsed()) {
     [#list grammar.parserTokenHooks as methodName] 
      result = ${methodName}(result);
     [/#list]
      result = token_source.getNextToken(result);
    }
[#list grammar.parserTokenHooks as methodName] 
    result = ${methodName}(result);
[/#list]
    nextTokenType=null;
    return result;
  }

  /**
   * @return the next Token off the stream. This is the same as #getToken(1)
   */
  final public Token getNextToken() {
    return getToken(1);
  }

/**
 * @param index how many tokens to look ahead
 * @return the specific regular (i.e. parsed) Token index ahead/behind in the stream. 
 * If we are in a lookahead, it looks ahead from the currentLookaheadToken
 * Otherwise, it is the lastConsumedToken. If you pass in a negative
 * number it goes backward.
 */
  final public Token getToken(final int index) {
    Token t = currentLookaheadToken == null ? lastConsumedToken : currentLookaheadToken;
    for (int i = 0; i < index; i++) {
      t = nextToken(t);
    }
    for (int i = 0; i > index; i--) {
      t = t.getPrevious();
      if (t == null) break;
    }
    return t;
  }

  private String tokenImage(int n) {
     return getToken(n).getImage();
  }

  private boolean checkNextTokenImage(String img) {
    return tokenImage(1).equals(img);
  }

  private boolean checkNextTokenType(TokenType type) {
    return getToken(1).getType() == type;
  }

  private final TokenType nextTokenType() {
    if (nextTokenType == null) {
       nextTokenType = nextToken(lastConsumedToken).getType();
    }
    return nextTokenType;
  }

  boolean activateTokenTypes(TokenType... types) {
    boolean result = false;
    for (TokenType tt : types) {
      result |= token_source.activeTokenTypes.add(tt);
    }
    if (result) {
      token_source.reset(getToken(0));
      nextTokenType = null;
    }
    return result;
  }


  private void uncacheTokens() {
      token_source.reset(getToken(0));
  }

  private void resetTo(LexicalState state) {
    token_source.reset(getToken(0), state);
  }

  private void resetTo(Token tok, LexicalState state) {
    token_source.reset(tok, state);
  } 

  boolean deactivateTokenTypes(TokenType... types) {
    boolean result = false;
    for (TokenType tt : types) {
      result |= token_source.activeTokenTypes.remove(tt);
    }
    if (result) {
        token_source.reset(getToken(0));
        nextTokenType = null;
    }
    return result;
  }

  private void fail(String message) [#if grammar.useCheckedException] throws ParseException [/#if] 
  {
    if (currentLookaheadToken == null) {
      throw new ParseException(this, message);
    }
    this.hitFailure = true;
  }

  private static HashMap<TokenType[], EnumSet<TokenType>> enumSetCache = new HashMap<>();

  private static EnumSet<TokenType> tokenTypeSet(TokenType first, TokenType... rest) {
    TokenType[] key = new TokenType[1 + rest.length];

    key[0] = first;
    if (rest.length > 0) {
      System.arraycopy(rest, 0, key, 1, rest.length);
    }
    Arrays.sort(key);
    if (enumSetCache.containsKey(key)) {
      return enumSetCache.get(key);
    }
    EnumSet<TokenType> result = (rest.length == 0) ? EnumSet.of(first) : EnumSet.of(first, rest);
    enumSetCache.put(key, result);
    return result;
  }

  /**
   *Are we in the production of the given name, either scanning ahead or parsing?
   */
  private boolean isInProduction(String productionName, String... prods) {
    if (currentlyParsedProduction != null) {
      if (currentlyParsedProduction.equals(productionName)) return true;
      for (String name : prods) {
        if (currentlyParsedProduction.equals(name)) return true;
      }
    }
    if (currentLookaheadProduction != null ) {
      if (currentLookaheadProduction.equals(productionName)) return true;
      for (String name : prods) {
        if (currentLookaheadProduction.equals(name)) return true;
      }
    }
    Iterator<NonTerminalCall> it = stackIteratorBackward();
    while (it.hasNext()) {
      NonTerminalCall ntc = it.next();
      if (ntc.productionName.equals(productionName)) {
        return true;
      }
      for (String name : prods) {
        if (ntc.productionName.equals(name)) {
          return true;
        }
      }
    }
    return false;
  }


[#import "ParserProductions.java.ftl" as ParserCode]
[@ParserCode.Productions /]
[#import "LookaheadRoutines.java.ftl" as LookaheadCode]
[@LookaheadCode.Generate/]
 
[#embed "ErrorHandling.java.ftl"]

[#if grammar.treeBuildingEnabled]
   [#embed "TreeBuildingCode.java.ftl"]
[#else]
  public boolean isTreeBuildingEnabled() {
    return false;
  } 
[/#if]
}
  
}
[#list grammar.otherParserCodeDeclarations as decl]
//Generated from code at ${decl.location}
   ${decl}
[/#list]

