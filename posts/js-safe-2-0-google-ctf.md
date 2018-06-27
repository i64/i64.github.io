# JS Safe 2.0 - Google CTF

```
You stumbled upon someone's "JS Safe" on the web. It's a simple HTML file that can store secrets in the browser's localStorage. This means that you won't be able to extract any secret from it (the secrets are on the computer of the owner), but it looks like it was hand-crafted to work only with the password of the owner..
```

[Ek](https://github.com/CyberSaxosTiGER/CyberSaxosTiGER.github.io/blob/master/files/4dead099e841668a8d86e36fcde8099ce134c195da9863dfb9039043d366942d.zip)


Sayfayı incelemeye başlayalım
 
```html
<input id="keyhole" autofocus onchange="open_safe()" placeholder="🔑">
```
id'i **keyhole** olan inputun onchange eventinde **opensafe()** fonksiyonunu çağırdığını görüyoruz. O zaman **opensafe()** fonksiyonuna bakacağız


```js
function open_safe() {
    keyhole.disabled = true;
    password = /^CTF{([0-9a-zA-Z_@!?-]+)}$/.exec(keyhole.value);
    if (!password || !x(password[1])) return document.body.className = 'denied';
    document.body.className = 'granted';
    password = Array.from(password[1]).map(c => c.charCodeAt());
    encrypted = JSON.parse(localStorage.content || '');
    content.value = encrypted.map((c, i) => c ^ password[i % password.length]).map(String.fromCharCode).join('')
}
```

**password** değişkenine **keyhole** içeriğini regex'e göre ayırdığını görüyoruz. 

```
eğer `CTF{ABC}` girersek
`password[0]` =>  `CTF{ABC}`
`password[1]` =>  `ABC`
```

```js
if (!password || !x(password[1])) return document.body.className = 'denied';
```

yani şuanlık **opensafe()** fonksiyonunu bırakıp **x()** fonksiyonuna bakacağız

```js
function x(х) {
    ord = Function.prototype.call.bind(''.charCodeAt);
    chr = String.fromCharCode;
    str = String;

    function h(s) {
        for (i = 0; i != s.length; i++) {
            a = ((typeof a == 'undefined' ? 1 : a) + ord(str(s[i]))) % 65521;
            b = ((typeof b == 'undefined' ? 0 : b) + a) % 65521
        }
        return chr(b >> 8) + chr(b & 0xFF) + chr(a >> 8) + chr(a & 0xFF)
    }

    function c(a, b, c) {
        for (i = 0; i != a.length; i++) c = (c || '') + chr(ord(str(a[i])) ^ ord(str(b[i % b.length])));
        return c
    }
    for (a = 0; a != 1000; a++) debugger;
    x = h(str(x));
    source = /Ӈ#7ùª9¨M¤À.áÔ¥6¦¨¹.ÿÓÂ.Ö£JºÓ¹WþÊmãÖÚG¤¢dÈ9&òªћ#³­1᧨/;
    source.toString = function () {
        return c(source, x)
    };
    try {
        console.log('debug', source);
        with(source) return eval('eval(c(source,x))')
    } catch (e) {}
}

```

kodu incelemeye başladık ve burada bir anti-debugger konulmuş

```js
for (a = 0; a != 1000; a++) debugger;
```

**a=1000** diyip yolumuza devam ediyoruz

```js
x = h(str(x));
```
Diye hileli bir satır var burada. **function x(х)** diye belirtilmiş. **h(str(x))** ve buradaki **x** değişken **x** değil, fonksiyon olan **x** yani **x = h(str(x));** degeri sabit. **x** fonksiyonunu değiştirmeden çalıştırıp **x** değerini çekiyoruz.

Yani x fonksiyonuna paslanan değerin hiçbir önemi yok

**x = h(str(x));**'den sonra **x**'in son hali **[130,30,10,154]** (unicode olduğu için charcode halini yazdık) **a = 2714** ve **b = 33310** olduğunu gözlemledik.

**c** fonksiyonuna **source** değişkenini **x**'in son halini yolladığımızda 

```
c(source,x);

'х==c(\'¢×&Ê´cÊ¯¬$¶³´}ÍÈ´T©Ð8Í³Í|Ô÷aÈÐÝ&¨þJ\',h(х))//᧢'
```

şifreli textimizi öğrendik

```js
c = (c || '') + chr(ord(str(a[i])) ^ ord(str(b[i % b.length])))
```

şifreli texti decrypt etmek için **key**'i bilmemiz gerekiyor. **([0-9a-zA-Z_@!?-]+)** regexine uygun bir şekilde çıktı veren şekilde **xor**'lamamız gerek.

bildiklerimiz 
* key uzunluğunun 4 hane olması
* 0-255 arası range olduğu
* her 4 cycleda keyin tekrar edeceği
* çıktının **([0-9a-zA-Z_@!?-]+)**'e uygun olacağı

yapılacaklar

* regex'e uygun char listesi oluşturmak
* 4 defa dönecek bir for
* 255 defa dönecek diğer bir for

eğer key 4 defada bir tekrar ediyorsa her defasında aynı keyi denemeye her 4. karakterde aynı keyi deniyerek false positive oranını düşürürüz


```python
encrypted_text = (162, 215, 38, 129, 202, 180, 99, 202, 175, 172, 36, 182, 179, 180, 125, 205, 200, 180, 84, 151, 169, 208, 56, 205, 179, 205, 124, 212, 156, 247, 97, 200, 208, 221, 38, 155, 168, 254, 74)
```

```python
valid_char_range = [ord(char) for char in (string.ascii_letters + string.digits  + '_@!?-')]
```

```python
for needle in range(4):
    choices = list(range(256))
    for encrypted_chunk in encrypted_text[needle::4]:
        choices = [
            choice 
            for choice in choices
            if (choice ^ encrypted_chunk) in valid_char_range
        ]
    print("key:", choices)
```

çıktı ise

```
key: [253]
key: [149, 153]
key: [21]
key: [249]
```

**c** fonksiyonun sifreli texti ve keyi yolladigimizda

```js
> key = ''.join((253, 153, 21, 249))
> c(encrypted_text, key)

'_N3x7-v3R51ON-h45-AnTI-4NTi-ant1-D3bUg_'
```

Ve flag


`CTF{_N3x7-v3R51ON-h45-AnTI-4NTi-ant1-D3bUg_}`