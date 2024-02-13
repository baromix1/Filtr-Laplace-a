COMMENT @
Temat: Filtr Laplace'a
Autor: Bartosz Ziarnik
Wersja: 1.0
@
;-------------------------------------------------------------------------
.DATA
; Zmienne
Maski BYTE 9 DUP (?) ; Maski filtru
PrzesuniecieZnakow BYTE 16 DUP (10000000y)	; Do sumowania masek z uwzglêdnieniem znaku
ileFiltrowac dq 0; ile pixeli ma przefiltrowac procedura

.CODE
; Kod Ÿród³owy procedur

ObliczNowaWartoscPikselaClamped PROC
    ; Procedura obliczaj¹ca now¹ wartoœæ piksela (tylko w jednym kolorze w ci¹gu jednego wywo³ania - R, G lub B) na podstawie pikseli u³o¿onych w siatkê 3x3.
    ; Na podstawie tablicy wejœciowej i tablicy masek obliczane i sumowane s¹ poszczególne wagi pikseli, a nastêpnie nowa wartoœæ dzielona jest przez sumê masek (jeœli ró¿na od 0).
    ; Procedura przyjmuje parametr (wartoœci R, G lub B pikseli z obszaru 3x3) w rejestrze XMM7.
    ; Procedura zwraca wartoœæ oznaczaj¹c¹ now¹ wartoœæ piksela œrodkowego w danym kolorze, w rejestrze RAX.

    MOVQ XMM1, QWORD PTR [Maski]       ; Przenoszenie wartoœci masek do wektora XMM1
    MOVDQU XMM2, XMM7                  ; Przenoszenie wartoœci piksela z obszaru 3x3 do wektora XMM2
    PMOVSXBW XMM1, XMM1                ; Konwersja wartoœci masek do 16-bitowych wartoœci
    PMADDWD XMM1, XMM2                 ; Mno¿enie i sumowanie wag pikseli z obszaru 3x3
    PHADDD XMM1, XMM1
    PHADDD XMM1, XMM1                  

    ; Zapisanie wyniku do rejestru EBX i zanegowanie wartoœci EBX (podzielenie przez -1)
    MOVD EBX, XMM1
    NEG EBX 

    ; Sprawdzenie, czy wynik mieœci siê w zakresie 0-255
    CMP EBX, 0
    JL WYNIK_PONIZEJ_0                  ; Wynik mniejszy od 0, zwrócenie 0
    CMP EBX, 255
    JG WYNIK_POWYZEJ_255                ; Wynik wiêkszy od 255, zwrócenie 255

    ; Wynik mieœci siê w zakresie 0-255, przypisanie do RAX
    MOVSXD RAX, EBX
    RET

WYNIK_PONIZEJ_0:
    MOV RAX, 0                          ; Wynik mniejszy od 0, zwrócenie 0
    RET

WYNIK_POWYZEJ_255:
    MOV RAX, 255                        ; Wynik wiêkszy od 255, zwrócenie 255
    RET

ObliczNowaWartoscPikselaClamped ENDP

FiltrLapl PROC
; Implementacja filtru Laplace'a (LAPL2) dla fragmentu bitmapy.
; Argumenty procedury:
; wskaznikNaWejsciowaTablice - wskaŸnik na tablicê wejœciow¹, zapisany do RCX
; wskaznikNaWyjsciowaTablice - wskaŸnik na tablicê wyjœciow¹, zapisany do RDX
; dlugoscBitmapy - d³ugoœæ bitmapy, zapisana do R8
; szerokoscBitmapy - szerokoœæ bitmapy, zapisana do R9
; indeksStartowy - indeks pocz¹tkowy filtra na stosie jako pi¹ty parametr
; ileIndeksowFiltrowac - liczba indeksów do filtrowania na stosie jako szósty parametr
; Procedura nie zwraca wyniku bezpoœrednio, wynik odczytywany jest z tablicy wyjœciowej.

; Procedura rozpoczyna siê od zapisania zawartoœci wszystkich rejestrów na stosie, a nastêpnie wczytuje parametry do odpowiednich rejestrów.
; Kod procedury skupia siê na iterowaniu przez fragment bitmapy i stosowaniu filtru Laplace'a na ka¿dym pikselu.

