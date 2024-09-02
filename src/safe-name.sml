structure SafeName:
sig
  val escapeJobname: string -> string
  val safeInput: {name: string, isPdfTeX: bool} -> string
end =
struct
  local
    fun escapeChar #" " = "_"
      | escapeChar c =
          if
            Char.isSpace c orelse c = #"\"" orelse c = #"$" orelse c = #"%"
            orelse c = #"&" orelse c = #"'" orelse c = #"(" orelse c = #")"
            orelse c = #";" orelse c = #"<" orelse c = #">" orelse c = #"\\"
            orelse c = #"^" orelse c = #"`" orelse c = #"|"
          then
            let
              val x = Char.ord c
              val s = Int.fmt StringCvt.HEX x
            in
              if x <= 0xf then "_0" ^ s else "_" ^ s
            end
          else
            String.str c
  in
    fun escapeJobname name = String.translate escapeChar name
  end

  local
    fun handleSpecialChar #"\\" = "~\\\\"
      | handleSpecialChar #"%" = "~\\%"
      | handleSpecialChar #"^" = "~\\^"
      | handleSpecialChar #"{" = "~\\{"
      | handleSpecialChar #"}" = "~\\}"
      | handleSpecialChar #"~" = "~\\~"
      | handleSpecialChar #"#" = "~\\#"
      | handleSpecialChar c = String.str c
    fun handleSpaces s =
      let
        fun go (s, acc) =
          if Substring.isEmpty s then
            Substring.concat (List.rev acc)
          else
            let
              val (a, b) = Substring.splitl (fn c => c <> #" ") s
              val (c, d) = Substring.splitl (fn c => c = #" ") b
              val c' = Substring.full (String.concatWith "~"
                (List.map String.str (Substring.explode c)))
            in
              go (d, c' :: a :: acc)
            end
      in
        go (Substring.full s, [])
      end
    fun handleNonAscii s =
      let
        fun go (s, acc) =
          if Substring.isEmpty s then
            Substring.concat (List.rev acc)
          else
            let
              val (a, b) = Substring.splitl Char.isAscii s
              val (c, d) = Substring.splitl (Bool.not o Char.isAscii) b
              val c' =
                if Substring.isEmpty c then c
                else Substring.full ("\\detokenize{" ^ Substring.string c ^ "}")
            in
              go (d, c' :: a :: acc)
            end
      in
        go (Substring.full s, [])
      end
  in
    fun safeInput {name, isPdfTeX} =
      let
        val escaped = handleSpaces (String.translate handleSpecialChar name)
        val escaped = if isPdfTeX then handleNonAscii escaped else escaped
      in
        if name = escaped then
          "\\input\"" ^ name ^ "\""
        else
          "\\begingroup\\escapechar-1\\let~\\string\\edef\\x{\"" ^ escaped
          ^ "\" }\\expandafter\\endgroup\\expandafter\\input\\x"
      end
  end
end;
