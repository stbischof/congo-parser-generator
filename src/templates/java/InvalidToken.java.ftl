/* Generated by: ${generated_by}. ${filename} ${settings.copyrightBlurb} */
package ${settings.parserPackage};

/**
 * ${settings.baseTokenClassName} subclass to represent lexically invalid input
 */
public class InvalidToken extends ${settings.baseTokenClassName}
[#if settings.faultTolerant] implements ParsingProblem [/#if] {

    public InvalidToken(${settings.lexerClassName} tokenSource, int beginOffset, int endOffset) {
        super(TokenType.INVALID, tokenSource, beginOffset, endOffset);
[#if settings.faultTolerant]
        super.setUnparsed(true);
        this.setDirty(true);
[/#if]
    }

    public String getNormalizedText() {
        return "Lexically Invalid Input:" + getImage();
    }

 [#if settings.faultTolerant]
    
    private ParseException cause;
    private String errorMessage;

    void setCause(ParseException cause) {
        this.cause = cause;
    }

    public ParseException getCause() {
        return cause;
    }

    public String getErrorMessage() {
        if (errorMessage != null) return errorMessage;
        return "lexically invalid input"; // REVISIT
    }
 [/#if]

}
