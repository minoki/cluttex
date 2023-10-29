structure OSUtil : sig
              val isWindows : bool
              val setEnv : string * string -> unit
          end = struct
val isWindows = LunarML.assumeDiscardable (fn () => Lua.== (Lua.field (Lua.Lib.os, "type"), Lua.fromString "windows")) ()
val os_setenv = LunarML.assumeDiscardable Lua.field (Lua.Lib.os, "setenv")
fun setEnv (name, value) = Lua.call0 os_setenv #[Lua.fromString name, Lua.fromString value]
end;
