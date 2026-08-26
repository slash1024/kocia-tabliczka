# Kocia Tabliczka — uruchomienie

Aplikacja do nauki tabliczki mnożenia z Kawką i Watkiem.
Działa w dwóch trybach:

* **lokalny** — nic nie konfigurujesz, postęp zostaje na jednym urządzeniu;
* **z kontami** — telefon dziecka wysyła postęp do chmury, telefon rodzica go podgląda.

---

## A. Tylko lokalnie (5 minut)

1. Wrzuć zawartość tego folderu na dowolny hosting HTTPS
   (najprościej: `app.netlify.com/drop`, przeciągasz **folder**, nie zip).
2. Otwórz otrzymany adres w Chrome na Androidzie → menu ⋮ → **Zainstaluj aplikację**.

Gotowe. Plik `config.js` zostawiasz pusty.

---

## B. Z kontami i podglądem dla rodzica

### 1. Załóż projekt w Supabase
1. `supabase.com` → **Start your project** → zaloguj się przez GitHub.
2. **New project**: nazwa dowolna, region najbliższy (Frankfurt), hasło do bazy zapisz.
3. Poczekaj ~2 minuty, aż projekt wstanie.

### 2. Wgraj schemat bazy
1. W menu po lewej: **SQL Editor** → **New query**.
2. Wklej całą zawartość pliku `supabase-schema.sql` i kliknij **Run**.
3. Powinno pojawić się „Success. No rows returned”.

### 3. Włącz logowanie anonimowe
**Authentication → Sign In / Providers → Anonymous Sign-Ins → Enable.**
Dzięki temu dziecko nie zakłada konta ani nie podaje maila — urządzenie dostaje własną tożsamość.

### 4. Wklej klucze do aplikacji
1. **Project Settings → API**.
2. Skopiuj **Project URL** oraz klucz **anon public**.
3. Wklej je do pliku `config.js`:

```js
window.KOCIA_CONFIG = {
  SUPABASE_URL: "https://twojprojekt.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOi..."
};
```

Klucz `anon` jest przeznaczony do publikacji — dostęp do danych pilnują reguły RLS z pliku SQL.
Nigdy nie wklejaj tu klucza `service_role`.

### 5. Wgraj folder na hosting
Tak jak w wariancie A.

### 6. Połącz telefony
1. **Telefon dziecka**: otwórz aplikację → „To telefon dziecka” → wpisz imię.
   W **Ustawieniach → Konto** pojawi się sześcioznakowy **kod rodzinny**.
2. **Telefon rodzica**: ta sama aplikacja → „Jestem rodzicem” → **Dodaj dziecko** → wpisz kod.
3. Po każdej rundzie postęp leci do chmury. Rodzic widzi mur, celność, serię dni,
   minuty, uciekinierów i ostatnie rundy.

---

## C. Plik APK

1. Wejdź na `pwabuilder.com`, podaj adres swojej strony.
2. **Package for stores → Android → Download package**.
3. W paczce znajdziesz `app-release-signed.apk` oraz `assetlinks.json`.
4. Plik `assetlinks.json` wrzuć na hosting do podfolderu `.well-known/`
   i wgraj folder ponownie. Sprawdź adres
   `twoja-strona/.well-known/assetlinks.json` — musi się otwierać.
5. Przenieś APK na telefon i zainstaluj (Android poprosi o zgodę na instalację
   z tego źródła).

**Zachowaj plik `signing.keystore` i hasła** z paczki PWABuilder — bez nich nie
zaktualizujesz aplikacji, trzeba by ją odinstalować.

---

## Aktualizacje

Po każdej zmianie w plikach podnieś numer wersji w pierwszej linii `sw.js`
(`kocia-tabliczka-v2` → `v3`) i wgraj folder ponownie. APK zostaje ten sam.

## Prywatność

* Bez `config.js` aplikacja nie wysyła nigdzie żadnych danych.
* Z kontami: w chmurze ląduje postęp nauki i imię. Bez maila, bez hasła, bez numeru telefonu.
* Reguły RLS pozwalają czytać postęp dziecka wyłącznie kontu rodzica z tej samej rodziny.
* Kod rodzinny działa jak zaproszenie — kto go zna, dołączy do rodziny. W razie wycieku
  usuń wiersz z tabeli `families` w Supabase i utwórz nową rodzinę.
