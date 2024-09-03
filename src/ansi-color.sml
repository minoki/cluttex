structure ANSIColor:
sig
  datatype color =
    DEFAULT
  | BLACK
  | RED
  | GREEN
  | YELLOW
  | BLUE
  | MAGENTA
  | CYAN
  | WHITE
  | BRIGHT_BLACK
  | BRIGHT_RED
  | BRIGHT_GREEN
  | BRIGHT_YELLOW
  | BRIGHT_BLUE
  | BRIGHT_MAGENTA
  | BRIGHT_CYAN
  | BRIGHT_WHITE
  val fromString: string -> color option
  val asForeground: color -> string option
  val asBackground: color -> string option
end =
struct
  datatype color =
    DEFAULT
  | BLACK
  | RED
  | GREEN
  | YELLOW
  | BLUE
  | MAGENTA
  | CYAN
  | WHITE
  | BRIGHT_BLACK
  | BRIGHT_RED
  | BRIGHT_GREEN
  | BRIGHT_YELLOW
  | BRIGHT_BLUE
  | BRIGHT_MAGENTA
  | BRIGHT_CYAN
  | BRIGHT_WHITE
  fun fromString "default" = SOME DEFAULT
    | fromString "black" = SOME BLACK
    | fromString "red" = SOME RED
    | fromString "green" = SOME GREEN
    | fromString "yellow" = SOME YELLOW
    | fromString "blue" = SOME BLUE
    | fromString "magenta" = SOME MAGENTA
    | fromString "cyan" = SOME CYAN
    | fromString "white" = SOME WHITE
    | fromString "brightblack" = SOME BRIGHT_BLACK
    | fromString "brightred" = SOME BRIGHT_RED
    | fromString "brightgreen" = SOME BRIGHT_GREEN
    | fromString "brightyellow" = SOME BRIGHT_YELLOW
    | fromString "brightblue" = SOME BRIGHT_BLUE
    | fromString "brightmagenta" = SOME BRIGHT_MAGENTA
    | fromString "brightcyan" = SOME BRIGHT_CYAN
    | fromString "brightwhite" = SOME BRIGHT_WHITE
    | fromString _ = NONE
  fun asForeground DEFAULT = NONE
    | asForeground BLACK = SOME "30"
    | asForeground RED = SOME "31"
    | asForeground GREEN = SOME "32"
    | asForeground YELLOW = SOME "33"
    | asForeground BLUE = SOME "34"
    | asForeground MAGENTA = SOME "35"
    | asForeground CYAN = SOME "36"
    | asForeground WHITE = SOME "37"
    | asForeground BRIGHT_BLACK = SOME "90"
    | asForeground BRIGHT_RED = SOME "91"
    | asForeground BRIGHT_GREEN = SOME "92"
    | asForeground BRIGHT_YELLOW = SOME "93"
    | asForeground BRIGHT_BLUE = SOME "94"
    | asForeground BRIGHT_MAGENTA = SOME "95"
    | asForeground BRIGHT_CYAN = SOME "96"
    | asForeground BRIGHT_WHITE = SOME "97"
  fun asBackground DEFAULT = NONE
    | asBackground BLACK = SOME "40"
    | asBackground RED = SOME "41"
    | asBackground GREEN = SOME "42"
    | asBackground YELLOW = SOME "43"
    | asBackground BLUE = SOME "44"
    | asBackground MAGENTA = SOME "45"
    | asBackground CYAN = SOME "46"
    | asBackground WHITE = SOME "47"
    | asBackground BRIGHT_BLACK = SOME "100"
    | asBackground BRIGHT_RED = SOME "101"
    | asBackground BRIGHT_GREEN = SOME "102"
    | asBackground BRIGHT_YELLOW = SOME "103"
    | asBackground BRIGHT_BLUE = SOME "104"
    | asBackground BRIGHT_MAGENTA = SOME "105"
    | asBackground BRIGHT_CYAN = SOME "106"
    | asBackground BRIGHT_WHITE = SOME "107"
end;
structure ANSIStyle:
sig
  type style =
    { foreground: ANSIColor.color option
    , background: ANSIColor.color option
    , bold: bool
    , dim: bool
    , underline: bool
    , blink: bool
    , reverse: bool
    , italic: bool
    , strike: bool
    }
  val defaultStyle: style
  val toString: style -> string
  val resetAll: string
end =
struct
  type style =
    { foreground: ANSIColor.color option
    , background: ANSIColor.color option
    , bold: bool
    , dim: bool
    , underline: bool
    , blink: bool
    , reverse: bool
    , italic: bool
    , strike: bool
    }
  val defaultStyle: style =
    { foreground = NONE
    , background = NONE
    , bold = false
    , dim = false
    , underline = false
    , blink = false
    , reverse = false
    , italic = false
    , strike = false
    }
  fun prependOption (SOME x, xs) = x :: xs
    | prependOption (NONE, xs) = xs
  fun toString
    ({ foreground
     , background
     , bold
     , dim
     , underline
     , blink
     , reverse
     , italic
     , strike
     }: style) =
    let
      val attrs = []
      val attrs = if strike then "9" :: attrs else attrs
      val attrs = if reverse then "7" :: attrs else attrs
      val attrs = if blink then "5" :: attrs else attrs
      val attrs = if underline then "4" :: attrs else attrs
      val attrs = if italic then "3" :: attrs else attrs
      val attrs = if dim then "2" :: attrs else attrs
      val attrs = if bold then "1" :: attrs else attrs
      val attrs = prependOption
        (Option.mapPartial ANSIColor.asBackground background, attrs)
      val attrs = prependOption
        (Option.mapPartial ANSIColor.asForeground foreground, attrs)
    in
      "\027[" ^ String.concatWith ";" attrs ^ "m"
    end
  val resetAll: string = "\027[0m"
end;
