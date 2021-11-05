structure ParseOption : sig
              datatype Parsed = DoubleHyphen of string * string option
                              | SingleHyphen of string * string option
                              | NonOption of string
              val parseOne : string list -> (Parsed * string list) option
              end = struct
datatype Parsed = DoubleHyphen of string * string option
                | SingleHyphen of string * string option
                | NonOption of string
fun parseOne (arg :: args) = if String.isPrefix "--" arg then
                                 let val arg = Substring.triml 2 (Substring.full arg)
                                     val (name, optEqValue) = Substring.splitl (fn c => c <> #"=") arg
                                     val name = Substring.string name
                                     val optValue = if Substring.isEmpty optEqValue then
                                                        NONE
                                                    else
                                                        SOME (Substring.string (Substring.triml 1 optEqValue))
                                 in SOME (DoubleHyphen (name, optValue), args)
                                 end
                             else if String.isPrefix "-" arg then
                                 let val arg = String.triml 1 (Substring.full arg)
                                     val (name, optEqValue) = Substring.splitl (fn c => c <> #"=") arg
                                     val name = Substring.string name
                                     val optValue = if Substring.isEmpty optEqValue then
                                                        NONE
                                                    else
                                                        SOME (Substring.string (Substring.triml 1 optEqValue))
                                 in SOME (SingleHyphen (name, optValue), args)
                                 end
                             else
                                 SOME (NonOption arg, args)
  | parseOne [] = NONE
end;
