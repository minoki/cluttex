structure CheckDriver:
sig
  datatype driver = DVIPDFMX | DVIPS | DVISVGM | PDFTEX | XETEX | LUATEX
  val checkDriver: driver * {kind: string, path: string} list -> unit
end =
struct
  datatype driver = DVIPDFMX | DVIPS | DVISVGM | PDFTEX | XETEX | LUATEX
  fun toString DVIPDFMX = "dvipdfmx"
    | toString DVIPS = "dvips"
    | toString DVISVGM = "dvisvgm"
    | toString PDFTEX = "pdftex"
    | toString XETEX = "xetex"
    | toString LUATEX = "luatex"
  structure graphics =
  struct
    datatype driver =
      DVIPDFMX
    | DVIPS
    | DVISVGM
    | PDFTEX
    | XETEX
    | LUATEX
    | UNKNOWN
    fun toString DVIPDFMX = "dvipdfmx"
      | toString DVIPS = "dvips"
      | toString DVISVGM = "dvisvgm"
      | toString PDFTEX = "pdftex"
      | toString XETEX = "xetex"
      | toString LUATEX = "luatex"
      | toString UNKNOWN = "unknown"
  end
  structure expl3 =
  struct
    datatype driver =
      PDFMODE
    | DVISVGM
    | XDVIPDFMX
    | DVIPDFMX
    | DVIPS
    | PDFTEX
    | LUATEX
    | XETEX
    | UNKNOWN
    fun toString PDFMODE = "pdfmode"
      | toString DVISVGM = "dvisvgm"
      | toString XDVIPDFMX = "xdvipdfmx"
      | toString DVIPDFMX = "dvipdfmx"
      | toString DVIPS = "dvips"
      | toString PDFTEX = "pdftex"
      | toString LUATEX = "luatex"
      | toString XETEX = "xetex"
      | toString UNKNOWN = "unknown"
  end
  structure hyperref =
  struct
    datatype driver = DVIPDFMX | DVIPS | PDFTEX | LUATEX | XETEX | UNKNOWN
    fun toString DVIPDFMX = "dvipdfmx"
      | toString DVIPS = "dvips"
      | toString PDFTEX = "pdftex"
      | toString LUATEX = "luatex"
      | toString XETEX = "xetex"
      | toString UNKNOWN = "unknown"
  end
  structure xypic =
  struct
    datatype driver = PDF | DVIPS | UNKNOWN
    fun toString PDF = "pdf"
      | toString DVIPS = "dvips"
      | toString UNKNOWN = "unknown"
  end
  (*: val correctDrivers : driver -> { graphics : graphics.driver, expl3_old : expl3.driver, expl3_new : expl3.driver, hyperref : hyperref.driver option, xypic : xypic.driver option } *)
  fun correctDrivers DVIPS =
        { graphics = graphics.DVIPS
        , expl3_old = expl3.DVIPS
        , expl3_new = expl3.DVIPS
        , hyperref = SOME hyperref.DVIPS
        , xypic = SOME xypic.DVIPS
        }
    | correctDrivers DVIPDFMX =
        { graphics = graphics.DVIPDFMX
        , expl3_old = expl3.DVIPDFMX
        , expl3_new = expl3.DVIPDFMX
        , hyperref = SOME hyperref.DVIPDFMX
        , xypic = SOME xypic.PDF
        }
    | correctDrivers DVISVGM =
        { graphics = graphics.DVISVGM
        , expl3_old = expl3.DVISVGM
        , expl3_new = expl3.DVISVGM
        , hyperref = NONE (* What to do? *)
        , xypic = NONE (* What to do? *)
        }
    | correctDrivers XETEX =
        { graphics = graphics.XETEX
        , expl3_old = expl3.XDVIPDFMX
        , expl3_new = expl3.XETEX
        , hyperref = SOME hyperref.XETEX
        , xypic = SOME xypic.PDF
        }
    | correctDrivers PDFTEX =
        { graphics = graphics.PDFTEX
        , expl3_old = expl3.PDFMODE
        , expl3_new = expl3.PDFTEX
        , hyperref = SOME hyperref.PDFTEX
        , xypic = SOME xypic.PDF
        }
    | correctDrivers LUATEX =
        { graphics = graphics.LUATEX
        , expl3_old = expl3.PDFMODE
        , expl3_new = expl3.LUATEX
        , hyperref = SOME hyperref.LUATEX
        , xypic = SOME xypic.PDF
        }
  fun checkDriver (expected_driver, filelist) =
    let
      val () =
        if Message.getVerbosity () >= 1 then
          Message.info ("checkdriver: expects " ^ toString expected_driver)
        else
          ()
      val loadedSet =
        List.foldl
          (fn ({kind, path}, set) =>
             if kind = "input" then StringSet.add (set, PathUtil.basename path)
             else set) StringSet.empty filelist
      fun loaded name = StringSet.member (loadedSet, name)
      val graphics_driver =
        if loaded "graphics.sty" orelse loaded "color.sty" then
          SOME
            (if loaded "dvipdfmx.def" then
               graphics.DVIPDFMX
             else if loaded "dvips.def" then
               graphics.DVIPS
             else if loaded "dvisvgm.def" then
               graphics.DVISVGM
             else if loaded "pdftex.def" then
               graphics.PDFTEX
             else if loaded "luatex.def" then
               graphics.LUATEX
             else if loaded "xetex.def" then
               graphics.XETEX
             else
               (* Not supported: dvipdf, dvipsone, emtex, textures, pctexps, pctexwin, pctexhp, pctex32, truetex, tcidvi, vtex *)
               graphics.UNKNOWN)
        else
          NONE
      val expl3_driver =
        if
          loaded "expl3-code.tex" orelse loaded "expl3.sty"
          orelse loaded "l3backend-dvips.def"
          orelse loaded "l3backend-dvipdfmx.def"
          orelse loaded "l3backend-xdvipdfmx.def"
          orelse loaded "l3backend-pdfmode.def"
          orelse loaded "l3backend-pdftex.def"
          orelse loaded "l3backend-luatex.def"
          orelse loaded "l3backend-xetex.def"
        then
          SOME
            (if loaded "l3backend-pdfmode.def" then expl3.PDFMODE
             else if loaded "l3backend-dvisvgm.def" then expl3.DVISVGM
             else if loaded "l3backend-xdvipdfmx.def" then expl3.XDVIPDFMX
             else if loaded "l3backend-dvipdfmx.def" then expl3.DVIPDFMX
             else if loaded "l3backend-dvips.def" then expl3.DVIPS
             else if loaded "l3backend-pdftex.def" then expl3.PDFTEX
             else if loaded "l3backend-luatex.def" then expl3.LUATEX
             else if loaded "l3backend-xetex.def" then expl3.XETEX
             else expl3.UNKNOWN)
        else
          NONE
      val hyperref_driver =
        if loaded "hyperref.sty" then
          SOME
            (if loaded "hluatex.def" then
               hyperref.LUATEX
             else if loaded "hpdftex.def" then
               hyperref.PDFTEX
             else if loaded "hxetex.def" then
               hyperref.XETEX
             else if loaded "hdvipdfm.def" then
               hyperref.DVIPDFMX
             else if loaded "hdvips.def" then
               hyperref.DVIPS
             else
               (* Not supported: dvipson, dviwind, tex4ht, texture, vtex, vtexhtm, xtexmrk, hypertex *)
               hyperref.UNKNOWN)
        else
          NONE
      val xypic_driver =
        if loaded "xy.tex" then
          SOME
            (if loaded "xypdf.tex" then
               xypic.PDF (* pdftex, luatex, xetex, dvipdfmx *)
             else if loaded "xydvips.tex" then
               xypic.DVIPS
             else
               xypic.UNKNOWN)
        else
          NONE
      val () =
        if Message.getVerbosity () >= 1 then
          ( Message.info
              ("checkdriver: graphics="
               ^
               (case graphics_driver of
                  NONE => "not loaded"
                | SOME d => graphics.toString d))
          ; Message.info
              ("checkdriver: expl3="
               ^
               (case expl3_driver of
                  NONE => "not loaded"
                | SOME d => expl3.toString d))
          ; Message.info
              ("checkdriver: hyperref="
               ^
               (case hyperref_driver of
                  NONE => "not loaded"
                | SOME d => hyperref.toString d))
          ; Message.info
              ("checkdriver: xypic="
               ^
               (case xypic_driver of
                  NONE => "not loaded"
                | SOME d => xypic.toString d))
          )
        else
          ()
      val
        { graphics = expected_graphics
        , expl3_old = expected_expl3_old
        , expl3_new = expected_expl3_new
        , hyperref = expected_hyperref
        , xypic = expected_xypic
        } = correctDrivers expected_driver
    in
      case graphics_driver of
        NONE => ()
      | SOME d =>
          if d <> expected_graphics then
            ( Message.diag
                "The driver option for grahipcs(x)/color is missing or wrong."
            ; Message.diag
                ("Consider setting '" ^ graphics.toString expected_graphics
                 ^ "' option.")
            )
          else
            ();
      case expl3_driver of
        NONE => ()
      | SOME d =>
          if d <> expected_expl3_old andalso d <> expected_expl3_new then
            ( Message.diag "The driver option for expl3 is missing or wrong."
            ; Message.diag
                ("Consider setting 'driver=" ^ expl3.toString expected_expl3_new
                 ^ "' option when loading expl3.")
            ; if expected_expl3_old <> expected_expl3_new then
                Message.diag
                  ("You might need to instead set 'driver="
                   ^ expl3.toString expected_expl3_old
                   ^ "' if you are using an older version of expl3.")
              else
                ()
            )
          else
            ();
      case (hyperref_driver, expected_hyperref) of
        (SOME actual, SOME expected) =>
          if actual <> expected then
            ( Message.diag "The driver option for hyperref is missing or wrong."
            ; Message.diag
                ("Consider setting '" ^ hyperref.toString expected ^ "' option.")
            )
          else
            ()
      | _ => ();
      case (xypic_driver, expected_xypic) of
        (SOME actual, SOME expected) =>
          if actual <> expected then
            ( Message.diag "The driver option for Xy-pic is missing or wrong."
            ; case (expected_driver, expected) of
                (DVIPDFMX, _) =>
                  Message.diag
                    "Consider setting 'dvipdfmx' option or running \\xyoption{pdf}."
              | (PDFTEX, _) =>
                  Message.diag
                    "Consider setting 'pdftex' option or running \\xyoption{pdf}."
              | (_, xypic.PDF) =>
                  Message.diag
                    "Consider setting 'pdf' package option or running \\xyoption{pdf}."
              | (_, xypic.DVIPS) =>
                  Message.diag "Consider setting 'dvips' option."
              | (_, xypic.UNKNOWN) => ()
            )
          else
            ()
      | _ => ()
    end
end;