; Przenosimy parametry do odpowiednich rejestrów
    MOV R10, QWORD PTR [RSP+48]    ; Za³aduj szósty parametr (ileIndeksowFiltrowac) do rejestru R10
    MOV ileFiltrowac, R10          ; Zapisz wartoœæ parametru do zmiennej ileFiltrowac
    MOV R10, QWORD PTR [RSP+40]    ; Za³aduj pi¹ty parametr (indeksStartowy) do rejestru R10

    ; Zapisujemy wartoœci rejestrów na stosie przed ich modyfikacj¹ w procedurze
    PUSH RAX 
    PUSH RBX 
    PUSH RCX 
    PUSH RDX 
    PUSH RSI 
    PUSH RDI 
    PUSH RBP 
    PUSH RSP 
    PUSH R8 
    PUSH R9 
    PUSH R10 
    PUSH R11 
    PUSH R12 
    PUSH R13 
    PUSH R14 
    PUSH R15 

    ; Przenosimy wartoœci parametrów do odpowiednich rejestrów
    MOV R11, RCX    ; R11 - wskaŸnik na tablicê wejœciow¹
    MOV R12, RDX    ; R12 - wskaŸnik na tablicê wyjœciow¹
    MOV R13, R8     ; R13 - iloœæ bajtów w tablicy wejœciowej
    MOV R14, R9     ; R14 - szerokoœæ obrazu (szerokoœæ w pikselach * 3)
    MOV R15, R10    ; R15 - indeks startowy

    ; Przygotowanie maski filtru Laplace'a
    PUSH RCX        ; Zachowaj zawartoœæ rejestru RCX
    LEA RCX, Maski ; Adres zmiennej globalnej maski jest ³adowany do RCX

    ; Inicjalizacja maski
    MOV BYTE PTR [RCX], -1
    MOV BYTE PTR [RCX+2], -1
    MOV BYTE PTR [RCX+6], -1
    MOV BYTE PTR [RCX+8], -1
    MOV BYTE PTR [RCX+1], -1
    MOV BYTE PTR [RCX+3], -1
    MOV BYTE PTR [RCX+5], -1
    MOV BYTE PTR [RCX+7], -1
    MOV BYTE PTR [RCX+4], 8
    POP RCX         ; Przywróæ zawartoœæ rejestru RCX

    ; Pêtla g³ówna - iteracja po tablicy bajtów (wejœciowej)
    JMP STARTGLOWNEJPETLI

STARTGLOWNEJPETLI:
    ; Za³adowanie wartoœci licznika iteracji do rejestru R8
    MOV R8, R15     ; R8 = indeks startowy

GLOWNAPETLA:
    ; Sprawdzenie warunków wyjœcia z pêtli g³ównej
    MOV R9, R14     ; R9 = szerokoœæ bitmapy
    CMP R8, R9      ; Porównanie indeksu z szerokoœci¹
    JL KONIECGLOWNEJPETLI ; Skok, jeœli indeks jest mniejszy od szerokoœci

    ; Lewa krawêdŸ bitmapy - pomijamy
    MOV RAX, R8     ; RAX = i
    XOR RDX, RDX    ; Zerowanie rejestru RDX (reszta z dzielenia)
    MOV RCX, R14    ; Za³aduj szerokoœæ bitmapy do rejestru RCX
    DIV RCX         ; Podziel zawartoœæ RAX przez RCX; RAX / RCX (dzielenie ca³kowite)
    CMP RDX, 0      ; SprawdŸ, czy reszta z dzielenia jest równa 0

    ; Jeœli reszta z dzielenia jest równa 0, to kontynuuj pêtlê g³ówn¹
    JE KONIECGLOWNEJPETLI

    ; Ostatni rz¹d bitmapy - pomijamy
    MOV RCX, R13    ; Za³aduj d³ugoœæ bitmapy do rejestru RCX
    SUB RCX, R14    ; Oblicz indeks ostatniego rz¹du
    CMP R8, RCX     ; Porównaj indeks z indeksem ostatniego rzêdu

    ; Jeœli indeks jest wiêkszy lub równy indeksowi ostatniego rzêdu, to kontynuuj pêtlê g³ówn¹
    JGE KONIECGLOWNEJPETLI

    ; Prawa krawêdŸ bitmapy - pomijamy
    MOV RAX, R8     ; RAX = i
    ADD RAX, 2      ; Przesuniêcie RAX o 2
    INC RAX         ; Inkrementacja RAX
    XOR RDX, RDX    ; Zerowanie rejestru RDX (reszta z dzielenia)
    MOV RCX, R14    ; Za³aduj szerokoœæ bitmapy do rejestru RCX
    DIV RCX         ; Podziel zawartoœæ RAX przez RCX; RAX / RCX (dzielenie ca³kowite)
    CMP RDX, 0      ; SprawdŸ, czy reszta z dzielenia jest równa 0

    ; Jeœli reszta z dzielenia jest równa 0, to kontynuuj pêtlê g³ówn¹
    JE KONIECGLOWNEJPETLI

    ; Iteracja po obszarze 3x3 wokó³ obecnego piksela i zapisanie wartoœci do tablicy r/g/b
    XOR R9, R9     ; Zerowanie rejestru R9 (licznik)
    PXOR xmm13, xmm13 ; Wyzerowanie rejestru xmm13 (suma pikseli koloru R)
    PXOR xmm14, xmm14 ; Wyzerowanie rejestru xmm14 (suma pikseli koloru G)
    PXOR xmm15, xmm15 ; Wyzerowanie rejestru xmm15 (suma pikseli koloru B)

