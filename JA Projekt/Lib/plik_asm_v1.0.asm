COMMENT @
Temat: Filtr Laplace'a
Autor: Bartosz Ziarnik
Wersja: 1.0
@
;-------------------------------------------------------------------------
.DATA
; Zmienne
Maski BYTE 9 DUP (?) ; Maski filtru
PrzesuniecieZnakow BYTE 16 DUP (10000000y)	; Do sumowania masek z uwzgl�dnieniem znaku
ileFiltrowac dq 0; ile pixeli ma przefiltrowac procedura

.CODE
; Kod �r�d�owy procedur

ObliczNowaWartoscPikselaClamped PROC
    ; Procedura obliczaj�ca now� warto�� piksela (tylko w jednym kolorze w ci�gu jednego wywo�ania - R, G lub B) na podstawie pikseli u�o�onych w siatk� 3x3.
    ; Na podstawie tablicy wej�ciowej i tablicy masek obliczane i sumowane s� poszczeg�lne wagi pikseli, a nast�pnie nowa warto�� dzielona jest przez sum� masek (je�li r�na od 0).
    ; Procedura przyjmuje parametr (warto�ci R, G lub B pikseli z obszaru 3x3) w rejestrze XMM7.
    ; Procedura zwraca warto�� oznaczaj�c� now� warto�� piksela �rodkowego w danym kolorze, w rejestrze RAX.

    MOVQ XMM1, QWORD PTR [Maski]       ; Przenoszenie warto�ci masek do wektora XMM1
    MOVDQU XMM2, XMM7                  ; Przenoszenie warto�ci piksela z obszaru 3x3 do wektora XMM2
    PMOVSXBW XMM1, XMM1                ; Konwersja warto�ci masek do 16-bitowych warto�ci
    PMADDWD XMM1, XMM2                 ; Mno�enie i sumowanie wag pikseli z obszaru 3x3
    PHADDD XMM1, XMM1
    PHADDD XMM1, XMM1                  

    ; Zapisanie wyniku do rejestru EBX i zanegowanie warto�ci EBX (podzielenie przez -1)
    MOVD EBX, XMM1
    NEG EBX 

    ; Sprawdzenie, czy wynik mie�ci si� w zakresie 0-255
    CMP EBX, 0
    JL WYNIK_PONIZEJ_0                  ; Wynik mniejszy od 0, zwr�cenie 0
    CMP EBX, 255
    JG WYNIK_POWYZEJ_255                ; Wynik wi�kszy od 255, zwr�cenie 255

    ; Wynik mie�ci si� w zakresie 0-255, przypisanie do RAX
    MOVSXD RAX, EBX
    RET

WYNIK_PONIZEJ_0:
    MOV RAX, 0                          ; Wynik mniejszy od 0, zwr�cenie 0
    RET

WYNIK_POWYZEJ_255:
    MOV RAX, 255                        ; Wynik wi�kszy od 255, zwr�cenie 255
    RET

ObliczNowaWartoscPikselaClamped ENDP

FiltrLapl PROC
; Implementacja filtru Laplace'a (LAPL2) dla fragmentu bitmapy.
; Argumenty procedury:
; wskaznikNaWejsciowaTablice - wska�nik na tablic� wej�ciow�, zapisany do RCX
; wskaznikNaWyjsciowaTablice - wska�nik na tablic� wyj�ciow�, zapisany do RDX
; dlugoscBitmapy - d�ugo�� bitmapy, zapisana do R8
; szerokoscBitmapy - szeroko�� bitmapy, zapisana do R9
; indeksStartowy - indeks pocz�tkowy filtra na stosie jako pi�ty parametr
; ileIndeksowFiltrowac - liczba indeks�w do filtrowania na stosie jako sz�sty parametr
; Procedura nie zwraca wyniku bezpo�rednio, wynik odczytywany jest z tablicy wyj�ciowej.

; Procedura rozpoczyna si� od zapisania zawarto�ci wszystkich rejestr�w na stosie, a nast�pnie wczytuje parametry do odpowiednich rejestr�w.
; Kod procedury skupia si� na iterowaniu przez fragment bitmapy i stosowaniu filtru Laplace'a na ka�dym pikselu.

