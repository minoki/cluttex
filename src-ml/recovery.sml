structure Recovery : sig
              val createMissingDirectories : { execlog : string, auxfile : string, outdir : string } -> bool
              val runEpstopdf : { options : AppOptions.options, execlog : string, originalWorkingDirectory : string } -> bool
              val tryRecovery : { options : AppOptions.options, execlog : string, auxfile : string, originalWorkingDirectory : string } -> bool
          end = struct
fun createMissingDirectories { execlog, auxfile, outdir }
    = if String.isSubstring "I can't write on file" execlog then
          (* There is a possibility that there are some subfiles under subdirectories.
           * Directories for sub-auxfiles are not created automatically, so we need to provide them. *)
          let val (madeNewDirectory, _) = AuxFile.createMissingDirectories { auxfile = auxfile, outdir = outdir, seen = StringSet.empty }
          in if madeNewDirectory andalso Message.getVerbosity () >= 1 then
                 Message.info "Created missing directories."
             else
                 ()
           ; madeNewDirectory
          end
      else
          false

fun runEpstopdf { options : AppOptions.options, execlog : string, originalWorkingDirectory : string }
    = if #shell_escape options <> SOME ShellEscape.FORBIDDEN then (* (possibly restricted) \write18 enabled *)
          let val lines = Substring.tokens (fn c => c = #"\n") (Substring.full execlog)
              fun doLine (line, run)
                  = case List.map Substring.string (Substring.tokens Char.isSpace line) of
                        ["(epstopdf)", "Command:", command, outfile', infile'] =>
                        if command = "<epstopdf" orelse command = "<repstopdf" andalso String.isPrefix "--outfile=" outfile' andalso String.isSuffix ">" infile' then
                            let val outfile = String.extract (outfile', 10, NONE)
                                val infile = String.substring (infile', 0, String.size infile' - 1)
                                val infileAbs = PathUtil.abspath { path = infile, cwd = SOME originalWorkingDirectory }
                            in if FSUtil.isFile infileAbs then (* input file exists *)
                                   let val outfileAbs = PathUtil.abspath { path = outfile, cwd = SOME (#output_directory options) }
                                       val () = if Message.getVerbosity () >= 1 then
                                                    Message.info ("Running epstopdf on " ^ infile ^ ".")
                                                else
                                                    ()
                                       val outdir = PathUtil.dirname outfileAbs
                                       val () = if not (FSUtil.isDirectory outdir) then
                                                    FSUtil.mkDirRec outdir
                                                else
                                                    ()
                                       val command = "epstopdf --outfile=" ^ ShellUtil.escape outfileAbs ^ " " ^ ShellUtil.escape infileAbs
                                       val () = Message.exec command
                                       val success = OS.Process.isSuccess (OS.Process.system command)
                                   in run orelse success
                                   end
                               else
                                   run
                            end
                        else
                            run
                      | _ => run
          in List.foldl doLine false lines
          end
      else
          false

(* The next time we will able to set \PassOptionsToPackage{outputdir=}{minted} *)
fun checkMinted { execlog } = String.isSubstring "Package minted Error: Missing Pygments output; \\inputminted was" execlog

fun tryRecovery { options, execlog, auxfile, originalWorkingDirectory }
    = let val recovered = createMissingDirectories { execlog = execlog, auxfile = auxfile, outdir = #output_directory options }
          val recovered = runEpstopdf { options = options, execlog = execlog, originalWorkingDirectory = originalWorkingDirectory } orelse recovered
          val recovered = recovered orelse checkMinted { execlog = execlog }
      in recovered
      end
end;
