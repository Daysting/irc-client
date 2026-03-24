using System.Collections.ObjectModel;
using System.Text.Json.Serialization;

namespace DaystingIRC.Windows;

public enum SaslMechanism
{
    Plain,
    External,
}

public enum PaneType
{
    Server,
    Channel,
    PrivateMessage,
}

public sealed class ProfileSettings : ObservableObject
{
    public const string LockedHost = "irc.daysting.com";
    public const int LockedPort = 6697;
    public const bool LockedTls = true;

    private string _nickname = "Guest";
    private string _primaryChannel = "#lobby";
    private string _alternateNicknamesCsv = string.Empty;
    private string _autoJoinChannelsCsv = string.Empty;
    private bool _enableSasl;
    private SaslMechanism _saslMechanism = SaslMechanism.Plain;
    private string _saslUsername = string.Empty;
    private string _saslPassword = string.Empty;
    private string _nickServPassword = string.Empty;
    private bool _delayJoinUntilNickServIdentify;
    private int _nickServIdentifyTimeoutSeconds = 8;
    private string _operName = string.Empty;
    private string _operPassword = string.Empty;
    private string _username = "daysting";
    private string _realName = "Daysting IRC";

    public string Nickname
    {
        get => _nickname;
        set => SetProperty(ref _nickname, value);
    }

    public string PrimaryChannel
    {
        get => _primaryChannel;
        set => SetProperty(ref _primaryChannel, value);
    }

    public string AlternateNicknamesCsv
    {
        get => _alternateNicknamesCsv;
        set => SetProperty(ref _alternateNicknamesCsv, value);
    }

    public string AutoJoinChannelsCsv
    {
        get => _autoJoinChannelsCsv;
        set => SetProperty(ref _autoJoinChannelsCsv, value);
    }

    public bool EnableSasl
    {
        get => _enableSasl;
        set => SetProperty(ref _enableSasl, value);
    }

    public SaslMechanism SaslMechanism
    {
        get => _saslMechanism;
        set => SetProperty(ref _saslMechanism, value);
    }

    public string SaslUsername
    {
        get => _saslUsername;
        set => SetProperty(ref _saslUsername, value);
    }

    public string SaslPassword
    {
        get => _saslPassword;
        set => SetProperty(ref _saslPassword, value);
    }

    public string NickServPassword
    {
        get => _nickServPassword;
        set => SetProperty(ref _nickServPassword, value);
    }

    public bool DelayJoinUntilNickServIdentify
    {
        get => _delayJoinUntilNickServIdentify;
        set => SetProperty(ref _delayJoinUntilNickServIdentify, value);
    }

    public int NickServIdentifyTimeoutSeconds
    {
        get => _nickServIdentifyTimeoutSeconds;
        set => SetProperty(ref _nickServIdentifyTimeoutSeconds, Math.Clamp(value, 3, 30));
    }

    public string OperName
    {
        get => _operName;
        set => SetProperty(ref _operName, value);
    }

    public string OperPassword
    {
        get => _operPassword;
        set => SetProperty(ref _operPassword, value);
    }

    public string Username
    {
        get => _username;
        set => SetProperty(ref _username, value);
    }

    public string RealName
    {
        get => _realName;
        set => SetProperty(ref _realName, value);
    }

    public ProfileSettings Clone()
    {
        return new ProfileSettings
        {
            Nickname = Nickname,
            PrimaryChannel = PrimaryChannel,
            AlternateNicknamesCsv = AlternateNicknamesCsv,
            AutoJoinChannelsCsv = AutoJoinChannelsCsv,
            EnableSasl = EnableSasl,
            SaslMechanism = SaslMechanism,
            SaslUsername = SaslUsername,
            SaslPassword = SaslPassword,
            NickServPassword = NickServPassword,
            DelayJoinUntilNickServIdentify = DelayJoinUntilNickServIdentify,
            NickServIdentifyTimeoutSeconds = NickServIdentifyTimeoutSeconds,
            OperName = OperName,
            OperPassword = OperPassword,
            Username = Username,
            RealName = RealName,
        };
    }

    public IReadOnlyList<string> ParseNickCandidates()
    {
        var candidates = new List<string>();
        AddIfPresent(candidates, Nickname);

        foreach (var candidate in AlternateNicknamesCsv.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            AddIfPresent(candidates, candidate);
        }

        if (candidates.Count == 0)
        {
            candidates.Add("Guest");
        }

        return candidates;
    }

    public IReadOnlyList<string> ParseAutoJoinChannels()
    {
        var channels = new List<string>();
        AddChannelIfValid(channels, PrimaryChannel);

        foreach (var channel in AutoJoinChannelsCsv.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
        {
            AddChannelIfValid(channels, channel);
        }

        return channels;
    }

    private static void AddIfPresent(List<string> values, string candidate)
    {
        var trimmed = candidate.Trim();
        if (!string.IsNullOrWhiteSpace(trimmed) && !values.Contains(trimmed, StringComparer.OrdinalIgnoreCase))
        {
            values.Add(trimmed);
        }
    }

    private static void AddChannelIfValid(List<string> channels, string candidate)
    {
        var trimmed = candidate.Trim();
        if (trimmed.StartsWith('#') && !channels.Contains(trimmed, StringComparer.OrdinalIgnoreCase))
        {
            channels.Add(trimmed);
        }
    }
}

public sealed class ChannelUser
{
    public ChannelUser(string nick, string prefix)
    {
        Nick = nick;
        Prefix = prefix;
    }

    public string Nick { get; }

    public string Prefix { get; }

