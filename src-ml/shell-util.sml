structure ShellUtil : sig
              val escape : string -> string
              val has_command : string -> bool
          end = struct
val luamod = LunarML.assumeDiscardable (fn () => Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.shellutil"]) ()
val escape : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "escape"))) ()
val has_command : string -> bool = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "has_command"))) ()
end;
