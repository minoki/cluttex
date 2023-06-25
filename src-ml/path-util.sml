structure PathUtil : sig
              val basename : string -> string
              val dirname : string -> string
              val parentdir : string -> string
              val trimext : string -> string
              val ext : string -> string
              val replaceext : { path : string, newext : string } -> string
              val join2 : string * string -> string
              val join : string list -> string
              val abspath : { path : string, cwd : string } -> string
          end = struct
val luamod = LunarML.assumeDiscardable (fn () => Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.shellutil"]) ()
val basename : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "basename"))) ()
val dirname : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "dirname"))) ()
val parentdir : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "parentdir"))) ()
val trimext : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "trimext"))) ()
val ext : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "ext"))) ()
fun replaceext { path : string, newext : string } : string = Lua.unsafeFromValue (Lua.call1 (Lua.field (luamod, "replaceext")) #[Lua.fromString path, Lua.fromString newext])
fun join2 (x : string, y : string) : string = Lua.unsafeFromValue (Lua.call1 (Lua.field (luamod, "join")) #[Lua.fromString x, Lua.fromString y])
fun join (xs : string list) : string = Lua.unsafeFromValue (Lua.call1 (Lua.field (luamod, "join")) (Vector.map Lua.fromString (Vector.fromList xs)))
fun abspath { path : string, cwd : string } : string = Lua.unsafeFromValue (Lua.call1 (Lua.field (luamod, "abspath")) #[Lua.fromString path, Lua.fromString cwd])
end;
