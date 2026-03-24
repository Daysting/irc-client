using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;
using System.Text;

namespace DaystingIRC.Windows;

public sealed class IrcClient : IAsyncDisposable
{
    public event Action<string>? LineReceived;
    public event Action<string>? LineSent;
    public event Action<string>? StatusChanged;
    public event Action<bool>? ConnectionStateChanged;
    public event Action<bool>? OperatorStatusChanged;
    public event Action<string>? NicknameChanged;

    private readonly SemaphoreSlim _writeLock = new(1, 1);
    private TcpClient? _tcpClient;
    private Stream? _stream;
    private StreamReader? _reader;
    private StreamWriter? _writer;
    private CancellationTokenSource? _lifetimeCts;
    private ProfileSettings? _activeProfile;
    private bool _awaitingCap;
    private bool _isSaslRequested;
    private bool _saslAuthenticateSent;
    private bool _hasCompletedRegistration;
    private bool _didJoinChannels;
    private bool _awaitingNickServIdentify;
    private CancellationTokenSource? _nickServJoinCts;
    private bool _isOperator;
    private List<string> _candidateNicks = new();
    private int _candidateNickIndex;
    private string _currentNickname = string.Empty;

    public bool IsConnected { get; private set; }

    public string CurrentNickname => _currentNickname;

    public async Task ConnectAsync(ProfileSettings profile)
    {
        await DisconnectAsync(false);
        _activeProfile = profile.Clone();
        _candidateNicks = _activeProfile.ParseNickCandidates().ToList();
        _candidateNickIndex = 0;
        _currentNickname = _candidateNicks.FirstOrDefault() ?? _activeProfile.Nickname;
        NicknameChanged?.Invoke(_currentNickname);
        ResetProtocolState();

        try
        {
            _tcpClient = new TcpClient();
            await _tcpClient.ConnectAsync(ProfileSettings.LockedHost, ProfileSettings.LockedPort);

            var baseStream = _tcpClient.GetStream();
            var sslStream = new SslStream(baseStream, false, (_, _, _, _) => true);
            await sslStream.AuthenticateAsClientAsync(new SslClientAuthenticationOptions
            {
                TargetHost = ProfileSettings.LockedHost,
                EnabledSslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13,
                CertificateRevocationCheckMode = X509RevocationMode.NoCheck,
            });

            _stream = sslStream;

            _reader = new StreamReader(_stream, Encoding.UTF8, false, 4096, leaveOpen: true);
            _writer = new StreamWriter(_stream, new UTF8Encoding(false), 4096, leaveOpen: true)
            {
                AutoFlush = true,
                NewLine = "\r\n",
            };

            _lifetimeCts = new CancellationTokenSource();
            IsConnected = true;
            ConnectionStateChanged?.Invoke(true);
            StatusChanged?.Invoke($"Connected to {ProfileSettings.LockedHost}:{ProfileSettings.LockedPort} TLS={ProfileSettings.LockedTls}");
            _ = Task.Run(() => ReceiveLoopAsync(_lifetimeCts.Token));
            await RegisterSessionAsync();
        }
        catch (Exception ex)
        {
            StatusChanged?.Invoke($"Connection failed: {ex.Message}");
            await DisconnectAsync(false);
        }
    }

    public Task DisconnectAsync(bool announce = true)
    {
        _nickServJoinCts?.Cancel();
        _nickServJoinCts?.Dispose();
        _nickServJoinCts = null;

        if (_lifetimeCts is not null)
        {
            _lifetimeCts.Cancel();
            _lifetimeCts.Dispose();
            _lifetimeCts = null;
        }

        _reader?.Dispose();
        _writer?.Dispose();
        _stream?.Dispose();
        _tcpClient?.Dispose();

        _reader = null;
        _writer = null;
        _stream = null;
        _tcpClient = null;
        _activeProfile = null;

        var wasConnected = IsConnected;
        IsConnected = false;
        ResetProtocolState();
        SetOperatorStatus(false);

        if (wasConnected)
        {
            ConnectionStateChanged?.Invoke(false);
            if (announce)
            {
                StatusChanged?.Invoke("Connection closed");
            }
        }
        return Task.CompletedTask;
    }