    public string DisplayName => string.Concat(Prefix, Nick);
}

public sealed class PaneViewModel : ObservableObject
{
    private readonly Dictionary<string, string> _users = new(StringComparer.OrdinalIgnoreCase);
    private string _title;
    private string _topic = string.Empty;
    private int _unreadCount;

    public PaneViewModel(string id, string title, PaneType type, string target)
    {
        Id = id;
        _title = title;
        Type = type;
        Target = target;
        Messages = new ObservableCollection<string>();
        Users = new ObservableCollection<ChannelUser>();
    }

    public string Id { get; }

    public PaneType Type { get; }

    public string Target { get; }

    public ObservableCollection<string> Messages { get; }

    public ObservableCollection<ChannelUser> Users { get; }

    public string Title
    {
        get => _title;
        set => SetProperty(ref _title, value);
    }

    public string Topic
    {
        get => _topic;
        set
        {
            if (SetProperty(ref _topic, value))
            {
                RaisePropertyChanged(nameof(HasTopic));
            }
        }
    }

    public bool HasTopic => !string.IsNullOrWhiteSpace(Topic);

    public int UnreadCount
    {
        get => _unreadCount;
        set
        {
            if (SetProperty(ref _unreadCount, value))
            {
                RaisePropertyChanged(nameof(HasUnread));
            }
        }
    }

    public bool HasUnread => UnreadCount > 0;

    [JsonIgnore]
    public bool CanClose => Type != PaneType.Server;

    public void ReplaceUsers(IEnumerable<(string Nick, string Prefix)> users)
    {
        _users.Clear();
        foreach (var (nick, prefix) in users)
        {
            _users[nick] = prefix;
        }

        RefreshUsers();
    }

    public void UpsertUser(string nick, string prefix = "")
    {
        _users[nick] = StrongestPrefix(_users.GetValueOrDefault(nick, string.Empty), prefix);
        RefreshUsers();
    }

    public void RemoveUser(string nick)
    {
        if (_users.Remove(nick))
        {
            RefreshUsers();
        }
    }

    public void RenameUser(string oldNick, string newNick)
    {
        if (!_users.Remove(oldNick, out var prefix))
        {
            return;
        }

        _users[newNick] = prefix;
        RefreshUsers();
    }

    public void ApplyPrefixChange(string nick, string prefix, bool adding)
    {
        if (!_users.TryGetValue(nick, out var existing))
        {
            existing = string.Empty;
        }

        _users[nick] = adding
            ? StrongestPrefix(existing, prefix)
            : existing == prefix ? string.Empty : existing;
        RefreshUsers();
    }

    public void ClearUsers()
    {
        if (_users.Count == 0)
        {
            return;
        }

        _users.Clear();
        RefreshUsers();
    }

    private void RefreshUsers()
    {
        var ordered = _users
            .Select(entry => new ChannelUser(entry.Key, entry.Value))
            .OrderByDescending(user => PrefixRank(user.Prefix))
            .ThenBy(user => user.Nick, StringComparer.OrdinalIgnoreCase)
            .ToList();

        Users.Clear();
        foreach (var user in ordered)
        {
            Users.Add(user);
        }
    }

    private static string StrongestPrefix(string left, string right)
    {
        return PrefixRank(right) > PrefixRank(left) ? right : left;
    }

    private static int PrefixRank(string prefix)
    {
        return prefix switch
        {
            "~" => 5,
            "&" => 4,
            "@" => 3,
            "%" => 2,
            "+" => 1,
            _ => 0,
        };
    }
}

public sealed record PaneSnapshot(string Id, string Title, PaneType Type, string Target);

public sealed record SessionState(List<PaneSnapshot> Panes, string SelectedPaneId);

public sealed class IrcMessage
{
    private IrcMessage(string raw, string prefix, string command, List<string> parameters, bool hasTrailing)
    {
        Raw = raw;
        Prefix = prefix;
        Command = command;
        Parameters = parameters;
        HasTrailing = hasTrailing;
    }

    public string Raw { get; }

    public string Prefix { get; }

    public string Command { get; }

    public List<string> Parameters { get; }

    public bool HasTrailing { get; }

    public string Nickname => Prefix.Split('!', 2)[0];

    public string? Trailing => HasTrailing && Parameters.Count > 0 ? Parameters[^1] : null;

    public string GetParameterOrEmpty(int index)
    {
        return index >= 0 && index < Parameters.Count ? Parameters[index] : string.Empty;
    }

    public static IrcMessage Parse(string raw)
    {
        var remainder = raw;
        var prefix = string.Empty;

        if (remainder.StartsWith(':'))
        {
            var prefixEnd = remainder.IndexOf(' ');
            if (prefixEnd > 0)
            {
                prefix = remainder[1..prefixEnd];
                remainder = remainder[(prefixEnd + 1)..];
            }
        }

        var trailingIndex = remainder.IndexOf(" :", StringComparison.Ordinal);
        var hasTrailing = trailingIndex >= 0;
        var trailing = string.Empty;
        if (hasTrailing)
        {
            trailing = remainder[(trailingIndex + 2)..];
            remainder = remainder[..trailingIndex];
        }

        var tokens = remainder.Split(' ', StringSplitOptions.RemoveEmptyEntries).ToList();
        var command = tokens.Count > 0 ? tokens[0] : string.Empty;
        if (tokens.Count > 0)
        {
            tokens.RemoveAt(0);
        }

        if (hasTrailing)
        {
            tokens.Add(trailing);
        }

        return new IrcMessage(raw, prefix, command, tokens, hasTrailing);
    }
}