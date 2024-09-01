structure LuaTeXInit : sig
              val createInitializationScript : string * { file_line_error : bool, halt_on_error : bool, output_directory : string, jobname : string } -> unit
          end = struct
val luamod = LunarML.assumeDiscardable (fn () => Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.luatexinit"]) ()
fun createInitializationScript (filename, options : { file_line_error : bool, halt_on_error : bool, output_directory : string, jobname : string })
    = Lua.call0 (Lua.field (luamod, "create_initialization_script")) #[Lua.fromString filename, Lua.unsafeToValue options]
end;
