using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;

namespace DaystingIRC.Windows;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new MainWindowViewModel();
        Closed += OnClosed;
    }

    private MainWindowViewModel ViewModel => (MainWindowViewModel)DataContext!;

    private async void ConnectClicked(object? sender, RoutedEventArgs e)
    {
        await ViewModel.ConnectAsync();
    }

    private async void DisconnectClicked(object? sender, RoutedEventArgs e)
    {
        await ViewModel.DisconnectAsync();
    }

    private async void SendClicked(object? sender, RoutedEventArgs e)
    {
        await ViewModel.SendInputAsync();
    }

    private async void InputKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            e.Handled = true;
            await ViewModel.SendInputAsync();
        }
    }

    private void ClosePaneClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: PaneViewModel pane })
        {
            ViewModel.ClosePane(pane);
        }
    }

    private async void OnClosed(object? sender, EventArgs e)
    {
        Closed -= OnClosed;
        await ViewModel.DisposeAsync();
    }
}