    public async Task SendRawAsync(string line)
    {
        if (!IsConnected || _writer is null)
        {
            return;
        }

        await _writeLock.WaitAsync();
        try
        {
            await _writer.WriteLineAsync(line);
            LineSent?.Invoke(line);
        }
        catch (Exception ex)
        {
            StatusChanged?.Invoke($"Send error: {ex.Message}");
        }
        finally
        {
            _writeLock.Release();
        }
    }

    public ValueTask DisposeAsync()
    {
        return new ValueTask(DisconnectAsync(false));
    }

    private void ResetProtocolState()
    {
        _awaitingCap = false;
        _isSaslRequested = false;
        _saslAuthenticateSent = false;
        _hasCompletedRegistration = false;
        _didJoinChannels = false;
        _awaitingNickServIdentify = false;
        _candidateNickIndex = 0;
    }

    private async Task RegisterSessionAsync()
    {
        if (_activeProfile is null)
        {
            return;
        }

        if (ShouldUseSasl(_activeProfile))
        {
            _awaitingCap = true;
            StatusChanged?.Invoke("Requesting IRCv3 CAP LS for SASL");
            await SendRawAsync("CAP LS 302");
        }

        await SendRawAsync($"NICK {_currentNickname}");
        await SendRawAsync($"USER {_activeProfile.Username} 0 * :{_activeProfile.RealName}");
    }

    private static bool ShouldUseSasl(ProfileSettings profile)
    {
        if (!profile.EnableSasl)
        {
            return false;
        }

        return profile.SaslMechanism switch
        {
            SaslMechanism.Plain => !string.IsNullOrWhiteSpace(profile.SaslPassword),
            SaslMechanism.External => true,
            _ => false,
        };
    }

    private async Task ReceiveLoopAsync(CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested && _reader is not null)
            {
                var line = await _reader.ReadLineAsync();
                if (line is null)
                {
                    break;
                }

                if (line.StartsWith("PING ", StringComparison.OrdinalIgnoreCase))
                {
                    await SendRawAsync(line.Replace("PING", "PONG", StringComparison.OrdinalIgnoreCase));
                }

                await HandleProtocolLineAsync(line);
                LineReceived?.Invoke(line);
            }

