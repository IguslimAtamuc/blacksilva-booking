BLACK SILVA — SHOP FOLDER
==========================

Aici pui produsele din magazin.

1) POZELE
   Pune pozele în acest folder „shop", denumite image1, image2, image3 ...
     shop/image1.jpg
     shop/image2.jpg
     shop/image3.jpg
   (merg .jpg, .png sau .webp — recomandat pătrate, ex. 800x800)

2) PREȚURILE și NUMELE
   Deschide fișierul „products.js" din acest folder.
   Pentru fiecare produs schimbi:
     img   -> numele fișierului pozei (ex: 'shop/image1.jpg')
     name  -> numele produsului
     price -> prețul (ex: '199 DKK')

   Produsele apar pe site în ORDINEA din listă.
   - Adaugi un produs: copiezi o linie și o modifici.
   - Ștergi un produs: ștergi linia lui.

   ATENȚIE: păstrează ghilimelele ' ' la fiecare valoare și virgula la finalul liniei.

3) UPLOAD
   Urcă tot folderul „shop" (cu products.js + pozele) lângă index.html,
   în public_html. Gata — apar automat în pagina Shop.

Până pui pozele, produsele apar cu un chenar „Add photo" și cu numele/prețul din products.js.
