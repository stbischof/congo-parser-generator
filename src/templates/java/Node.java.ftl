[#ftl strict_vars=true]
/* Generated by: ${generated_by}. ${filename} ${grammar.copyrightBlurb} */
[#if grammar.parserPackage?has_content]
package ${grammar.parserPackage};
[/#if]
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.lang.reflect.*;
import java.util.function.Predicate;
[#if grammar.settings.FREEMARKER_NODES?? && grammar.settings.FREEMARKER_NODES]
import freemarker.template.*;
[/#if]

public interface Node 
[#if grammar.settings.FREEMARKER_NODES?? && grammar.settings.FREEMARKER_NODES]
   extends TemplateNodeModel, TemplateScalarModel
[/#if] {
    // Marker interface for objects
    // that represent a node's type, i.e. TokenType
    public interface NodeType {}

    //Marker interface for tokens
    public interface TerminalNode extends Node {}

    default NodeType getType() {
        return null;
    }

    /** Life-cycle hook method called after the node has been made the current
	 *  node 
	 */
    default void open() {}

  	/** 
  	 * Life-cycle hook method called after all the child nodes have been
     * added. 
     */
    default void close() {}


    /**
     * @return the input source (usually a filename) from which this Node came from
     */
    default String getInputSource() {
        TokenSource<?> tokenSource = getTokenSource();
        return tokenSource == null ? "input" : tokenSource.getInputSource();
    }

   /**
     * Returns whether this node has any children.
     * 
     * @return Returns <code>true</code> if this node has any children,
     *         <code>false</code> otherwise.
     */
    default boolean hasChildNodes() {
       return getChildCount() > 0;
    }

    /**
     * @param n The Node to set as the parent. Mostly used internally.
     * The various addChild or appendChild sorts of methods should use this 
     * to set the node's parent. 
     */
    void setParent(Node n);

    /**
     * @return this node's parent Node 
     */
    Node getParent();
     
     // The following 9 methods will typically just 
     // delegate straightforwardly to a List object that
     // holds the child nodes

     /**
      * appends a child node to this Node
      * @param n the Node to append
      */ 
     void addChild(Node n);

     /**
      * inserts a child Node at a specific index, displacing the 
      * nodes after the index by 1.
      * @param i the (zero-based) index at which to insert the node
      * @param n the Node to insert
      */
     void addChild(int i, Node n);

     /**
      * @return the Node at the specific offset
      * @param i the index of the Node to return
      */
     Node getChild(int i);

     /**
      * Replace the node at index i
      * @param i the index
      * @param n the node  
      */ 
     void setChild(int i, Node n);

     /**
      * Remove the node at index i. Any Nodes after i
      * are shifted to the left.
      * @return the removed Node
      * @param i the index at which to remove 
      */
     Node removeChild(int i);

     /**
      * Removes the Node from this node's children
      * @param n the Node to remove
      * @return whether the Node was present
      */ 
     default boolean removeChild(Node n) {
         int index = indexOf(n);
         if (index == -1) return false;
         removeChild(index);
         return true;
     }

     /**
      * Replaces a child node with another one. It does
      * nothing if the first parameter is not actually a child node.
      * @param current the Node to be replaced
      * @param replacement the Node to substitute
      * @return whether any replacement took place
      */
     default boolean replaceChild(Node current, Node replacement) {
         int index = indexOf(current);
         if (index == -1) return false;
         setChild(index, replacement);
         return true;
     }

     /**
      * Insert a Node right before a given Node. It does nothing
      * if the where Node is not actually a child node.
      * @param where the Node that is the location where to prepend
      * @param inserted the Node to prepend
      * @return whether a Node was prepended 
      */
     default boolean prependChild(Node where, Node inserted) {
         int index = indexOf(where);
         if (index == -1) return false;
         addChild(index, inserted);
         return true;
     }

     /**
      * Insert a node right after a given Node. It does nothing 
      * if the where node is not actually a child node.
      * @param where the Node after which to append
      * @param inserted the Node to be inserted
      * @return whether a Node really was appended
      */
     default boolean appendChild(Node where, Node inserted) {
         int index = indexOf(where);
         if (index == -1) return false;
         addChild(index+1, inserted);
         return true;
     }

     /**
      * @return the index of the child Node. Or -1 if it is not
      * a child Node.
      * @param child the Node to get the index of
      */
     default int indexOf(Node child) {
         for (int i=0; i<getChildCount(); i++) {
             if (child == getChild(i)) {
                 return i;
             }
         }
         return -1;
     }

     default Node previousSibling() {
         Node parent = getParent();
         if (parent == null) return null;
         int idx = parent.indexOf(this);
         if (idx <=0) return null;
         return parent.getChild(idx-1);
     }

     default Node nextSibling() {
         Node parent = getParent();
         if (parent == null) return null;
         int idx = parent.indexOf(this);
         if (idx >= parent.getChildCount() -1) return null;
         return parent.getChild(idx+1);
     }

     /**
      * Remove all the child nodes
      */
     void clearChildren();

     /**
      * @return the number of child nodes
      */
     int getChildCount();
     
     /**
      * @return a List containing this node's child nodes
      * The default implementation returns a copy, so modifying the 
      * list that is returned has no effect on this object. Most 
      * implementations of this should similarly return a copy or
      * possibly immutable wrapper around the list.
      */
      default List<Node> children(boolean includeUnparsedTokens) {
         List<Node> result = new ArrayList<>();
         for (int i = 0; i < getChildCount(); i++) {
             Node child = getChild(i);
             if (includeUnparsedTokens && child instanceof Token) {
                 Token tok = (Token) child;
                 if (!tok.isUnparsed()) {
                     result.addAll(tok.precedingUnparsedTokens());
                 }
             } 
             result.add(child);
         }
         return result;
      }

      default List<Node> children() {
          return children(false);
      }

    /**
     * @return a List containing all the tokens in a Node
     * @param includeCommentTokens Whether to include comment tokens
     */
     default List<Token> getAllTokens(boolean includeCommentTokens) {
		List<Token> result = new ArrayList<>();
        for (Iterator<Node> it = iterator(); it.hasNext();) {
            Node child = it.next();
            if (child instanceof Token) {
                Token token = (Token) child;
                if (token.isUnparsed()) {
                    continue;
                }
                if (includeCommentTokens) {
                    result.addAll(token.precedingUnparsedTokens());
                }
                result.add(token);
            } 
            else if (child.getChildCount() >0) {
               result.addAll(child.getAllTokens(includeCommentTokens));
            }
        }
        return result;
    }

    /**
     * @return All the tokens in the node that 
     * are "real" (i.e. participate in parsing)
     */
    default List<Token> getRealTokens() {
        return descendants(Token.class, t->!t.isUnparsed());
    }
    
     /**
      * @return the #${grammar.lexerClassName} from which this Node object
      * originated. There is no guarantee that this doesn't return null.
      * Most likely that would simply be because you constructed the 
      * Node yourself, i.e. it didn't really come about via the parsing/tokenizing
      * machinery.
      */
     TokenSource<Token> getTokenSource();

     void setTokenSource(TokenSource<Token> tokenSource);

     /**
      * @return the original source content this Node came from
      * a reference to the #${grammar.lexerClassName} that stores the source code and
      * the start/end location info stored in the Node object itself.
      * This method could throw a NullPointerException if #getTokenSource
      * returns null. Also, the return value could be spurious if 
      * the content of the source file was changed meanwhile. But
      * this is just the default implementation of an API and it does not 
      * address this problem!
      */
    default String getSource() {
        TokenSource<?> tokenSource = getTokenSource();
        return tokenSource == null ? null : tokenSource.getText(getBeginOffset(), getEndOffset());
    }

    default String getImage() {
        return getSource();
    }

    default int getLength() {
        return getEndOffset() - getBeginOffset();
    }

    /**
     * @return the (1-based) line location where this Node starts
     */      
    default int getBeginLine() {
        TokenSource<?> tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getLineFromOffset(getBeginOffset());                
    };

    /**
     * @return the (1-based) line location where this Node ends
     */
    default int getEndLine() {
        TokenSource<?> tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getLineFromOffset(getEndOffset()-1);
    };

    /**
     * @return the (1-based) column where this Node starts
     */
    default int getBeginColumn() {
        TokenSource<?> tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getCodePointColumnFromOffset(getBeginOffset());        
    };

    /**
     * @return the (1-based) column offset where this Node ends
     */ 
    default int getEndColumn() {
        TokenSource<?> tokenSource = getTokenSource();
        return tokenSource == null ? 0 : tokenSource.getCodePointColumnFromOffset(getEndOffset()-1);
    }
    
    /**
     * @return the offset in the input source where the token begins,
     * expressed in code units.
     */
    int getBeginOffset();

    /**
     * @return the offset in the input source where the token ends,
     * expressed in code units. This is actually the offset where the 
     * very next token would begin.
     */
     int getEndOffset();

     /**
      * Set the offset where the token begins, expressed in code units. 
      */
      void setBeginOffset(int beginOffset);

     /**
      * Set the offset where the token ends, actually the location where
      * the very next token should begin.
      */
      void setEndOffset(int endOffet);

    /**
     * @return a String that gives the starting location of this Node. This is a default
     * implementation that could be overridden 
     */
    default String getLocation() {
         return getInputSource() + ":" + getBeginLine() + ":" + getBeginColumn();
    }
     
     
     /**
      * @return whether this Node was created by regular operations of the 
      * parsing machinery. 
      */
     default boolean isUnparsed() {
        return false;
     }

     /**
      * Mark whether this Node is unparsed, i.e. <i>not</i> the result of 
      * normal parsing
      * @param b whether to set the Node as unparsed or parsed.
      */ 
     void setUnparsed(boolean b);
     
    default <T extends Node>T firstChildOfType(Class<T>clazz) {
        for (int i=0; i<getChildCount();i++) {
            Node child = getChild(i);
            if (clazz.isInstance(child)) return clazz.cast(child);
        }
        return null; 
    }

    default <T extends Node>T firstChildOfType(Class<T> clazz, Predicate<T> pred) {
        for (int i=0; i<getChildCount();i++) {
            Node child = getChild(i);
            if (clazz.isInstance(child)) {
                T t = clazz.cast(child);
                if (pred.test(t)) return t;
            }
        }
        return null;
    }

[#if grammar.tokensAreNodes]
    default Node firstDescendantOfType(NodeType type) {
         for (int i=0; i<getChildCount(); i++) {
             Node child = getChild(i);
             if (child.getType() == type) {
                return (Token) child;
             } else {
                 Node tok = child.firstDescendantOfType(type);
                 if (tok != null) return tok;
             }
         }
         return null;
    }

    default Node firstChildOfType(NodeType tokenType) {
        for (int i=0; i<getChildCount();i++) {
            Node child = getChild(i);
            if (child.getType() == tokenType) return child;
        }
        return null;
    }
[/#if]

    default <T extends Node>T firstDescendantOfType(Class<T> clazz) {
         for (int i=0; i<getChildCount();i++) {
             Node child = getChild(i);
             if (clazz.isInstance(child)) return clazz.cast(child);
             else {
                 T descendant = child.firstDescendantOfType(clazz);
                 if (descendant !=null) return descendant;
             }
         }
         return null;
    }

    default <T extends Node>List<T>childrenOfType(Class<T>clazz) {
        List<T>result=new java.util.ArrayList<>();
        for (int i=0; i< getChildCount(); i++) {
            Node child = getChild(i);
            if (clazz.isInstance(child)) {
                result.add(clazz.cast(child));
            }
        }
        return result;
   }
   
   default <T extends Node> List<T> descendantsOfType(Class<T> clazz) {
        List<T> result = new ArrayList<T>();
        for (int i=0; i< getChildCount(); i++) {
            Node child = getChild(i);
            if (clazz.isInstance(child)) {
                result.add(clazz.cast(child));
            } 
            result.addAll(child.descendantsOfType(clazz));
        }
        return result;
   }
   
   default <T extends Node> T firstAncestorOfType(Class<T> clazz) {
        Node parent = this;
        while (parent !=null) {
           parent = parent.getParent();
           if (clazz.isInstance(parent)) {
               return clazz.cast(parent);
           }
        }
        return null;
    }

    default NodeType getTokenType() {
        //return this instanceof Token ? ((Token)this).getType() : null;
        return getType();
    }

[#if grammar.tokensAreNodes]
    /**
     * @return the very first token that is part of this node.
     * It may be an unparsed (i.e. special) token.
     */
    default Token getFirstToken() {
        Node first = getFirstChild();
        if (first == null) return null;
        if (first instanceof Token) {
            Token tok = (Token) first;
            while (tok.previousCachedToken() != null && tok.previousCachedToken().isUnparsed()) {
                tok = tok.previousCachedToken();
            }
           return tok;
        }
        return first.getFirstToken(); 
    }

    default Token getLastToken() {
        Node last = getLastChild();
        if (last == null) return null;
        if (last instanceof Token) {
            return (Token) last;
        }
        return last.getLastToken();
    }
[/#if]    
    
    /**
     * Copy the location info from another Node
     * @param from the Node to copy the info from 
     */
    default void copyLocationInfo(Node from) {
        setTokenSource(from.getTokenSource());
        setBeginOffset(from.getBeginOffset());
        setEndOffset(from.getEndOffset());
        setTokenSource(from.getTokenSource());
    }

    /**
     * Copy the location info given a start and end Node
     * @param start the start node
     * @param end the end node
     */
    default void copyLocationInfo(Node start, Node end) {
        setTokenSource(start.getTokenSource());
        if (getTokenSource()==null) setTokenSource(end.getTokenSource());
        setBeginOffset(start.getBeginOffset());
        setEndOffset(end.getEndOffset());
    }

    default void replace(Node toBeReplaced) {
        copyLocationInfo(toBeReplaced);
        Node parent = toBeReplaced.getParent();
        if (parent !=null) {
           int index = parent.indexOf(toBeReplaced);
           parent.setChild(index, this);
        }
    }
    
    /**
     * Returns the first child of this node. If there is no such node, this returns
     * <code>null</code>.
     * 
     * @return the first child of this node. If there is no such node, this returns
     *         <code>null</code>.
     */
    default Node getFirstChild() {
        return getChildCount() > 0 ? getChild(0) : null;
    }
    
    
     /**
     * Returns the last child of the given node. If there is no such node, this
     * returns <code>null</code>.
     * 
     * @return the last child of the given node. If there is no such node, this
     *         returns <code>null</code>.
     */ 
    default Node getLastChild() {
        int count = getChildCount();
        return count>0 ? getChild(count-1): null;
    }

    default Node getRoot() {
        Node parent = this;
        while (parent.getParent() != null ) {
            parent = parent.getParent();
        }
        return parent; 
    }
    
     static public List<Token> getTokens(Node node) {
        List<Token> result = new ArrayList<Token>();
        for (Node child : node.children()) {
            if (child instanceof Token) {
                result.add((Token) child);
            } else {
                result.addAll(getTokens(child));
            }
        }
        return result;
    }
        
        
    static public List<Token> getRealTokens(Node n) {
        List<Token> result = new ArrayList<Token>();
		for (Token token : getTokens(n)) {
		    if (!token.isUnparsed()) {
		        result.add(token);
		    }
		}
	    return result;
    }

    default List<Node> descendants() {
        return descendants(Node.class, null);
    }

    default List<Node> descendants(Predicate<? super Node> predicate) {
        return descendants(Node.class, predicate);
    }

    default <T extends Node> List<T> descendants(Class<T> clazz) {
        return descendants(clazz, null);
    }

    default <T extends Node> List<T> descendants(Class<T> clazz, Predicate<? super T> predicate) {
       List<T> result = new ArrayList<>();
       for (Node child : children()) {
          if (clazz.isInstance(child)) {
              T t = clazz.cast(child);
              if (predicate == null || predicate.test(t)) {
                  result.add(t);
              }
          }
          result.addAll(child.descendants(clazz, predicate)); 
       }
       return result;
    }

    default void dump(String prefix) {
        String output;

        if (this instanceof Token) {
            output = toString().trim();
        }
        else {
            output = String.format("<%s (%d, %d)-(%d, %d)>",
                                   getClass().getSimpleName(),
                                   getBeginLine(), getBeginColumn(),
                                   getEndLine(), getEndColumn());
        }
        // String output = (this instanceof Token) ? toString().trim() : getClass().getSimpleName();
[#if grammar.faultTolerant]
        if (this.isDirty()) {
            output += " (incomplete)";
        }
[/#if]
        if (output.length() > 0) {
            System.out.println(prefix + output);
        }
        for (Iterator<Node> it = iterator(); it.hasNext();) {
            Node child = it.next();
            child.dump(prefix + "  ");
        }
    }

    default void dump() {
        dump("");
    }
[#if grammar.faultTolerant]    

    default boolean isDirty() {
        return false;
    }

    void setDirty(boolean dirty);

[/#if]    

    // NB: This is not thread-safe
    // If the node's children could change out from under you,
    // you could have a problem.

    default public ListIterator<Node> iterator() {
        return new ListIterator<Node>() {
            private int current = -1;
            private boolean justModified;
            
            public boolean hasNext() {
                return current+1 < getChildCount();
            }
            
            public Node next() {
                justModified = false;
                return getChild(++current);
            }
            
            public Node previous() {
                justModified = false;
                return getChild(--current);
            }
            
            public void remove() {
                if (justModified) throw new IllegalStateException();
                removeChild(current);
                --current;
                justModified = true;
            }
            
            public void add(Node n) {
                if (justModified) throw new IllegalStateException();
                addChild(current+1, n);
                justModified = true;
            }
            
            public boolean hasPrevious() {
                return current >0;
            }
            
            public int nextIndex() {
                return current + 1;
            }
            
            public int previousIndex() {
                return current;
            }
            
            public void set(Node n) {
                setChild(current, n);
            }
        };
    }

 	static abstract public class Visitor {
        static private Map<Class<? extends Node.Visitor>, Map<Class<? extends Node>, Method>> mapLookup;
        static private final Method DUMMY_METHOD;
        static {
            try {
                // Use this just to represent no method found, since ConcurrentHashMap cannot contains nulls
                DUMMY_METHOD = Object.class.getMethod("toString");
            } catch (Exception e) {throw new RuntimeException(e);} // Never happens anyway.
            mapLookup = Collections.synchronizedMap(new HashMap<Class<? extends Node.Visitor>, Map<Class<? extends Node>, Method>>());
        }
        private Map<Class<? extends Node>, Method> methodCache;
        {
            this.methodCache = mapLookup.get(this.getClass());
            if (methodCache == null) {
                methodCache = new ConcurrentHashMap<Class<? extends Node>, Method>();
                mapLookup.put(this.getClass(), methodCache);
            }
        }
        protected boolean visitUnparsedTokens;
		
		private Method getVisitMethod(Node node) {
			Class<? extends Node> nodeClass = node.getClass();
            Method method = methodCache.get(nodeClass);
            if (method == null) {
                methodCache.put(nodeClass, getVisitMethodImpl(nodeClass));
            }
            return methodCache.get(nodeClass);
		}

        // Find handler method for this node type. If there is none, 
        // it checks for a handler for any explicitly marked interfaces
        // If necessary, it climbs the class hierarchy to superclasses
        private Method getVisitMethodImpl(Class<?> nodeClass) {
            if (nodeClass == null || !Node.class.isAssignableFrom(nodeClass)) return DUMMY_METHOD;
            try {
                Method m = this.getClass().getDeclaredMethod("visit", nodeClass);
                if (!Modifier.isPublic(nodeClass.getModifiers()) || !Modifier.isPublic(m.getModifiers())) {
                    m.setAccessible(true);
                }
                return m;
            } catch (NoSuchMethodException e) {}
            for (Class<?> interf : nodeClass.getInterfaces()) {
                if (Node.class.isAssignableFrom(interf) && !Node.class.equals(interf)) try {
                    Method m = this.getClass().getDeclaredMethod("visit", interf);
                    if (!Modifier.isPublic(interf.getModifiers()) || !Modifier.isPublic(m.getModifiers())) {
                        m.setAccessible(true);
                    }
                    return m;
                } catch (NoSuchMethodException e) {}
            }
            return getVisitMethodImpl(nodeClass.getSuperclass());
        }

		/**
		 * Tries to invoke (via reflection) the appropriate visit(...) method
		 * defined in a subclass. If there is none, it just calls the recurse() routine.
         * @param node the Node to "visit" 
		 */
		public final void visit(Node node) {
			Method visitMethod = getVisitMethod(node);
			if (visitMethod == DUMMY_METHOD) {
				recurse(node);
			} else try {
				visitMethod.invoke(this, node);
			} catch (InvocationTargetException ite) {
	    		Throwable cause = ite.getCause();
	    		if (cause instanceof RuntimeException) {
	    			throw (RuntimeException) cause;
	    		}
	    		throw new RuntimeException(ite);
	 		} catch (IllegalAccessException iae) {
	 			throw new RuntimeException(iae);
	 		}
		}

        /**
         * Just recurses over (i.e. visits) node's children
         * @param node the node we are traversing
         */
		public void recurse(Node node) {
            for (Node child : node.children(visitUnparsedTokens)) {
                visit(child);
            }
		}
    }
}
