structure TeXEngine : sig
              type engine_type
              type run_options = { engine_executable : string option
                                 , halt_on_error : bool
                                 , interaction : AppOptions.InteractionMode.interaction option
                                 , file_line_error : bool
                                 , synctex : string option
                                 , shell_escape : AppOptions.ShellEscape.shell_escape option
                                 , jobname : string option
                                 , output_directory : string option
                                 , extra_options : string list
                                 , output_format : AppOptions.OutputFormat.format
                                 , draftmode : bool (* pdfTeX / XeTeX / LuaTeX *)
                                 , fmt : string option
                                 , lua_initialization_script : string option (* LuaTeX only *)
                                 }
              type engine = { name : string
                            , executable : string
                            , supports_pdf_generation : bool
                            , dvi_extension : string
                            , supports_draftmode : bool
                            , engine_type : engine_type
                            }
              val isLuaTeX : engine -> bool
              val buildCommand : engine * string * run_options -> string
              val get : string -> engine option
          end = struct
datatype engine_type = PDFTEX | XETEX | LUATEX | OTHER
type run_options = { engine_executable : string option
                   , halt_on_error : bool
                   , interaction : AppOptions.InteractionMode.interaction option
                   , file_line_error : bool
                   , synctex : string option
                   , shell_escape : AppOptions.ShellEscape.shell_escape option
                   , jobname : string option
                   , output_directory : string option
                   , extra_options : string list
                   , output_format : AppOptions.OutputFormat.format
                   , draftmode : bool (* pdfTeX / XeTeX / LuaTeX *)
                   , fmt : string option
                   , lua_initialization_script : string option (* LuaTeX only *)
                   }
type engine = { name : string
              , executable : string
              , dvi_extension : string
              , supports_pdf_generation : bool
              , supports_draftmode : bool
              , engine_type : engine_type
              }
