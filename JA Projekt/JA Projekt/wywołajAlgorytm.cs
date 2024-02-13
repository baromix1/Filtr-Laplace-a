using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;
using System.Windows.Forms;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TaskbarClock;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TrackBar;

namespace JA_Projekt
{
    internal class wywołajAlgorytm
    {
        // Deklaracje metod wywołujących funkcje z biblioteki natywnej

#if DEBUG
        [DllImport("Lib.dll")]
#endif
#if RELEASE
        [DllImport("CppLib.dll")]
#endif
        private static extern void FiltrLaplCpp(IntPtr wskaznikNaWejsciowaTablice, IntPtr wskaznikNaWyjsciowaTablice, int dlugoscBitmapy, int szerokoscBitmapy, int indeksStartowy, int ileIndeksowFiltrowac);
#if DEBUG
        [DllImport("Lib.dll")]
#endif
#if RELEASE
        [DllImport("Lib.dll")]
#endif
        private static extern void FiltrLapl(IntPtr wskaznikNaWejsciowaTablice, IntPtr wskaznikNaWyjsciowaTablice, int dlugoscBitmapy, int szerokoscBitmapy, int indeksStartowy, int ileIndeksowFiltrowac);

        private static System.Timers.Timer timer = new System.Timers.Timer();
        static DateTime start;

        // Metoda asynchroniczna filtrująca obraz
        public static async Task<byte[]> filtruj(byte[] bytes, int iloscWatkow, int width, bool isAsm)
        {
            // Lista wątków i inicjalizacja zmiennych
            List<Watek> listaWatkow = new List<Watek>();
            int JuzFiltrowane = 0;

            // Podział obrazu na wątki i utworzenie listy wątków
            for (int i = 0; i < iloscWatkow; i++)
            {
                var watek = new Watek()
                {
                    IdWatku = i
                };

                // Obliczenie ilości indeksów do filtrowania dla danego wątku
                int iloscFiltrowanychIndeksow;
                if (i == iloscWatkow - 1)
                {
                    iloscFiltrowanychIndeksow = bytes.Length - JuzFiltrowane;
                }
                else
                {
                    iloscFiltrowanychIndeksow = bytes.Length / iloscWatkow;
                    iloscFiltrowanychIndeksow -= iloscFiltrowanychIndeksow % 3; // Zapewnienie, że ilość bajtów jest wielokrotnością 3 (R, G, B)
                }

                watek.IleFiltrowac = iloscFiltrowanychIndeksow;
                watek.OutputBytesPart = new byte[iloscFiltrowanychIndeksow];

                JuzFiltrowane += iloscFiltrowanychIndeksow;

                listaWatkow.Add(watek);
            }

            // Tworzenie listy zadań do wykonania
            List<Task> tasks = new List<Task>();
            int indexZero = 0;
            var outputBytes = new byte[bytes.Length];

            // Tworzenie i uruchamianie zadań dla każdego wątku
            for (int i = 0; i < iloscWatkow; i++)
            {
                Watek watek_i = listaWatkow[i];
                int index = indexZero;
                Task task = new Task(() =>
                {
                    var czescTablicyWyjsciowej = new byte[watek_i.IleFiltrowac];
                    var kopiaBitmapyWejsciowej = new byte[bytes.Length];

                    Array.Copy(bytes, 0, kopiaBitmapyWejsciowej, 0, bytes.Length);

                    unsafe
                    {
                        // Uzyskanie wskaźników na tablice wejściową i wyjściową
                        fixed (byte* wskaznikNaTabliceWejsciowa = &kopiaBitmapyWejsciowej[0])
                        fixed (byte* wskaznikNaTabliceWyjsciowa = &czescTablicyWyjsciowej[0])
                        {
                            var intPtrNaTabliceWejsciowa = new IntPtr(wskaznikNaTabliceWejsciowa);
                            var intPtrNaTabliceWyjsciowa = new IntPtr(wskaznikNaTabliceWyjsciowa);
                            Console.WriteLine("thread: " + Thread.CurrentThread.ManagedThreadId);
                            // Wybór funkcji filtrującej na podstawie wartości isAsm
                            if (isAsm)
                            {
                                FiltrLapl(intPtrNaTabliceWejsciowa, intPtrNaTabliceWyjsciowa, kopiaBitmapyWejsciowej.Length, width * 3, index, watek_i.IleFiltrowac);
                            }
                            else
                            {
                                FiltrLaplCpp(intPtrNaTabliceWejsciowa, intPtrNaTabliceWyjsciowa, kopiaBitmapyWejsciowej.Length, width * 3, index, watek_i.IleFiltrowac);
                            }

                            // Kopiowanie danych z wyjściowej tablicy bajtów do tablicy wyjściowej wątku
                            Marshal.Copy(intPtrNaTabliceWyjsciowa, watek_i.OutputBytesPart, 0, watek_i.IleFiltrowac);
                        }
                    }
                });
                tasks.Add(task);
                indexZero += watek_i.IleFiltrowac;
            }

            // Uruchomienie zadań i monitorowanie czasu ich wykonania
            start = DateTime.Now;
            timer.Enabled = true;
            foreach (var task in tasks) { ThreadPool.QueueUserWorkItem(_ => task.Start()); }
            await Task.WhenAll(tasks);
            timer.Enabled = false;
            TimeSpan time = DateTime.Now - start;
            int minutes = time.Minutes;
            int seconds = time.Seconds;
            int miliseconds = time.Milliseconds;
            MessageBox.Show("Czas wykonania: " + minutes + "m " + seconds + "s " + miliseconds + "ms", "Czas", MessageBoxButtons.OK, MessageBoxIcon.Information);

            // Łączenie wyników z poszczególnych wątków w jedną tablicę wyjściową
            byte[] tablicaWyjsciowa = new byte[0];
            listaWatkow.OrderBy(wartosc => wartosc.IdWatku).ToList().ForEach(wartosc =>
            {
                tablicaWyjsciowa = tablicaWyjsciowa.Concat(wartosc.OutputBytesPart).ToArray();
            });

            outputBytes = tablicaWyjsciowa;
            return outputBytes;
        }
    }
}