; Przenosimy parametry do odpowiednich rejestr�w
    MOV R10, QWORD PTR [RSP+48]    ; Za�aduj sz�sty parametr (ileIndeksowFiltrowac) do rejestru R10
    MOV ileFiltrowac, R10          ; Zapisz warto�� parametru do zmiennej ileFiltrowac
    MOV R10, QWORD PTR [RSP+40]    ; Za�aduj pi�ty parametr (indeksStartowy) do rejestru R10

    ; Zapisujemy warto�ci rejestr�w na stosie przed ich modyfikacj� w procedurze
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

    ; Przenosimy warto�ci parametr�w do odpowiednich rejestr�w
    MOV R11, RCX    ; R11 - wska�nik na tablic� wej�ciow�
    MOV R12, RDX    ; R12 - wska�nik na tablic� wyj�ciow�
    MOV R13, R8     ; R13 - ilo�� bajt�w w tablicy wej�ciowej
    MOV R14, R9     ; R14 - szeroko�� obrazu (szeroko�� w pikselach * 3)
    MOV R15, R10    ; R15 - indeks startowy

    ; Przygotowanie maski filtru Laplace'a
    PUSH RCX        ; Zachowaj zawarto�� rejestru RCX
    LEA RCX, Maski ; Adres zmiennej globalnej maski jest �adowany do RCX

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
    POP RCX         ; Przywr�� zawarto�� rejestru RCX

    ; P�tla g��wna - iteracja po tablicy bajt�w (wej�ciowej)
    JMP STARTGLOWNEJPETLI

STARTGLOWNEJPETLI:
    ; Za�adowanie warto�ci licznika iteracji do rejestru R8
    MOV R8, R15     ; R8 = indeks startowy

GLOWNAPETLA:
    ; Sprawdzenie warunk�w wyj�cia z p�tli g��wnej
    MOV R9, R14     ; R9 = szeroko�� bitmapy
    CMP R8, R9      ; Por�wnanie indeksu z szeroko�ci�
    JL KONIECGLOWNEJPETLI ; Skok, je�li indeks jest mniejszy od szeroko�ci

    ; Lewa kraw�d� bitmapy - pomijamy
    MOV RAX, R8     ; RAX = i
    XOR RDX, RDX    ; Zerowanie rejestru RDX (reszta z dzielenia)
    MOV RCX, R14    ; Za�aduj szeroko�� bitmapy do rejestru RCX
    DIV RCX         ; Podziel zawarto�� RAX przez RCX; RAX / RCX (dzielenie ca�kowite)
    CMP RDX, 0      ; Sprawd�, czy reszta z dzielenia jest r�wna 0

    ; Je�li reszta z dzielenia jest r�wna 0, to kontynuuj p�tl� g��wn�
    JE KONIECGLOWNEJPETLI

    ; Ostatni rz�d bitmapy - pomijamy
    MOV RCX, R13    ; Za�aduj d�ugo�� bitmapy do rejestru RCX
    SUB RCX, R14    ; Oblicz indeks ostatniego rz�du
    CMP R8, RCX     ; Por�wnaj indeks z indeksem ostatniego rz�du

    ; Je�li indeks jest wi�kszy lub r�wny indeksowi ostatniego rz�du, to kontynuuj p�tl� g��wn�
    JGE KONIECGLOWNEJPETLI

    ; Prawa kraw�d� bitmapy - pomijamy
    MOV RAX, R8     ; RAX = i
    ADD RAX, 2      ; Przesuni�cie RAX o 2
    INC RAX         ; Inkrementacja RAX
    XOR RDX, RDX    ; Zerowanie rejestru RDX (reszta z dzielenia)
    MOV RCX, R14    ; Za�aduj szeroko�� bitmapy do rejestru RCX
    DIV RCX         ; Podziel zawarto�� RAX przez RCX; RAX / RCX (dzielenie ca�kowite)
    CMP RDX, 0      ; Sprawd�, czy reszta z dzielenia jest r�wna 0

    ; Je�li reszta z dzielenia jest r�wna 0, to kontynuuj p�tl� g��wn�
    JE KONIECGLOWNEJPETLI

    ; Iteracja po obszarze 3x3 wok� obecnego piksela i zapisanie warto�ci do tablicy r/g/b
    XOR R9, R9     ; Zerowanie rejestru R9 (licznik)
    PXOR xmm13, xmm13 ; Wyzerowanie rejestru xmm13 (suma pikseli koloru R)
    PXOR xmm14, xmm14 ; Wyzerowanie rejestru xmm14 (suma pikseli koloru G)
    PXOR xmm15, xmm15 ; Wyzerowanie rejestru xmm15 (suma pikseli koloru B)

