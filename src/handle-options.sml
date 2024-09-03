functor HandleOptions (val showMessageAndFail : string -> 'a
                       val showUsage : unit -> 'a
                       val showVersion : unit -> 'a
                      ) : sig
            val parse : AppOptions.initial_options * string list -> AppOptions.initial_options * string list
        end = struct
open AppOptions
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
  | testOption ((SHORT s, WITH_ARG f), arg :: args)
    = if arg = s then
          case args of
              [] => raise Fail ("argument missing after " ^ s)
            | arg' :: args' => SOME (f arg', args') (* -x foo *)
      else if String.isPrefix s arg then (* -xfoo *)
          let val arg' = String.extract (arg, String.size s, NONE)
          in SOME (f arg', args)
          end
      else
          NONE
  | testOption ((SHORT s, WITH_OPTIONAL_ARG { default, action }), arg :: args)
    = if arg = s then
          SOME (action default, args)
      else if String.isPrefix s arg then (* -xfoo *)
          let val arg' = String.extract (arg, String.size s, NONE)
          in SOME (action arg', args)
          end
      else
          NONE
  | testOption ((LONG s, SIMPLE v), arg :: args) = if arg = s then
                                                       SOME (v, args)
                                                   else
                                                       NONE
  | testOption ((LONG s, WITH_ARG f), arg :: args)
    = if arg = s then
          case args of
              [] => raise Fail ("argument missing after " ^ s)
            | arg' :: args' => SOME (f arg', args') (* -option foo *)
      else if String.isPrefix (s ^ "=") arg then (* -option=foo *)
          let val arg' = String.extract (arg, String.size s + 1, NONE)
          in SOME (f arg', args)
          end
      else
          NONE
  | testOption ((LONG s, WITH_OPTIONAL_ARG { default, action }), arg :: args)
    = if arg = s then
          SOME (action default, args)
      else if String.isPrefix (s ^ "=") arg then (* -option=foo *)
          let val arg' = String.extract (arg, String.size s + 1, NONE)
          in SOME (action arg', args)
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
                | OPT_SHELL_ESCAPE of ShellEscape.shell_escape
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
                | OPT_CONFIG_FILE of string
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
                  ,(LONG "-shell-escape", SIMPLE (OPT_SHELL_ESCAPE ShellEscape.ALLOWED))
                  ,(LONG "--shell-escape", SIMPLE (OPT_SHELL_ESCAPE ShellEscape.ALLOWED))
                  ,(LONG "-no-shell-escape", SIMPLE (OPT_SHELL_ESCAPE ShellEscape.FORBIDDEN))
                  ,(LONG "--no-shell-escape", SIMPLE (OPT_SHELL_ESCAPE ShellEscape.FORBIDDEN))
                  ,(LONG "-shell-restricted", SIMPLE (OPT_SHELL_ESCAPE ShellEscape.RESTRICTED))
                  ,(LONG "--shell-restricted", SIMPLE (OPT_SHELL_ESCAPE ShellEscape.RESTRICTED))
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
                  ,(LONG "--config-file", WITH_ARG OPT_CONFIG_FILE)
                  ]
fun parse (opts : initial_options, args)
    = case parseOption (optionDescs, args) of
          SOME (OPT_ENGINE engine, args) => (case #engine opts of
                                                 NONE => parse ({ opts where engine = SOME engine }, args)
                                               | SOME _ => showMessageAndFail "multiple --engine options"
                                            )
        | SOME (OPT_ENGINE_EXECUTABLE executable, args) => (case #engine_executable opts of
                                                                NONE => parse ({ opts where engine_executable = SOME executable }, args)
                                                              | SOME _ => showMessageAndFail "multiple --engine-executable options"
                                                           )
        | SOME (OPT_OUTPUT output, args) => (case #output opts of
                                                 NONE => parse ({ opts where output = SOME output }, args)
                                               | SOME _ => showMessageAndFail "multiple --output options"
                                            )
        | SOME (OPT_FRESH, args) => (case #fresh opts of
                                         false => parse ({ opts where fresh = true }, args)
                                       | true => showMessageAndFail "multiple --fresh options"
                                    )
        | SOME (OPT_MAX_ITERATIONS n, args) => (case #max_iterations opts of
                                                    NONE => (case Int.fromString n of
                                                                 SOME n => parse ({ opts where max_iterations = SOME n }, args)
                                                               | NONE => showMessageAndFail "invalid value for --max-iterations option"
                                                            )
                                                  | SOME _ => showMessageAndFail "multiple --max-iterations options"
                                               )
        | SOME (OPT_START_WITH_DRAFT, args) => (case #start_with_draft opts of
                                                    false => parse ({ opts where start_with_draft = true }, args)
                                                  | true => showMessageAndFail "multiple --start-with-draft options"
                                               )
        | SOME (OPT_WATCH engine, args) => (case #watch opts of
                                                NONE => (case WatchEngine.fromString engine of
                                                             SOME engine => parse ({ opts where watch = SOME engine }, args)
                                                           | NONE => showMessageAndFail "invalid value for --watch option"
                                                        )
                                            | SOME _ => showMessageAndFail "multiple --watch options"
                                         )
        | SOME (OPT_HELP, args) => showUsage ()
        | SOME (OPT_VERSION, args) => showVersion ()
        | SOME (OPT_VERBOSE, args) => ( Message.beMoreVerbose ()
                                      ; parse (opts, args)
                                      )
        | SOME (OPT_COLOR mode, args) => (case #color opts of
                                              NONE => (case ColorMode.fromString mode of
                                                           SOME mode => ( Message.setColors mode
                                                                        ; parse ({ opts where color = SOME mode }, args)
                                                                        )
                                                         | NONE => showMessageAndFail "invalid value for --color option"
                                                      )
                                            | SOME _ => showMessageAndFail "multiple --color options"
                                         )
        | SOME (OPT_CHANGE_DIRECTORY x, args) => (case #change_directory opts of
                                                      NONE => parse ({ opts where change_directory = SOME x }, args)
                                                    | SOME _ => showMessageAndFail "multiple --change-directory options"
                                                 )
        | SOME (OPT_INCLUDEONLY x, args) => (case #includeonly opts of
                                                 NONE => parse ({ opts where includeonly = SOME x }, args)
                                               | SOME _ => showMessageAndFail "multiple --includeonly options"
                                            )
        | SOME (OPT_MAKE_DEPENDS x, args) => (case #make_depends opts of
                                                  NONE => parse ({ opts where make_depends = SOME x }, args)
                                                | SOME _ => showMessageAndFail "multiple --make-depends options"
                                             )
        | SOME (OPT_PRINT_OUTPUT_DIRECTORY, args) => (case #print_output_directory opts of
                                                          false => parse ({ opts where print_output_directory = true }, args)
                                                        | true => showMessageAndFail "multiple --print-output-directory options"
                                                     )
        | SOME (OPT_PACKAGE_SUPPORT s, args) => let val packages = String.tokens (fn c => c = #"," orelse Char.isSpace c) s
                                                    val ps = List.foldl (fn ("minted", ps) => { ps where minted = true }
                                                                        | ("epstopdf", ps) => { ps where epstopdf = true }
                                                                        | (pkg, ps) => ( if Message.getVerbosity () >= 1 then
                                                                                             Message.warn ("ClutTeX provides no special support for '" ^ pkg ^ "'.")
                                                                                         else
                                                                                             ()
                                                                                       ; ps
                                                                                       )
                                                                        ) (#package_support opts) packages
                                                in parse ({ opts where package_support = ps }, args)
                                                end
        | SOME (OPT_CHECK_DRIVER driver, args) => (case #check_driver opts of
                                                       NONE => (case DviDriver.fromString driver of
                                                                    SOME driver => parse ({ opts where check_driver = SOME driver }, args)
                                                                  | NONE => showMessageAndFail "invalid value for --check-driver option"
                                                               )
                                                     | SOME _ => showMessageAndFail "multiple --check-driver options"
                                                  )
        | SOME (OPT_SYNCTEX x, args) => (case #synctex opts of
                                             NONE => parse ({ opts where synctex = SOME x }, args)
                                           | SOME _ => showMessageAndFail "multiple --synctex options"
                                        )
        | SOME (OPT_FILE_LINE_ERROR x, args) => parse ({ opts where file_line_error = x }, args)
        | SOME (OPT_INTERACTION x, args) => (case #interaction opts of
                                                 NONE => (case InteractionMode.fromString x of
                                                              SOME interaction => parse ({ opts where interaction = SOME interaction }, args)
                                                            | NONE => showMessageAndFail "invalid argument for --interaction"
                                                         )
                                               | SOME _ => showMessageAndFail "multiple --interaction options"
                                            )
        | SOME (OPT_HALT_ON_ERROR x, args) => parse ({ opts where halt_on_error = x }, args)
        | SOME (OPT_SHELL_ESCAPE se, args) => (case #shell_escape opts of
                                                   NONE => parse ({ opts where shell_escape = SOME se }, args)
                                                 | SOME _ => showMessageAndFail "multiple --(no-)shell-escape / --shell-restricted options"
                                              )
        | SOME (OPT_JOBNAME x, args) => (case #jobname opts of
                                             NONE => parse ({ opts where jobname = SOME x }, args)
                                           | SOME _ => showMessageAndFail "multiple --jobname options"
                                        )
        | SOME (OPT_FMT x, args) => (case #fmt opts of
                                         NONE => parse ({ opts where fmt = SOME x }, args)
                                       | SOME _ => showMessageAndFail "multiple --fmt options"
                                    )
        | SOME (OPT_OUTPUT_DIRECTORY x, args) => (case #output_directory opts of
                                                      NONE => parse ({ opts where output_directory = SOME x }, args)
                                                    | SOME _ => showMessageAndFail "multiple --output-directory options"
                                                 )
        | SOME (OPT_OUTPUT_FORMAT format, args) => (case #output_format opts of
                                                        NONE => (case OutputFormat.fromString format of
                                                                     SOME format => parse ({ opts where output_format = SOME format }, args)
                                                                   | NONE => showMessageAndFail "invalid value for --output-format option"
                                                                )
                                                      | SOME _ => showMessageAndFail "multiple --output-format options"
                                                   )
        | SOME (OPT_TEX_OPTION x, args) => let val x = ShellUtil.escape x
                                           in parse ({ opts where tex_extraoptions = x :: #tex_extraoptions opts }, args)
                                           end
        | SOME (OPT_TEX_OPTIONS x, args) => parse ({ opts where tex_extraoptions = x :: #tex_extraoptions opts }, args)
        | SOME (OPT_DVIPDFMX_OPTION x, args) => let val x = ShellUtil.escape x
                                                in parse ({ opts where dvipdfmx_extraoptions = x :: #dvipdfmx_extraoptions opts }, args)
                                                end
        | SOME (OPT_DVIPDFMX_OPTIONS x, args) => parse ({ opts where tex_extraoptions = x :: #dvipdfmx_extraoptions opts }, args)
        | SOME (OPT_MAKEINDEX x, args) => (case #makeindex opts of
                                               NONE => parse ({ opts where makeindex = SOME x }, args)
                                             | SOME _ => showMessageAndFail "multiple --makeindex options"
                                          )
        | SOME (OPT_BIBTEX x, args) => (case #bibtex_or_biber opts of
                                            NONE => parse ({ opts where bibtex_or_biber = SOME (BIBTEX x) }, args)
                                          | SOME _ => showMessageAndFail "multiple --bibtex / --biber options"
                                       )
        | SOME (OPT_BIBER x, args) => (case #bibtex_or_biber opts of
                                           NONE => parse ({ opts where bibtex_or_biber = SOME (BIBER x) }, args)
                                         | SOME _ => showMessageAndFail "multiple --bibtex / --biber options"
                                      )
        | SOME (OPT_MAKEGLOSSARIES x, args) => (case #makeglossaries opts of
                                                    NONE => parse ({ opts where makeglossaries = SOME x }, args)
                                                  | SOME _ => showMessageAndFail "multiple --makeglossaries options"
                                               )
        | SOME (OPT_CONFIG_FILE x, args) => (case #config_file opts of
                                                 NONE => parse ({ opts where config_file = SOME x }, args)
                                               | SOME _ => showMessageAndFail "multiple --config-file options"
                                            )
        | NONE => (case args of
                       "--" :: args => (opts, args)
                     | arg :: args' =>
                       if String.isPrefix "-" arg then
                           showMessageAndFail ("Unrecognized option: " ^ arg ^ ".\n")
                       else
                           (opts, args)
                     | [] => showUsage () (* showMessageAndFail "No input given. Try --help.\n" *)
                  )
end;
