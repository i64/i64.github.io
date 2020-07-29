# Unpacking pyarmor - Soder CTF

el konulan kitabim Introduction to Computer Theory'in namusunu kurtarmak icin yazilan bir yazi. temelde packli pyarmor uygulamasini unpack eylemeyi anlatmaktadir.

## analiz

program calisitirildigi vakit cikti vermiyor.
```shell
> ./SierraTwo_V2.exe
```
hizlica bilindik bir string var mi diye kontrol etmek icin hata mesajlari icin ufak bir grep atmak bazen iyi bir fikir olabilir.

```shell
[0x140008b14]> iz ~ Err
1    0x00021df8 0x1400233f8 38   39   .rdata  ascii   Error allocating decompression buffer\n
3    0x00021e28 0x140023428 26   27   .rdata  ascii   Error %d from inflate: %s\n
4    0x00021e48 0x140023448 30   31   .rdata  ascii   Error %d from inflateInit: %s\n
8    0x00021ec8 0x1400234c8 23   24   .rdata  ascii   Error decompressing %s\n
18   0x00021fa0 0x1400235a0 15   16   .rdata  ascii   Error on file\n.
21   0x00021fc8 0x1400235c8 35   36   .rdata  ascii   Error allocating memory for status\n
23   0x00022010 0x140023610 25   26   .rdata  ascii   Error opening archive %s\n
25   0x00022040 0x140023640 17   18   .rdata  ascii   Error copying %s\n
31   0x000220a8 0x1400236a8 20   21   .rdata  ascii   Error extracting %s\n
142  0x00022f38 0x140024538 31   32   .rdata  ascii   Error loading Python DLL '%s'.\n
154  0x00023110 0x140024710 34   35   .rdata  ascii   Error detected starting Python VM.
173  0x00023310 0x140024910 30   31   .rdata  ascii   Error creating child process!\n
```

