structure InteractionMode : sig
              datatype interaction = BATCHMODE | NONSTOPMODE | SCROLLMODE | ERRORSTOPMODE
              val fromString : string -> interaction option
              val toString : interaction -> string
          end = struct
datatype interaction = BATCHMODE | NONSTOPMODE | SCROLLMODE | ERRORSTOPMODE
fun fromString "batchmode" = SOME BATCHMODE
  | fromString "nonstopmode" = SOME NONSTOPMODE
  | fromString "scrollmode" = SOME SCROLLMODE
  | fromString "errorstopmode" = SOME ERRORSTOPMODE
  | fromString _ = NONE
fun toString BATCHMODE = "batchmode"
  | toString NONSTOPMODE = "nonstopmode"
  | toString SCROLLMODE = "scrollmode"
  | toString ERRORSTOPMODE = "errorstopmode"
end;

structure ShellEscape : sig
              datatype shell_escape = ALLOWED | RESTRICTED | FORBIDDEN
          end = struct
datatype shell_escape = ALLOWED | RESTRICTED | FORBIDDEN
end;

structure OutputFormat : sig
              datatype format = PDF | DVI
              val fromString : string -> format option
          end = struct
datatype format = PDF | DVI
fun fromString "pdf" = SOME PDF
  | fromString "dvi" = SOME DVI
  | fromString _ = NONE
end;
