using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Text.Json;
using Avalonia.Media;
using Avalonia.Threading;

namespace DaystingIRC.Windows;

public sealed class MainWindowViewModel : ObservableObject, IAsyncDisposable
{
    private const string ServerPaneId = "server";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
    };

    private readonly IrcClient _client = new();
    private readonly string _storageDirectory;
    private readonly string _profilePath;
    private readonly string _sessionPath;
    private PaneViewModel _selectedPane;
    private string _currentNickname;
    private string _inputText = string.Empty;
    private string _statusText = "Ready";
    private bool _isConnected;
    private bool _isOperator;
    private IBrush _themeBackgroundBrush = new SolidColorBrush(Color.Parse("#FBF8F2"));
    private IBrush _themeTextBrush = new SolidColorBrush(Color.Parse("#1B1F23"));

    public MainWindowViewModel()
    {
        _storageDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DaystingIRC.Windows");
        _profilePath = Path.Combine(_storageDirectory, "profile.json");
        _sessionPath = Path.Combine(_storageDirectory, "session.json");

        Profile = LoadProfile();
        ApplyThemeFromProfile();
        _currentNickname = Profile.Nickname;
        SaslMechanisms = Enum.GetValues<SaslMechanism>();

        Panes = new ObservableCollection<PaneViewModel> { CreateServerPane() };
        _selectedPane = Panes[0];
        RestoreSession();

        Profile.PropertyChanged += OnProfileChanged;
        _client.LineReceived += line => Dispatcher.UIThread.Post(() => HandleIncomingLine(line));
        _client.LineSent += line => Dispatcher.UIThread.Post(() => AppendMessage(ServerPaneId, $"-> {line}", false));
        _client.StatusChanged += status => Dispatcher.UIThread.Post(() =>
        {
            StatusText = status;
            AppendMessage(ServerPaneId, $"[status] {status}", false);
        });
        _client.ConnectionStateChanged += connected => Dispatcher.UIThread.Post(() =>
        {
            IsConnected = connected;
            if (!connected)
            {
                IsOperator = false;
            }
        });
        _client.OperatorStatusChanged += state => Dispatcher.UIThread.Post(() => IsOperator = state);
        _client.NicknameChanged += nick => Dispatcher.UIThread.Post(() => _currentNickname = nick);
    }

    public ProfileSettings Profile { get; }

    public ObservableCollection<PaneViewModel> Panes { get; }

    public IReadOnlyList<SaslMechanism> SaslMechanisms { get; }

    public string InputText
    {
        get => _inputText;
        set => SetProperty(ref _inputText, value);
    }

    public string StatusText
    {
        get => _statusText;
        set => SetProperty(ref _statusText, value);
    }

    public bool IsConnected
    {
        get => _isConnected;
        set
        {
            if (SetProperty(ref _isConnected, value))
            {
                RaisePropertyChanged(nameof(CanConnect));
                RaisePropertyChanged(nameof(IsDisconnected));
            }
        }
    }

    public bool IsDisconnected => !IsConnected;

    public bool IsOperator
    {
        get => _isOperator;
        set => SetProperty(ref _isOperator, value);
    }

    public bool CanConnect => !IsConnected && !string.IsNullOrWhiteSpace(Profile.Nickname) && Profile.PrimaryChannel.StartsWith('#');

    public bool IsThemeBackgroundColorValid => Color.TryParse(Profile.ThemeBackgroundColor, out _);

    public bool IsThemeTextColorValid => Color.TryParse(Profile.ThemeTextColor, out _);

    public bool HasThemeValidationIssues => !IsThemeBackgroundColorValid || !IsThemeTextColorValid;

    public string ThemeValidationMessage
    {
        get
        {
            if (!IsThemeBackgroundColorValid && !IsThemeTextColorValid)
            {
                return "Theme background and text colors are invalid. Use hex values like #FBF8F2 and #1B1F23.";
            }

            if (!IsThemeBackgroundColorValid)
            {
                return "Theme background color is invalid. Use a value like #FBF8F2.";
            }

            if (!IsThemeTextColorValid)
            {
                return "Theme text color is invalid. Use a value like #1B1F23.";
            }

            return string.Empty;
        }
    }

    public IBrush ThemeBackgroundBrush
    {
        get => _themeBackgroundBrush;
        private set => SetProperty(ref _themeBackgroundBrush, value);
    }

    public IBrush ThemeTextBrush
    {
        get => _themeTextBrush;
        private set => SetProperty(ref _themeTextBrush, value);
    }

    public PaneViewModel SelectedPane
    {
        get => _selectedPane;
        set
        {
            if (SetProperty(ref _selectedPane, value))
            {
                _selectedPane.UnreadCount = 0;
                SaveSession();
            }
        }
    }

    public async Task ConnectAsync()
    {
        if (!CanConnect)
        {
            AppendMessage(ServerPaneId, "[status] Profile is incomplete. Nick and primary channel are required.", false);
            return;
        }

        await _client.ConnectAsync(Profile);
    }

    public async Task DisconnectAsync()
    {
        await _client.DisconnectAsync();
        IsConnected = false;
        IsOperator = false;
    }

    public async Task SendInputAsync()
    {
        var text = InputText.Trim();
        if (string.IsNullOrWhiteSpace(text) || !IsConnected)
        {
            return;
        }

        InputText = string.Empty;

        if (text.StartsWith('/'))
        {
            await HandleSlashCommandAsync(text);
            return;
        }

        var target = ResolveActiveTarget();
        if (string.IsNullOrWhiteSpace(target))
        {
            AppendMessage(ServerPaneId, "[status] Select a channel or private tab before sending a normal message.", false);
            return;
        }

        await _client.SendRawAsync($"PRIVMSG {target} :{text}");
        AppendMessage(EnsurePaneForTarget(target).Id, $"<{_currentNickname}> {text}", false);
    }

    public void ClosePane(PaneViewModel pane)
    {
        if (!pane.CanClose)
        {
            return;
        }

        var selectedAnother = false;
        if (ReferenceEquals(SelectedPane, pane))
        {
            SelectedPane = Panes.First();
            selectedAnother = true;
        }

        Panes.Remove(pane);
        if (!selectedAnother && !Panes.Contains(SelectedPane))
        {
            SelectedPane = Panes.First();
        }

        SaveSession();
    }

    public ValueTask DisposeAsync()
    {
        Profile.PropertyChanged -= OnProfileChanged;
        return _client.DisposeAsync();
    }

    public void ResetThemeColors()
    {
        Profile.ThemeBackgroundColor = "#FBF8F2";
        Profile.ThemeTextColor = "#1B1F23";
    }

    private void OnProfileChanged(object? sender, PropertyChangedEventArgs e)
    {
        SaveProfile();
        if (e.PropertyName == nameof(ProfileSettings.Nickname) || e.PropertyName == nameof(ProfileSettings.PrimaryChannel))
        {
            RaisePropertyChanged(nameof(CanConnect));
        }

        if (e.PropertyName == nameof(ProfileSettings.ThemeBackgroundColor) || e.PropertyName == nameof(ProfileSettings.ThemeTextColor))
        {
            ApplyThemeFromProfile();
            RaisePropertyChanged(nameof(IsThemeBackgroundColorValid));
            RaisePropertyChanged(nameof(IsThemeTextColorValid));
            RaisePropertyChanged(nameof(HasThemeValidationIssues));
            RaisePropertyChanged(nameof(ThemeValidationMessage));
        }
    }

    private void ApplyThemeFromProfile()
    {
        ThemeBackgroundBrush = new SolidColorBrush(ParseColorOrDefault(Profile.ThemeBackgroundColor, "#FBF8F2"));
        ThemeTextBrush = new SolidColorBrush(ParseColorOrDefault(Profile.ThemeTextColor, "#1B1F23"));
    }

    private static Color ParseColorOrDefault(string input, string fallback)
    {
        return Color.TryParse(input, out var parsed) ? parsed : Color.Parse(fallback);
    }

    private async Task HandleSlashCommandAsync(string input)
    {
        var parts = input[1..].Split(' ', 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0)
        {
            return;
        }

        var command = parts[0].ToLowerInvariant();
        var rest = parts.Length > 1 ? parts[1] : string.Empty;
        switch (command)
        {
            case "me":
                var target = ResolveActiveTarget();
                if (string.IsNullOrWhiteSpace(target) || string.IsNullOrWhiteSpace(rest))
                {
                    AppendMessage(ServerPaneId, "[status] /me requires an active target and action text.", false);
                    return;
                }

                await _client.SendRawAsync($"PRIVMSG {target} :\u0001ACTION {rest}\u0001");
                AppendMessage(EnsurePaneForTarget(target).Id, $"* {_currentNickname} {rest}", false);
                break;
            case "query":
                if (string.IsNullOrWhiteSpace(rest))
                {
                    AppendMessage(ServerPaneId, "[status] /query requires a nickname.", false);
                    return;
                }

                SelectedPane = EnsurePrivatePane(rest);
                break;
            case "close":
                ClosePane(SelectedPane);
                break;
            case "disconnect":
                await DisconnectAsync();
                break;
            case "connect":
                await ConnectAsync();
                break;
            case "ns":
            case "cs":
            case "ms":
            case "os":
            case "hs":
            case "bs":
                var serviceName = command switch
                {
                    "ns" => "NickServ",
                    "cs" => "ChanServ",
                    "ms" => "MemoServ",
                    "os" => "OperServ",
                    "hs" => "HostServ",
                    _ => "BotServ",
                };
                await _client.SendRawAsync($"PRIVMSG {serviceName} :{rest}");
                AppendMessage(ServerPaneId, $"[service] {serviceName}: {rest}", false);
                break;
            default:
                await _client.SendRawAsync(input[1..]);
                break;
        }
    }

    private void HandleIncomingLine(string line)
    {
        AppendMessage(ServerPaneId, $"<- {line}", false);
        var message = IrcMessage.Parse(line);

        switch (message.Command)
        {
            case "PRIVMSG":
                HandlePrivmsg(message);
                break;
            case "JOIN":
                HandleJoin(message);
                break;
            case "PART":
                HandlePart(message);
                break;
            case "QUIT":
                HandleQuit(message);
                break;
            case "NICK":
                HandleNick(message);
                break;
            case "332":
                HandleTopicReply(message);
                break;
            case "331":
                HandleNoTopicReply(message);
                break;
            case "TOPIC":
                HandleTopicChange(message);
                break;
            case "353":
                HandleNamesReply(message);
                break;
            case "MODE":
                HandleChannelModeChange(message);
                break;
        }
    }

    private void HandlePrivmsg(IrcMessage message)
    {
        var sender = message.Nickname;
        var target = message.GetParameterOrEmpty(0);
        var body = message.Trailing ?? string.Empty;
        var isAction = body.StartsWith("\u0001ACTION ", StringComparison.Ordinal) && body.EndsWith("\u0001", StringComparison.Ordinal);
        if (isAction)
        {
            body = body[8..^1];
        }

        var pane = string.Equals(target, _currentNickname, StringComparison.OrdinalIgnoreCase)
            ? EnsurePrivatePane(sender)
            : EnsurePaneForTarget(target);
        var rendered = isAction ? $"* {sender} {body}" : $"<{sender}> {body}";
        AppendMessage(pane.Id, rendered, true);
        if (string.Equals(target, pane.Target, StringComparison.OrdinalIgnoreCase))
        {
            pane.UpsertUser(sender);
        }
    }

    private void HandleJoin(IrcMessage message)
    {
        var nick = message.Nickname;
        var channel = (message.Trailing ?? message.GetParameterOrEmpty(0)).Trim();
        if (string.IsNullOrWhiteSpace(channel))
        {
            return;
        }

        var pane = EnsureChannelPane(channel);
        pane.UpsertUser(nick);
        AppendMessage(pane.Id, $"-!- {nick} joined {channel}", !string.Equals(nick, _currentNickname, StringComparison.OrdinalIgnoreCase));
    }

    private void HandlePart(IrcMessage message)
    {
        var nick = message.Nickname;
        var channel = message.GetParameterOrEmpty(0);
        if (TryFindPane(channel, PaneType.Channel, out var pane))
        {
            pane.RemoveUser(nick);
            var reason = message.Trailing;
            AppendMessage(pane.Id, string.IsNullOrWhiteSpace(reason) ? $"-!- {nick} left {channel}" : $"-!- {nick} left {channel} ({reason})", true);
        }
    }

    private void HandleQuit(IrcMessage message)
    {
        var nick = message.Nickname;
        var reason = message.Trailing;
        foreach (var pane in Panes.Where(pane => pane.Type == PaneType.Channel))
        {
            pane.RemoveUser(nick);
        }

        if (!string.IsNullOrWhiteSpace(reason))
        {
            AppendMessage(ServerPaneId, $"-!- {nick} quit ({reason})", false);
        }
    }

    private void HandleNick(IrcMessage message)
    {
        var oldNick = message.Nickname;
        var newNick = (message.Trailing ?? message.GetParameterOrEmpty(0)).TrimStart(':');
        if (string.IsNullOrWhiteSpace(newNick))
        {
            return;
        }

        if (string.Equals(oldNick, _currentNickname, StringComparison.OrdinalIgnoreCase))
        {
            _currentNickname = newNick;
        }

        foreach (var pane in Panes.Where(pane => pane.Type == PaneType.Channel))
        {
            pane.RenameUser(oldNick, newNick);
        }

        var privatePane = Panes.FirstOrDefault(pane => pane.Type == PaneType.PrivateMessage && string.Equals(pane.Target, oldNick, StringComparison.OrdinalIgnoreCase));
        if (privatePane is not null)
        {
            privatePane.Title = newNick;
        }

        AppendMessage(ServerPaneId, $"-!- {oldNick} is now known as {newNick}", false);
    }

    private void HandleTopicReply(IrcMessage message)
    {
        var channel = message.GetParameterOrEmpty(1);
        if (TryFindPane(channel, PaneType.Channel, out var pane))
        {
            pane.Topic = message.Trailing ?? string.Empty;
        }
    }

    private void HandleNoTopicReply(IrcMessage message)
    {
        var channel = message.GetParameterOrEmpty(1);
        if (TryFindPane(channel, PaneType.Channel, out var pane))
        {
            pane.Topic = string.Empty;
        }
    }

    private void HandleTopicChange(IrcMessage message)
    {
        var channel = message.GetParameterOrEmpty(0);
        var topic = message.Trailing ?? string.Empty;
        var pane = EnsureChannelPane(channel);
        pane.Topic = topic;
        AppendMessage(pane.Id, $"-!- {message.Nickname} changed the topic to: {topic}", true);
    }

    private void HandleNamesReply(IrcMessage message)
    {
        var channel = message.GetParameterOrEmpty(2);
        var namesPayload = message.Trailing ?? string.Empty;
        if (string.IsNullOrWhiteSpace(channel) || string.IsNullOrWhiteSpace(namesPayload))
        {
            return;
        }

        var pane = EnsureChannelPane(channel);
        foreach (var entry in namesPayload.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            var prefix = entry[0] is '~' or '&' or '@' or '%' or '+' ? entry[0].ToString() : string.Empty;
            var nick = prefix.Length == 0 ? entry : entry[1..];
            pane.UpsertUser(nick, prefix);
        }
    }

    private void HandleChannelModeChange(IrcMessage message)
    {
        var channel = message.GetParameterOrEmpty(0);
        if (!TryFindPane(channel, PaneType.Channel, out var pane) || message.Parameters.Count < 3)
        {
            return;
        }

        var modeString = message.GetParameterOrEmpty(1);
        var parameterIndex = 2;
        var adding = true;
        foreach (var mode in modeString)
        {
            switch (mode)
            {
                case '+':
                    adding = true;
                    continue;
                case '-':
                    adding = false;
                    continue;
            }

            var prefix = mode switch
            {
                'q' => "~",
                'a' => "&",
                'o' => "@",
                'h' => "%",
                'v' => "+",
                _ => string.Empty,
            };

            if (string.IsNullOrEmpty(prefix) || parameterIndex >= message.Parameters.Count)
            {
                continue;
            }

            var nick = message.GetParameterOrEmpty(parameterIndex);
            parameterIndex += 1;
            pane.ApplyPrefixChange(nick, prefix, adding);
        }
    }

    private PaneViewModel EnsurePaneForTarget(string target)
    {
        return target.StartsWith('#') ? EnsureChannelPane(target) : EnsurePrivatePane(target);
    }

    private PaneViewModel EnsureChannelPane(string channel)
    {
        if (TryFindPane(channel, PaneType.Channel, out var pane))
        {
            return pane;
        }

        pane = new PaneViewModel($"channel:{channel.ToLowerInvariant()}", channel, PaneType.Channel, channel);
        Panes.Add(pane);
        SaveSession();
        return pane;
    }

    private PaneViewModel EnsurePrivatePane(string nickname)
    {
        if (TryFindPane(nickname, PaneType.PrivateMessage, out var pane))
        {
            return pane;
        }

        pane = new PaneViewModel($"query:{nickname.ToLowerInvariant()}", nickname, PaneType.PrivateMessage, nickname);
        Panes.Add(pane);
        SaveSession();
        return pane;
    }

    private bool TryFindPane(string target, PaneType type, out PaneViewModel pane)
    {
        pane = Panes.FirstOrDefault(candidate => candidate.Type == type && string.Equals(candidate.Target, target, StringComparison.OrdinalIgnoreCase))
            ?? null!;
        return pane is not null;
    }

    private string ResolveActiveTarget()
    {
        if (SelectedPane.Type != PaneType.Server)
        {
            return SelectedPane.Target;
        }

        return Profile.PrimaryChannel.StartsWith('#') ? Profile.PrimaryChannel : string.Empty;
    }

    private void AppendMessage(string paneId, string message, bool incrementUnread)
    {
        var pane = Panes.FirstOrDefault(candidate => candidate.Id == paneId);
        if (pane is null)
        {
            return;
        }

        pane.Messages.Add(message);
        if (incrementUnread && !ReferenceEquals(pane, SelectedPane))
        {
            pane.UnreadCount += 1;
        }
    }

    private static PaneViewModel CreateServerPane()
    {
        var pane = new PaneViewModel(ServerPaneId, "Server", PaneType.Server, string.Empty);
        pane.Messages.Add("Ready. Configure nick/channel and connect.");
        return pane;
    }

    private ProfileSettings LoadProfile()
    {
        try
        {
            if (File.Exists(_profilePath))
            {
                var profile = JsonSerializer.Deserialize<ProfileSettings>(File.ReadAllText(_profilePath), JsonOptions);
                if (profile is not null)
                {
                    return profile;
                }
            }
        }
        catch
        {
        }

        return new ProfileSettings();
    }

    private void SaveProfile()
    {
        Directory.CreateDirectory(_storageDirectory);
        File.WriteAllText(_profilePath, JsonSerializer.Serialize(Profile, JsonOptions));
    }

    private void RestoreSession()
    {
        try
        {
            if (!File.Exists(_sessionPath))
            {
                return;
            }

            var session = JsonSerializer.Deserialize<SessionState>(File.ReadAllText(_sessionPath), JsonOptions);
            if (session is null)
            {
                return;
            }

            foreach (var pane in session.Panes)
            {
                if (pane.Type == PaneType.Server || Panes.Any(existing => existing.Id == pane.Id))
                {
                    continue;
                }

                Panes.Add(new PaneViewModel(pane.Id, pane.Title, pane.Type, pane.Target));
            }

            var selected = Panes.FirstOrDefault(pane => pane.Id == session.SelectedPaneId);
            if (selected is not null)
            {
                SelectedPane = selected;
            }
        }
        catch
        {
        }
    }

    private void SaveSession()
    {
        Directory.CreateDirectory(_storageDirectory);
        var snapshots = Panes
            .Select(pane => new PaneSnapshot(pane.Id, pane.Title, pane.Type, pane.Target))
            .ToList();
        var session = new SessionState(snapshots, SelectedPane.Id);
        File.WriteAllText(_sessionPath, JsonSerializer.Serialize(session, JsonOptions));
    }
}