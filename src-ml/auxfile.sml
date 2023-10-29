structure AuxFile : sig
              val createMissingDirectories : { auxfile : string, outdir : string, seen : StringSet.set } -> bool * StringSet.set
              val extractBibTeXLines : { auxfile : string, outdir : string } -> string list
          end = struct
fun stripPrefix prefix s = if String.isPrefix prefix s then
                               SOME (Substring.extract (s, String.size prefix, NONE))
                           else
                               NONE
fun isInput (line, outdir) = case stripPrefix "\\@input{" line of
                                 NONE => NONE
                               | SOME rest => let val subauxfile = Substring.string (Substring.takel (fn c => c <> #"}") rest)
                                                  val subauxfile_abs = PathUtil.abspath { path = subauxfile, cwd = SOME outdir }
                                              in SOME { subauxfile = subauxfile, subauxfile_abs = subauxfile_abs }
                                              end
fun createMissingDirectories { auxfile, outdir, seen }
    = let val ins = TextIO.openIn auxfile
          val seen = StringSet.add (seen, auxfile)
          fun go (did, seen) = case TextIO.inputLine ins of
                                   NONE => (TextIO.closeIn ins; (did, seen))
                                 | SOME line => case isInput (line, outdir) of
                                                    NONE => go (did, seen)
                                                  | SOME { subauxfile, subauxfile_abs } =>
                                                    if FSUtil.isFile subauxfile_abs then
                                                        let val (did', seen) = createMissingDirectories { auxfile = subauxfile_abs, outdir = outdir, seen = seen }
                                                        in go (did orelse did', seen)
                                                        end
                                                    else
                                                        let val dir = PathUtil.join2 (outdir, PathUtil.dirname subauxfile)
                                                        in if FSUtil.isDirectory dir then
                                                               go (did, seen)
                                                           else
                                                               ( FSUtil.mkDirRec dir
                                                               ; go (true, seen)
                                                               )
                                                        end
      in go (false, seen)
      end

(* \citation, \bibdata, \bibstyle *)
fun extractBibTeXLines' { auxfile, outdir, revLines }
    = let val ins = TextIO.openIn auxfile
          fun go revLines = case TextIO.inputLine ins of
                                NONE => (TextIO.closeIn ins; revLines)
                              | SOME line => case isInput (line, outdir) of
                                                 SOME { subauxfile, subauxfile_abs } =>
                                                 if FSUtil.isFile subauxfile_abs then
                                                     let val revLines = extractBibTeXLines' { auxfile = subauxfile_abs, outdir = outdir, revLines = revLines }
                                                     in go revLines
                                                     end
                                                 else
                                                     go revLines
                                               | NONE => let val isBibTeXLine = case stripPrefix "\\" line of
                                                                                    SOME s => (case Substring.string (Substring.takel (fn c => Char.isAlpha c orelse c = #"@") s) of
                                                                                                   "citation" => true
                                                                                                 | "bibdata" => true
                                                                                                 | "bibstyle" => true
                                                                                                 | _ => false
                                                                                              )
                                                                                  | NONE => false
                                                         in if isBibTeXLine then
                                                                ( if Message.getVerbosity () >= 2 then
                                                                      Message.info ("BibTeX line: " ^ Substring.string (Substring.dropr Char.isSpace (Substring.full line)))
                                                                  else
                                                                      ()
                                                                ; go (line :: revLines)
                                                                )
                                                            else
                                                                go revLines
                                                         end
      in go revLines
      end
fun extractBibTeXLines { auxfile, outdir } = List.rev (extractBibTeXLines' { auxfile = auxfile, outdir = outdir, revLines = [] })
end;
