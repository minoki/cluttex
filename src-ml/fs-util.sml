structure FSUtil : sig
              val copyCommand : { from : string, to : string } -> string
              val isFile : string -> bool
              val isDirectory : string -> bool
              val mkDirRec : string -> unit
              val removeRec : string -> unit
              val touch : string -> unit
          end = struct
val lfs = LunarML.assumeDiscardable (fn () => Lua.call1 Lua.Lib.require #[Lua.fromString "lfs"]) ()
val luamod = LunarML.assumeDiscardable (fn () => Lua.call1 Lua.Lib.require #[Lua.fromString "texrunner.fsutil"]) ()
fun copyCommand { from, to } : string = Lua.unsafeFromValue (Lua.call1 (Lua.field (luamod, "copy_command")) #[Lua.fromString from, Lua.fromString to])
val isFile : string -> bool = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "isfile"))) ()
val isDirectory : string -> bool = LunarML.assumeDiscardable (fn () => Lua.unsafeFromValue (Lua.field (luamod, "isdir"))) ()
fun mkDirRec path = let val (succ, err) = Lua.call2 (Lua.field (luamod, "mkdir_rec")) #[Lua.fromString path]
                    in if Lua.isFalsy succ then
                           raise Lua.Error err
                       else
                           ()
                    end
fun removeRec path = let val (succ, err) = Lua.call2 (Lua.field (luamod, "remove_rec")) #[Lua.fromString path]
                     in if Lua.isFalsy succ then
                            raise Lua.Error err
                        else
                            ()
                     end
fun touch path = let val (succ, err) = Lua.call2 (Lua.field (lfs, "touch")) #[Lua.fromString path]
                 in if Lua.isFalsy succ then
                        raise Lua.Error err
                    else
                        ()
                 end
end;
