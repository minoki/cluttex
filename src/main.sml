(* This file is part of ClutTeX. *)
structure Main = struct
val CLUTTEX_VERSION = "v0.7.0"

val COPYRIGHT_NOTICE =
"Copyright (C) 2016-2024  ARATA Mizuki\n\
\\n\
\This program is free software: you can redistribute it and/or modify\n\
\it under the terms of the GNU General Public License as published by\n\
\the Free Software Foundation, either version 3 of the License, or\n\
\(at your option) any later version.\n\
\\n\
\This program is distributed in the hope that it will be useful,\n\
\but WITHOUT ANY WARRANTY; without even the implied warranty of\n\
\MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n\
\GNU General Public License for more details.\n\
\\n\
\You should have received a copy of the GNU General Public License\n\
\along with this program.  If not, see <http://www.gnu.org/licenses/>.\n";

exception Abort

(* Workaround for recent Universal CRT *)
val () = Lua.call0 Lua.Lib.os.setlocale #[Lua.fromString "", Lua.fromString "ctype"]

fun getEnvMulti [] = NONE
  | getEnvMulti (name :: xs) = case OS.Process.getEnv name of
                                   SOME x => SOME x
                                 | NONE => getEnvMulti xs

fun genOutputDirectory (temporary_directory : string option, xs : string list)
    = let val message = String.concatWith "\000" xs
          val hash = MD5.md5AsLowerHex (Byte.stringToBytes message)
          val tmpdir = case temporary_directory of
                           SOME tmpdir => tmpdir
                         | NONE => case getEnvMulti ["TMPDIR", "TMP", "TEMP"] of
                                       SOME tmpdir => tmpdir
                                     | NONE => case getEnvMulti ["HOME", "USERPROFILE"] of
                                                   SOME home => OS.Path.joinDirFile { dir = home, file = ".latex-build-temp" } (* $XDG_CACHE_HOME/cluttex, $HOME/.cache/cluttex *)
                                                 | NONE => raise Fail "environment variable 'TMPDIR' not set!"
      in OS.Path.joinDirFile { dir = tmpdir, file = "cluttex-" ^ hash }
      end

fun showUsage () = let val progName = CommandLine.name ()
                   in TextIO.output (TextIO.stdErr,
"ClutTeX: Process TeX files without cluttering your working directory\n\
\\n\
\Usage:\n\
\  " ^ progName ^ " [options] [--] FILE.tex\n\
\\n\
\Options:\n\
\  -e, --engine=ENGINE          Specify which TeX engine to use.\n\
\                                 ENGINE is one of the following:\n\
\                                     pdflatex, pdftex,\n\
\                                     lualatex, luatex, luajittex,\n\
\                                     xelatex, xetex, latex, etex, tex,\n\
\                                     platex, eptex, ptex,\n\
\                                     uplatex, euptex, uptex,\n\
\      --engine-executable=COMMAND+OPTIONs\n\
\                               The actual TeX command to use.\n\
\                                 [default: ENGINE]\n\
\  -o, --output=FILE            The name of output file.\n\
\                                 [default: JOBNAME.pdf or JOBNAME.dvi]\n\
\      --fresh                  Clean intermediate files before running TeX.\n\
\                                 Cannot be used with --output-directory.\n\
\      --max-iterations=N       Maximum number of running TeX to resolve\n\
\                                 cross-references.  [default: 3]\n\
\      --start-with-draft       Start with draft mode.\n\
\      --[no-]change-directory  Change directory before running TeX.\n\
\      --watch[=ENGINE]         Watch input files for change.  Requires fswatch\n\
\                                 or inotifywait to be installed. ENGINE is one of\n\
\                                 `fswatch', `inotifywait' or `auto' [default: `auto']\n\
\      --tex-option=OPTION      Pass OPTION to TeX as a single option.\n\
\      --tex-options=OPTIONs    Pass OPTIONs to TeX as multiple options.\n\
\      --dvipdfmx-option[s]=OPTION[s]  Same for dvipdfmx.\n\
\      --makeindex=COMMAND+OPTIONs  Command to generate index, such as\n\
\                                     `makeindex' or `mendex'.\n\
\      --bibtex=COMMAND+OPTIONs     Command for BibTeX, such as\n\
\                                     `bibtex' or `pbibtex'.\n\
\      --biber[=COMMAND+OPTIONs]    Command for Biber.\n\
\      --makeglossaries[=COMMAND+OPTIONs]  Command for makeglossaries.\n\
\  -h, --help                   Print this message and exit.\n\
\  -v, --version                Print version information and exit.\n\
\  -V, --verbose                Be more verbose.\n\
\      --color[=WHEN]           Make ClutTeX's message colorful. WHEN is one of\n\
\                                 `always', `auto', or `never'.\n\
\                                 [default: `auto' if --color is omitted,\n\
\                                           `always' if WHEN is omitted]\n\
\      --includeonly=NAMEs      Insert '\\includeonly{NAMEs}'.\n\
\      --make-depends=FILE      Write dependencies as a Makefile rule.\n\
\      --print-output-directory  Print the output directory and exit.\n\
\      --package-support=PKG1[,PKG2,...]\n\
\                               Enable special support for some shell-escaping\n\
\                                 packages.\n\
\                               Currently supported: minted, epstopdf\n\
\      --check-driver=DRIVER    Check that the correct driver file is loaded.\n\
\                               DRIVER is one of `dvipdfmx', `dvips', `dvisvgm'.\n\
\\n\
\      --[no-]shell-escape\n\
\      --shell-restricted\n\
\      --synctex=NUMBER\n\
\      --fmt=FMTNAME\n\
\      --[no-]file-line-error   [default: yes]\n\
\      --[no-]halt-on-error     [default: yes]\n\
\      --interaction=STRING     [default: nonstopmode]\n\
\      --jobname=STRING\n\
\      --output-directory=DIR   [default: somewhere in the temporary directory]\n\
\      --output-format=FORMAT   FORMAT is `pdf' or `dvi'.  [default: pdf]\n\
\\n" ^ COPYRIGHT_NOTICE)
                    ; OS.Process.exit OS.Process.success
                   end

