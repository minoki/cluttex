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
fun showUsage () = (TextIO.output (TextIO.stdErr, "Usage: cluttex\n"); OS.Process.exit OS.Process.failure)
structure HandleOptions = HandleOptions (fun showMessageAndFail message = (TextIO.output (TextIO.stdErr, message ^ "\n"); OS.Process.exit OS.Process.failure)
                                         val showUsage = showUsage
                                         fun showVersion () = (TextIO.output (TextIO.stdErr, "cluttex version x.x\n"); OS.Process.exit OS.Process.failure)
                                        )
val (options, rest) = HandleOptions.parse (AppOptions.init, CommandLine.arguments ());
val () = case #color options of
             NONE => Message.setColors Message.AUTO
           | _ => ()
val inputfile = case rest of
                    [] => showUsage () (* No input file given *)
                  | [input] => input
                  | _ => ( Message.error "Multiple input files are not supported."
                         ; OS.Process.exit OS.Process.failure
                         )
val engine = let val name = case #engine options of
                                SOME name => name
                              | NONE => let val name = CommandLine.name ()
                                            val basename = PathUtil.trimext (PathUtil.basename name)
                                            (* If run as 'cl<engine name>' (e.g. 'cllualatex'), then the default engine is <engine name>. *)
                                        in if String.isPrefix "cl" basename andalso CharVector.all Char.isAlphaNum basename then
                                               String.extract (basename, 2, NONE)
                                           else
                                               ( Message.error "Engine not specified."
                                               ; OS.Process.exit OS.Process.failure
                                               )
                                        end
             in case TeXEngine.get name of
                    SOME engine => engine
                  | NONE => ( Message.error ("Unknown engine name '" ^ name ^ "'.")
                            ; OS.Process.exit OS.Process.failure
                            )
             end
val output_format = Option.getOpt (#output_format options, AppOptions.OutputFormat.PDF)
val check_driver = case output_format of
                       OutputFormat.PDF =>
                       ( case #check_driver options of
                             NONE => ()
                           | SOME _ => ( Message.error ("--check-driver can only be used when the output format is DVI.")
                                       ; OS.Process.exit OS.Process.failure
                                       )
                       ; if #support_pdf_generation engine then
                             if TeXEngine.isLuaTeX engine then
                                 SOME CheckDriver.LUATEX
                             else if TeXEngine.isXeTeX engine then
                                 SOME CheckDriver.XETEX
                             else if TeXEngine.isPdfTeX engine then
                                 SOME CheckDriver.PDFTEX
                             else
                                 ( Message.warn ("Unknown engine: " ^ #name engine)
                                 ; Message.warn "Driver check will not work."
                                 )
                         else
                             (* ClutTeX uses dvipdfmx to generate PDF from DVI output *)
                             SOME CheckDriver.DVIPDFMX
                       )
                     | OutputFormat.DVI =>
                       case #check_driver options of
                           SOME AppOptions.DviDriver.DVIPDFMX => SOME CheckDriver.DVIPDFMX
                         | SOME AppOptions.DviDriver.DVIPS => SOME CheckDriver.DVIPS
                         | SOME AppOptions.DviDriver.DVISVGM => SOME CheckDriver.DVISVGM
                         | NONE => NONE
val (jobname, jobname_for_output) = case #jobname options of
                                        SOME jobname => (jobname, jobname)
                                      | NONE => let val basename = PathUtil.basename (PathUtil.trimext inputfile)
                                                in (SafeName.escapeJobname basename, jobname)
                                                end
val output_extension = case output_format of
                           OutputFormat.DVI => #dvi_extension engine (* "dvi" or "xdv" *)
                         | OutputFormat.PDF => "pdf"
val output = case #output options of
                 NONE => jobname_for_output ^ "." ^ output_extension
               | SOME output => output
val options : AppOptions.options = { engine = engine
                                   , engine_executable = #engine_executable options
                                   , output = #output options
                                   , fresh = #fresh options
                                   , max_iterations = Option.getOpt (#max_iterations options, 3)
                                   , start_with_draft = #start_with_draft options
                                   , watch = #watch options
                                   , change_directory = Option.getOpt (#change_directory options, false)
                                   , includeonly = #includeonly options
                                   , make_depends = #make_depends options
                                   , print_output_directory = #print_output_directory options
                                   , package_support = #package_support options
                                   , check_driver = check_driver
                                   , synctex = #synctex options
                                   , file_line_error = #file_line_error options
                                   , interaction = Option.getOpt (#interaction options, InteractionMode.NONSTOPMODE)
                                   , halt_on_error = #halt_on_error options
                                   , shell_escape = #shell_escape options
                                   , jobname = jobname
                                   , fmt = #fmt options
                                   , output_directory = case #output_directory options of
                                                            SOME dir => dir
                                                          | NONE => 
                                   }
