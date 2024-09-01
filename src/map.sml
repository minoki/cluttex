structure StringSet = RedBlackSetFn (type ord_key = string
                                     val compare = String.compare
                                    );
structure StringMap = RedBlackMapFn (type ord_key = string
                                     val compare = String.compare
                                    );
