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
structure HandleOptions = HandleOptions (fun showMessageAndFail message = (TextIO.output (TextIO.stdErr, message ^ "\n"); OS.Process.exit OS.Process.failure)
                                         fun showUsage () = (TextIO.output (TextIO.stdErr, "Usage: cluttex\n"); OS.Process.exit OS.Process.failure)
                                         fun showVersion () = (TextIO.output (TextIO.stdErr, "cluttex version x.x\n"); OS.Process.exit OS.Process.failure)
                                        )
val (options, args') = HandleOptions.parse (AppOptions.init, CommandLine.arguments ());
