structure AppOptions:
sig
  structure DviDriver:
  sig
    datatype driver = DVIPDFMX | DVIPS | DVISVGM
    val fromString: string -> driver option
  end
  datatype bibtex_or_biber = BIBTEX of string | BIBER of string
  structure WatchEngine:
  sig
    datatype engine = FSWATCH | INOTIFYWAIT | AUTO
    val fromString: string -> engine option
  end
  structure ColorMode:
  sig
    datatype mode = datatype Message.mode
    val fromString: string -> mode option
  end
  structure SourceDateEpoch:
  sig
    datatype time = NOW | RAW of string
    val fromString: string -> time option
  end
  type initial_options =
    { engine: string option
    , engine_executable: string option
    , output: string option
    , fresh: bool (* default: false *)
    , max_iterations: int option
    , start_with_draft: bool
    , watch: WatchEngine.engine option
    , color: ColorMode.mode option
    , change_directory: bool option
    , includeonly: string option
    , make_depends: string option
    , print_output_directory: bool (* default: false *)
    , package_support: {minted: bool, epstopdf: bool, pdfx: bool}
    , check_driver: DviDriver.driver option (* dvipdfmx | dvips | dvisvgm *)
    , source_date_epoch: SourceDateEpoch.time option
    , synctex: string option (* should be int? *)
    , file_line_error: bool
    , interaction: InteractionMode.interaction option (* batchmode | nonstopmode | scrollmode | errorstopmode *)
    , halt_on_error: bool
    , shell_escape: ShellEscape.shell_escape option
    , jobname: string option
    , fmt: string option
    , output_directory: string option
    , output_format: OutputFormat.format option (* pdf | dvi *)
    , tex_extraoptions: string list
    , dvipdfmx_extraoptions: string list
    , makeindex: string option
    , bibtex_or_biber: bibtex_or_biber option
    , makeglossaries: string option
    , config_file: string option
    }
  type options =
    { engine: TeXEngine.engine
    , engine_executable: string option
    , output: string
    , fresh: bool
    , max_iterations: int
    , start_with_draft: bool
    , watch: WatchEngine.engine option
    , change_directory: bool
    , includeonly: string option
    , make_depends: string option
    , print_output_directory: bool
    , package_support: {minted: bool, epstopdf: bool, pdfx: bool}
    , check_driver: CheckDriver.driver option
    , source_date_epoch: SourceDateEpoch.time option
    , synctex: string option
    , file_line_error: bool
    , interaction: InteractionMode.interaction
    , halt_on_error: bool
    , shell_escape: ShellEscape.shell_escape option
    , jobname: string
    , fmt: string option
    , output_directory: string
    , output_format: OutputFormat.format
    , tex_extraoptions: string list
    , dvipdfmx_extraoptions: string list
    , makeindex: string option
    , bibtex_or_biber: bibtex_or_biber option
    , makeglossaries: string option
    }
  val init: initial_options
end =
struct
  structure DviDriver =
  struct
    datatype driver = DVIPDFMX | DVIPS | DVISVGM
    fun fromString "dvipdfmx" = SOME DVIPDFMX
      | fromString "dvips" = SOME DVIPS
      | fromString "dvisvgm" = SOME DVISVGM
      | fromString _ = NONE
  end
  datatype bibtex_or_biber = BIBTEX of string | BIBER of string
  structure WatchEngine =
  struct
    datatype engine = FSWATCH | INOTIFYWAIT | AUTO
    fun fromString "fswatch" = SOME FSWATCH
      | fromString "inotifywait" = SOME INOTIFYWAIT
      | fromString "auto" = SOME AUTO
      | fromString _ = NONE
  end
  structure ColorMode =
  struct
    datatype mode = datatype Message.mode
    fun fromString "always" = SOME ALWAYS
      | fromString "auto" = SOME AUTO
      | fromString "never" = SOME NEVER
      | fromString _ = NONE
  end
  structure SourceDateEpoch =
  struct
    datatype time = NOW | RAW of string
    fun fromString "now" = SOME NOW
      | fromString s =
          if String.size s > 0 andalso CharVector.all Char.isDigit s then
            SOME (RAW s)
          else
            NONE
  end
  type initial_options =
    { engine: string option
    , engine_executable: string option
    , output: string option
    , fresh: bool (* default: false *)
    , max_iterations: int option
    , start_with_draft: bool
    , watch: WatchEngine.engine option
    , color: ColorMode.mode option
    , change_directory: bool option
    , includeonly: string option
    , make_depends: string option
    , print_output_directory: bool (* default: false *)
    , package_support: {minted: bool, epstopdf: bool, pdfx: bool}
    , check_driver: DviDriver.driver option (* dvipdfmx | dvips | dvisvgm *)
    , source_date_epoch: SourceDateEpoch.time option
    , synctex: string option (* should be int? *)
    , file_line_error: bool
    , interaction: InteractionMode.interaction option (* batchmode | nonstopmode | scrollmode | errorstopmode *)
    , halt_on_error: bool
    , shell_escape: ShellEscape.shell_escape option
    , jobname: string option
    , fmt: string option
    , output_directory: string option
    , output_format: OutputFormat.format option (* pdf | dvi *)
    , tex_extraoptions: string list
    , dvipdfmx_extraoptions: string list
    , makeindex: string option
    , bibtex_or_biber: bibtex_or_biber option
    , makeglossaries: string option
    , config_file: string option
    }
  type options =
    { engine: TeXEngine.engine
    , engine_executable: string option
    , output: string
    , fresh: bool
    , max_iterations: int
    , start_with_draft: bool
    , watch: WatchEngine.engine option
    , change_directory: bool
    , includeonly: string option
    , make_depends: string option
    , print_output_directory: bool
    , package_support: {minted: bool, epstopdf: bool, pdfx: bool}
    , check_driver: CheckDriver.driver option
    , source_date_epoch: SourceDateEpoch.time option
    , synctex: string option
    , file_line_error: bool
    , interaction: InteractionMode.interaction
    , halt_on_error: bool
    , shell_escape: ShellEscape.shell_escape option
    , jobname: string
    , fmt: string option
    , output_directory: string
    , output_format: OutputFormat.format
    , tex_extraoptions: string list
    , dvipdfmx_extraoptions: string list
    , makeindex: string option
    , bibtex_or_biber: bibtex_or_biber option
    , makeglossaries: string option
    }
  val init: initial_options =
    { engine = NONE
    , engine_executable = NONE
    , output = NONE
    , fresh = false
    , max_iterations = NONE
    , start_with_draft = false
    , watch = NONE
    , color = NONE
    , change_directory = NONE
    , includeonly = NONE
    , make_depends = NONE
    , print_output_directory = false
    , package_support = {minted = false, epstopdf = false, pdfx = false}
    , check_driver = NONE
    , source_date_epoch = NONE
    , synctex = NONE
    , file_line_error = true
    , interaction = NONE
    , halt_on_error = true
    , shell_escape = NONE
    , jobname = NONE
    , fmt = NONE
    , output_directory = NONE
    , output_format = NONE
    , tex_extraoptions = []
    , dvipdfmx_extraoptions = []
    , makeindex = NONE
    , bibtex_or_biber = NONE
    , makeglossaries = NONE
    , config_file = NONE
    }
end;
