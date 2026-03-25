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

    private void ResetThemeClicked(object? sender, RoutedEventArgs e)
    {
        ViewModel.ResetThemeColors();
    }

    private async void OpenPrivateChatClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            await ViewModel.OpenPrivateConversationAsync(user.Nick);
        }
    }

    private void WhoisUserClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            ViewModel.PrefillWhois(user.Nick);
        }
    }

    private void MentionUserClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            ViewModel.PrefillMention(user.Nick);
        }
    }

    private async void OpUserClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            await ViewModel.PerformChannelUserModeAsync("+o", user.Nick);
        }
    }

    private async void DeopUserClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            await ViewModel.PerformChannelUserModeAsync("-o", user.Nick);
        }
    }

    private async void VoiceUserClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            await ViewModel.PerformChannelUserModeAsync("+v", user.Nick);
        }
    }

    private async void DevoiceUserClicked(object? sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { DataContext: ChannelUser user })
        {
            await ViewModel.PerformChannelUserModeAsync("-v", user.Nick);
        }
    }

    private async void OnClosed(object? sender, EventArgs e)
    {
        Closed -= OnClosed;
        await ViewModel.DisposeAsync();
    }
}