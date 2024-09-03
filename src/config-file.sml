structure ConfigFile:
sig
  type config =
    { temporary_directory: string option
    , color: { type_: ANSIStyle.style option
             , execute: ANSIStyle.style option
             , error: ANSIStyle.style option
             , warning: ANSIStyle.style option
             , diagnostic: ANSIStyle.style option
             , information: ANSIStyle.style option
             }
    }
  val defaultConfig: config
  val loadConfig: string -> config
end =
struct

  type config =
    { temporary_directory: string option
    , color: { type_: ANSIStyle.style option
             , execute: ANSIStyle.style option
             , error: ANSIStyle.style option
             , warning: ANSIStyle.style option
             , diagnostic: ANSIStyle.style option
             , information: ANSIStyle.style option
             }
    }

  val defaultConfig: config =
    { temporary_directory = NONE
    , color =
        { type_ = NONE
        , execute = NONE
        , error = NONE
        , warning = NONE
        , diagnostic = NONE
        , information = NONE
        }
    }

  fun get (table: TomlValue.table, key) =
    case List.find (fn (key', _) => key' = key) table of
      NONE => NONE
    | SOME (_, value) => SOME value

  fun weakGet (SOME table : TomlValue.table option, key) =
        (case List.find (fn (key', _) => key' = key) table of
           NONE => NONE
         | SOME (_, value) => SOME value)
    | weakGet (NONE, _) = NONE

  infix ?|> ??
  (* Option.mapPartial, flipped *)
  fun (SOME x) ?|> f = f x
    | NONE ?|> _ = NONE

  val op?? = Option.getOpt

  (*: val checkBool : string -> TomlValue.value -> bool option *)
  fun checkBool _ (TomlValue.BOOL x) = SOME x
    | checkBool path _ =
        (Message.warn ("Config entry " ^ path ^ " should be a boolean."); NONE)

  (*: val checkString : string -> TomlValue.value -> string option *)
  fun checkString _ (TomlValue.STRING x) = SOME x
    | checkString path _ =
        (Message.warn ("Config entry " ^ path ^ " should be a string."); NONE)

  (*: val checkTable : string -> TomlValue.value -> TomlValue.table option *)
  fun checkTable _ (TomlValue.TABLE x) = SOME x
    | checkTable path _ =
        (Message.warn ("Config entry " ^ path ^ " should be a table."); NONE)

  (*: val checkColor : string -> TomlValue.value -> ANSIColor.color option *)
  fun checkColor path (TomlValue.STRING x) =
        (case ANSIColor.fromString x of
           SOME c => SOME c
         | NONE =>
             ( Message.warn
                 ("Config entry " ^ path ^ " should be a valid color.")
             ; NONE
             ))
    | checkColor path _ =
        (Message.warn ("Config entry " ^ path ^ " should be a string."); NONE)

  (*: val parseStyle : string -> TomlValue.value -> ANSIStyle.style option *)
  fun parseStyle path (TomlValue.TABLE t) =
        SOME
          { foreground = get (t, "fore") ?|> checkColor (path ^ ".fore")
          , background = get (t, "back") ?|> checkColor (path ^ ".back")
          , bold = get (t, "bold") ?|> checkBool (path ^ ".bold") ?? false
          , dim = get (t, "dim") ?|> checkBool (path ^ ".dim") ?? false
          , underline =
              get (t, "underline") ?|> checkBool (path ^ ".underline") ?? false
          , blink = get (t, "blink") ?|> checkBool (path ^ ".blink") ?? false
          , reverse =
              get (t, "reverse") ?|> checkBool (path ^ ".reverse") ?? false
          , italic = get (t, "italic") ?|> checkBool (path ^ ".italic") ?? false
          , strike = get (t, "strike") ?|> checkBool (path ^ ".strike") ?? false
          }
    | parseStyle path _ =
        (Message.warn ("Config entry " ^ path ^ " should be a table."); NONE)

  fun loadConfig path =
    let
      val ins = TextIO.openIn path
      val ins' = ValidateUtf8.mkValidatingStream (TextIO.getInstream ins)
      val table =
        ParseToml.parse (ValidateUtf8.validatingReader TextIO.StreamIO.input1)
          ins'
    in
      { temporary_directory =
          get (table, "temporary-directory")
          ?|> checkString "temporary-directory"
      , color =
          let
            val color = get (table, "color") ?|> checkTable "color"
          in
            { type_ = weakGet (color, "type") ?|> parseStyle "color.type"
            , execute =
                weakGet (color, "execute") ?|> parseStyle "color.execute"
            , error = weakGet (color, "error") ?|> parseStyle "color.error"
            , warning =
                weakGet (color, "warning") ?|> parseStyle "color.warning"
            , diagnostic =
                weakGet (color, "diagnostic") ?|> parseStyle "color.diagnostic"
            , information =
                weakGet (color, "information")
                ?|> parseStyle "color.information"
            }
          end
      }
    end
end;