142 numarali string bize bunun pyinstaller oldugunu dusundurdu.
```shell
[0x140008b14]> iz ~ PyInstaller
177  0x00023370 0x140024970 35   36   .rdata  ascii   PyInstaller: FormatMessageW failed.
178  0x00023398 0x140024998 44   45   .rdata  ascii   PyInstaller: pyi_win32_utils_to_utf8 failed.
```
tahminimizde dogru ciktik. yani yanilmiyormusuz. pyinstaller kullaniyor ise [`pyinstxtractor`](https://github.com/extremecoders-re/pyinstxtractor) yardimi ile icindeki [pyc](https://www.python.org/dev/peps/pep-3147/) dosylarini edinebiliriz.

```shell
> python3.8 pyinstxtractor.py SierraTwo_V2.exe
[+] Processing SierraTwo_V2.exe
[+] Pyinstaller version: 2.1+
[+] Python version: 38
[+] Length of package: 10795430 bytes
[+] Found 976 files in CArchive
[+] Beginning extraction...please standby
[+] Possible entry point: pyiboot01_bootstrap.pyc
[+] Possible entry point: pyi_rth__tkinter.pyc
[+] Possible entry point: pyi_rth_multiprocessing.pyc
[+] Possible entry point: SierraTwo.pyc
[+] Found 399 files in PYZ archive
[+] Successfully extracted pyinstaller archive: SierraTwo_V2.exe

You can now use a python decompiler on the pyc files within the extracted directory
```

cikarttigimmiz dosyayi calistirmak istedigimiz vakit **pytransform** modulunu bulamadigini belirtiyor.

```shell    
SierraTwo_V2.exe_extracted> python3.8 SierraTwo.pyc
Traceback (most recent call last):
  File "dist\obf\SierraTwo.py", line 2, in <module>
ModuleNotFoundError: No module named 'pytransform'
```

**pytransform** ismi aslinda tanidik bir isim. python bytecode packeri olan pyarmor'a ait runtime kutuphanesinin adi. bunu hizlica grepleyip teyit etme imkanimiz bulunmakta.

```shell
>> grep -rn pyarmor
Binary file PYZ-00.pyz_extracted/config.pyc matches
Binary file PYZ-00.pyz_extracted/pytransform.pyc matches
Binary file SierraTwo.pyc matches
Binary file _pytransform.dll matches
```

## aksiyon alimi
kendi [dokumantasyonlarinda](https://pyarmor.readthedocs.io/en/latest/how-to-do.html) bulunan dosya hiyerarsisini olusturarak ise koyulabiliriz. 
```
SierraTwo.pyc
pytransform/
    __init__.py
    _pytransform.so
```

**__init__.py** dosyasini ise pyinstallerdan cikan **pytransform.pyc** ile degistirecegiz.

simdi dosyamizi calsitirabiliyor olmamiz gerekiyor.
```shell
>> python3.8 .\SierraTwo.pyc
Traceback (most recent call last):
  File "<dist\obf\SierraTwo.py>", line 4, in <module>
  File "<frozen SierraTwo>", line 21, in <module>
ModuleNotFoundError: No module named 'slack'
```

cok sansliyiz ki kutuphane bagimli bir kod cikti. **kutuphane bagimliligi** = **library hijacking** slack.py diye bir dosya olusturup icine istedigimiz icerigi koyabiliriz. 
oncelikle import edildigimizden dolayi callstack'te alakali frame'e gidip etrafi yoklamamiz gerekiyor. bundan dolayi oncelik ile frameleri yoklayalim.
burada bilgilendirici olsun diye inspect ile yapiyorum yoksa **import pdb; pdb.set_trace()** denilip bir pdb shelli spawnlanabilir.

```python
import inspect

for frameinfo in inspect.stack():
    print(frameinfo.frame)
```

```python
<frame at 0x000001FA7D4BB1E0, file 'asykrem\\slack.py', line 7, code <module>>
<frame at 0x000001FA7D497550, file '<frozen importlib._bootstrap>', line 219, code _call_with_frames_removed>
<frame at 0x000001FA7D488900, file '<frozen importlib._bootstrap_external>', line 783, code exec_module>
<frame at 0x000001FA7D438BE0, file '<frozen importlib._bootstrap>', line 671, code _load_unlocked>
<frame at 0x000001FA7D48C440, file '<frozen importlib._bootstrap>', line 975, code _find_and_load_unlocked>
<frame at 0x000001FA7D4389F0, file '<frozen importlib._bootstrap>', line 991, code _find_and_load>
<frame at 0x000001FA7D4971F0, file '<frozen SierraTwo>', line 21, code <module>>
<frame at 0x000001FA7D12B440, file 'dist\\obf\\SierraTwo.py', line 4, code <module>>
```

bizi alakadar eden frame'in 0x000001FA7D4971F0'te ki frame oldugu bariz goruluyor. bundan mutevellit bu frame'i incelemek uzere bir yerlere tutturabiliriz.

```python
frame = inspect.stack()[6]
```

bildigimiz python'da bytecode'ta kullanilmak uzere degisken isimleri ve constant degerleri kod objesi ile birlikte geliyor.
yani constant degerler(fonksiyonlar gibi) hala kodumuzun icinde olabilir.

```python
c = frame.f_code

for idx, obj in enumerate(c.co_consts):
    if inspect.iscode(obj):
        print(idx, obj.co_name)
```
```shell
5 prepare_shell
7 create_channel
9 next_channel
11 machine_info
15 uploader_thread
17 upload
19 respawn
21 handle_user_input
23 commands
25 listen
27 hide_process
32 protect_pytransform
```

daha sonra ise bu fonksiyonlarda ki degiskenleri bastirabilirsek belki yararli bir seyler elde edebiliriz.
    
```python
for idx, obj in enumerate(c.co_consts):
    if inspect.iscode(obj):
        print(idx, obj.co_name, obj.co_consts)
```

```python
5 prepare_shell (None, 'channels', 'channel', 'id', ('channel', 'users'), ('channel', 'text'), ('channel',), 'messages', 0, 'ts', ('channel', 'timestamp'))
7 create_channel (None, ('name',))
9 next_channel (None, 0, 'name', '-', 2, 1)
11 machine_info (None, '', 'Windows', 'wmic csproduct get UUID', ' ', 5, 'Linux', 'cat', '/etc/machine-id', 'Darwin', 'ioreg', '-d2', '-c', 'IOPlatformExpertDevice', '|', 'awk', '-F', "'/IOPlatformUUID/{print $(NF-1)}'", 'unknown', '`', '` with the `', '` UUID connected.')
15 uploader_thread (None, '', True, ('file', 'channels', 'filename', 'title'), 'Uploaded `', '`', 'File not found.', False)
17 upload (None, True, ('target', 'daemon', 'args'), 'Please wait while your file is uploaded.', ('channel', 'text'), 'Cannot start uploader thread')
19 respawn (None, '', 'b0', '9b', 'b1', '21', '6e', '10', '40', '3c', '72', '23', '6f', '16', 'af', '14', '1a', '64', '12', 'c8', '5b', 'a6', '69', 'b4', '6d', '74', 'a2', 'cf', '62', '52', '58', '30', 'e0', '65', 'db', '1e', '56', '73', 'c4', 'c2', '7e', '20', '24', '8e', 'ce', '42', '17', '9a', '87', 'fb', 'dd', 'eb', 'ea', '25', 'aa', 'fa', 'a9', '2e', '78', 'de', '66', '00', '85', 'dc', '36', '32', '59', 'ae', '3a', '2b', '29', 'da', 'd5', 'f5', '2f', '2c', 'fe', 'cd', '2a', '90', 'e6', '18', '75', '26', '68', '2d', 'be', '35', 'd0', '5a', '31', '22', '5f', '76', '27', 'e1', '91', '45', '63', '94', '5d', '4c', '15', 'ff', 'e2', '5e', '28', '61', 'ee', 'f6', '08', 'c3', 'c7', 'b6', 'b5', '02', '55', 'ef', 'd9', '04', 'ad', <code object varxor at 0x0000023226DFF5B0, file "<frozen SierraTwo>", line 400>, 'respawn.<locals>.varxor', '__main__', 1, 37, 'a', 'b', 'z')
21 handle_user_input (None, '', 'Error reading command output.', ('channel', 'text'), 'The command did not return anything.', '`', 'Output contains an illegal character.', 0, <code object <listcomp> at 0x0000023226DFF660, file "<frozen SierraTwo>", line 440>, 'handle_user_input.<locals>.<listcomp>', '```', 'Output size is too big. If you are trying to read a file, try uploading it.', 'Unknown error.')
23 commands (None, 'upload', ' ', 1, 'cd', '`cd` complete.', ('channel', 'text'), 'shell_exit', 0)
25 listen (None, '', 'randomval', ('channel',), 0.8, 'messages', 0, 'client_msg_id', 'text', 0.3)
27 hide_process (None, 0, 'taskkill /PID ', ' /f')
32 protect_pytransform (None, 0, <code object assert_builtin at 0x0000023226DFF9D0, file "<frozen SierraTwo>", line 530>, 'protect_pytransform.<locals>.assert_builtin', <code object check_obfuscated_script at 0x0000023226DFFB30, file "<frozen SierraTwo>", line 536>, 'protect_pytransform.<locals>.check_obfuscated_script', <code object check_mod_pytransform at 0x0000023226DFFC90, file "<frozen SierraTwo>", line 545>, 'protect_pytransform.<locals>.check_mod_pytransform', <code object check_lib_pytransform at 0x0000023226DFFD40, file "<frozen SierraTwo>", line 559>, 'protect_pytransform.<locals>.check_lib_pytransform')
```

bir miktar supheli bir veri bulduk gibi.

```python
19 respawn (None, '', 'b0', '9b', 'b1', '21', '6e', '10', '40', '3c', '72', '23', '6f', '16', 'af', '14', '1a', '64', '12', 'c8', '5b', 'a6', '69', 'b4', '6d', '74', 'a2', 'cf', '62', '52', '58', '30', 'e0', '65', 'db', '1e', '56', '73', 'c4', 'c2', '7e', '20', '24', '8e', 'ce', '42', '17', '9a', '87', 'fb', 'dd', 'eb', 'ea', '25', 'aa', 'fa', 'a9', '2e', '78', 'de', '66', '00', '85', 'dc', '36', '32', '59', 'ae', '3a', '2b', '29', 'da', 'd5', 'f5', '2f', '2c', 'fe', 'cd', '2a', '90', 'e6', '18', '75', '26', '68', '2d', 'be', '35', 'd0', '5a', '31', '22', '5f', '76', '27', 'e1', '91', '45', '63', '94', '5d', '4c', '15', 'ff', 'e2', '5e', '28', '61', 'ee', 'f6', '08', 'c3', 'c7', 'b6', 'b5', '02', '55', 'ef', 'd9', '04', 'ad', <code object varxor at 0x0000023226DFF5B0, file "<frozen SierraTwo>", line 400>, 'respawn.<locals>.varxor', '__main__', 1, 37, 'a', 'b', 'z')
```
sonucta bu fonksiyon bir codeobject. yani exec calistirabiliriz.

```python
frame = inspect.stack()[6].frame
respawn = frame.f_code.co_consts[19]
print(exec(respawn))
```
```
None
```
ama uzucu bir sekilde bu fonksiyon bize bir sey dondurmuyor. [**dis**](https://docs.python.org/3/library/dis.html) kutuphanesini kullanarak bytecode'u disassemble edebiliriz.

```python
import dis
dis.dis(respawn)
```

```python
167           0 JUMP_ABSOLUTE           18
              2 NOP

168           4 NOP
        >>    6 POP_BLOCK

169           8 BEGIN_FINALLY
             10 NOP

170          12 NOP
             14 EXTENDED_ARG             4

171          16 JUMP_ABSOLUTE         1066
        >>   18 LOAD_GLOBAL              2 (__armor_enter__)

172          20 CALL_FUNCTION            0
             22 POP_TOP

173          24 NOP
             26 NOP

174          28 EXTENDED_ARG             4
             30 SETUP_FINALLY         1034 (to 1066)

175          32 INPLACE_POWER
             34 NOP

176     >>   36 MAP_ADD                 40
             38 <222>                  175
                ...
                ...
                ...
                ...
Traceback (most recent call last):
  File "<dist\obf\SierraTwo.py>", line 4, in <module>
  File "<frozen SierraTwo>", line 21, in <module>
  File "ayskrem\slack.py", line 38, in <module>
    dis.dis(respawn)
  File "xi\git\c\cpython\lib\dis.py", line 79, in dis
    _disassemble_recursive(x, file=file, depth=depth)
  File "xi\git\c\cpython\lib\dis.py", line 373, in _disassemble_recursive
    disassemble(co, file=file)
  File "xi\git\c\cpython\lib\dis.py", line 369, in disassemble
    _disassemble_bytes(co.co_code, lasti, co.co_varnames, co.co_names,
  File "xi\git\c\cpython\lib\dis.py", line 401, in _disassemble_bytes
    for instr in _get_instructions_bytes(code, varnames, names,
  File "xi\git\c\cpython\lib\dis.py", line 340, in _get_instructions_bytes
    argval, argrepr = _get_name_info(arg, names)
  File "xi\git\c\cpython\lib\dis.py", line 304, in _get_name_info
    argval = name_list[name_index]
IndexError: tuple index out of range
```

fakat malesef hayal kirikligina ugradik. pyarmor'un dokumantasyonuna bakar isek bunun [wrap-mode](https://pyarmor.readthedocs.io/en/latest/mode.html?highlight=__armor_enter__#wrap-mode) ozelligi oldugunu gorebiliriz

```python
LOAD_GLOBALS    N (__armor_enter__)     N = length of co_consts
CALL_FUNCTION   0
POP_TOP
SETUP_FINALLY   X (jump to wrap footer) X = size of original byte code

Here it's obfuscated bytecode of original function

LOAD_GLOBALS    N + 1 (__armor_exit__)
CALL_FUNCTION   0
POP_TOP
END_FINALLY
```
su yapiya gore **__armor_enter__** kendi referansini alip aradaki bytecode araligini guncelliyor.

bu durumda yapabilecegimiz iki durum var. ilki cpython'a ufak bir patch atmak digeri ise extension'u/library'i reverslemek. buyuk ihtimalle cpython'u patchlemek daha kolay ve hizli olacaktir.

cpython'da bildigimiz uzere bytecode'lar **ceval.c** uzerinde isleniyor. sorunumuz polimorfik bir codeobject oldugundan dolayi sadece calisan bytecodelari dumplayacagiz. yani switch_case'den hemen once byte-codelari dumplamamiz yeterlidir.

```diff
@@ -759,6 +759,11 @@ _PyEval_EvalFrameDefault(PyFrameObject *f, int throwflag)
     _Py_atomic_int * const eval_breaker = &ceval->eval_breaker;
     PyCodeObject *co;

+    FILE *a_logger;
+    int logger_flag;
+    if ((logger_flag = PyUnicode_CompareWithASCIIString(f->f_code->co_name, "respawn") == 0)) {
+        a_logger = fopen("xi\respawn.bin", "wb");
+    }
     /* when tracing we set things up so that

            not (instr_lb <= current_bytecode_offset < instr_ub)
@@ -1077,9 +1082,12 @@ _PyEval_EvalFrameDefault(PyFrameObject *f, int throwflag)
 /* Start of code */

     /* push frame */
-    if (Py_EnterRecursiveCall(""))
+    if (Py_EnterRecursiveCall("")){
+        if (logger_flag) {
+            fclose(a_logger);
+       }
         return NULL;
-
+    }
     tstate->frame = f;

     if (tstate->use_tracing) {
@@ -1319,6 +1327,16 @@ main_loop:
             }
         }
 #endif
+       if (logger_flag) {
+          if (HAS_ARG(opcode)) {
+               fputc(opcode, a_logger);
+               fputc(oparg, a_logger);
+          }
+           else {
+              fputc(opcode, a_logger);
+              fputc(0, a_logger);
+          }
+       }

         switch (opcode) {

@@ -3813,7 +3831,9 @@ exit_eval_frame:
     Py_LeaveRecursiveCall();
     f->f_executing = 0;
     tstate->frame = f->f_back;
-
+    if (logger_flag){
+       fclose(a_logger);
+    }
     return _Py_CheckFunctionResult(NULL, retval, "PyEval_EvalFrameEx");
 }
```

peki kodumuzu guncelledik. respawn fonksiyonunu bir defa calistirmamiz gerekiyor.

```python
exec(respawn)
```

simdi **respawn.bin** dosyasina goz atabiliriz.

```python
dis.dis(respawn.replace(co_code=open("respawn.bin", "rb").read()), depth=0)
```

```python
167           0 JUMP_ABSOLUTE           18
              2 LOAD_GLOBAL              2 (__armor_enter__)

168           4 CALL_FUNCTION            0
        >>    6 POP_TOP

169           8 NOP
             10 NOP

170          12 EXTENDED_ARG             4
             14 SETUP_FINALLY         1034 (to 1050)

171          16 LOAD_CONST               1 ('')
        >>   18 STORE_FAST               0 (z2)

172          20 LOAD_CONST               2 ('b0')
             22 STORE_FAST               1 (t6)

173          24 LOAD_CONST               3 ('9b')
             26 STORE_FAST               2 (f23)

174          28 LOAD_CONST               4 ('b1')
             30 STORE_FAST               3 (u46)
                ...
                ...
                ...
            938 STORE_FAST             229 (a67)
            940 LOAD_CONST             121 (<code object varxor at 0x000001E90F0FF5B0, file "<frozen SierraTwo>", line 400>)

407         942 LOAD_CONST             122 ('respawn.<locals>.varxor')
            944 MAKE_FUNCTION            0

408         946 STORE_FAST             230 (varxor)
            948 LOAD_GLOBAL              0 (__name__)
            950 LOAD_CONST             123 ('__main__')
            952 COMPARE_OP               2 (==)
            954 EXTENDED_ARG             4

409         956 POP_JUMP_IF_FALSE     1062
            958 LOAD_CONST               0 (None)
            960 JUMP_ABSOLUTE            6
            962 POP_BLOCK
            964 BEGIN_FINALLY
            966 NOP
            968 NOP
            970 EXTENDED_ARG             4

410         972 JUMP_ABSOLUTE         1066
            974 LOAD_GLOBAL              3 (__armor_exit__)
            976 CALL_FUNCTION            0
            978 POP_TOP
            980 END_FINALLY
            982 RETURN_VALUE
```

varxor'ada bakalim fakat varxor'da packli. tekrardan dumplamaya eriniyorsak(-ki ben erindim) elimizle bir kac deneme yapabiliriz.

```python
def varxor(a, b): pass
varxor.__code__ = respawn.co_consts[respawn.co_consts.index('ad') + 1]

>>> varxor(1, 2)
*** TypeError: 'int' object is not iterable
>>> varxor('1', '2')
'3'
>>> varxor('23123AB', 'F0')
'd3'
>>> varxor('23123AB', '')
''
```
yani varxor kabaca bize hexstring xor yapiyor. suanlik boyle kabul edilebilir gibi. hata olursa tekrar bir goz atariz

```python
lambda a, b: a and b and hex(int(a, 16) ^ int(b, 16))[2:]
```

bayagi bir degisken olsuturduktan sonra eger main ise calistirdigi bir kisim bulunuyor. bundan dolayi onu main olduguna dair ikna etmemiz gerekiyor.

```python
exec(respawn, exec(respawn, {"__name__": "__main__"}))
dis.dis(respawn.replace(co_code=open("respawn.bin", "rb").read()), depth=0)
```

(kodun tamami degil, sadece eksik kismi budur)
```python
408         946 STORE_FAST             230 (varxor)
            948 LOAD_GLOBAL              0 (__name__)
            950 LOAD_CONST             123 ('__main__')
            952 COMPARE_OP               2 (==)
            954 EXTENDED_ARG             4

409         956 POP_JUMP_IF_FALSE     1062
            958 LOAD_CONST             124 (1)
            960 STORE_FAST             231 (i)
            962 LOAD_FAST              231 (i)
            964 LOAD_CONST             125 (37)
            966 COMPARE_OP               1 (<=)
            968 EXTENDED_ARG             4
            970 POP_JUMP_IF_FALSE     1062

410         972 LOAD_GLOBAL              1 (locals)
            974 CALL_FUNCTION            0
            976 LOAD_CONST             126 ('a')
        >>  978 LOAD_FAST              231 (i)
            980 FORMAT_VALUE             0
            982 BUILD_STRING             2
            984 BINARY_SUBSCR
            986 STORE_FAST             232 (a)

411         988 LOAD_GLOBAL              1 (locals)
            990 CALL_FUNCTION            0
            992 LOAD_CONST             127 ('b')
            994 LOAD_FAST              231 (i)
            996 FORMAT_VALUE             0
            998 BUILD_STRING             2
           1000 BINARY_SUBSCR
           1002 STORE_FAST             233 (b)

413        1004 LOAD_GLOBAL              1 (locals)
           1006 CALL_FUNCTION            0
           1008 LOAD_CONST             128 ('z')
           1010 LOAD_FAST              231 (i)
           1012 FORMAT_VALUE             0
           1014 BUILD_STRING             2
           1016 BINARY_SUBSCR

415        1018 STORE_FAST             234 (z)
           1020 LOAD_FAST              234 (z)
           1022 LOAD_FAST              230 (varxor)
           1024 LOAD_FAST              232 (a)
           1026 LOAD_FAST              233 (b)
           1028 CALL_FUNCTION            2
           1030 INPLACE_ADD
           1032 STORE_FAST             234 (z)
           1034 LOAD_FAST              231 (i)
           1036 LOAD_CONST             124 (1)
           1038 INPLACE_ADD
           1040 STORE_FAST             231 (i)
           1042 EXTENDED_ARG             3
           1044 JUMP_ABSOLUTE          978
```

yukaridaki bytecodun tahmini karsiligi su sekilde
```python
while i <= 37:
    a = locals()[f"a{i}"]
    b = locals()[f"b{i}"]
    z = locals()[f"z{i}"]
    z += varxor(a, b)
    i += 1
```

locals dinamik bir yapi fakat degiskenlere sadece bir defa atama gerceklestiriliyor. **dis** kutuphanesinden **get_instruction** fonksiyonunu kullanip kod uzerinden hizlica construct edilebilir

```python
STORE_FAST = opcode.opmap["STORE_FAST"]
LOAD_CONST = opcode.opmap["LOAD_CONST"]

result = ""
_locals = dict()

for instruction in dis.get_instructions(respawn.replace(co_code=open("respawn.bin", "rb").read())):
    if instruction.opcode == STORE_FAST:
        _locals[instruction.argval] = last.argval 
    elif instruction.opcode == LOAD_CONST:
        last = instruction

for i in range(1, 37):
    a = _locals[f"a{i}"]
    b = _locals[f"b{i}"]
    z = _locals[f"z{i}"]
    result += z + (a and b and hex(int(a, 16) ^ int(b, 16))[2:])

print(bytearray.fromhex(result[:-1]).decode())
```

ve flag
```
flag{S3ri0uSlY_Y0u_s0Lv3D_tH1s_t00}
```

#### bu arada gunumun cogunlugunu gecirdigim cpython'u ogrenmeme vesile olan big code'a tesekkurlerimi iletiyorum