PETLAZEWNETRZNA:
    ; Iteracja po osi X (kolumny)
    XOR R10, R10   ; Zerowanie rejestru R10 (indeks kolumny)
    CMP R9, 3      ; Sprawdzenie, czy osi¹gniêto krawêdŸ obszaru 3x3
    JE KONIECPODWOJNEJPETLI ; Jeœli tak, to zakoñcz pêtlê

    JMP PETLAWEWNETRZNA

PETLAWEWNETRZNA:
    ; Iteracja po osi Y (rzêdy)
    ; Obliczenie indeksu piksela wejœciowego
    MOV RCX, R10   ; Za³aduj indeks kolumny do rejestru RCX
    DEC RCX        ; Dekrementacja RCX
    IMUL RCX, 3    ; Pomnó¿ RCX przez 3 (przesuniêcie w lewo o 3 bity)
    MOV RAX, R9    ; Za³aduj indeks rzêdu do rejestru RAX
    DEC RAX        ; Dekrementacja RAX
    IMUL RAX, R14  ; Pomnó¿ RAX przez szerokoœæ obrazu (przesuniêcie w lewo o szerokoœæ obrazu)
    ADD RCX, RAX   ; Dodaj RCX do RAX
    ADD RCX, R8    ; Dodaj RCX do indeksu startowego (i)

    ; Wczytaj wartoœæ piksela wejœciowego z tablicy i zapisz do odpowiednich rejestrów xmm
    XOR RAX, RAX   ; Zerowanie RAX
    MOV AL, BYTE PTR [R11 + RCX] ; Wczytaj wartoœæ piksela wejœciowego z tablicy

    ; Zapisz wartoœæ piksela do odpowiedniego rejestru xmm
    PSLLDQ XMM13, 2 ; Przesuñ zawartoœæ xmm13 o 2 bajty w lewo
    MOVD XMM7, EAX  ; Za³aduj wartoœæ piksela do xmm7
    ADDPS XMM13, XMM7 ; Dodaj wartoœæ piksela do xmm13

    ; Inkrementacja indeksu kolumny
    INC RCX        ; Inkrementacja indeksu kolumny

    ; Wczytaj wartoœæ piksela wejœciowego z tablicy i zapisz do odpowiednich rejestrów xmm
    XOR RAX, RAX   ; Zerowanie RAX
    MOV AL, BYTE PTR [R11 + RCX] ; Wczytaj wartoœæ piksela wejœciowego z tablicy

    ; Zapisz wartoœæ piksela do odpowiedniego rejestru xmm
    PSLLDQ XMM14, 2 ; Przesuñ zawartoœæ xmm14 o 2 bajty w lewo
    MOVD XMM7, EAX  ; Za³aduj wartoœæ piksela do xmm7
    ADDPS XMM14, XMM7 ; Dodaj wartoœæ piksela do xmm14

    ; Inkrementacja indeksu kolumny
    INC RCX        ; Inkrementacja indeksu kolumny

    ; Wczytaj wartoœæ piksela wejœciowego z tablicy i zapisz do odpowiednich rejestrów xmm
    XOR RAX, RAX   ; Zerowanie RAX
    MOV AL, BYTE PTR [R11 + RCX] ; Wczytaj wartoœæ piksela wejœciowego z tablicy

    ; Zapisz wartoœæ piksela do odpowiedniego rejestru xmm
    PSLLDQ XMM15, 2 ; Przesuñ zawartoœæ xmm15 o 2 bajty w lewo
    MOVD XMM7, EAX  ; Za³aduj wartoœæ piksela do xmm7
    ADDPS XMM15, XMM7 ; Dodaj wartoœæ piksela do xmm15

    ; Inkrementacja indeksu kolumny
    INC R10        ; Inkrementacja indeksu kolumny

    ; Sprawdzenie warunku wyjœcia z pêtli wewnêtrznej
    CMP R10, 3     ; Sprawdzenie, czy osi¹gniêto krawêdŸ obszaru 3x3
    JNE PETLAWEWNETRZNA ; Jeœli nie, to przejdŸ do kolejnej iteracji

    ; Inkrementacja indeksu rzêdu
    INC R9         ; Inkrementacja indeksu rzêdu

    ; Powrót do pêtli zewnêtrznej
    JMP PETLAZEWNETRZNA

