using System;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace JA_Projekt
{
    public partial class Form1 : Form
    {
        private int iloscWatkow; // Liczba wątków do wykorzystania
        private int iloscWatkowProcesora; // Ilosc wątków procesora
        public Form1()
        {
            InitializeComponent();
        }

        // Obsługa zdarzenia kliknięcia na obraz
        private void pictureBox1_Click(object sender, EventArgs e)
        {
            // Tu można dodać logikę obsługi kliknięcia na obrazie, jeśli jest potrzebna
        }

        // Obsługa zdarzenia wybrania pliku w oknie dialogowym
        private void openFileDialog_FileOk(object sender, System.ComponentModel.CancelEventArgs e)
        {
            // Można dodać logikę obsługi wybrania pliku w oknie dialogowym, jeśli jest potrzebna
        }

        // Inicjalizacja formularza
        private void Form1_Load(object sender, EventArgs e)
        {
            // Ustawienia początkowe formularza i elementów interfejsu użytkownika
            pictureBox.Dock = DockStyle.Fill;
            pictureBox.SizeMode = PictureBoxSizeMode.Zoom;
            Controls.Add(pictureBox);

            iloscWatkowProcesora = Environment.ProcessorCount;

            openFileDialog.Filter = "Obrazy (*.jpg;*.png)|*.jpg;*.png|Wszystkie pliki (*.*)|*.*";
            openFileDialog.Title = "Wybierz obraz";
            openFileDialog.FileName = "";

            button1.Text = "Otwórz plik";
            button2.Text = "Filtruj";
            checkBox1.Text = "C++";
            checkBox2.Text = "Assembler";

            comboBox1.Items.AddRange(new string[] { "Ilość wątków: 1", "Ilość wątków: 2", "Ilość wątków: 4", "Ilość wątków: 8", "Ilość wątków: 16", "Ilość wątków: 32", "Ilość wątków: 64", "Ilość wątków: 1000", "Ilość wątków(procesora): "+ iloscWatkowProcesora });
            comboBox1.SelectedIndex = 8; // Domyślnie ustawiana ilość wątków na 8
            comboBox1.DropDownStyle = ComboBoxStyle.DropDownList;
            iloscWatkow = 8;

            // Ustawienie minimalnej i maksymalnej liczby wątków w puli wątków
            ThreadPool.SetMinThreads(1000, 1000);
            ThreadPool.SetMaxThreads(1000, 1000);
            
        }

        // Obsługa zdarzenia kliknięcia przycisku "Otwórz plik"
        private void button1_Click(object sender, EventArgs e)
        {
            // Otwarcie okna dialogowego wyboru pliku
            if (openFileDialog.ShowDialog() == DialogResult.OK)
            {
                string filePath = openFileDialog.FileName;

                // Sprawdzenie, czy plik istnieje
                if (File.Exists(filePath))
                {
                    Image image = Image.FromFile(filePath);
                    Size size = image.Size;
                    // Sprawdzenie, czy rozmiar obrazu nie przekracza 1920x1080
                    if (size.Width <= 1920 && size.Height <= 1080)
                    {
                        pictureBox.Size = size;
                        pictureBox.Image = image;
                    }
                    else
                    {
                        MessageBox.Show("Wybrany plik jest za duży.", "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
                else
                {
                    MessageBox.Show("Wybrany plik nie istnieje.", "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        // Obsługa zdarzenia zmiany stanu checkboxa "C++"
        private void checkBox1_CheckedChanged(object sender, EventArgs e)
        {
            if (checkBox1.Checked)
                checkBox2.Checked = false;
        }

        // Obsługa zdarzenia zmiany stanu checkboxa "Assembler"
        private void checkBox2_CheckedChanged(object sender, EventArgs e)
        {
            if (checkBox2.Checked)
                checkBox1.Checked = false;
        }

        // Obsługa zdarzenia kliknięcia przycisku "Filtruj"
        private async void button2_Click(object sender, EventArgs e)
        {
            // Sprawdzenie, czy wybrano język filtracji
            if (checkBox2.Checked || checkBox1.Checked)
            {
                try
                {
                    Image image = pictureBox.Image;

                    // Sprawdzenie, czy wybrano obraz
                    if (image == null)
                    {
                        MessageBox.Show("Nie wybrano obrazu.", "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return;
                    }
                    Size size = image.Size;

                    byte[] bytes = new byte[size.Width * size.Height * 3];
                    Bitmap input = new Bitmap(image);

                    // Konwersja obrazu na tablicę bajtów
                    for (int i = 0; i < size.Width; i++)
                    {
                        for (int j = 0; j < size.Height; j++)
                        {
                            bytes[(i * size.Height + j) * 3] = input.GetPixel(i, j).R;
                            bytes[(i * size.Height + j) * 3 + 1] = input.GetPixel(i, j).G;
                            bytes[(i * size.Height + j) * 3 + 2] = input.GetPixel(i, j).B;
                        }
                    }

                    // Filtracja obrazu
                    bool isAsm = checkBox2.Checked;
                    var outputBytes = await wywołajAlgorytm.filtruj(bytes, iloscWatkow, size.Height, isAsm);

                    // Konwersja przefiltrowanych bajtów na obraz
                    Bitmap output = new Bitmap(size.Width, size.Height);
                    for (int x = 0; x < size.Width; x++)
                    {
                        for (int y = 0; y < size.Height; y++)
                        {
                            output.SetPixel(x, y, Color.FromArgb(outputBytes[(y + x * size.Height) * 3], outputBytes[(y + x * size.Height) * 3 + 1], outputBytes[(y + x * size.Height) * 3 + 2]));
                        }
                    }
                    pictureBox.Image = output;
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Wystąpił błąd podczas wykonywania operacji." + ex.Message, "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
            else
            {
                MessageBox.Show("Nie wybrano żadnego języka.", "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        // Obsługa zmiany wybranej liczby wątków w ComboBoxie
        private void comboBox1_SelectedIndexChanged(object sender, EventArgs e)
        {
            switch (comboBox1.SelectedIndex)
            {
                case 0:
                    iloscWatkow = 1;
                    break;
                case 1:
                    iloscWatkow = 2;
                    break;
                case 2:
                    iloscWatkow = 4;
                    break;
                case 3:
                    iloscWatkow = 8;
                    break;
                case 4:
                    iloscWatkow = 16;
                    break;
                case 5:
                    iloscWatkow = 32;
                    break;
                case 6:
                    iloscWatkow = 64;
                    break;
                case 7:
                    iloscWatkow = 1000;
                    break;
                case 8:
                    iloscWatkow = iloscWatkowProcesora;
                    break;
            }
        }

      
    }
}
