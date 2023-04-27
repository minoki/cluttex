fun getEnvMulti [] = NONE
  | getEnvMulti (name :: xs) = case OS.Process.getEnv name of
                                   SOME x => SOME x
                                 | NONE => getEnvMulti xs
fun genOutputDirectory (xs : string list)
    = let val message = String.concatWith "\000" xs
          val hash = MD5.md5AsLowerHex (Byte.stringToBytes message)
          val tmpdir = case getEnvMulti ["TMPDIR", "TMP", "TEMP"] of
                           SOME tmpdir => tmpdir
                         | NONE => case getEnvMulti ["HOME", "USERPROFILE"] of
                                       SOME home => OS.Path.joinDirFile { dir = home, file = ".latex-build-temp" } (* $XDG_CACHE_HOME/cluttex, $HOME/.cache/cluttex *)
                                     | NONE => raise Fail "environment variable 'TMPDIR' not set!"
      in OS.Path.joinDirFile { dir = tmpdir, file = "cluttex-" ^ hash }
      end
structure DviDriver = struct
datatype driver = DVIPDFMX | DVIPS | DVISVGM
fun fromString "dvipdfmx" = SOME DVIPDFMX
  | fromString "dvips" = SOME DVIPS
  | fromString "dvisvgm" = SOME DVISVGM
  | fromString _ = NONE
end
structure InteractionMode = struct
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
end
structure ShellEscape = struct
datatype shell_escape = ALLOWED | RESTRICTED | FORBIDDEN
end
structure OutputFormat = struct
datatype format = PDF | DVI
fun fromString "pdf" = SOME PDF
  | fromString "dvi" = SOME DVI
  | fromString _ = NONE
end
datatype bibtex_or_biber = BIBTEX of string | BIBER of string
structure WatchEngine = struct
datatype engine = FSWATCH | INOTIFYWAIT | AUTO
fun fromString "fswatch" = SOME FSWATCH
  | fromString "inotifywait" = SOME INOTIFYWAIT
  | fromString "auto" = SOME AUTO
  | fromString _ = NONE
end
structure ColorMode = struct
datatype mode = ALWAYS | AUTO | NEVER
fun fromString "always" = SOME ALWAYS
  | fromString "auto" = SOME AUTO
  | fromString "never" = SOME NEVER
  | fromString _ = NONE
end
type app_options = { engine : string option
                   , engine_executable : string option
                   , output : string option
                   , fresh : bool (* default: false *)
                   , max_iterations : int option
                   , start_with_draft : bool
                   , watch : WatchEngine.engine option
                   , verbosity : int
                   , color : ColorMode.mode option
                   , change_directory : bool option
                   , includeonly : string option
                   , make_depends : string option
                   , print_output_directory : bool (* default: false *)
                   , package_support : { minted : bool, epstopdf : bool }
                   , check_driver : DviDriver.driver option (* dvipdfmx | dvips | dvisvgm *)
                   , synctex : string option (* should be int? *)
                   , file_line_error : bool
                   , interaction : InteractionMode.interaction option (* batchmode | nonstopmode | scrollmode | errorstopmode *)
                   , halt_on_error : bool
                   , shell_escape : ShellEscape.shell_escape option
                   , jobname : string option
                   , fmt : string option
                   , output_directory : string option
                   , output_format : OutputFormat.format option (* pdf | dvi *)
                   , tex_extraoptions : string list
                   , dvipdfmx_extraoptions : string list
                   , makeindex : string option
                   , bibtex_or_biber : bibtex_or_biber option
                   , makeglossaries : string option
                   }
