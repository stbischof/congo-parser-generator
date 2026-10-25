#var MULTIPLE_LEXICAL_STATE_HANDLING = (lexerData::numLexicalStates > 1)

private CallStack parsingStack = new CallStack(32);
private final ArrayList<NonTerminalCall> lookaheadStack = new ArrayList<>();
// The entries the lookahead stack has had, one per depth, for reuse. Only their
// production name is read, and neither a ParseException nor a ParseState copies them.
private final ArrayList<NonTerminalCall> lookaheadEntries = new ArrayList<>();

#if settings::faultTolerant
  private EnumSet<TokenType> currentFollowSet;
#endif

private void pushOntoCallStack(NonTerminalCall.Site site) {
   ${settings::baseTokenClassName} location = getToken(1);
   parsingStack.push(site, location.getTokenSource(), location.getBeginOffset() ${settings::faultTolerant ? ", currentFollowSet"});
}

private void pushOntoCallStack(String methodName, String fileName, int line, int column) {
   pushOntoCallStack(new NonTerminalCall.Site("${settings::parserClassName}", fileName, methodName, line, column));
}

private void popCallStack() {
    int top = parsingStack.size() - 1;
    this.currentlyParsedProduction = parsingStack.productionName(top);
   #if settings::faultTolerant
    this.outerFollowSet = parsingStack.followSet(top);
   #endif
    parsingStack.pop();
}

/**
 * The parse call stack. An entry is kept as its place in the grammar and its location,
 * and its NonTerminalCall is only made when the stack is read; it is then kept until
 * the entry is popped.
 */
private static final class CallStack extends java.util.AbstractList<NonTerminalCall> implements java.util.RandomAccess {
    private NonTerminalCall.Site[] sites;
    private TokenSource[] tokenSources;
    private int[] positions;
   #if settings::faultTolerant
    private EnumSet<TokenType>[] followSets;
   #endif
    private NonTerminalCall[] entries;
    private int size;

    @SuppressWarnings("unchecked")
    CallStack(int capacity) {
        sites = new NonTerminalCall.Site[capacity];
        tokenSources = new TokenSource[capacity];
        positions = new int[capacity];
   #if settings::faultTolerant
        followSets = (EnumSet<TokenType>[]) new EnumSet<?>[capacity];
   #endif
        entries = new NonTerminalCall[capacity];
    }

    private void ensureCapacity(int capacity) {
        if (capacity > sites.length) {
            int length = Math.max(capacity, sites.length * 2);
            sites = Arrays.copyOf(sites, length);
            tokenSources = Arrays.copyOf(tokenSources, length);
            positions = Arrays.copyOf(positions, length);
   #if settings::faultTolerant
            followSets = Arrays.copyOf(followSets, length);
   #endif
            entries = Arrays.copyOf(entries, length);
        }
    }

    void push(NonTerminalCall.Site site, TokenSource tokenSource, int position ${settings::faultTolerant ? ", EnumSet<TokenType> followSet"}) {
        ensureCapacity(size + 1);
        sites[size] = site;
        tokenSources[size] = tokenSource;
        positions[size] = position;
   #if settings::faultTolerant
        followSets[size] = followSet;
   #endif
        entries[size++] = null;
        modCount++;
    }

    void pop() {
        checkIndex(size - 1, size);
        entries[--size] = null;
        modCount++;
    }

    String productionName(int index) {
        NonTerminalCall entry = entries[index];
        return entry != null ? entry.productionName : sites[index].productionName;
    }

   #if settings::faultTolerant
    @SuppressWarnings("unchecked")
    EnumSet<TokenType> followSet(int index) {
        NonTerminalCall entry = entries[index];
        return entry != null ? (EnumSet<TokenType>) entry.followSet : followSets[index];
    }
   #endif

    CallStack copy() {
        CallStack copy = new CallStack(0);
        copy.sites = sites.clone();
        copy.tokenSources = tokenSources.clone();
        copy.positions = positions.clone();
   #if settings::faultTolerant
        copy.followSets = followSets.clone();
   #endif
        copy.entries = entries.clone();
        copy.size = size;
        return copy;
    }

    // REVISIT(JDK>8): Objects.checkIndex (Java 9) instead, once the generated code may require
    // more than Java 8 (CongoCC's examples compile it for Java 8). Same exception and message.
    private static void checkIndex(int index, int length) {
        if (index < 0 || index >= length) {
            throw new IndexOutOfBoundsException("Index " + index + " out of bounds for length " + length);
        }
    }

