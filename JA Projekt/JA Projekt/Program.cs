using JA_Projekt;
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace JA_Projekt
{
    
    static class Program
    {

        /// <summary>
        /// Główny punkt wejścia dla aplikacji.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Form1()); // Tutaj używamy formularza, który chcemy uruchomić jako główny.
        }
    }
}
