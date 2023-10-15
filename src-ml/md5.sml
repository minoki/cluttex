signature MD5 = sig
    type hash = Word32.word * Word32.word * Word32.word * Word32.word
    val compute : Word8Vector.vector -> hash
    val hashToLowerHexString : hash -> string
    val hashToUpperHexString : hash -> string
    val md5AsLowerHex : Word8Vector.vector -> string
    val md5AsUpperHex : Word8Vector.vector -> string
end
structure MD5 : MD5 = struct
type hash = Word32.word * Word32.word * Word32.word * Word32.word
infix |>
fun x |> f = f x
val << = Word32.<<
val >> = Word32.>>
val andb = Word32.andb
val orb = Word32.orb
val xorb = Word32.xorb
infix << >> andb orb xorb <<<
fun x <<< y = (x << y) orb (x >> (0w32 - y))
fun F (X, Y, Z) = (X andb Y) orb (Word32.notb X andb Z)
fun G (X, Y, Z) = (X andb Z) orb (Y andb Word32.notb Z)
fun H (X, Y, Z) = X xorb (Y xorb Z)
fun I (X, Y, Z) = Y xorb (X orb Word32.notb Z)
fun Round1 X y = let fun ABCD (k, t) (a, b, c, d) = let val a = b + ((a + F (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w7)
                                                    in (a, b, c, d)
                                                    end
                     fun DABC (k, t) (b, c, d, a) = let val a = b + ((a + F (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w12)
                                                    in (b, c, d, a)
                                                    end
                     fun CDAB (k, t) (c, d, a, b) = let val a = b + ((a + F (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w17)
                                                    in (c, d, a, b)
                                                    end
                     fun BCDA (k, t) (d, a, b, c) = let val a = b + ((a + F (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w22)
                                                    in (d, a, b, c)
                                                    end
                 in y 
                        |> ABCD (0,  0wxd76aa478)
                        |> DABC (1,  0wxe8c7b756)
                        |> CDAB (2,  0wx242070db)
                        |> BCDA (3,  0wxc1bdceee)
                        |> ABCD (4,  0wxf57c0faf)
                        |> DABC (5,  0wx4787c62a)
                        |> CDAB (6,  0wxa8304613)
                        |> BCDA (7,  0wxfd469501)
                        |> ABCD (8,  0wx698098d8)
                        |> DABC (9,  0wx8b44f7af)
                        |> CDAB (10, 0wxffff5bb1)
                        |> BCDA (11, 0wx895cd7be)
                        |> ABCD (12, 0wx6b901122)
                        |> DABC (13, 0wxfd987193)
                        |> CDAB (14, 0wxa679438e)
                        |> BCDA (15, 0wx49b40821)
                 end
fun Round2 X y = let fun ABCD (k, t) (a, b, c, d) = let val a = b + ((a + G (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w5)
                                                    in (a, b, c, d)
                                                    end
                     fun DABC (k, t) (b, c, d, a) = let val a = b + ((a + G (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w9)
                                                    in (b, c, d, a)
                                                    end
                     fun CDAB (k, t) (c, d, a, b) = let val a = b + ((a + G (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w14)
                                                    in (c, d, a, b)
                                                    end
                     fun BCDA (k, t) (d, a, b, c) = let val a = b + ((a + G (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w20)
                                                    in (d, a, b, c)
                                                    end
                 in y 
                        |> ABCD (1,  0wxf61e2562)
                        |> DABC (6,  0wxc040b340)
                        |> CDAB (11, 0wx265e5a51)
                        |> BCDA (0,  0wxe9b6c7aa)
                        |> ABCD (5,  0wxd62f105d)
                        |> DABC (10, 0wx02441453)
                        |> CDAB (15, 0wxd8a1e681)
                        |> BCDA (4,  0wxe7d3fbc8)
                        |> ABCD (9,  0wx21e1cde6)
                        |> DABC (14, 0wxc33707d6)
                        |> CDAB (3,  0wxf4d50d87)
                        |> BCDA (8,  0wx455a14ed)
                        |> ABCD (13, 0wxa9e3e905)
                        |> DABC (2,  0wxfcefa3f8)
                        |> CDAB (7,  0wx676f02d9)
                        |> BCDA (12, 0wx8d2a4c8a)
                 end
fun Round3 X y = let fun ABCD (k, t) (a, b, c, d) = let val a = b + ((a + H (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w4)
                                                    in (a, b, c, d)
                                                    end
                     fun DABC (k, t) (b, c, d, a) = let val a = b + ((a + H (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w11)
                                                    in (b, c, d, a)
                                                    end
                     fun CDAB (k, t) (c, d, a, b) = let val a = b + ((a + H (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w16)
                                                    in (c, d, a, b)
                                                    end
                     fun BCDA (k, t) (d, a, b, c) = let val a = b + ((a + H (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w23)
                                                    in (d, a, b, c)
                                                    end
                 in y
                        |> ABCD (5,  0wxfffa3942)
                        |> DABC (8,  0wx8771f681)
                        |> CDAB (11, 0wx6d9d6122)
                        |> BCDA (14, 0wxfde5380c)
                        |> ABCD (1,  0wxa4beea44)
                        |> DABC (4,  0wx4bdecfa9)
                        |> CDAB (7,  0wxf6bb4b60)
                        |> BCDA (10, 0wxbebfbc70)
                        |> ABCD (13, 0wx289b7ec6)
                        |> DABC (0,  0wxeaa127fa)
                        |> CDAB (3,  0wxd4ef3085)
                        |> BCDA (6,  0wx04881d05)
                        |> ABCD (9,  0wxd9d4d039)
                        |> DABC (12, 0wxe6db99e5)
                        |> CDAB (15, 0wx1fa27cf8)
                        |> BCDA (2,  0wxc4ac5665)
                 end
fun Round4 X y = let fun ABCD (k, t) (a, b, c, d) = let val a = b + ((a + I (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w6)
                                                    in (a, b, c, d)
                                                    end
                     fun DABC (k, t) (b, c, d, a) = let val a = b + ((a + I (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w10)
                                                    in (b, c, d, a)
                                                    end
                     fun CDAB (k, t) (c, d, a, b) = let val a = b + ((a + I (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w15)
                                                    in (c, d, a, b)
                                                    end
                     fun BCDA (k, t) (d, a, b, c) = let val a = b + ((a + I (b, c, d) + Word32VectorSlice.sub (X, k) + t) <<< 0w21)
                                                    in (d, a, b, c)
                                                    end
                 in y
                        |> ABCD (0,  0wxf4292244)
                        |> DABC (7,  0wx432aff97)
                        |> CDAB (14, 0wxab9423a7)
                        |> BCDA (5,  0wxfc93a039)
                        |> ABCD (12, 0wx655b59c3)
                        |> DABC (3,  0wx8f0ccc92)
                        |> CDAB (10, 0wxffeff47d)
                        |> BCDA (1,  0wx85845dd1)
                        |> ABCD (8,  0wx6fa87e4f)
                        |> DABC (15, 0wxfe2ce6e0)
                        |> CDAB (6,  0wxa3014314)
                        |> BCDA (13, 0wx4e0811a1)
                        |> ABCD (4,  0wxf7537e82)
                        |> DABC (11, 0wxbd3af235)
                        |> CDAB (2,  0wx2ad7d2bb)
                        |> BCDA (9,  0wxeb86d391)
                 end
fun c x = String.sub ("0123456789abcdef", Word32.toInt x)
fun cc x = String.implode [c (x >> 0w4), c (x andb 0wxf)]
fun compute (content : Word8Vector.vector) : Word32.word * Word32.word * Word32.word * Word32.word
    = let val content32 : Word32Vector.vector
              = let val origLen = Word8Vector.length content
                    val r = Word8Vector.length content mod 64
                    val padded = Word8Vector.concat [content, Word8Vector.fromList [0wx80], Word8Vector.tabulate (if r < 56 then 63 - r else 127 - r, fn _ => 0w0)]
                    val paddedLen = Word8Vector.length padded
                    (* val (* assert *) true = paddedLen mod 64 = 0 *)
                    val content8 = Word8Array.tabulate (paddedLen, fn i => Word8Vector.sub (padded, i))
                    val () = PackWord64Little.update (content8, paddedLen div 8 - 1, LargeWord.fromInt (8 * origLen))
                in Word32Vector.tabulate (Word8Array.length content8 div 4, fn i => Word32.fromLarge (PackWord32Little.subArr (content8, i)))
                end
          (* val (* assert *) true = Word32Vector.length content32 mod 16 = 0 *)
          val max = Word32Vector.length content32 div 16
          fun loop (i, a, b, c, d)
              = if i >= max then
                    (a, b, c, d)
                else
                    let val X = Word32VectorSlice.slice (content32, i * 16, SOME 16)
                        val (a', b', c', d') = (a, b, c, d) |> Round1 X |> Round2 X |> Round3 X |> Round4 X
                    in loop (i + 1, a + a', b + b', c + c', d + d')
                    end
      in loop (0, 0wx67452301, 0wxefcdab89, 0wx98badcfe, 0wx10325476)
      end
fun word32ToHexString (x : Word32.word) = String.concat [ cc (x andb 0wxff)
                                                        , cc ((x >> 0w8) andb 0wxff)
                                                        , cc ((x >> 0w16) andb 0wxff)
                                                        , cc (x >> 0w24)
                                                        ]
fun hashToLowerHexString (a, b, c, d) = word32ToHexString a ^ word32ToHexString b ^ word32ToHexString c ^ word32ToHexString d
fun hashToUpperHexString h = String.map Char.toUpper (hashToLowerHexString h)
fun md5AsLowerHex content = hashToLowerHexString (compute content)
fun md5AsUpperHex content = hashToUpperHexString (compute content)
end;
(*
print (MD5.md5AsLowerHex (Byte.stringToBytes "") ^ "\n"); (* d41d8cd98f00b204e9800998ecf8427e *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "a") ^ "\n"); (* 0cc175b9c0f1b6a831c399e269772661 *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "abc") ^ "\n"); (* 900150983cd24fb0d6963f7d28e17f72 *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "message digest") ^ "\n"); (* f96b697d7cb7938d525a2f31aaf161d0 *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "abcdefghijklmnopqrstuvwxyz") ^ "\n"); (* c3fcd3d76192e4007dfb496cca67e13b *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz012") ^ "\n"); (* b76972fe0dff4baac395b531646f738e *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123") ^ "\n"); (* 27eca74a76daae63f472b250b5bcff9d *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234") ^ "\n"); (* 7b704b4e3d241d250fd327d433c27250 *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") ^ "\n"); (* d174ab98d277d9f5a5611c2c9f419d9f *)
print (MD5.md5AsLowerHex (Byte.stringToBytes "12345678901234567890123456789012345678901234567890123456789012345678901234567890") ^ "\n"); (* 57edf4a22be3c955ac49da2e2107b67a *)
*)