PETLAZEWNETRZNA:
    ; Iteracja po osi X (kolumny)
    XOR R10, R10   ; Zerowanie rejestru R10 (indeks kolumny)
    CMP R9, 3      ; Sprawdzenie, czy osi�gni�to kraw�d� obszaru 3x3
    JE KONIECPODWOJNEJPETLI ; Je�li tak, to zako�cz p�tl�

    JMP PETLAWEWNETRZNA

PETLAWEWNETRZNA:
    ; Iteracja po osi Y (rz�dy)
    ; Obliczenie indeksu piksela wej�ciowego
    MOV RCX, R10   ; Za�aduj indeks kolumny do rejestru RCX
    DEC RCX        ; Dekrementacja RCX
    IMUL RCX, 3    ; Pomn� RCX przez 3 (przesuni�cie w lewo o 3 bity)
    MOV RAX, R9    ; Za�aduj indeks rz�du do rejestru RAX
    DEC RAX        ; Dekrementacja RAX
    IMUL RAX, R14  ; Pomn� RAX przez szeroko�� obrazu (przesuni�cie w lewo o szeroko�� obrazu)
    ADD RCX, RAX   ; Dodaj RCX do RAX
    ADD RCX, R8    ; Dodaj RCX do indeksu startowego (i)

    ; Wczytaj warto�� piksela wej�ciowego z tablicy i zapisz do odpowiednich rejestr�w xmm
    XOR RAX, RAX   ; Zerowanie RAX
    MOV AL, BYTE PTR [R11 + RCX] ; Wczytaj warto�� piksela wej�ciowego z tablicy

    ; Zapisz warto�� piksela do odpowiedniego rejestru xmm
    PSLLDQ XMM13, 2 ; Przesu� zawarto�� xmm13 o 2 bajty w lewo
    MOVD XMM7, EAX  ; Za�aduj warto�� piksela do xmm7
    ADDPS XMM13, XMM7 ; Dodaj warto�� piksela do xmm13

    ; Inkrementacja indeksu kolumny
    INC RCX        ; Inkrementacja indeksu kolumny

    ; Wczytaj warto�� piksela wej�ciowego z tablicy i zapisz do odpowiednich rejestr�w xmm
    XOR RAX, RAX   ; Zerowanie RAX
    MOV AL, BYTE PTR [R11 + RCX] ; Wczytaj warto�� piksela wej�ciowego z tablicy

    ; Zapisz warto�� piksela do odpowiedniego rejestru xmm
    PSLLDQ XMM14, 2 ; Przesu� zawarto�� xmm14 o 2 bajty w lewo
    MOVD XMM7, EAX  ; Za�aduj warto�� piksela do xmm7
    ADDPS XMM14, XMM7 ; Dodaj warto�� piksela do xmm14

    ; Inkrementacja indeksu kolumny
    INC RCX        ; Inkrementacja indeksu kolumny

    ; Wczytaj warto�� piksela wej�ciowego z tablicy i zapisz do odpowiednich rejestr�w xmm
    XOR RAX, RAX   ; Zerowanie RAX
    MOV AL, BYTE PTR [R11 + RCX] ; Wczytaj warto�� piksela wej�ciowego z tablicy

    ; Zapisz warto�� piksela do odpowiedniego rejestru xmm
    PSLLDQ XMM15, 2 ; Przesu� zawarto�� xmm15 o 2 bajty w lewo
    MOVD XMM7, EAX  ; Za�aduj warto�� piksela do xmm7
    ADDPS XMM15, XMM7 ; Dodaj warto�� piksela do xmm15

    ; Inkrementacja indeksu kolumny
    INC R10        ; Inkrementacja indeksu kolumny

    ; Sprawdzenie warunku wyj�cia z p�tli wewn�trznej
    CMP R10, 3     ; Sprawdzenie, czy osi�gni�to kraw�d� obszaru 3x3
    JNE PETLAWEWNETRZNA ; Je�li nie, to przejd� do kolejnej iteracji

    ; Inkrementacja indeksu rz�du
    INC R9         ; Inkrementacja indeksu rz�du

    ; Powr�t do p�tli zewn�trznej
    JMP PETLAZEWNETRZNA

