(* This file is part of ClutTeX. *)
structure Main = struct
val CLUTTEX_VERSION = "v0.6"

exception Abort

(* Workaround for recent Universal CRT *)
val () = Lua.call0 Lua.Lib.os.setlocale #[Lua.fromString "", Lua.fromString "ctype"]

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

fun showUsage () = (TextIO.output (TextIO.stdErr, "Usage: cluttex\n"); OS.Process.exit OS.Process.failure) (* TODO *)
structure HandleOptions = HandleOptions (fun showMessageAndFail message = (TextIO.output (TextIO.stdErr, message ^ "\n"); OS.Process.exit OS.Process.failure)
                                         val showUsage = showUsage
                                         fun showVersion () = (TextIO.output (TextIO.stdErr, "cluttex version x.x\n"); OS.Process.exit OS.Process.failure)
                                        )
fun main () = let val (options, rest) = HandleOptions.parse (AppOptions.init, CommandLine.arguments ());
                  val () = case #color options of
                               NONE => Message.setColors Message.AUTO
                             | _ => ()
                  val inputfile = case rest of
                                      [] => showUsage () (* No input file given *)
                                    | [input] => input
                                    | _ => ( Message.error "Multiple input files are not supported."
                                           ; OS.Process.exit OS.Process.failure
                                           )
                  val engine = case #engine options of
                                   SOME name => (case TeXEngine.get name of
                                                     SOME engine => engine
                                                   | NONE => ( Message.error ("Unknown engine name '" ^ name ^ "'.")
                                                             ; OS.Process.exit OS.Process.failure
                                                             )
                                                )
                                 | NONE => let val name = CommandLine.name ()
                                               val basename = PathUtil.trimext (PathUtil.basename name)
                                               (* If run as 'cl<engine name>' (e.g. 'cllualatex'), then the default engine is <engine name>. *)
                                               fun notSpecified () = ( Message.error "Engine not specified."
                                                                     ; OS.Process.exit OS.Process.failure
                                                                     )
                                           in if String.isPrefix "cl" basename andalso CharVector.all Char.isAlphaNum basename then
                                                  case TeXEngine.get (String.extract (basename, 2, NONE)) of
                                                      NONE => notSpecified ()
                                                    | SOME engine => engine
                                              else
                                                  notSpecified ()
                                           end
                  val output_format = Option.getOpt (#output_format options, OutputFormat.PDF)
                  val check_driver = case output_format of
                                         OutputFormat.PDF =>
                                         ( case #check_driver options of
                                               NONE => ()
                                             | SOME _ => ( Message.error ("--check-driver can only be used when the output format is DVI.")
                                                         ; OS.Process.exit OS.Process.failure
                                                         )
                                         ; if #supports_pdf_generation engine then
                                               if TeXEngine.isLuaTeX engine then
                                                   SOME CheckDriver.LUATEX
                                               else if TeXEngine.isXeTeX engine then
                                                   SOME CheckDriver.XETEX
                                               else if TeXEngine.isPdfTeX engine then
                                                   SOME CheckDriver.PDFTEX
                                               else
                                                   ( Message.warn ("Unknown engine: " ^ #name engine)
                                                   ; Message.warn "Driver check will not work."
                                                   ; NONE
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
                                                                  in (SafeName.escapeJobname basename, basename)
                                                                  end
                  val output_extension = case output_format of
                                             OutputFormat.DVI => #dvi_extension engine (* "dvi" or "xdv" *)
                                           | OutputFormat.PDF => "pdf"
                  val output_from_original_wd = case #output options of
                                                    NONE => jobname_for_output ^ "." ^ output_extension
                                                  | SOME output => output
                  val output_directory_from_original_wd
                      = case #output_directory options of
                            SOME dir => if #fresh options then
                                            ( Message.error "--fresh and --output-directory cannot be used together."
                                            ; OS.Process.exit OS.Process.failure
                                            )
                                        else
                                            dir
                          | NONE => let val inputfile_abs = PathUtil.abspath { path = inputfile, cwd = NONE }
                                        val output_directory = genOutputDirectory [inputfile_abs, jobname, Option.getOpt (#engine_executable options, #executable engine)]
                                    in if not (FSUtil.isDirectory output_directory) then
                                           FSUtil.mkDirRec output_directory
                                       else if #fresh options then
                                           ( if Message.getVerbosity () >= 1 then
                                                 Message.info ("Cleaning '" ^ output_directory ^ "'...")
                                             else
                                                 ()
                                           ; FSUtil.removeRec output_directory
                                           ; OS.FileSys.mkDir output_directory
                                           )
                                       else
                                           ()
                                     ; output_directory
                                    end

                  val () = if #print_output_directory options then
                               ( print (output_directory_from_original_wd ^ "\n")
                               ; OS.Process.exit OS.Process.success
                               )
                           else
                               ()

                  val pathsep = if OSUtil.isWindows then
                                    ";"
                                else
                                    ":"

                  val original_wd = OS.FileSys.getDir ()
                  val (output, output_directory, tex_output_directory)
                      = if Option.getOpt (#change_directory options, false) then
                            let val TEXINPUTS = Option.getOpt (OS.Process.getEnv "TEXINPUTS", "")
                                val LUAINPUTS = Option.getOpt (OS.Process.getEnv "LUAINPUTS", "")
                                val () = OS.FileSys.chDir output_directory_from_original_wd
                                val () = OSUtil.setEnv ("TEXINPUTS", original_wd ^ pathsep ^ TEXINPUTS)
                                val () = OSUtil.setEnv ("LUAINPUTS", original_wd ^ pathsep ^ LUAINPUTS)
                            in (PathUtil.abspath { path = output_from_original_wd, cwd = SOME original_wd }, ".", NONE)
                            end
                        else
                            (output_from_original_wd, output_directory_from_original_wd, SOME output_directory_from_original_wd)
                  val output = case #bibtex_or_biber options of
                                   SOME _ => let val BIBINPUTS = Option.getOpt (OS.Process.getEnv "BIBINPUTS", "")
                                                 val () = OSUtil.setEnv ("BIBINPUTS", original_wd ^ pathsep ^ BIBINPUTS)
                                             in PathUtil.abspath { path = output_from_original_wd, cwd = SOME original_wd } (* Is this needed? *)
                                             end
                                 | NONE => output

                  (*
                   * Set `max_print_line' environment variable if not already set.
                   *
                   * According to texmf.cnf:
                   *   45 < error_line < 255,
                   *   30 < half_error_line < error_line - 15,
                   *   60 <= max_print_line.
                   *
                   * On TeX Live 2023, (u)(p)bibtex fails if max_print_line >= 20000.
                   *)
                  val () = case OS.Process.getEnv "max_print_line" of
                               NONE => OSUtil.setEnv ("max_print_line", "16384")
                             | SOME _ => ()

                  fun pathInOutputDirectory ext = PathUtil.join2 (output_directory, jobname ^ "." ^ ext)

                  val recorderfile = pathInOutputDirectory "fls"
                  val recorderfile2 = pathInOutputDirectory "cluttex-fls"

                  val tex_output_format = case output_format of
                                              OutputFormat.DVI => OutputFormat.DVI
                                            | OutputFormat.PDF => if #supports_pdf_generation engine then
                                                                      OutputFormat.PDF
                                                                  else
                                                                      OutputFormat.DVI

                  (* Setup LuaTeX initialization script *)
                  val lua_initialization_script
                      = if TeXEngine.isLuaTeX engine then
                            let val initscriptfile = pathInOutputDirectory "cluttexinit.lua"
                            in LuaTeXInit.createInitializationScript (initscriptfile, { file_line_error = #file_line_error options, halt_on_error = #halt_on_error options, output_directory = output_directory, jobname = jobname })
                             ; SOME initscriptfile
                            end
                        else
                            NONE
                  val tex_options : TeXEngine.run_options
                      = { engine_executable = #engine_executable options
                        , interaction = SOME (Option.getOpt (#interaction options, InteractionMode.NONSTOPMODE))
                        , file_line_error = #file_line_error options
                        , halt_on_error = #halt_on_error options
                        , synctex = #synctex options
                        , output_directory = tex_output_directory
                        , shell_escape = #shell_escape options
                        , jobname = SOME jobname
                        , fmt = #fmt options
                        , extra_options = #tex_extraoptions options
                        , output_format = tex_output_format
                        , draftmode = false
                        , lua_initialization_script = lua_initialization_script
                        }

                  fun executeCommand (command, recover)
                      = let val () = Message.exec command
                            val status = OS.Process.system command
                            val success_or_recoverd = if OS.Process.isSuccess status then
                                                          true
                                                      else
                                                          case recover of
                                                              SOME f => f ()
                                                            | NONE => false
                        in if success_or_recoverd then
                               ()
                           else
                               ( Message.error "Command exit abnormally" (* TODO: show status code: Unix.fromStatus *)
                               ; raise Abort
                               )
                        end

                  fun singleRun (auxstatus, iteration)
                      = let val () = ()
                        in ()
                        end

              in ()
              end
end;
val () = Main.main ();
