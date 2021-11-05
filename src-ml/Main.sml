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
                                       SOME home => OS.Path.joinDirFile { dir = home, file = ".latex-build-temp" }
                                     | NONE => raise Fail "environment variable 'TMPDIR' not set!"
      in OS.Path.joinDirFile { dir = tmpdir, file = "latex-build-" ^ hash }
      end
datatype driver = DVIPDFMX | DVIPS | DVISVGM
datatype interaction = BATCHMODE | NONSTOPMODE | SCROLLMODE | ERRORSTOPMODE
datatype shell_escape = ALLOWED | RESTRICTED | FORBIDDEN
datatype output_format = PDF | DVI
datatype bibtex_or_biber = BIBTEX of string | BIBER of string
type app_options = { engine : string option
                   , engine_executable : string option
                   , output : string option
                   , fresh : bool (* default: false *)
                   , max_iterations : int option
                   , start_with_draft : bool option
                   , watch : bool option
                   , verbosity : int
                   , color : string option
                   , change_directory : bool option
                   , includeonly : string option
                   , make_depends : string option
                   , print_output_directory : bool (* default: false *)
                   , package_support : string list
                   , check_driver : driver option (* dvipdfmx | dvips | dvisvgm *)
                   , synctex : string option (* should be int? *)
                   , file_line_error : bool option
                   , interaction : interaction option (* batchmode | nonstopmode | scrollmode | errorstopmode *)
                   , halt_on_error : bool option
                   , shell_escape : shell_escape option
                   , jobname : string option
                   , fmt : string option
                   , output_directory : string option
                   , output_format : output_format option (* pdf | dvi *)
                   , tex_extraoptions : string list
                   , dvipdfmx_extraoptions : string list
                   , makeindex : string option
                   , bibtex_or_biber : bibtex_or_biber option
                   , makeglossaries : string option
                   }
