structure ShellUtil : sig
              val escape : string -> string
              val hasCommand : string -> bool
              val cd : string
          end = struct
val luamod = LunarML.assumeDiscardable (fn () => Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.shellutil"]) ()
val escape : string -> string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "escape"))) ()
val hasCommand : string -> bool = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "has_command"))) ()
val cd : string = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "cd"))) ()
end;
