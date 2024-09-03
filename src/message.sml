structure Message : sig
              datatype mode = ALWAYS | AUTO | NEVER
              val setColors : mode -> unit
              val exec : string -> unit
              val error : string -> unit
              val warn : string -> unit
              val diag : string -> unit
              val info : string -> unit
              val getVerbosity : unit -> int
              val beMoreVerbose : unit -> unit
              val setTypeStyle : ANSIStyle.style -> unit
              val setExecuteStyle : ANSIStyle.style -> unit
              val setErrorStyle : ANSIStyle.style -> unit
              val setWarningStyle : ANSIStyle.style -> unit
              val setDiagnosticStyle : ANSIStyle.style -> unit
              val setInformationStyle : ANSIStyle.style -> unit
          end = struct
val () = Lua.setGlobal ("CLUTTEX_VERBOSITY", Lua.fromInt 0)
fun getVerbosity () : int = Lua.unsafeFromValue (Lua.global "CLUTTEX_VERBOSITY")
fun beMoreVerbose () = let val verbosity = Lua.global "CLUTTEX_VERBOSITY"
                       in Lua.setGlobal ("CLUTTEX_VERBOSITY", Lua.+ (verbosity, Lua.fromInt 1))
                       end

datatype mode = ALWAYS | AUTO | NEVER
val useColors = ref false
fun setColors ALWAYS = let val isatty = Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.isatty"]
                           val enableVirtualTerminal = Lua.field (isatty, "enable_virtual_terminal")
                           val stderr = Lua.field (Lua.global "io", "stderr")
                       in useColors := true
                        ; if not (Lua.isFalsy enableVirtualTerminal) then
                              let val succ = Lua.call1 enableVirtualTerminal #[stderr]
                              in if Lua.isFalsy succ andalso getVerbosity () >= 2 then
                                     TextIO.output (TextIO.stdErr, "ClutTeX: Failed to enable virtual terminal\n")
                                 else
                                     ()
                              end
                          else
                              ()
                       end
  | setColors AUTO = let val isatty = Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.isatty"]
                         val enableVirtualTerminal = Lua.field (isatty, "enable_virtual_terminal")
                         val stderr = Lua.field (Lua.global "io", "stderr")
                         val u = not (Lua.isFalsy (Lua.call1 (Lua.field (isatty, "isatty")) #[stderr]))
                     in useColors := u
                      ; if u andalso not (Lua.isFalsy enableVirtualTerminal) then
                            let val succ : bool = Lua.unsafeFromValue (Lua.call1 enableVirtualTerminal #[stderr])
                            in useColors := succ
                             ; if not succ andalso getVerbosity () >= 2 then
                                   TextIO.output (TextIO.stdErr, "ClutTeX: Failed to enable virtual terminal\n")
                               else
                                   ()
                            end
                        else
                            ()
                     end
  | setColors NEVER = useColors := false

structure CMD = struct
(* ESCAPE: hex 1B = dec 27 = oct 33 *)
val reset      = "\027[0m"
val underline  = "\027[4m"
val fg_black   = "\027[30m"
val fg_red     = "\027[31m"
val fg_green   = "\027[32m"
val fg_yellow  = "\027[33m"
val fg_blue    = "\027[34m"
val fg_magenta = "\027[35m"
val fg_cyan    = "\027[36m"
val fg_white   = "\027[37m"
val fg_reset   = "\027[39m"
val bg_black   = "\027[40m"
val bg_red     = "\027[41m"
val bg_green   = "\027[42m"
val bg_yellow  = "\027[43m"
val bg_blue    = "\027[44m"
val bg_magenta = "\027[45m"
val bg_cyan    = "\027[46m"
val bg_white   = "\027[47m"
val bg_reset   = "\027[49m"
val fg_x_black   = "\027[90m"
val fg_x_red     = "\027[91m"
val fg_x_green   = "\027[92m"
val fg_x_yellow  = "\027[93m"
val fg_x_blue    = "\027[94m"
val fg_x_magenta = "\027[95m"
val fg_x_cyan    = "\027[96m"
val fg_x_white   = "\027[97m"
val bg_x_black   = "\027[100m"
val bg_x_red     = "\027[101m"
val bg_x_green   = "\027[102m"
val bg_x_yellow  = "\027[103m"
val bg_x_blue    = "\027[104m"
val bg_x_magenta = "\027[105m"
val bg_x_cyan    = "\027[106m"
val bg_x_white   = "\027[107m"
end

val typeStyle : string ref
  = ref (ANSIStyle.toString { foreground = SOME ANSIColor.BRIGHT_WHITE
                            , background = SOME ANSIColor.RED
                            , bold = false
                            , dim = false
                            , underline = false
                            , blink = false
                            , reverse = false
                            , italic = false
                            , strike = false
                            }
        )
val executeStyle : string ref
  = ref (ANSIStyle.toString { foreground = SOME ANSIColor.CYAN
                            , background = NONE
                            , bold = false
                            , dim = false
                            , underline = false
                            , blink = false
                            , reverse = false
                            , italic = false
                            , strike = false
                            }
        )
val errorStyle : string ref
  = ref (ANSIStyle.toString { foreground = SOME ANSIColor.RED
                            , background = NONE
                            , bold = false
                            , dim = false
                            , underline = false
                            , blink = false
                            , reverse = false
                            , italic = false
                            , strike = false
                            }
        )
val warningStyle : string ref
  = ref (ANSIStyle.toString { foreground = SOME ANSIColor.BLUE
                            , background = NONE
                            , bold = false
                            , dim = false
                            , underline = false
                            , blink = false
                            , reverse = false
                            , italic = false
                            , strike = false
                            }
        )
val diagnosticStyle : string ref
  = ref (ANSIStyle.toString { foreground = SOME ANSIColor.BLUE
                            , background = NONE
                            , bold = false
                            , dim = false
                            , underline = false
                            , blink = false
                            , reverse = false
                            , italic = false
                            , strike = false
                            }
        )
val informationStyle : string ref
  = ref (ANSIStyle.toString { foreground = SOME ANSIColor.MAGENTA
                            , background = NONE
                            , bold = false
                            , dim = false
                            , underline = false
                            , blink = false
                            , reverse = false
                            , italic = false
                            , strike = false
                            }
        )

fun setTypeStyle style = typeStyle := ANSIStyle.toString style
fun setExecuteStyle style = executeStyle := ANSIStyle.toString style
fun setErrorStyle style = errorStyle := ANSIStyle.toString style
fun setWarningStyle style = warningStyle := ANSIStyle.toString style
fun setDiagnosticStyle style = diagnosticStyle := ANSIStyle.toString style
fun setInformationStyle style = informationStyle := ANSIStyle.toString style

fun exec commandline = if !useColors then
                           TextIO.output (TextIO.stdErr, !typeStyle ^ "[EXEC]" ^ ANSIStyle.resetAll ^ " " ^ !executeStyle ^ commandline ^ ANSIStyle.resetAll ^ "\n")
                       else
                           TextIO.output (TextIO.stdErr, "[EXEC] " ^ commandline ^ "\n")
fun error message = if !useColors then
                        TextIO.output (TextIO.stdErr, !typeStyle ^ "[ERROR]" ^ ANSIStyle.resetAll ^ " " ^ !errorStyle ^ message ^ ANSIStyle.resetAll ^ "\n")
                    else
                        TextIO.output (TextIO.stdErr, "[ERROR] " ^ message ^ "\n")
fun warn message = if !useColors then
                        TextIO.output (TextIO.stdErr, !typeStyle ^ "[WARN]" ^ ANSIStyle.resetAll ^ " " ^ !warningStyle ^ message ^ ANSIStyle.resetAll ^ "\n")
                    else
                        TextIO.output (TextIO.stdErr, "[WARN] " ^ message ^ "\n")
fun diag message = if !useColors then
                        TextIO.output (TextIO.stdErr, !typeStyle ^ "[DIAG]" ^ ANSIStyle.resetAll ^ " " ^ !diagnosticStyle ^ message ^ ANSIStyle.resetAll ^ "\n")
                    else
                        TextIO.output (TextIO.stdErr, "[DIAG] " ^ message ^ "\n")
fun info message = if !useColors then
                        TextIO.output (TextIO.stdErr, !typeStyle ^ "[INFO]" ^ ANSIStyle.resetAll ^ " " ^ !informationStyle ^ message ^ ANSIStyle.resetAll ^ "\n")
                    else
                        TextIO.output (TextIO.stdErr, "[INFO] " ^ message ^ "\n")
end;