KONIECPODWOJNEJPETLI:
    ; Wywo³anie funkcji ObliczNowaWartoscPikselaClamped dla koloru R
    MOVDQU XMM7, XMM13
    CALL ObliczNowaWartoscPikselaClamped

    ; Obliczenie indeksu piksela wyjœciowego
    MOV RDX, R8    ; Za³aduj indeks piksela wyjœciowego (i - indeksStartowy)
    SUB RDX, R15   ; Odjêcie indeksu startowego od indeksu piksela
    MOV BYTE PTR [R12 + RDX], AL ; Zapisanie wartoœci piksela do tablicy wyjœciowej dla koloru R

    ; Wywo³anie funkcji ObliczNowaWartoscPikselaClamped dla koloru G
    MOVDQU XMM7, XMM14
    CALL ObliczNowaWartoscPikselaClamped

    ; Obliczenie indeksu piksela wyjœciowego
    MOV RDX, R8    ; Za³aduj indeks piksela wyjœciowego (i - indeksStartowy)
    SUB RDX, R15   ; Odjêcie indeksu startowego od indeksu piksela
    INC RDX        ; Inkrementacja indeksu piksela wyjœciowego
    MOV BYTE PTR [R12 + RDX], AL ; Zapisanie wartoœci piksela do tablicy wyjœciowej dla koloru G

    ; Wywo³anie funkcji ObliczNowaWartoscPikselaClamped dla koloru B
    MOVDQU XMM7, XMM15
    CALL ObliczNowaWartoscPikselaClamped

    ; Obliczenie indeksu piksela wyjœciowego
    MOV RDX, R8    ; Za³aduj indeks piksela wyjœciowego (i - indeksStartowy)
    SUB RDX, R15   ; Odjêcie indeksu startowego od indeksu piksela
    INC RDX        ; Inkrementacja indeksu piksela wyjœciowego
    INC RDX        ; Inkrementacja indeksu piksela wyjœciowego
    MOV BYTE PTR [R12 + RDX], AL ; Zapisanie wartoœci piksela do tablicy wyjœciowej dla koloru B

    ; Powrót do pêtli g³ównej
    JMP KONIECGLOWNEJPETLI

KONIECGLOWNEJPETLI:
    ; Zwiêkszenie licznika iteracji
    ADD R8, 3      ; Inkrementacja indeksu o 3 (przeskocz o 3 piksele)

    ; Obliczenie indeksu koñcowego
    MOV RAX, R15   ; Za³aduj indeks startowy do RAX
    ADD RAX, ileFiltrowac ; Dodaj iloœæ filtrowanych indeksów
    CMP R8, RAX    ; Porównaj aktualny indeks z indeksem koñcowym
    JL GLOWNAPETLA ; Jeœli indeks jest mniejszy, to powróæ do pêtli g³ównej

KONIEC:
    ; Przywrócenie zawartoœci rejestrów
    POP R15        ; Przywrócenie zawartoœci rejestru R15
    POP R14        ; Przywrócenie zawartoœci rejestru R14
    POP R13        ; Przywrócenie zawartoœci rejestru R13
    POP R12        ; Przywrócenie zawartoœci rejestru R12
    POP R11        ; Przywrócenie zawartoœci rejestru R11
    POP R10        ; Przywrócenie zawartoœci rejestru R10
    POP R9         ; Przywrócenie zawartoœci rejestru R9
    POP R8         ; Przywrócenie zawartoœci rejestru R8
    POP RSP        ; Przywrócenie zawartoœci rejestru RSP
    POP RBP        ; Przywrócenie zawartoœci rejestru RBP
    POP RDI        ; Przywrócenie zawartoœci rejestru RDI
    POP RSI        ; Przywrócenie zawartoœci rejestru RSI
    POP RDX        ; Przywrócenie zawartoœci rejestru RDX
    POP RCX        ; Przywrócenie zawartoœci rejestru RCX
    POP RBX        ; Przywrócenie zawartoœci rejestru RBX
    POP RAX        ; Przywrócenie zawartoœci rejestru RAX

    RET            ; Powrót z procedury FiltrLapl
FiltrLapl ENDP



END
;-------------------------------------------------------------------------