    @Override
    public int size() {
        return size;
    }

    @Override
    public NonTerminalCall get(int index) {
        checkIndex(index, size);
        NonTerminalCall entry = entries[index];
        if (entry == null) {
            entry = entries[index] = new NonTerminalCall(sites[index], tokenSources[index], positions[index] ${settings::faultTolerant ? ", followSets[index]"});
        }
        return entry;
    }

    @Override
    public NonTerminalCall set(int index, NonTerminalCall entry) {
        NonTerminalCall previous = get(index);
        entries[index] = entry;
        return previous;
    }

    @Override
    public void add(int index, NonTerminalCall entry) {
        checkIndex(index, size + 1);
        ensureCapacity(size + 1);
        shift(index, index + 1);
        entries[index] = entry;
        size++;
        modCount++;
    }

    @Override
    public NonTerminalCall remove(int index) {
        NonTerminalCall previous = get(index);
        shift(index + 1, index);
        entries[--size] = null;
        modCount++;
        return previous;
    }

    @Override
    protected void removeRange(int from, int to) {
        shift(to, from);
        Arrays.fill(entries, size - (to - from), size, null);
        size -= to - from;
        modCount++;
    }

    // Moves the entries from index from on to index to.
    private void shift(int from, int to) {
        int count = size - from;
        System.arraycopy(sites, from, sites, to, count);
        System.arraycopy(tokenSources, from, tokenSources, to, count);
        System.arraycopy(positions, from, positions, to, count);
   #if settings::faultTolerant
        System.arraycopy(followSets, from, followSets, to, count);
   #endif
        System.arraycopy(entries, from, entries, to, count);
    }
}

private void restoreCallStack(int prevSize) {
    while (parsingStack.size() > prevSize) {
       popCallStack();
    }
}