structure HandleOptions = HandleOptions (fun showMessageAndFail message = (TextIO.output (TextIO.stdErr, message ^ "\n"); OS.Process.exit OS.Process.failure)
                                         val showUsage = showUsage
                                         fun showVersion () = (TextIO.output (TextIO.stdErr, "cluttex " ^ CLUTTEX_VERSION ^ "\n"); OS.Process.exit OS.Process.success)
                                        )

(*: val pathInOutputDirectory : AppOptions.options * string -> string *)
fun pathInOutputDirectory (options : AppOptions.options, ext) = PathUtil.join2 (#output_directory options, #jobname options ^ "." ^ ext)
(*: val executeCommand : string * (unit -> bool) option -> unit *)
(*
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
             ( Message.error "Command exited abnormally" (* TODO: show status code: Unix.fromStatus *)
             ; raise Abort
             )
      end
*)
fun executeCommand (command, recover)
    = let val () = Message.exec command
          val (success, termination, status_or_signal) = Lua.call3 Lua.Lib.os.execute #[Lua.fromString command]
          val (success, termination, status_or_signal) : bool * string option * Lua.value
              = if Lua.typeof success = "number" then (* Lua 5.1 or LuaTeX *)
                    (Lua.== (success, Lua.fromInt 0), NONE, success)
                else
                    (Lua.unsafeFromValue success, SOME (Lua.unsafeFromValue termination), status_or_signal)
          val success_or_recovered = success orelse (case recover of
                                                         SOME f => f ()
                                                       | NONE => false
                                                    )
      in if success_or_recovered then
             ()
         else
             ( case termination of
                   SOME "exit" => Message.error ("Command exited abnormally: exit status " ^ Lua.unsafeFromValue (Lua.call1 Lua.Lib.tostring #[status_or_signal]))
                 | SOME "signal" => Message.error ("Command exited abnormally: signal " ^ Lua.unsafeFromValue (Lua.call1 Lua.Lib.tostring #[status_or_signal]))
                 | _ => Message.error ("Command exited abnormally: " ^ Lua.unsafeFromValue (Lua.call1 Lua.Lib.tostring #[status_or_signal]))
             ; raise Abort
             )
      end

type run_params = { options : AppOptions.options
                  , inputfile : string
                  , engine : TeXEngine.engine
                  , tex_options : TeXEngine.run_options
                  , recorderfile : string
                  , recorderfile2 : string
                  , original_wd : string
                  , output_extension : string
                  }
datatype single_run_result = SHOULD_RERUN of Reruncheck.aux_status StringMap.map
                           | NO_NEED_TO_RERUN
                           | NO_PAGES_OF_OUTPUT

(* Run TeX command ( *tex, *latex) *)
(*: val singleRun : run_params * Reruncheck.aux_status StringMap.map * int -> single_run_result *)
fun singleRun ({ options, inputfile, engine, tex_options, recorderfile, recorderfile2, original_wd, ... } : run_params, auxstatus, iteration)
    = let val mainauxfile = pathInOutputDirectory (options, "aux")
          val { auxstatus, minted, epstopdf, bibtex_aux_hash }
              = if FSUtil.isFile recorderfile then
                    (* Recorder file already exists *)
                    let val recorded = Reruncheck.parseRecorderFile { file = recorderfile, options = options }
                        val recorded = if TeXEngine.isLuaTeX engine andalso FSUtil.isFile recorderfile2 then
                                           Reruncheck.parseRecorderFileContinued { file = recorderfile2, options = options, previousResult = recorded }
                                       else
                                           recorded
                        val (filelist, filemap) = Reruncheck.getFileInfo recorded
                        val auxstatus = Reruncheck.collectFileInfo (filelist, auxstatus)
                        val { minted, epstopdf } = List.foldl (fn ({ path, ... }, { minted, epstopdf }) =>
                                                                  { minted = minted orelse String.isSuffix "minted/minted.sty" path
                                                                  , epstopdf = epstopdf orelse String.isSuffix "epstopdf.sty" path
                                                                  }
                                                              ) { minted = false, epstopdf = false } filelist
                        val bibtex_aux_hash = case #bibtex_or_biber options of
                                                  SOME (AppOptions.BIBTEX _) =>
                                                  let val biblines = AuxFile.extractBibTeXLines { auxfile = mainauxfile, outdir = #output_directory options }
                                                  in SOME (MD5.compute (Byte.stringToBytes (String.concatWith "\n" biblines)))
                                                  end
                                                | _ => NONE
                    in { auxstatus, minted, epstopdf, bibtex_aux_hash }
                    end
                else
                    (* This is the first execution *)
                    if StringMap.isEmpty auxstatus then
                        { auxstatus = StringMap.empty, minted = false, epstopdf = false, bibtex_aux_hash = NONE }
                    else
                        ( Message.error "Recorder file was not generated during the execution!"
                        ; raise Abort
                        )
          val tex_injection = case #includeonly options of
                                  SOME io => "\\includeonly{" ^ io ^ "}"
                                | NONE => ""
          val tex_injection = if minted orelse #minted (#package_support options) then
                                  let val () = if not (#minted (#package_support options)) then
                                                   Message.diag "You may want to use --package-support=minted option."
                                               else
                                                   ()
                                      val outdir = #output_directory options
                                      val outdir = if OSUtil.isWindows then
                                                       String.map (fn #"\\" => #"/" | c => c) outdir (* Use forward slashes *)
                                                   else
                                                       outdir
                                  in tex_injection ^ "\\PassOptionsToPackage{outputdir=" ^ outdir ^ "}{minted}"
                                  end
                              else
                                  tex_injection
          val tex_injection = if epstopdf orelse #epstopdf (#package_support options) then
                                  let val () = if not (#epstopdf (#package_support options)) then
                                                   Message.diag "You may want to use --package-support=epstopdf option."
                                               else
                                                   ()
                                      val outdir = #output_directory options
                                      val outdir = if OSUtil.isWindows then
                                                       String.map (fn #"\\" => #"/" | c => c) outdir (* Use forward slashes *)
                                                   else
                                                       outdir
                                      val outdir = if String.isSuffix "/" outdir then
                                                       outdir
                                                   else
                                                       outdir ^ "/" (* Must end with a directory separator *)
                                  in tex_injection ^ "\\PassOptionsToPackage{outdir=" ^ outdir ^ "}{epstopdf}"
                                  end
                              else
                                  tex_injection
          val inputline = tex_injection ^ SafeName.safeInput { name = inputfile, isPdfTeX = TeXEngine.isPdfTeX engine }
          val (current_tex_options, lightweight_mode)
              = if iteration = 1 andalso #start_with_draft options then
                    if #supports_draftmode engine then
                        ({ tex_options where draftmode = true, interaction = SOME InteractionMode.BATCHMODE }, true)
                    else
                        ({ tex_options where interaction = SOME InteractionMode.BATCHMODE }, true)
                else
                    ({ tex_options where draftmode = false }, false)
          val command = TeXEngine.buildCommand (engine, inputline, current_tex_options)
          val execlogCache = ref NONE
          fun getExecLog () = case !execlogCache of
                                  NONE => let val ins = TextIO.openIn (pathInOutputDirectory (options, "log"))
                                              val log = TextIO.inputAll ins
                                              val () = TextIO.closeIn ins
                                          in execlogCache := SOME log
                                           ; log
                                          end
                                | SOME log => log
          val recovered = ref false
          fun recover () = let val execlog = getExecLog ()
                               val r = Recovery.tryRecovery { options = options, execlog = execlog, auxfile = pathInOutputDirectory (options, "aux"), originalWorkingDirectory = original_wd }
                           in recovered := true
                            ; r
                           end
          val () = executeCommand (command, SOME recover)
      in if !recovered then
             SHOULD_RERUN StringMap.empty
         else
             let val recorded = Reruncheck.parseRecorderFile { file = recorderfile, options = options }
                 val recorded = if TeXEngine.isLuaTeX engine andalso FSUtil.isFile recorderfile2 then
                                    Reruncheck.parseRecorderFileContinued { file = recorderfile2, options = options, previousResult = recorded }
                                else
                                    recorded
                 val (filelist, filemap) = Reruncheck.getFileInfo recorded
                 val execlog = getExecLog ()

                 (* Check driver *)
                 val () = case #check_driver options of
                              NONE => ()
                            | SOME driver => CheckDriver.checkDriver (driver, List.map (fn { path, abspath, kind } => { path = path, kind = case kind of Reruncheck.INPUT => "input" | Reruncheck.OUTPUT => "output" | Reruncheck.AUXILIARY => "auxiliary"}) filelist)

                 (* makeindex *)
                 val filelist = case #makeindex options of
                                    NONE => (* Check log file *)
                                    ( if Lua.isFalsy (Lua.call1 Lua.Lib.string.find #[Lua.fromString execlog, Lua.fromString "No file [^\n]+%.ind%."]) then
                                          ()
                                      else
                                          Message.diag "You may want to use --makeindex option."
                                    ; filelist
                                    )
                                  | SOME makeindex =>
                                    let fun go (file, filelist_acc) (* Look for .idx files and run MakeIndex *)
                                            = if PathUtil.ext (#path file) = "idx" then
                                                  (* Run makeindex if the .idx file is new or updated *)
                                                  let val idxfileinfo = { path = #path file, abspath = #abspath file, kind = Reruncheck.AUXILIARY }
                                                      val output_ind = PathUtil.replaceext { path = #abspath file, newext = "ind" }
                                                  in if #1 (Reruncheck.compareFileInfo ([idxfileinfo], auxstatus)) orelse Reruncheck.compareFileTime { srcAbs = #abspath file, dst = output_ind, auxstatus = auxstatus } then
                                                         let val idx_dir = PathUtil.dirname (#abspath file)
                                                             val makeindex_command = [
                                                                 "cd", ShellUtil.escape idx_dir, "&&",
                                                                 makeindex, (* Do not escape `makeindex` to allow additional options *)
                                                                 "-o", PathUtil.basename output_ind,
                                                                 PathUtil.basename (#abspath file)
                                                             ]
                                                         in executeCommand (String.concatWith " " makeindex_command, NONE)
                                                          ; { path = output_ind, abspath = output_ind, kind = Reruncheck.AUXILIARY } :: filelist_acc
                                                         end
                                                     else
                                                         ( FSUtil.touch output_ind handle Lua.Error err => Message.warn ("Failed to touch " ^ output_ind ^ " (" ^ Lua.unsafeFromValue err ^ ")")
                                                         ; filelist_acc
                                                         )
                                                  end
                                              else
                                                  filelist_acc
                                    in List.foldl go filelist filelist
                                    end

                 (* makeglossaries *)
                 val filelist = case #makeglossaries options of
                                    NONE => (* Check log file *)
                                    ( if Lua.isFalsy (Lua.call1 Lua.Lib.string.find #[Lua.fromString execlog, Lua.fromString "No file [^\n]+%.gls%."]) then
                                          ()
                                      else
                                          Message.diag "You may want to use --makeglossaries option."
                                    ; filelist
                                    )
                                  | SOME makeglossaries =>
                                    let fun go (file, filelist_acc) (* Look for .glo files and run makeglossaries *)
                                            = if PathUtil.ext (#path file) = "glo" then
                                                  (* Run makeglossaries if the .glo file is new or updated *)
                                                  let val glofileinfo = { path = #path file, abspath = #abspath file, kind = Reruncheck.AUXILIARY }
                                                      val output_gls = PathUtil.replaceext { path = #abspath file, newext = "gls" }
                                                  in if #1 (Reruncheck.compareFileInfo ([glofileinfo], auxstatus)) orelse Reruncheck.compareFileTime { srcAbs = #abspath file, dst = output_gls, auxstatus = auxstatus } then
                                                         let val makeglossaries_command = [
                                                                 makeglossaries,
                                                                 "-d", ShellUtil.escape (#output_directory options),
                                                                 PathUtil.trimext (PathUtil.basename (#path file))
                                                             ]
                                                         in executeCommand (String.concatWith " " makeglossaries_command, NONE)
                                                          ; { path = output_gls, abspath = output_gls, kind = Reruncheck.AUXILIARY } :: filelist_acc
                                                         end
                                                     else
                                                         ( FSUtil.touch output_gls handle Lua.Error err => Message.warn ("Failed to touch " ^ output_gls ^ " (" ^ Lua.unsafeFromValue err ^ ")")
                                                         ; filelist_acc
                                                         )
                                                  end
                                              else
                                                  filelist_acc
                                    in List.foldl go filelist filelist
                                    end

                 (* bibtex/biber *)
                 val filelist = case #bibtex_or_biber options of
                                    NONE => ( if Lua.isFalsy (Lua.call1 Lua.Lib.string.find #[Lua.fromString execlog, Lua.fromString "No file [^\n]+%.bbl%."]) then
                                                  ()
                                              else
                                                  Message.diag "You may want to use --bibtex or biber option."
                                            ; filelist
                                            )
                                  | SOME (AppOptions.BIBTEX bibtex) =>
                                    let val biblines2 = AuxFile.extractBibTeXLines { auxfile = mainauxfile, outdir = #output_directory options }
                                        val bibtex_aux_hash2 = if List.null biblines2 then
                                                                   NONE
                                                               else
                                                                   SOME (MD5.compute (Byte.stringToBytes (String.concatWith "\n" biblines2)))
                                        val output_bbl = pathInOutputDirectory (options, "bbl")
                                    in if bibtex_aux_hash <> bibtex_aux_hash2 orelse Reruncheck.compareFileTime { srcAbs = PathUtil.abspath { path = mainauxfile, cwd = NONE }, dst = output_bbl, auxstatus = auxstatus } then
                                           (* The input for BibTeX command has changed... *)
                                           let val bibtex_command = [
                                                   "cd", ShellUtil.escape (#output_directory options), "&&",
                                                   bibtex,
                                                   PathUtil.basename mainauxfile
                                               ]
                                           in executeCommand (String.concatWith " " bibtex_command, NONE)
                                           end
                                       else
                                           ( if Message.getVerbosity () >= 1 then
                                                 Message.info "No need to run BibTeX."
                                             else
                                                 ()
                                           ; FSUtil.touch output_bbl handle Lua.Error err => Message.warn ("Failed to touch " ^ output_bbl ^ " (" ^ Lua.unsafeFromValue err ^ ")")
                                           )
                                     ; filelist
                                    end
                            | SOME (AppOptions.BIBER biber) =>
                              let fun go (file, filelist_acc)
                                      (* Usual compilation with biber
                                       * tex     -> pdflatex tex -> aux,bcf,pdf,run.xml
                                       * bcf     -> biber bcf    -> bbl
                                       * tex,bbl -> pdflatex tex -> aux,bcf,pdf,run.xml
                                       *)
                                      = if PathUtil.ext (#path file) = "bcf" then
                                            (* Run biber if the .bcf file is new or updated *)
                                            let val bcffileinfo = { path = #path file, abspath = #abspath file, kind = Reruncheck.AUXILIARY }
                                                val output_bbl = PathUtil.replaceext { path = #abspath file, newext = "bbl" }
                                                fun check_bib_update abspath
                                                    = let val ins = TextIO.openIn abspath
                                                          fun go updated_dot_bib
                                                              = case TextIO.inputLine ins of
                                                                    NONE => updated_dot_bib
                                                                  | SOME l =>
                                                                    let val bib = Lua.call1 Lua.Lib.string.match #[Lua.fromString l, Lua.fromString "<bcf:datasource .*>(.*)</bcf:datasource>"]
                                                                    in if Lua.isFalsy bib then
                                                                           go updated_dot_bib (* continue *)
                                                                       else
                                                                           let val bib = Lua.unsafeFromValue bib : string
                                                                               val bibfile = PathUtil.join2 (original_wd, bib)
                                                                               val updated_dot_bib = if FSUtil.isFile bibfile then
                                                                                                         let val updated_dot_bib_tmp = not (Reruncheck.compareFileTime { srcAbs = PathUtil.abspath { path = mainauxfile, cwd = NONE }, dst = bibfile, auxstatus = auxstatus })
                                                                                                         in if updated_dot_bib_tmp then
                                                                                                                Message.info (bibfile ^ " is newer than aux")
                                                                                                            else
                                                                                                                ()
                                                                                                          ; updated_dot_bib orelse updated_dot_bib_tmp
                                                                                                         end
                                                                                                     else
                                                                                                         ( Message.warn (bibfile ^ " is not accessible")
                                                                                                         ; updated_dot_bib
                                                                                                         )
                                                                           in go updated_dot_bib
                                                                           end
                                                                    end
                                                      in go false before TextIO.closeIn ins
                                                      end
                                                val updated_dot_bib = check_bib_update (#abspath file)
                                            in if updated_dot_bib orelse #1 (Reruncheck.compareFileInfo ([bcffileinfo], auxstatus)) orelse Reruncheck.compareFileTime { srcAbs = #abspath file, dst = output_bbl, auxstatus = auxstatus } then
                                                   let val biber_command = [
                                                           biber, (* Do not escape `biber` to allow additional options *)
                                                           "--output-directory", ShellUtil.escape (#output_directory options),
                                                           PathUtil.basename (#abspath file)
                                                       ]
                                                   in executeCommand (String.concatWith " " biber_command, NONE)
                                                    ; { path = output_bbl, abspath = output_bbl, kind = Reruncheck.AUXILIARY } :: filelist
                                                   end
                                               else
                                                   ( FSUtil.touch output_bbl handle Lua.Error err => Message.warn ("Failed to touch " ^ output_bbl ^ " (" ^ Lua.unsafeFromValue err ^ ")")
                                                   ; filelist_acc
                                                   )
                                            end
                                        else
                                            filelist_acc
                              in List.foldl go filelist filelist
                              end

             in if String.isSubstring "No pages of output." execlog then
                    NO_PAGES_OF_OUTPUT
                else
                    let val (should_rerun, auxstatus) = Reruncheck.compareFileInfo (filelist, auxstatus)
                    in if should_rerun orelse lightweight_mode then
                           SHOULD_RERUN auxstatus
                       else
                           NO_NEED_TO_RERUN
                    end
             end
      end

(* Run (La)TeX (possibly multiple times) and produce a PDF/DVI file. *)
(*: val doTypeset : run_params -> unit *)
fun doTypeset (run_params as { options, engine, output_extension, recorderfile, recorderfile2, ... } : run_params)
    = let fun loop (iteration, auxstatus)
              = let val iteration = iteration + 1
                in case singleRun (run_params, auxstatus, iteration) of
                       NO_PAGES_OF_OUTPUT => ( Message.warn "No pages of output."
                                             ; false
                                             )
                     | NO_NEED_TO_RERUN => true
                     | SHOULD_RERUN auxstatus => if iteration >= #max_iterations options then
                                                     ( Message.warn "LaTeX should be run once more."
                                                     ; true
                                                     )
                                                 else
                                                     loop (iteration, auxstatus)
                end
      in if loop (0, StringMap.empty) then
             (* Successful *)
             ( if #output_format options = OutputFormat.DVI orelse #supports_pdf_generation engine then
                   (* Output file (DVI/PDF) is generated in the output directory *)
                   let val outfile = pathInOutputDirectory (options, output_extension)
                       val onCopyError = if OSUtil.isWindows then
                                             SOME (fn () => let val output_format = case #output_format options of
                                                                                        OutputFormat.DVI => "DVI"
                                                                                      | OutputFormat.PDF => "PDF"
                                                            in Message.error ("Failed to copy file.  Some applications may be locking the " ^ output_format ^ " file.")
                                                             ; false
                                                            end
                                                  )
                                         else
                                             NONE
                   in executeCommand (FSUtil.copyCommand { from = outfile, to = #output options }, onCopyError)
                    ; if List.null (#dvipdfmx_extraoptions options) then
                          ()
                      else
                          Message.warn "--dvipdfmx-option[s] are ignored."
                   end
               else
                   (* DVI file is generated, but PDF file is wanted *)
                   let val dvifile = pathInOutputDirectory (options, "dvi")
                       val dvipdfmx_command = "dvipdfmx" :: "-o" :: ShellUtil.escape (#output options) :: #dvipdfmx_extraoptions options @ [ShellUtil.escape dvifile]
                   in executeCommand (String.concatWith " " dvipdfmx_command, NONE)
                   end
             ; (* Copy SyncTeX file if necessary *)
               if #output_format options = OutputFormat.PDF then
                   let val synctex = Lua.unsafeFromValue (Lua.call1 Lua.Lib.tonumber #[Lua.fromString (Option.getOpt (#synctex options, "0"))]) : int
                       val synctex_ext = if synctex > 0 then
                                             (* Compressed SyncTeX file (.synctex.gz) *)
                                             SOME "synctex.gz"
                                         else if synctex < 0 then
                                             (* Uncompressed SyncTeX file (.synctex) *)
                                             SOME "synctex"
                                         else
                                             NONE
                   in case synctex_ext of
                          SOME ext => executeCommand (FSUtil.copyCommand { from = pathInOutputDirectory (options, ext), to = PathUtil.replaceext { path = #output options, newext = ext } }, NONE)
                        | NONE => ()
                   end
               else
                   ()
             ; (* Write dependencies file *)
               case #make_depends options of
                   SOME make_depends =>
                   let val recorded = Reruncheck.parseRecorderFile { file = recorderfile, options = options }
                       val recorded = if TeXEngine.isLuaTeX engine andalso FSUtil.isFile recorderfile2 then
                                          Reruncheck.parseRecorderFileContinued { file = recorderfile2, options = options, previousResult = recorded }
                                      else
                                          recorded
                       val (filelist, _) = Reruncheck.getFileInfo recorded
                       val outs = TextIO.openOut make_depends
                   in TextIO.output (outs, #output options ^ ":") (* TODO: quote *)
                    ; List.app (fn { path, abspath = _, kind = Reruncheck.INPUT } => TextIO.output (outs, " " ^ path) (* TODO: quote *)
                               | _ => ()) filelist
                    ; TextIO.output (outs, "\n")
                    ; TextIO.closeOut outs
                   end
                 | NONE => ()
             ; (* Successful *)
               if Message.getVerbosity () >= 1 then
                   Message.info "Command exited successfully"
               else
                   ()
             )
         else
             (* No pages of output. *)
             ()
      end

(*: val doWatchWindows : Lua.value -> string list -> bool *)
fun doWatchWindows fswatcherlib files
    = let val watcher = Lua.call1 Lua.Lib.assert (Lua.call (Lua.field (fswatcherlib, "new")) #[])
          val () = List.app (fn file => Lua.call0 Lua.Lib.assert (Lua.method (watcher, "add") #[Lua.fromString file])) files
          val result = Lua.call1 Lua.Lib.assert (Lua.method (watcher, "next") #[])
          val () = if Message.getVerbosity () >= 2 then
                       Message.info (Lua.unsafeFromValue (Lua.field (result, "action")) ^ " " ^ Lua.unsafeFromValue (Lua.field (result, "path")))
                   else
                       ()
          val () = Lua.method0 (watcher, "close") #[]
      in true
      end

(*: val doWatchFswatch : string list -> bool *)
fun doWatchFswatch files
    = let val fswatch_command = "fswatch" :: "--one-event" :: "--event=Updated" :: "--" :: List.map ShellUtil.escape files
          val fswatch_command_str = String.concatWith " " fswatch_command
          val () = if Message.getVerbosity () >= 1 then
                       Message.exec fswatch_command_str
                   else
                       ()
          val fswatch = Lua.call1 Lua.Lib.assert (Lua.call Lua.Lib.io.popen #[Lua.fromString fswatch_command_str, Lua.fromString "r"])
          val readLine = Lua.method1 (fswatch, "lines") #[]
          fun go () = let val l = Lua.call1 readLine #[]
                      in if Lua.isFalsy l then
                             false
                         else if List.exists (fn path => Lua.unsafeFromValue l = path) files then
                             true
                         else
                             go ()
                      end
      in go () before Lua.method0 (fswatch, "close") #[]
      end

(*: val doWatchInotifywait : string list -> bool *)
fun doWatchInotifywait files
    = let val inotifywait_command = "inotifywait" :: "--event=modify" :: "--event=attrib" :: "--format=%w" :: "--quiet" :: List.map ShellUtil.escape files
          val inotifywait_command_str = String.concatWith " " inotifywait_command
          val () = if Message.getVerbosity () >= 1 then
                       Message.exec inotifywait_command_str
                   else
                       ()
          val inotifywait = Lua.call1 Lua.Lib.assert (Lua.call Lua.Lib.io.popen #[Lua.fromString inotifywait_command_str, Lua.fromString "r"])
          val readLine = Lua.method1 (inotifywait, "lines") #[]
          fun go () = let val l = Lua.call1 readLine #[]
                      in if Lua.isFalsy l then
                             false
                         else if List.exists (fn path => Lua.unsafeFromValue l = path) files then
                             true
                         else
                             go ()
                      end
      in go () before Lua.method0 (inotifywait, "close") #[]
      end

(*: val runWatchMode : AppOptions.WatchEngine.engine * run_params -> unit *)
fun runWatchMode (watch_engine, run_params as { options, engine, recorderfile, recorderfile2, ... } : run_params)
    = let val fswatcherlib = if OSUtil.isWindows then
                                 (* Windows: Try built-in filesystem watcher *)
                                 let val (succ, result) = Lua.call2 Lua.Lib.pcall #[Lua.Lib.require, Lua.fromString "texrunner.fswatcher_windows"]
                                 in if Lua.isFalsy succ then
                                        ( if Message.getVerbosity () >= 1 then
                                              Message.warn ("Failed to load texrunner.fswatcher_windows: " ^ Lua.unsafeFromValue result)
                                          else
                                              ()
                                        ; NONE
                                        )
                                    else
                                        SOME result
                                 end
                             else
                                 NONE
          val doWatch = case fswatcherlib of
                            SOME fswatcherlib =>
                            ( if Message.getVerbosity () >= 2 then
                                  Message.info "Using built-in filesystem watcher for Windows"
                              else
                                  ()
                            ; doWatchWindows fswatcherlib
                            )
                          | NONE => if ShellUtil.hasCommand "fswatch" andalso (watch_engine = AppOptions.WatchEngine.AUTO orelse watch_engine = AppOptions.WatchEngine.AUTO) then
                                        ( if Message.getVerbosity () >= 2 then
                                              Message.info "Using `fswatch' command"
                                          else
                                              ()
                                        ; doWatchFswatch
                                        )
                                    else if ShellUtil.hasCommand "inotifywait" andalso (watch_engine = AppOptions.WatchEngine.AUTO orelse watch_engine = AppOptions.WatchEngine.INOTIFYWAIT) then
                                        ( if Message.getVerbosity () >= 2 then
                                              Message.info "Using `inotifywait' command"
                                          else
                                              ()
                                        ; doWatchInotifywait
                                        )
                                    else
                                        ( case watch_engine of
                                              AppOptions.WatchEngine.AUTO => Message.error "Could not watch files because neither `fswatch' nor `inotifywait' was installed."
                                            | AppOptions.WatchEngine.FSWATCH => Message.error "Could not watch files because your selected engine `fswatch' was not installed."
                                            | AppOptions.WatchEngine.INOTIFYWAIT => Message.error "Could not watch files because your selected engine `inotifywait' was not installed."
                                        ; Message.info "See ClutTeX's manual for details."
                                        ; OS.Process.exit OS.Process.failure
                                        )

          val _ = (doTypeset run_params; true) handle Abort => false
          (* TODO: filenames here can be UTF-8 if command_line_encoding=utf-8 *)
          val recorded = Reruncheck.parseRecorderFile { file = recorderfile, options = options }
          val recorded = if TeXEngine.isLuaTeX engine andalso FSUtil.isFile recorderfile2 then
                             Reruncheck.parseRecorderFileContinued { file = recorderfile2, options = options, previousResult = recorded }
                         else
                             recorded
          val (filelist, _) = Reruncheck.getFileInfo recorded
          val inputFilesToWatch = List.mapPartial (fn { path = _, abspath, kind = Reruncheck.INPUT } => SOME abspath | _ => NONE) filelist
          fun loop inputFilesToWatch
              = if doWatch inputFilesToWatch then
                    let val success = (doTypeset run_params; true) handle Abort => false
                    in if success then
                           let val recorded = Reruncheck.parseRecorderFile { file = recorderfile, options = options }
                               val recorded = if TeXEngine.isLuaTeX engine andalso FSUtil.isFile recorderfile2 then
                                                  Reruncheck.parseRecorderFileContinued { file = recorderfile2, options = options, previousResult = recorded }
                                              else
                                                  recorded
                               val (filelist, _) = Reruncheck.getFileInfo recorded
                               val inputFilesToWatch = List.mapPartial (fn { path = _, abspath, kind = Reruncheck.INPUT } => SOME abspath | _ => NONE) filelist
                           in loop inputFilesToWatch
                           end
                       else
                           loop inputFilesToWatch (* error; watch the same files again *)
                    end
                else
                    () (* exit *)
      in loop inputFilesToWatch
      end

fun getConfigFilePath (SOME configFilePath) = SOME configFilePath
  | getConfigFilePath NONE = case OS.Process.getEnv "CLUTTEX_CONFIG_FILE" of
                                 SOME f => SOME f
                               | NONE => if OSUtil.isWindows then
                                            case OS.Process.getEnv "APPDATA" of
                                                SOME appData => SOME (appData ^ "\\cluttex\\config.toml")
                                              | NONE => NONE
                                         else
                                            case OS.Process.getEnv "XDG_CONFIG_HOME" of
                                                SOME xdgConfigHome => SOME (xdgConfigHome ^ "/cluttex/config.toml")
                                              | NONE => case OS.Process.getEnv "HOME" of
                                                            SOME home => SOME (home ^ "/.config/cluttex/config.toml")
                                                          | NONE => NONE

fun loadConfig configFileOpt = case getConfigFilePath configFileOpt of
                                   NONE => ConfigFile.defaultConfig
                                 | SOME path => (ConfigFile.loadConfig path handle IO.Io _ => ConfigFile.defaultConfig
                                                                                 | ValidateUtf8.InvalidUtf8 => (Message.error ("Config file " ^ path ^ " is not UTF-8 encoded."); ConfigFile.defaultConfig)
                                                                                 | TomlParseError.ParseError e => (Message.error ("Config file " ^ path ^ " is not a valid TOML file: " ^ TomlParseError.toString e); ConfigFile.defaultConfig)
                                                )

fun main () = let val (options, rest) = HandleOptions.parse (AppOptions.init, CommandLine.arguments ())
                  val config = loadConfig (#config_file options)

                  (* Apply colors *)
                  val () = Option.app Message.setTypeStyle (#type_ (#color config))
                  val () = Option.app Message.setExecuteStyle (#execute (#color config))
                  val () = Option.app Message.setErrorStyle (#error (#color config))
                  val () = Option.app Message.setWarningStyle (#warning (#color config))
                  val () = Option.app Message.setDiagnosticStyle (#diagnostic (#color config))
                  val () = Option.app Message.setInformationStyle (#information (#color config))

                  val watch = #watch options
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
                                        val output_directory = genOutputDirectory (#temporary_directory config, [inputfile_abs, jobname, Option.getOpt (#engine_executable options, #executable engine)])
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
                  val options : AppOptions.options
                      = { engine = engine
                        , engine_executable = #engine_executable options
                        , output = output
                        , fresh = #fresh options
                        , max_iterations = Option.getOpt (#max_iterations options, 4)
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
                        , output_directory = output_directory
                        , output_format = output_format
                        , tex_extraoptions = #tex_extraoptions options
                        , dvipdfmx_extraoptions = #dvipdfmx_extraoptions options
                        , makeindex = #makeindex options
                        , bibtex_or_biber = #bibtex_or_biber options
                        , makeglossaries = #makeglossaries options
                        }
                  val run_params = { options = options
                                   , inputfile = inputfile
                                   , engine = engine
                                   , tex_options = tex_options
                                   , recorderfile = recorderfile
                                   , recorderfile2 = recorderfile2
                                   , original_wd = original_wd
                                   , output_extension = output_extension
                                   }
              in case watch of
                     NONE => (doTypeset run_params handle Abort => OS.Process.exit OS.Process.failure)
                   | SOME watch_engine => runWatchMode (watch_engine, run_params)
              end
end;
val () = Main.main ();