fun isLuaTeX ({ engine_type, ... } : engine) = engine_type = LUATEX
fun buildCommand (engine : engine, inputline, options : run_options)
    = let val executable = Option.getOpt (#engine_executable options, #executable engine)
          val revCommand = ["-recorder", executable]
          val revCommand = case #fmt options of
                               NONE => revCommand
                             | SOME fmt => "-fmt=" ^ fmt :: revCommand
          val revCommand = case #halt_on_error options of
                               false => revCommand
                             | true => "-halt-on-error" :: revCommand
          val revCommand = case #interaction options of
                               NONE => revCommand
                             | SOME mode => "-interaction=" ^ AppOptions.InteractionMode.toString mode :: revCommand
          val revCommand = case #file_line_error options of
                               false => revCommand
                             | true => "-file-line-error" :: revCommand
          val revCommand = case #synctex options of
                               NONE => revCommand
                             | SOME synctex => "-synctex=" ^ ShellUtil.escape synctex :: revCommand
          val revCommand = case #shell_escape options of
                               NONE => revCommand
                             | SOME AppOptions.ShellEscape.FORBIDDEN => "-no-shell-escape" :: revCommand
                             | SOME AppOptions.ShellEscape.RESTRICTED => "-shell-restricted" :: revCommand
                             | SOME AppOptions.ShellEscape.ALLOWED => "-shell-escape" :: revCommand
          val revCommand = case #jobname options of
                               NONE => revCommand
                             | SOME jobname => "-jobname=" ^ ShellUtil.escape jobname :: revCommand
          val revCommand = case #output_directory options of
                               NONE => revCommand
                             | SOME dir => "-output-directory=" ^ ShellUtil.escape dir :: revCommand
          val revCommand = case #engine_type engine of
                               OTHER => revCommand
                             | PDFTEX => let val revCommand = if #draftmode options then
                                                                  "-draftmode" :: revCommand
                                                              else
                                                                  revCommand
                                         in case #output_format options of
                                                AppOptions.OutputFormat.DVI => "-output-format=dvi" :: revCommand
                                              | AppOptions.OutputFormat.PDF => revCommand
                                         end
                             | XETEX => if #draftmode options orelse #output_format options = AppOptions.OutputFormat.DVI then
                                            "-no-pdf" :: revCommand
                                        else
                                            revCommand
                             | LUATEX => let val revCommand = case #lua_initialization_script options of
                                                                  NONE => revCommand
                                                                | SOME script => "--lua=" ^ ShellUtil.escape script :: revCommand
                                             val revCommand = if #draftmode options then
                                                                  "--draftmode" :: revCommand
                                                              else
                                                                  revCommand
                                         in case #output_format options of
                                                AppOptions.OutputFormat.DVI => "--output-format=dvi" :: revCommand
                                              | AppOptions.OutputFormat.PDF => revCommand
                                         end
          val revCommand = List.revAppend (#extra_options options, revCommand)
          val revCommand = ShellUtil.escape inputline :: revCommand
      in String.concatWith " " (List.rev revCommand)
      end
val pdftex_or_pdflatex = { supports_pdf_generation = true
                         , dvi_extension = "dvi"
                         , supports_draftmode = true
                         , engine_type = PDFTEX
                         }
val pdftex : engine = { name = "pdftex", executable = "pdftex", ... = pdftex_or_pdflatex }
val pdflatex : engine = { name = "pdflatex", executable = "pdflatex", ... = pdftex_or_pdflatex }
val luatex_or_lualatex = { supports_pdf_generation = true
                         , dvi_extension = "dvi"
                         , supports_draftmode = true
                         , engine_type = LUATEX
                         }
val luatex : engine = { name = "luatex", executable = "luatex", ... = luatex_or_lualatex }
val lualatex : engine = { name = "lualatex", executable = "lualatex", ... = luatex_or_lualatex }
val luajittex : engine = { name = "luajittex", executable = "luajittex", ... = luatex_or_lualatex }
val xetex_or_xelatex = { supports_pdf_generation = true
                       , dvi_extension = "xdv"
                       , supports_draftmode = true
                       , engine_type = XETEX
                       }
val xetex : engine = { name = "xetex", executable = "xetex", ... = xetex_or_xelatex }
val xelatex : engine = { name = "xelatex", executable = "xelatex", ... = xetex_or_xelatex }
val other_engine = { supports_pdf_generation = false
                   , dvi_extension = "dvi"
                   , supports_draftmode = false
                   , engine_type = OTHER
                   }
val tex : engine = { name = "tex", executable = "tex", ... = other_engine }
val etex : engine = { name = "etex", executable = "etex", ... = other_engine }
val latex : engine = { name = "latex", executable = "latex", ... = other_engine }
val ptex : engine = { name = "ptex", executable = "ptex", ... = other_engine }
val eptex : engine = { name = "eptex", executable = "eptex", ... = other_engine }
val platex : engine = { name = "platex", executable = "platex", ... = other_engine }
val uptex : engine = { name = "uptex", executable = "uptex", ... = other_engine }
val euptex : engine = { name = "euptex", executable = "euptex", ... = other_engine }
val uplatex : engine = { name = "uplatex", executable = "uplatex", ... = other_engine }
fun get "pdftex" = SOME pdftex
  | get "pdflatex" = SOME pdflatex
  | get "luatex" = SOME luatex
  | get "lualatex" = SOME lualatex
  | get "luajittex" = SOME luajittex
  | get "xetex" = SOME xetex
  | get "xelatex" = SOME xelatex
  | get "tex" = SOME tex
  | get "etex" = SOME etex
  | get "latex" = SOME latex
  | get "ptex" = SOME ptex
  | get "eptex" = SOME eptex
  | get "platex" = SOME platex
  | get "uptex" = SOME uptex
  | get "euptex" = SOME euptex
  | get "uplatex" = SOME uplatex
  | get _ = NONE
end;