datatype 'a option_action = SIMPLE of 'a
                          | WITH_ARG of string -> 'a
                          | WITH_OPTIONAL_ARG of { default : string, action : string -> 'a }
datatype option_desc = SHORT of string
                     | LONG of string
fun testOption (_, []) = NONE
  | testOption ((SHORT s, SIMPLE v), arg :: args) = if arg = s then
                                                        SOME (v, args)
                                                    else
                                                        NONE
  | testOption ((SHORT s, WITH_ARG f), arg :: args) = if arg = s then
                                                          case args of
                                                              [] => raise Fail ("argument missing after " ^ s)
                                                            | arg' :: args' => SOME (f arg', args') (* -x foo *)
                                                      else if String.isPrefix s arg then (* -xfoo *)
                                                          let val arg' = String.extract (arg, String.size s, NONE)
                                                          in SOME (f arg', args)
                                                          end
                                                      else
                                                          NONE
  | testOption ((LONG s, SIMPLE v), arg :: args) = if arg = s then
                                                       SOME (v, args)
                                                   else
                                                       NONE
  | testOption ((LONG s, WITH_ARG f), arg :: args) = if arg = s then
                                                         case args of
                                                             [] => raise Fail ("argument missing after " ^ s)
                                                           | arg' :: args' => SOME (f arg', args') (* -option foo *)
                                                     else if String.isPrefix (s ^ "=") arg then (* -option=foo *)
                                                         let val arg' = String.extract (arg, String.size s + 1, NONE)
                                                         in SOME (f arg', args)
                                                         end
                                                     else
                                                         NONE
fun parseOption (descs, []) = NONE
  | parseOption (descs, args) = let fun go [] = NONE
                                      | go (desc :: descs) = case testOption (desc, args) of
                                                                 SOME r => SOME r
                                                               | NONE => go descs
                                in go descs
                                end
datatype option = OPT_ENGINE of string (* -e,--engine=ENGINE *)
                | OPT_ENGINE_EXECUTABLE of string (* --engine-executable=EXECUTABLE *)
                | OPT_OUTPUT of string (* -o,--output=OUTPUT *)
                | OPT_FRESH (* --fresh *)
                | OPT_MAX_ITERATIONS of string (* --max-iterations=N *)
                | OPT_START_WITH_DRAFT (* --start-with-draft *)
                | OPT_CHANGE_DIRECTORY of bool (* --change-directory,--no-change-directory *)
                | OPT_WATCH of string (* --watch[=auto] *)
                | OPT_HELP (* -h,-help,--help *)
                | OPT_VERSION
                | OPT_VERBOSE
                | OPT_COLOR of string (* --color[=always] *)
                | OPT_INCLUDEONLY of string
                | OPT_MAKE_DEPENDS of string
                | OPT_PRINT_OUTPUT_DIRECTORY
                | OPT_PACKAGE_SUPPORT of string
                | OPT_CHECK_DRIVER of string
                | OPT_SYNCTEX of string
                | OPT_FILE_LINE_ERROR of bool
                | OPT_INTERACTION of string
                | OPT_HALT_ON_ERROR of bool
                | OPT_SHELL_ESCAPE of shell_escape
                | OPT_JOBNAME of string
                | OPT_FMT of string
                | OPT_OUTPUT_DIRECTORY of string
                | OPT_OUTPUT_FORMAT of string
                | OPT_TEX_OPTION of string
                | OPT_TEX_OPTIONS of string
                | OPT_DVIPDFMX_OPTION of string
                | OPT_DVIPDFMX_OPTIONS of string
                | OPT_MAKEINDEX of string
                | OPT_BIBTEX of string
                | OPT_BIBER of string
                | OPT_MAKEGLOSSARIES of string
val optionDescs = [(SHORT "-e", WITH_ARG OPT_ENGINE)
                  ,(LONG "--engine", WITH_ARG OPT_ENGINE)
                  ,(LONG "--engine-executable", WITH_ARG OPT_ENGINE_EXECUTABLE)
                  ,(SHORT "-o", WITH_ARG OPT_OUTPUT)
                  ,(LONG "--output", WITH_ARG OPT_OUTPUT)
                  ,(LONG "--fresh", SIMPLE OPT_FRESH)
                  ,(LONG "--max-iterations", WITH_ARG OPT_MAX_ITERATIONS)
                  ,(LONG "--start-with-draft", SIMPLE OPT_START_WITH_DRAFT)
                  ,(LONG "--change-directory", SIMPLE (OPT_CHANGE_DIRECTORY true))
                  ,(LONG "--no-change-directory", SIMPLE (OPT_CHANGE_DIRECTORY false))
                  ,(LONG "--watch", WITH_OPTIONAL_ARG { action = OPT_WATCH, default = "auto" })
                  ,(SHORT "-h", SIMPLE OPT_HELP)
                  ,(LONG "-help", SIMPLE OPT_HELP)
                  ,(LONG "--help", SIMPLE OPT_HELP)
                  ,(SHORT "-v", SIMPLE OPT_VERSION)
                  ,(LONG "--version", SIMPLE OPT_VERSION)
                  ,(SHORT "-V", SIMPLE OPT_VERBOSE)
                  ,(LONG "--verbose", SIMPLE OPT_VERBOSE)
                  ,(LONG "--color", WITH_OPTIONAL_ARG { action = OPT_COLOR, default = "always" })
                  ,(LONG "--includeonly", WITH_ARG OPT_INCLUDEONLY)
                  ,(LONG "--make-depends", WITH_ARG OPT_MAKE_DEPENDS)
                  ,(LONG "--print-output-directory", SIMPLE OPT_PRINT_OUTPUT_DIRECTORY)
                  ,(LONG "--package-support", WITH_ARG OPT_PACKAGE_SUPPORT)
                  ,(LONG "--check-driver", WITH_ARG OPT_CHECK_DRIVER)
                  ,(LONG "-synctex", WITH_ARG OPT_SYNCTEX)
                  ,(LONG "--synctex", WITH_ARG OPT_SYNCTEX)
                  ,(LONG "-file-line-error", SIMPLE (OPT_FILE_LINE_ERROR true))
                  ,(LONG "--file-line-error", SIMPLE (OPT_FILE_LINE_ERROR true))
                  ,(LONG "-no-file-line-error", SIMPLE (OPT_FILE_LINE_ERROR false))
                  ,(LONG "--no-file-line-error", SIMPLE (OPT_FILE_LINE_ERROR false))
                  ,(LONG "-interaction", WITH_ARG OPT_INTERACTION)
                  ,(LONG "--interaction", WITH_ARG OPT_INTERACTION)
                  ,(LONG "-halt-on-error", SIMPLE (OPT_HALT_ON_ERROR true))
                  ,(LONG "--halt-on-error", SIMPLE (OPT_HALT_ON_ERROR true))
                  ,(LONG "-no-halt-on-error", SIMPLE (OPT_HALT_ON_ERROR false))
                  ,(LONG "--no-halt-on-error", SIMPLE (OPT_HALT_ON_ERROR false))
                  ,(LONG "-shell-escape", SIMPLE (OPT_SHELL_ESCAPE ALLOWED))
                  ,(LONG "--shell-escape", SIMPLE (OPT_SHELL_ESCAPE ALLOWED))
                  ,(LONG "-no-shell-escape", SIMPLE (OPT_SHELL_ESCAPE FORBIDDEN))
                  ,(LONG "--no-shell-escape", SIMPLE (OPT_SHELL_ESCAPE FORBIDDEN))
                  ,(LONG "-shell-restricted", SIMPLE (OPT_SHELL_ESCAPE RESTRICTED))
                  ,(LONG "--shell-restricted", SIMPLE (OPT_SHELL_ESCAPE RESTRICTED))
                  ,(LONG "-jobname", WITH_ARG OPT_JOBNAME)
                  ,(LONG "--jobname", WITH_ARG OPT_JOBNAME)
                  ,(LONG "-fmt", WITH_ARG OPT_FMT)
                  ,(LONG "--fmt", WITH_ARG OPT_FMT)
                  ,(LONG "-output-directory", WITH_ARG OPT_OUTPUT_DIRECTORY)
                  ,(LONG "--output-directory", WITH_ARG OPT_OUTPUT_DIRECTORY)
                  ,(LONG "-output-format", WITH_ARG OPT_OUTPUT_FORMAT)
                  ,(LONG "--output-format", WITH_ARG OPT_OUTPUT_FORMAT)
                  ,(LONG "--tex-option", WITH_ARG OPT_TEX_OPTION)
                  ,(LONG "--tex-options", WITH_ARG OPT_TEX_OPTIONS)
                  ,(LONG "--dvipdfmx-option", WITH_ARG OPT_DVIPDFMX_OPTION)
                  ,(LONG "--dvipdfmx-options", WITH_ARG OPT_DVIPDFMX_OPTIONS)
                  ,(LONG "--makeindex", WITH_ARG OPT_MAKEINDEX)
                  ,(LONG "--bibtex", WITH_ARG OPT_BIBTEX)
                  ,(LONG "--biber", WITH_OPTIONAL_ARG { action = OPT_BIBER, default = "biber" })
                  ,(LONG "--makeglossaries", WITH_OPTIONAL_ARG { action = OPT_MAKEGLOSSARIES, default = "makeglossaries" })
                  ]
fun parseArgs (opts : options) args
    = case parseOption (optionDescs, args) of
          SOME (OPT_ENGINE engine, args) => (case #engine opts of
                                                 NONE => parseArgs { opts where engine = SOME engine } args
                                               | SOME _ => showMessageAndFail "multiple --engine options"
                                            )
        | SOME (OPT_ENGINE_EXECUTABLE executable, args) => (case #engine_executable opts of
                                                                NONE => parseArgs { opts where engine_executable = SOME engine_executable } args
                                                              | SOME _ => showMessageAndFail "multiple --engine-executable options"
                                                           )
        | SOME (OPT_OUTPUT output, args) => (case #output opts of
                                                 NONE => parseArgs { opts where output = SOME output } args
                                               | SOME _ => showMessageAndFail "multiple --output options"
                                            )
        | SOME (OPT_FERSH, args) => (case #fresh opts of
                                         false => parseArgs { opts where fresh = true } args
                                       | true => showMessageAndFail "multiple --fresh options"
                                    )
        | SOME (OPT_MAX_ITERATIONS n, args) => (case #max_iterations opts of
                                                    NONE => (case Int.fromString n of
                                                                 SOME n => parseArgs { opts where max_iterations = SOME n } args
                                                               | NONE => showMessageAndFail "invalid value for --max-iterations option"
                                                            )
                                                  | SOME _ => showMessageAndFail "multiple --max-iterations options"
                                               )
        | SOME (OPT_START_WITH_DRAFT, args) => (case #start_with_draft opts of
                                                    false => parseArgs { opts where start_with_draft = true } args
                                                  | true => showMessageAndFail "multiple --start-with-draft options"
                                               )
        | SOME (OPT_WATCH engine, args) => (case #watch opts of
                                                NONE => (case WatchEngine.fromString engine of
                                                             SOME engine => parseArgs { opts where watch = SOME engine } args
                                                           | NONE => showMessageAndFail "invalid value for --watch option"
                                                        )
                                            | SOME _ => showMessageAndFail "multiple --watch options"
                                         )
        | SOME (OPT_HELP, args) => showUsage ()
        | SOME (OPT_VERSION, args) => showVersion ()
        | SOME (OPT_VERBOSE, args) => parseArgs { opts where verbosity = #verbosity opts + 1 } args
        | SOME (OPT_COLOR mode, args) => (case #color opts of
                                              NONE => (case ColorMode.fromString mode of
                                                           SOME mode => parseArgs { opts where color = SOME mode } args
                                                         | NONE => showMessageAndFail "invalid value for --color option"
                                                      )
                                            | SOME _ => showMessageAndFail "multiple --color options"
                                         )
        | SOME (OPT_CHANGE_DIRECTORY x, args) => (case #change_directory opts of
                                                      NONE => parseArgs { opts where change_directory = SOME x } args
                                                    | SOME _ => showMessageAndFail "multiple --change-directory options"
                                                 )
        | SOME (OPT_INCLUDEONLY x, args) => (case #includeonly opts of
                                                 NONE => parseArgs { opts where includeonly = SOME x } args
                                               | SOME _ => showMessageAndFail "multiple --includeonly options"
                                            )
        | SOME (OPT_MAKE_DEPENDS x, args) => (case #make_depends opts of
                                                  NONE => parseArgs { opts where make_depends = SOME x } args
                                                | SOME _ => showMessageAndFail "multiple --make-depends options"
                                             )
        | SOME (OPT_PRINT_OUTPUT_DIRECTORY, args) => (case #print_output_directory opts of
                                                          false => parseArgs { opts where print_output_directory = true } args
                                                        | true => showMessageAndFail "multiple --print-output-directory options"
                                                     )
        | SOME (OPT_PACKAGE_SUPPORT s, args) => let val packages = String.tokens (fn c => c = "," orelse Char.isSpace c) s
                                                    val ps = List.foldl (fn ("minted", ps) => { ps where minted = true }
                                                                        | ("epstopdf", ps) => { ps where epstopdf = true }
                                                                        | (pkg, ps) => ( if #verbosity opts >= 1 then
                                                                                             warn ("ClutTeX provides no special support for '" ^ pkg ^ "'.")
                                                                                         else
                                                                                             ()
                                                                                       ; ps
                                                                                       )
                                                                        ) (#package_support opts) packages
                                                in parseArgs { opts where package_support = ps } args
                                                end
        | SOME (OPT_CHECK_DRIVER driver, args) => (case #check_driver opts of
                                                       NONE => (case DviDriver.fromString driver of
                                                                    SOME driver => parseArgs { opts where driver = SOME driver } args
                                                                  | NONE => showMessageAndFail "invalid value for --check-driver option"
                                                               )
                                                     | SOME _ => showMessageAndFail "multiple --check-driver options"
                                                  )
        | SOME (OPT_SYNCTEX x, args) => (case #synctex opts of
                                             NONE => parseArgs { opts where synctex = SOME x } args
                                           | SOME _ => showMessageAndFail "multiple --synctex options"
                                        )
        | SOME (OPT_FILE_LINE_ERROR x, args) => parseArgs { opts where file_line_error = x } args
        | SOME (OPT_INTERACTION x, args) => (case #interaction opts of
                                                 NONE => (case InteractionMode.fromString x of
                                                              SOME interaction => parseArgs { opts where interaction = SOME interaction } args
                                                            | NONE => showMessageAndFail "invalid argument for --interaction"
                                                         )
                                               | SOME _ => showMessageAndFail "multiple --interaction options"
                                            )
        | SOME (OPT_HALT_ON_ERROR x, args) => parseArgs { opts where halt_on_error = x } args
        | SOME (OPT_SHELL_ESCAPE se, args) => (case #shell_escape opts of
                                                   NONE => parseArgs { opts where shell_escape = SOME se } args
                                                 | SOME _ => showMessageAndFail "multiple --(no-)shell-escape / --shell-restricted options"
                                              )
        | SOME (OPT_JOBNAME x, args) => (case #jobname opts of
                                             NONE => parseArgs { opts where jobname = SOME x } args
                                           | SOME _ => showMessageAndFail "multiple --jobname options"
                                        )
        | SOME (OPT_FMT x, args) => (case #fmt opts of
                                         NONE => parseArgs { opts where fmt = SOME x } args
                                       | SOME _ => showMessageAndFail "multiple --fmt options"
                                    )
        | SOME (OPT_OUTPUT_DIRECTORY x, args) => (case #output_directory opts of
                                                      NONE => parseArgs { opts where output_directory = SOME x } args
                                                    | SOME _ => showMessageAndFail "multiple --output-directory options"
                                                 )
        | SOME (OPT_OUTPUT_FORMAT format, args) => (case #output_format opts of
                                                        NONE => (case OutputFormat.fromString format of
                                                                     SOME format => parseArgs { opts where output_format = SOME format } args
                                                                   | NONE => showMessageAndFail "invalid value for --output-format option"
                                                                )
                                                      | SOME _ => showMessageAndFail "multiple --output-format options"
                                                   )
        | SOME (OPT_TEX_OPTION x, args) => let val x = ShellUtil.escape x
                                           in parseArgs { opts where tex_extraoptions = x :: #tex_extraoptions opts } args
                                           end
        | SOME (OPT_TEX_OPTIONS x, args) => parseArgs { opts where tex_extraoptions = x @ #tex_extraoptions opts } args
        | SOME (OPT_DVIPDFMX_OPTION x, args) => let val x = ShellUtil.escape x
                                                in parseArgs { opts where dvipdfmx_extraoptions = x :: #dvipdfmx_extraoptions opts } args
                                                end
        | SOME (OPT_DVIPDFMX_OPTIONS x, args) => parseArgs { opts where tex_extraoptions = x @ #dvipdfmx_extraoptions opts } args
        | SOME (OPT_MAKEINDEX x, args) => (case #makeindex opts of
                                               NONE => parseArgs { opts where makeindex = SOME x } args
                                             | SOME _ => showMessageAndFail "multiple --makeindex options"
                                          )
        | SOME (OPT_BIBTEX x, args) => (case #bibtex_or_biber opts of
                                            NONE => parseArgs { opts where bibtex_or_biber = SOME (BIBTEX x) } args
                                          | SOME _ => showMessageAndFail "multiple --bibtex / --biber options"
                                       )
        | SOME (OPT_BIBER x, args) => (case #bibtex_or_biber opts of
                                           NONE => parseArgs { opts where bibtex_or_biber = SOME (BIBER x) } args
                                         | SOME _ => showMessageAndFail "multiple --bibtex / --biber options"
                                      )
        | SOME (OPT_MAKEGLOSSARIES x, args) => (case #makeglossaries opts of
                                                    NONE => parseArgs { opts where makeglossaries = SOME x } args
                                                  | SOME _ => showMessageAndFail "multiple --makeglossaries options"
                                               )
        | NONE => (case args of
                       "--" :: args => handleInputFile opts args
                     | arg :: args' =>
                       if String.isPrefix "-" arg then
                           showMessageAndFail ("Unrecognized option: " ^ arg ^ ".\n")
                       else
                           handleInputFile opts args
                     | [] => showMessageAndFail "No input given. Try --help.\n"
                  )