private ListIterator<NonTerminalCall> stackIteratorForward() {
    final ListIterator<NonTerminalCall> parseStackIterator = parsingStack.listIterator();
    final ListIterator<NonTerminalCall> lookaheadStackIterator = lookaheadStack.listIterator();
    return new ListIterator<NonTerminalCall>() {
        public boolean hasNext() {
            return parseStackIterator.hasNext() || lookaheadStackIterator.hasNext();
        }
        public NonTerminalCall next() {
            return parseStackIterator.hasNext() ? parseStackIterator.next() : lookaheadStackIterator.next();
        }
        public NonTerminalCall previous() {
           return lookaheadStackIterator.hasPrevious() ? lookaheadStackIterator.previous() : parseStackIterator.previous();
        }
        public boolean hasPrevious() {
            return lookaheadStackIterator.hasPrevious() || parseStackIterator.hasPrevious();
        }
        public void add(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void set(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void remove() {throw new UnsupportedOperationException();}
        public int previousIndex() {throw new UnsupportedOperationException();}
        public int nextIndex() {throw new UnsupportedOperationException();}
    };
}

private ListIterator<NonTerminalCall> stackIteratorBackward() {
    final ListIterator<NonTerminalCall> parseStackIterator = parsingStack.listIterator(parsingStack.size());
    final ListIterator<NonTerminalCall> lookaheadStackIterator = lookaheadStack.listIterator(lookaheadStack.size());
    return new ListIterator<NonTerminalCall>() {
        public boolean hasNext() {
            return lookaheadStackIterator.hasPrevious() || parseStackIterator.hasPrevious();
        }
        public NonTerminalCall next() {
            return lookaheadStackIterator.hasPrevious() ? lookaheadStackIterator.previous() : parseStackIterator.previous();
        }
        public NonTerminalCall previous() {
           return parseStackIterator.hasNext() ? parseStackIterator.next() : lookaheadStackIterator.next();
        }
        public boolean hasPrevious() {
            return parseStackIterator.hasNext() || lookaheadStackIterator.hasNext();
        }
        public void add(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void set(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void remove() {throw new UnsupportedOperationException();}
        public int previousIndex() {throw new UnsupportedOperationException();}
        public int nextIndex() {throw new UnsupportedOperationException();}
    };
}

private Iterator<String> backwardStackIteratorIncludingCurrent() {
    String first = currentLookaheadProduction != null ? currentLookaheadProduction : currentlyParsedProduction;
    Iterator<NonTerminalCall> it = stackIteratorBackward();
    return new Iterator<String>() {
        boolean atStart = true;
        public boolean hasNext() {
            return it.hasNext();
        }
        public String next() {
            if (atStart == true) {
                atStart = false;
                return first;
            }
            return it.next().productionName;
        }
    };
}

private void pushOntoLookaheadStack(NonTerminalCall.Site site) {
    int depth = lookaheadStack.size();
    NonTerminalCall ntc;
    if (depth < lookaheadEntries.size()) {
        ntc = lookaheadEntries.get(depth);
        ntc.reuse(site, getToken(1));
    } else {
        ntc = new NonTerminalCall(site, getToken(1) ${settings::faultTolerant ? ", null"});
        lookaheadEntries.add(ntc);
    }
    lookaheadStack.add(ntc);
}

private void popLookaheadStack() {
    NonTerminalCall ntc = lookaheadStack.remove(lookaheadStack.size() - 1);
    this.currentLookaheadProduction = ntc.productionName;
}

void dumpLookaheadStack(PrintStream ps) {
    ListIterator<NonTerminalCall> it = lookaheadStack.listIterator(lookaheadStack.size());
    while (it.hasPrevious()) {
        ps.print(it.previous());
    }
}

void dumpCallStack(PrintStream ps) {
    ListIterator<NonTerminalCall> it = parsingStack.listIterator(parsingStack.size());
    while (it.hasPrevious()) {
        ps.print(it.previous());
    }
}

void dumpLookaheadCallStack(PrintStream ps) {
    ps.println("Current Parser Production is: " + currentlyParsedProduction);
    ps.println("Current Lookahead Production is: " + currentLookaheadProduction);
    ps.println("---Lookahead Stack---");
    dumpLookaheadStack(ps);
    ps.println("---Call Stack---");
    dumpCallStack(ps);
}

#if settings::faultTolerant
   #if settings::faultTolerantDefault
    private boolean tolerantParsing = true;
   #else
    private boolean tolerantParsing = false;
   #endif
    // Are we pending a recovery routine to
    // get back on the rails?
    private boolean pendingRecovery;

    private java.util.List<ParsingProblem> parsingProblems = new java.util.ArrayList<>();

    public java.util.List<ParsingProblem> getParsingProblems() {
        return parsingProblems;
    }

    public boolean hasProblems() {
        return !parsingProblems.isEmpty();
    }

    void addParsingProblem(ParsingProblem problem) {
        parsingProblems.add(problem);
    }
#endif

    public boolean isParserTolerant() {
       #if settings::faultTolerant
        return tolerantParsing;
       #else
        return false;
       #endif
    }

    public void setParserTolerant(boolean tolerantParsing) {
        #if settings::faultTolerant
          this.tolerantParsing = tolerantParsing;
        #else
          if (tolerantParsing) {
            throw new UnsupportedOperationException("This parser was not built with that feature!");
          }
        #endif
    }

      private ${settings::baseTokenClassName} consumeToken(TokenType expectedType
        #if settings::faultTolerant
          , boolean tolerant, EnumSet<TokenType> followSet, Runnable recoveryAction
        #else
          , NonTerminalCall.Site site
        #endif
      )
      ${settings::useCheckedException ? "throws ParseException"}
      {
        ${settings::baseTokenClassName} nextToken = nextToken(lastConsumedToken);
        if (nextToken.getType() != expectedType) {
            #if lexerData::hasContextualTokens
               if (typeMatches(expectedType, nextToken)) {
                  nextToken = nextToken.replaceType(expectedType);
               }
               else
            #endif
            nextToken = handleUnexpectedTokenType(expectedType, nextToken
            #if settings::faultTolerant
               , tolerant, followSet
            #else
               , site
            #endif
            );
        }
        this.lastConsumedToken = nextToken;
#if settings::treeBuildingEnabled
      if (buildTree && tokensAreNodes) {
      lastConsumedToken.open();
  #list grammar::openNodeScopeHooks as hook
     ${hook}(lastConsumedToken);
  #endlist
          pushNode(lastConsumedToken);
     lastConsumedToken.close();
  #list grammar::closeNodeScopeHooks as hook
     ${hook}(lastConsumedToken);
  #endlist
      }
#endif
#if settings::faultTolerant
// Check whether the very next token is in the follow set of the last consumed token
// and if it is not, we check one token ahead to see if skipping the next token remedies
// the problem.
      if (followSet != null && isParserTolerant()) {
         nextToken = nextToken(lastConsumedToken);
         if (!followSet.contains(nextToken.getType())) {
            ${settings::baseTokenClassName} nextNext = nextToken(nextToken);
            if (followSet.contains(nextNext.getType())) {
               nextToken.setSkipped(true);
            }
         }
      }
      if (lastConsumedToken.isSkipped() || lastConsumedToken.isVirtual() || nextToken.isSkipped()) {
         recoveryAction.run();
      }
#endif
      return lastConsumedToken;
  }

  private ${settings::baseTokenClassName} handleUnexpectedTokenType(TokenType expectedType, ${settings::baseTokenClassName} nextToken
      #if settings::faultTolerant
        , boolean tolerant, EnumSet<TokenType> followSet
      #else
        , NonTerminalCall.Site site
      #endif
      )
      #if settings::useCheckedException
         throws ParseException
      #endif
      {
      #if !settings::faultTolerant
       // The terminal is the innermost entry of the call stack, but it is
       // pushed only now that it failed, not for every token consumed.
       pushOntoCallStack(site);
       ParseException pe = new ParseException(nextToken, EnumSet.of(expectedType), parsingStack);
       popCallStack();
       throw pe;
      #else
       if (!this.tolerantParsing) {
          throw new ParseException(nextToken, EnumSet.of(expectedType), parsingStack);
       }
       ${settings::baseTokenClassName} nextNext = nextToken(nextToken);
       if (nextNext.getType() == expectedType) {
             [#-- REVISIT. Here we skip one token (as well as any InvalidToken) but maybe (probably!) this behavior
             should be configurable. But we need to experiment, because this is really a heuristic question, no?--]
             nextToken.setSkipped(true);
#if settings::treeBuildingEnabled
             pushNode(nextToken);
#endif
             return nextNext;
       }
         #-- Since skipping the next token did not work, we will insert a virtual token
       if (tolerant || followSet == null || followSet.contains(nextToken.getType())) {
           ${settings::baseTokenClassName} virtualToken = ${settings::baseTokenClassName}.newToken(expectedType);
           virtualToken.setVirtual(true);
           virtualToken.copyLocationInfo(nextToken);
#if lexerData::hasLexicalStateTransitions
           if (token_source.doLexicalStateSwitch(expectedType)) {
              token_source.reset(virtualToken);
           }
#endif
           return virtualToken;
       }
       throw new ParseException(nextToken, EnumSet.of(expectedType), parsingStack);
      #endif
  }

  private class ParseState {
       ${settings::baseTokenClassName} lastConsumed;
       CallStack parsingStack;
   #if MULTIPLE_LEXICAL_STATE_HANDLING
       LexicalState lexicalState;
   #endif
       EnumSet<TokenType> activeTokenTypes;
   #if settings::treeBuildingEnabled
       NodeScope nodeScope;
   #endif
       ParseState() {
           this.lastConsumed = ${settings::parserClassName}.this.lastConsumedToken;
           this.parsingStack = ${settings::parserClassName}.this.parsingStack.copy();
#if MULTIPLE_LEXICAL_STATE_HANDLING
           this.lexicalState = token_source.lexicalState;
#endif
           if (${settings::parserClassName}.this.token_source.activeTokenTypes!=null) {
               activeTokenTypes = ${settings::parserClassName}.this.token_source.activeTokenTypes.clone();
           }
#if settings::treeBuildingEnabled
           this.nodeScope = currentNodeScope.clone();
#endif
       }
  }

  private ArrayList<ParseState> parseStateStack = new ArrayList<>();

  private void stashParseState() {
      parseStateStack.add(new ParseState());
  }

  private ParseState popParseState() {
      return parseStateStack.remove(parseStateStack.size() - 1);
  }

  private void restoreStashedParseState() {
     ParseState state = popParseState();
#if settings::treeBuildingEnabled
     currentNodeScope = state.nodeScope;
#endif
     ${settings::parserClassName}.this.parsingStack = state.parsingStack;
    if (state.lastConsumed != null) {
        //REVISIT
         lastConsumedToken = state.lastConsumed;
    }
#if MULTIPLE_LEXICAL_STATE_HANDLING
     token_source.reset(lastConsumedToken, state.lexicalState);
#else
     token_source.reset(lastConsumedToken);
#endif
     token_source.activeTokenTypes = state.activeTokenTypes;
  }

