#include "pch.h"
#include <algorithm>

using namespace std;

// Funkcja wywoływana automatycznie podczas pierwszego załadowania DLL.
// Parametry:
// - hModule: uchwyt do modułu DLL
// - ul_reason_for_call: rodzaj wywołania
// - lpReserved: zarezerwowane, nieużywane
BOOL APIENTRY DllMain(HMODULE hModule, DWORD  ul_reason_for_call, LPVOID lpReserved)
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

// Główna funkcja aplikująca filtr Laplace'a (LAPL1) na bitmapę.
// Parametry:
// - wejscie: wskaźnik na tablicę bajtów reprezentującą bitmapę wejściową
// - wyjscie: wskaźnik na tablicę bajtów, do której zostanie zapisany przefiltrowany fragment
// - dlugoscBitmapy: długość całej bitmapy (w bajtach)
// - szerokoscBitmapy: szerokość pojedynczej linii bitmapy (w bajtach)
// - indeksStartowy: indeks pierwszego piksela do filtrowania
// - liczbaPikseliDoFiltrowania: liczba pikseli do filtrowania
extern "C" __declspec(dllexport) void __stdcall FiltrLaplCpp(unsigned char* wejscie, unsigned char* wyjscie, int dlugoscBitmapy, int szerokoscBitmapy, int indeksStartowy, int liczbaPikseliDoFiltrowania)
{
    // Maski dla filtru Laplace'a
    int maski[9] = { -1, -1, -1, -1, 8, -1, -1, -1, -1 };

    // Iterujemy się po każdym indeksie fragmentu który musimy przefiltrować (w każdej iteracji operujemy na 3 indeksach R,G,B)
    for (int i = indeksStartowy; i < indeksStartowy + liczbaPikseliDoFiltrowania; i += 3)
    {
        // Pomijamy indeksy bitmapy które leżą na krawędzi - ich nie filtrujemy zgodnie z algorytmem.
        if ((i < szerokoscBitmapy * 3) || (i % (szerokoscBitmapy * 3) == 0) || (i >= (dlugoscBitmapy - szerokoscBitmapy * 3)) || ((i + 2 + 3) % (szerokoscBitmapy * 3) == 0))
        {
            continue;
        }

        // Inicjalizujemy tablicę od wartości tablicy 3x3 odpowiednio R, G i B.
        unsigned char piksele[9][3];

        // Zczytujemy wartości z obszaru 3x3 wokół obecnego piksela i zapisujemy je do tablic piksele.
        int k = 0;
        for (int y = -1; y <= 1; ++y)
        {
            for (int x = -1; x <= 1; ++x)
            {
                int indeksPiksela = i + (szerokoscBitmapy * 3 * y + x * 3);

                piksele[k][0] = wejscie[indeksPiksela]; // Kanał R
                piksele[k][1] = wejscie[indeksPiksela + 1]; // Kanał G
                piksele[k][2] = wejscie[indeksPiksela + 2]; // Kanał B

                ++k;
            }
        }

        // Obliczamy nową wartość piksela dla każdego kanału (R,G,B)
        int nowePiksele[3] = { 0, 0, 0 };
        for (int k = 0; k < 9; ++k) {
            for (int c = 0; c < 3; ++c) {
                nowePiksele[c] += piksele[k][c] * maski[k];
            }
        }

        // Ustawiamy dolny i górny zakres wartości piksela
        const int dolnyZakres = 0;
        const int gornyZakres = 255;

        // Ustawiamy nową wartość piksela zgodnie z zakresem
        for (int c = 0; c < 3; ++c) {
            nowePiksele[c] = max(dolnyZakres, min(gornyZakres, nowePiksele[c]));
        }

        // Zapisujemy wartości przefiltrowanych pikseli (dla R,G,B) do wyjściowej tablicy.
        int indeksPikselaWyjscie = i - indeksStartowy;
        for (int c = 0; c < 3; ++c) {
            wyjscie[indeksPikselaWyjscie + c] = static_cast<unsigned char>(nowePiksele[c]);
        }
    }
}