            if (!cancellationToken.IsCancellationRequested)
            {
                StatusChanged?.Invoke("Server closed the connection");
                await DisconnectAsync(false);
                ConnectionStateChanged?.Invoke(false);
            }
        }
        catch (ObjectDisposedException)
        {
        }
        catch (Exception ex)
        {
            StatusChanged?.Invoke($"Receive error: {ex.Message}");
            await DisconnectAsync(false);
            ConnectionStateChanged?.Invoke(false);
        }
    }

    private async Task HandleProtocolLineAsync(string line)
    {
        if (string.IsNullOrWhiteSpace(line))
        {
            return;
        }

        var message = IrcMessage.Parse(line);
        switch (message.Command)
        {
            case "CAP":
                await HandleCapAsync(message);
                break;
            case "AUTHENTICATE":
                await HandleAuthenticateAsync(message);
                break;
            case "381":
                SetOperatorStatus(true);
                StatusChanged?.Invoke("Operator status granted");
                break;
            case "491":
                SetOperatorStatus(false);
                StatusChanged?.Invoke("Operator login denied");
                break;
            case "221":
                var userModes = message.Trailing ?? message.GetParameterOrEmpty(message.Parameters.Count - 1);
                SetOperatorStatus(userModes.Contains('o'));
                break;
            case "MODE":
                HandleOwnModeChange(message);
                break;
            case "433":
                await HandleNicknameInUseAsync();
                break;
            case "900":
            case "903":
                if (_awaitingCap)
                {
                    StatusChanged?.Invoke("SASL authentication succeeded");
                    await SendRawAsync("CAP END");
                    _awaitingCap = false;
                    await CompleteRegistrationPostAuthAsync();
                }
                break;
            case "904":
            case "905":
            case "906":
            case "907":
                if (_awaitingCap)
                {
                    StatusChanged?.Invoke("SASL authentication failed; continuing without SASL");
                    await SendRawAsync("CAP END");
                    _awaitingCap = false;
                    await CompleteRegistrationPostAuthAsync();
                }
                break;
            case "001":
                var welcomeNick = message.GetParameterOrEmpty(0);
                if (!string.IsNullOrWhiteSpace(welcomeNick))
                {
                    UpdateCurrentNickname(welcomeNick);
                }

                if (!_awaitingCap)
                {
                    await CompleteRegistrationPostAuthAsync();
                }

                break;
            case "NICK":
                if (string.Equals(message.Nickname, _currentNickname, StringComparison.OrdinalIgnoreCase))
                {
                    UpdateCurrentNickname((message.Trailing ?? message.GetParameterOrEmpty(0)).TrimStart(':'));
                }

                break;
            default:
                if (_awaitingNickServIdentify)
                {
                    var lowered = line.ToLowerInvariant();
                    if (IsNickServIdentifySuccess(lowered))
                    {
                        _awaitingNickServIdentify = false;
                        _nickServJoinCts?.Cancel();
                        StatusChanged?.Invoke("NickServ identify succeeded");
                        await JoinConfiguredChannelsAsync("NickServ identify succeeded");
                    }
                    else if (IsNickServIdentifyFailure(lowered))
                    {
                        _awaitingNickServIdentify = false;
                        _nickServJoinCts?.Cancel();
                        StatusChanged?.Invoke("NickServ identify failed; joining anyway");
                        await JoinConfiguredChannelsAsync("NickServ identify failed");
                    }
                }

                break;
        }
    }

    private async Task HandleCapAsync(IrcMessage message)
    {
        var subcommand = message.GetParameterOrEmpty(1).ToUpperInvariant();
        switch (subcommand)
        {
            case "LS":
                if (message.Raw.Contains("sasl", StringComparison.OrdinalIgnoreCase) && !_isSaslRequested)
                {
                    _isSaslRequested = true;
                    StatusChanged?.Invoke("Server supports SASL, requesting capability");
                    await SendRawAsync("CAP REQ :sasl");
                }
                else
                {
                    StatusChanged?.Invoke("Server CAP LS did not advertise SASL");
                    await SendRawAsync("CAP END");
                    _awaitingCap = false;
                    await CompleteRegistrationPostAuthAsync();
                }

                break;
            case "ACK":
                if (message.Raw.Contains("sasl", StringComparison.OrdinalIgnoreCase) && _activeProfile is not null)
                {
                    StatusChanged?.Invoke("SASL capability acknowledged");
                    var mechanism = _activeProfile.SaslMechanism == SaslMechanism.External ? "EXTERNAL" : "PLAIN";
                    await SendRawAsync($"AUTHENTICATE {mechanism}");
                }

                break;
            case "NAK":
                StatusChanged?.Invoke("Server rejected SASL capability; continuing without SASL");
                await SendRawAsync("CAP END");
                _awaitingCap = false;
                await CompleteRegistrationPostAuthAsync();
                break;
        }
    }

    private async Task HandleAuthenticateAsync(IrcMessage message)
    {
        if (!_awaitingCap || _activeProfile is null || _saslAuthenticateSent)
        {
            return;
        }

        if (message.GetParameterOrEmpty(0) != "+")
        {
            return;
        }

        _saslAuthenticateSent = true;
        if (_activeProfile.SaslMechanism == SaslMechanism.External)
        {
            await SendRawAsync("AUTHENTICATE +");
            return;
        }

        var authcid = string.IsNullOrWhiteSpace(_activeProfile.SaslUsername)
            ? _activeProfile.Username
            : _activeProfile.SaslUsername;
        var payload = $"{authcid}\0{authcid}\0{_activeProfile.SaslPassword}";
        var encoded = Convert.ToBase64String(Encoding.UTF8.GetBytes(payload));
        await SendRawAsync($"AUTHENTICATE {encoded}");
    }

    private async Task CompleteRegistrationPostAuthAsync()
    {
        if (_hasCompletedRegistration || _activeProfile is null)
        {
            return;
        }

        _hasCompletedRegistration = true;

        if (!string.IsNullOrWhiteSpace(_activeProfile.NickServPassword))
        {
            StatusChanged?.Invoke("Sending /NS IDENTIFY with password");
            await SendRawAsync($"PRIVMSG NickServ :IDENTIFY {_activeProfile.NickServPassword}");
        }

        if (!string.IsNullOrWhiteSpace(_activeProfile.OperName) && !string.IsNullOrWhiteSpace(_activeProfile.OperPassword))
        {
            StatusChanged?.Invoke("Sending /OPER login");
            await SendRawAsync($"OPER {_activeProfile.OperName} {_activeProfile.OperPassword}");
        }

        if (_activeProfile.DelayJoinUntilNickServIdentify && !string.IsNullOrWhiteSpace(_activeProfile.NickServPassword))
        {
            _awaitingNickServIdentify = true;
            ScheduleNickServFallbackJoin(Math.Max(3, _activeProfile.NickServIdentifyTimeoutSeconds));
            StatusChanged?.Invoke("Waiting for NickServ identify before joining channels");
            return;
        }

        await JoinConfiguredChannelsAsync("Standard post-auth join");
    }

    private void ScheduleNickServFallbackJoin(int timeoutSeconds)
    {
        _nickServJoinCts?.Cancel();
        _nickServJoinCts?.Dispose();
        _nickServJoinCts = new CancellationTokenSource();
        var cancellationToken = _nickServJoinCts.Token;

        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(timeoutSeconds), cancellationToken);
                if (!cancellationToken.IsCancellationRequested && _awaitingNickServIdentify)
                {
                    _awaitingNickServIdentify = false;
                    StatusChanged?.Invoke("NickServ identify timed out; joining channels");
                    await JoinConfiguredChannelsAsync("NickServ identify timeout");
                }
            }
            catch (TaskCanceledException)
            {
            }
        }, cancellationToken);
    }

    private async Task JoinConfiguredChannelsAsync(string reason)
    {
        if (_didJoinChannels || _activeProfile is null)
        {
            return;
        }

        _didJoinChannels = true;
        var channels = _activeProfile.ParseAutoJoinChannels();
        foreach (var channel in channels)
        {
            await SendRawAsync($"JOIN {channel}");
        }

        StatusChanged?.Invoke(channels.Count > 0
            ? $"Joined {string.Join(", ", channels)} ({reason})"
            : $"No channels configured to join ({reason})");
    }

    private async Task HandleNicknameInUseAsync()
    {
        if (_candidateNickIndex + 1 >= _candidateNicks.Count)
        {
            StatusChanged?.Invoke("Nickname in use and no alternate nicknames remain");
            return;
        }

        _candidateNickIndex += 1;
        var replacement = _candidateNicks[_candidateNickIndex];
        StatusChanged?.Invoke($"Nickname in use, trying alternate nick {replacement}");
        UpdateCurrentNickname(replacement);
        await SendRawAsync($"NICK {replacement}");
    }

    private void HandleOwnModeChange(IrcMessage message)
    {
        if (_activeProfile is null || message.Parameters.Count < 2)
        {
            return;
        }

        var target = message.GetParameterOrEmpty(0);
        if (!string.Equals(target, _currentNickname, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var modes = message.GetParameterOrEmpty(1);
        if (modes.Contains("+o", StringComparison.Ordinal))
        {
            SetOperatorStatus(true);
        }
        else if (modes.Contains("-o", StringComparison.Ordinal))
        {
            SetOperatorStatus(false);
        }
    }

    private void SetOperatorStatus(bool newValue)
    {
        if (_isOperator == newValue)
        {
            return;
        }

        _isOperator = newValue;
        OperatorStatusChanged?.Invoke(newValue);
    }

    private void UpdateCurrentNickname(string nickname)
    {
        if (string.IsNullOrWhiteSpace(nickname) || string.Equals(_currentNickname, nickname, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        _currentNickname = nickname;
        NicknameChanged?.Invoke(_currentNickname);
    }

    private static bool IsNickServIdentifySuccess(string line)
    {
        return line.Contains("nickserv", StringComparison.Ordinal)
            && (line.Contains("you are now identified", StringComparison.Ordinal)
                || line.Contains("password accepted", StringComparison.Ordinal)
                || line.Contains("successfully identified", StringComparison.Ordinal)
                || line.Contains("recognized", StringComparison.Ordinal));
    }

    private static bool IsNickServIdentifyFailure(string line)
    {
        return line.Contains("nickserv", StringComparison.Ordinal)
            && (line.Contains("password incorrect", StringComparison.Ordinal)
                || line.Contains("invalid password", StringComparison.Ordinal)
                || line.Contains("authentication failed", StringComparison.Ordinal)
                || line.Contains("incorrect password", StringComparison.Ordinal));
    }
}