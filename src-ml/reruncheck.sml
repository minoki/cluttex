structure Reruncheck :> sig
              datatype file_kind = INPUT | OUTPUT | AUXILIARY
              type file_info = { path : string
                               , abspath : string
                               , kind : file_kind
                               }
              type recorded
              val parseRecorderFile : { file : string, options : AppOptions.options } -> recorded
              val parseRecorderFileContinued : { file : string, options : AppOptions.options, previousResult : recorded } -> recorded
              val getFileInfo : recorded -> file_info list * file_info StringMap.map
              type aux_status = { mtime : Time.time option
                                , size : Position.int option
                                , md5sum : MD5.hash option
                                }
              val collectFileInfo : file_info list * aux_status ref StringMap.map -> aux_status ref StringMap.map
              val compareFileTime : { srcAbs : string, dst : string, auxstatus : aux_status StringMap.map } -> bool
          end = struct
datatype file_kind = INPUT | OUTPUT | AUXILIARY
type file_info = { path : string
                 , abspath : string
                 , kind : file_kind
                 }
type recorded = file_info ref list * file_info ref StringMap.map
fun getFileInfo ((fileInfo, fileMap) : recorded) = (List.foldl (fn (x, xs) => !x :: xs) [] fileInfo, StringMap.map ! fileMap)
fun parseRecorderFileContinued { file, options : AppOptions.options, previousResult = (fileList, fileMap) }
    = let val ins = TextIO.openIn file
          fun go (fileList, fileMap)
              = case TextIO.inputLine ins of
                    NONE => (TextIO.closeIn ins; (fileList, fileMap))
                  | SOME line =>
                    let val (t, rest) = Substring.splitl Char.isAlphaNum (Substring.full line)
                        val path = Substring.string (Substring.dropl Char.isSpace (Substring.dropr Char.isSpace rest))
                    in case Substring.string t of
                           "PWD" => go (fileList, fileMap) (* ignore *)
                         | "INPUT" =>
                           let val abspath = PathUtil.abspath { path = path, cwd = NONE }
                           in case StringMap.find (fileMap, abspath) of
                                  SOME (r as ref { path = path', abspath = abspath', kind }) =>
                                  ( r := { path = if String.size path < String.size path' then
                                                      path
                                                  else
                                                      path'
                                         , abspath = abspath'
                                         , kind = if kind = OUTPUT then
                                                      (* The files listed in both INPUT and OUTPUT are considered to be auxiliary files. *)
                                                      AUXILIARY
                                                  else
                                                      kind
                                         }
                                  ; go (fileList, fileMap)
                                  )
                                | NONE =>
                                  if FSUtil.isFile path then
                                      let val r = ref { path = path
                                                      , abspath = abspath
                                                      , kind = if PathUtil.ext path = "bbl" then
                                                                   AUXILIARY
                                                               else
                                                                   INPUT
                                                      }
                                      in go (r :: fileList, StringMap.insert (fileMap, abspath, r))
                                      end
                                  else
                                      (* Maybe a command execution *)
                                      go (fileList, fileMap)
                           end
                         | "OUTPUT" =>
                           let val abspath = PathUtil.abspath { path = path, cwd = NONE }
                           in case StringMap.find (fileMap, abspath) of
                                  SOME (r as ref { path = path', abspath = abspath', kind }) =>
                                  ( r := { path = if String.size path < String.size path' then
                                                      path
                                                  else
                                                      path'
                                         , abspath = abspath'
                                         , kind = if kind = INPUT then
                                                      (* The files listed in both INPUT and OUTPUT are considered to be auxiliary files. *)
                                                      AUXILIARY
                                                  else
                                                      kind
                                         }
                                  ; go (fileList, fileMap)
                                  )
                                | NONE =>
                                  let val ext = PathUtil.ext path
                                      val r = ref { path = path
                                                  , abspath = abspath
                                                  , kind = if ext = "out" orelse (#makeindex options <> NONE andalso ext = "idx") orelse ext = "bcf" orelse ext = "glo" then
                                                               (* .out: hyperref bookmarks file
                                                                * .idx: input for makeindex
                                                                * .bcf: biber
                                                                * .glo: makeglossaries
                                                                *)
                                                               AUXILIARY
                                                           else
                                                               OUTPUT
                                                  }
                                  in go (r :: fileList, StringMap.insert (fileMap, abspath, r))
                                  end
                           end
                         | t => ( Message.warn ("Unrecognized line in recorder file '" ^ file ^ "': " ^ t)
                                ; go (fileList, fileMap)
                                )
                    end
      in go (fileList, fileMap)
      end
fun parseRecorderFile { file, options } = parseRecorderFileContinued { file = file, options = options, previousResult = ([], StringMap.empty) }

type aux_status = { mtime : Time.time option
                  , size : Position.int option
                  , md5sum : MD5.hash option
                  }

fun md5sumOfFile (path : string) : MD5.hash
    = let val ins = BinIO.openIn path
          val data = BinIO.inputAll ins before BinIO.closeIn ins
      in MD5.compute data
      end

fun collectFileInfo (fileList : file_info list, auxstatus : aux_status ref StringMap.map) : aux_status ref StringMap.map
    = let fun go ({ abspath, kind, ... } : file_info, auxstatus) : aux_status ref StringMap.map
              = if FSUtil.isFile abspath then
                    let val (status, auxstatus) = case StringMap.find (auxstatus, abspath) of
                                                      NONE => let val s = ref { mtime = NONE, size = NONE, md5sum = NONE }
                                                              in (s, StringMap.insert (auxstatus, abspath, s))
                                                              end
                                                    | SOME status => (status, auxstatus)
                    in case kind of
                           INPUT => (case status of
                                         ref (s as { mtime = NONE, ... }) => status := { s where mtime = SOME (OS.FileSys.modTime abspath) }
                                       | _ => ()
                                    )
                         | AUXILIARY => let val s = !status
                                            val s = case s of
                                                        { mtime = NONE, ... } => { s where mtime = SOME (OS.FileSys.modTime abspath) }
                                                      | _ => s
                                            val s = case s of
                                                        { size = NONE, ... } => { s where size = SOME (OS.FileSys.fileSize abspath) }
                                                      | _ => s
                                            val s = case s of
                                                        { md5sum = NONE, ... } => { s where md5sum = SOME (md5sumOfFile abspath) }
                                                      | _ => s
                                        in status := s
                                        end
                         | OUTPUT => ()
                     ; auxstatus
                    end
                else
                    auxstatus
      in List.foldl go auxstatus fileList
      end

fun compareFileInfo (fileList : file_info list, auxstatus : aux_status StringMap.map) : bool * aux_status ref StringMap.map
    = let fun go ([], newauxstatus) = (false, newauxstatus)
            | go ({ path = shortPath, abspath, kind } :: fileList, newauxstatus)
              = if FSUtil.isFile abspath then
                    let val (shouldRerun, newauxstatus)
                            = case kind of
                                  INPUT => (* Input file: User might have modified while running TeX. *)
                                  let val mtime = OS.FileSys.modTime abspath
                                  in case StringMap.find (auxstatus, abspath) of
                                         SOME { mtime = SOME mtime', ... } =>
                                         if Time.< (mtime', mtime) then
                                             (* Input file was updated during execution *)
                                             ( Message.info ("Input file '" ^ shortPath ^ "' was modified (by user, or some external commands).")
                                             ; (true, StringMap.insert (newauxstatus, abspath, ref { mtime = SOME mtime, size = NONE, md5sum = NONE }))
                                             )
                                         else
                                             (false, newauxstatus)
                                       | _ => (* New input file *)
                                         (false, newauxstatus)
                                  end
                                | AUXILIARY => (* Auxiliary file: Compare file contents. *)
                                  (case StringMap.find (auxstatus, abspath) of
                                       SOME s =>
                                       let val size = OS.FileSys.fileSize abspath
                                           val sizeIsDifferent = case #size s of
                                                                     SOME z => z <> size
                                                                   | NONE => true
                                           val (modifiedBecause, newauxstatus)
                                               = if sizeIsDifferent then
                                                     let val previousSize = case #size s of
                                                                                SOME z => Position.toString z
                                                                              | NONE => "(N/A)"
                                                     in (SOME ("size: " ^ previousSize ^ " -> " ^ Position.toString size), StringMap.insert (newauxstatus, abspath, ref { mtime = NONE, size = SOME size, md5sum = NONE }))
                                                     end
                                                 else
                                                     let val md5sum = md5sumOfFile abspath
                                                         val md5sumIsDifferent = case #md5sum s of
                                                                                     SOME h => h <> md5sum
                                                                                   | NONE => true
                                                     in if md5sumIsDifferent then
                                                            let val previousMd5sum = case #md5sum s of
                                                                                         SOME h => MD5.hashToLowerHexString h
                                                                                       | NONE => "(N/A)"
                                                            in (SOME ("md5: " ^ previousMd5sum ^ " -> " ^ MD5.hashToLowerHexString md5sum), StringMap.insert (newauxstatus, abspath, ref { mtime = NONE, size = SOME size, md5sum = SOME md5sum }))
                                                            end
                                                        else
                                                            (NONE, newauxstatus)
                                                     end
                                       in case modifiedBecause of
                                              SOME reason => ( Message.info ("File '" ^ shortPath ^ "' was modified (" ^ reason ^ ").")
                                                             ; (true, newauxstatus)
                                                             )
                                            | NONE => ( if Message.getVerbosity () >= 1 then
                                                            Message.info ("File '" ^ shortPath ^ "' unmodified (size and md5sum).")
                                                        else
                                                            ()
                                                      ; (false, newauxstatus)
                                                      )
                                       end
                                     | NONE => (* New file *)
                                       let val (shouldRerun, newauxstatus)
                                               = if String.isSuffix ".aux" abspath then
                                                     let val size = OS.FileSys.fileSize abspath
                                                     in if size = 8 then
                                                            let val ins = BinIO.openIn abspath
                                                                val contents = BinIO.inputAll ins before BinIO.closeIn ins
                                                                val isTrivial = Byte.bytesToString contents = "\\relax \n"
                                                                val newauxstatus = StringMap.insert (newauxstatus, abspath, ref { mtime = NONE, size = SOME size, md5sum = SOME (MD5.compute contents) })
                                                            in (not isTrivial, newauxstatus)
                                                            end
                                                        else
                                                            let val newauxstatus = StringMap.insert (newauxstatus, abspath, ref { mtime = NONE, size = SOME size, md5sum = NONE })
                                                            in (true, newauxstatus)
                                                            end
                                                     end
                                                 else
                                                     (true, newauxstatus)
                                       in if shouldRerun then
                                              Message.info ("New auxiliary file '" ^ shortPath ^ "'.")
                                          else if Message.getVerbosity () >= 1 then
                                              Message.info ("Ignoring almost-empty auxiliary file '" ^ shortPath ^ "'.")
                                          else
                                              ()
                                        ; (shouldRerun, newauxstatus)
                                       end
                                  )
                                | OUTPUT => (false, newauxstatus)
                    in if shouldRerun then
                           (true, newauxstatus)
                       else
                           go (fileList, newauxstatus)
                    end
                else
                    go (fileList, newauxstatus)
      in go (fileList, StringMap.empty)
      end

(* true if src is newer than dst *)
fun compareFileTime { srcAbs, dst, auxstatus : aux_status StringMap.map }
    = if not (FSUtil.isFile dst) then
          true
      else
          case StringMap.find (auxstatus, srcAbs) of
              SOME { mtime = SOME mtime, ... } => Time.> (mtime, OS.FileSys.modTime dst)
            | _ => false
end;