KONIECPODWOJNEJPETLI:
    ; Wywo�anie funkcji ObliczNowaWartoscPikselaClamped dla koloru R
    MOVDQU XMM7, XMM13
    CALL ObliczNowaWartoscPikselaClamped

    ; Obliczenie indeksu piksela wyj�ciowego
    MOV RDX, R8    ; Za�aduj indeks piksela wyj�ciowego (i - indeksStartowy)
    SUB RDX, R15   ; Odj�cie indeksu startowego od indeksu piksela
    MOV BYTE PTR [R12 + RDX], AL ; Zapisanie warto�ci piksela do tablicy wyj�ciowej dla koloru R

    ; Wywo�anie funkcji ObliczNowaWartoscPikselaClamped dla koloru G
    MOVDQU XMM7, XMM14
    CALL ObliczNowaWartoscPikselaClamped

    ; Obliczenie indeksu piksela wyj�ciowego
    MOV RDX, R8    ; Za�aduj indeks piksela wyj�ciowego (i - indeksStartowy)
    SUB RDX, R15   ; Odj�cie indeksu startowego od indeksu piksela
    INC RDX        ; Inkrementacja indeksu piksela wyj�ciowego
    MOV BYTE PTR [R12 + RDX], AL ; Zapisanie warto�ci piksela do tablicy wyj�ciowej dla koloru G

    ; Wywo�anie funkcji ObliczNowaWartoscPikselaClamped dla koloru B
    MOVDQU XMM7, XMM15
    CALL ObliczNowaWartoscPikselaClamped

    ; Obliczenie indeksu piksela wyj�ciowego
    MOV RDX, R8    ; Za�aduj indeks piksela wyj�ciowego (i - indeksStartowy)
    SUB RDX, R15   ; Odj�cie indeksu startowego od indeksu piksela
    INC RDX        ; Inkrementacja indeksu piksela wyj�ciowego
    INC RDX        ; Inkrementacja indeksu piksela wyj�ciowego
    MOV BYTE PTR [R12 + RDX], AL ; Zapisanie warto�ci piksela do tablicy wyj�ciowej dla koloru B

    ; Powr�t do p�tli g��wnej
    JMP KONIECGLOWNEJPETLI

KONIECGLOWNEJPETLI:
    ; Zwi�kszenie licznika iteracji
    ADD R8, 3      ; Inkrementacja indeksu o 3 (przeskocz o 3 piksele)

    ; Obliczenie indeksu ko�cowego
    MOV RAX, R15   ; Za�aduj indeks startowy do RAX
    ADD RAX, ileFiltrowac ; Dodaj ilo�� filtrowanych indeks�w
    CMP R8, RAX    ; Por�wnaj aktualny indeks z indeksem ko�cowym
    JL GLOWNAPETLA ; Je�li indeks jest mniejszy, to powr�� do p�tli g��wnej

KONIEC:
    ; Przywr�cenie zawarto�ci rejestr�w
    POP R15        ; Przywr�cenie zawarto�ci rejestru R15
    POP R14        ; Przywr�cenie zawarto�ci rejestru R14
    POP R13        ; Przywr�cenie zawarto�ci rejestru R13
    POP R12        ; Przywr�cenie zawarto�ci rejestru R12
    POP R11        ; Przywr�cenie zawarto�ci rejestru R11
    POP R10        ; Przywr�cenie zawarto�ci rejestru R10
    POP R9         ; Przywr�cenie zawarto�ci rejestru R9
    POP R8         ; Przywr�cenie zawarto�ci rejestru R8
    POP RSP        ; Przywr�cenie zawarto�ci rejestru RSP
    POP RBP        ; Przywr�cenie zawarto�ci rejestru RBP
    POP RDI        ; Przywr�cenie zawarto�ci rejestru RDI
    POP RSI        ; Przywr�cenie zawarto�ci rejestru RSI
    POP RDX        ; Przywr�cenie zawarto�ci rejestru RDX
    POP RCX        ; Przywr�cenie zawarto�ci rejestru RCX
    POP RBX        ; Przywr�cenie zawarto�ci rejestru RBX
    POP RAX        ; Przywr�cenie zawarto�ci rejestru RAX

    RET            ; Powr�t z procedury FiltrLapl
FiltrLapl ENDP



END
;-------------------------------------------------------------------------