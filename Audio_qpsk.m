function Audio_qpsk(mode, audio_src, audio_sec)
%% Audio_qpsk.m - Gui am thanh qua modem QPSK (am thanh -> 8 bit/mau -> bit -> khung QPSK)
%   Audio_qpsk('tx')               sinh tx_cable_audio.wav + tx_params_audio.mat (copy sang dien thoai, phat)
%   Audio_qpsk('tx','giong.wav',3) nhu tren nhung gui file cua ban, 3 s dau (mac dinh handel.mat, 1 s)
%   Audio_qpsk('rx')               thu that qua cap, giai dieu che bang Rx_qpsk.m, ghi + phat rx_audio.wav
%   Audio_qpsk('rx','loopback')    tu-kiem-tra khong can cap (BER phai = 0)
%   Audio_qpsk('rx','file')        giai ma lai rx_debug_audio.wav da thu truoc do
% Chay trong ham -> workspace rieng, khong lan bien voi Tx.m/Tx_qpsk.m (het loi BER~0.5 do ghep nham).
% Khong phat truc tiep (streaming): gui ca doan roi phat lai, nen toc do bit chi quyet dinh
% khung dai bao lau (8 kHz x 8 bit = 64 kbps, baud 4000 -> ~6.7 kbps thuc -> 1 s am thanh ~ 10 s khung).

if nargin < 2, audio_src = 'record'; end
d = fileparts(mfilename('fullpath'));
params_file = 'tx_params_audio.mat';
rx_wav = 'rx_debug_audio.wav';

if strcmp(mode, 'tx')
    AUDIO_FILE = '';    % '' = dung handel.mat co san cua MATLAB; hoac ten file .wav (tham so thu 2 cua 'tx')
    if nargin >= 2, AUDIO_FILE = audio_src; end
    audio_fs = 8000;    % tan so lay mau am thanh gui di
    if nargin < 3, audio_sec = 1; end % do dai doan gui (s), tham so thu 3 cua 'tx'
    Fs = 48000; Fc = 8000;
    baud_rate = 4000;   % da chay dung qua cap that (2 lan, BER 0); ha xuong 1000 neu kenh khac cho BER > 0
    sps = Fs/baud_rate;
    syms_per_block = 5;
    pilot_sym = (1+1j)/sqrt(2);

    if isempty(AUDIO_FILE)
        S = load('handel'); x = S.y; x_fs = S.Fs;
    else
        [x, x_fs] = audioread(AUDIO_FILE);
    end
    x = resample(mean(x, 2), audio_fs, round(x_fs));
    x = x(1:min(end, round(audio_sec*audio_fs)));
    audio_q = uint8(round((x/max(abs(x)) + 1)/2*255));       % luong tu 8 bit
    n_audio = numel(audio_q);
    audio_bits = reshape(dec2bin(audio_q, 8).' - '0', 1, []);  % MSB truoc

    bits_per_block = 2*syms_per_block;
    n_pad = mod(-numel(audio_bits), bits_per_block);
    data_bits = [audio_bits, zeros(1, n_pad)];
    num_blocks = numel(data_bits)/bits_per_block;
    preamble_bits = randi([0 1], 1, 50);

    % Cung anh xa Gray va bo cuc khung [pilot, 5 ky hieu] nhu Tx_qpsk.m
    data_syms = ((2*data_bits(1:2:end)-1) + 1j*(2*data_bits(2:2:end)-1)) / sqrt(2);
    blocks = [repmat(pilot_sym, 1, num_blocks); reshape(data_syms, syms_per_block, num_blocks)];
    symbols = [2*preamble_bits - 1, blocks(:).'];
    baseband = repelem(symbols, sps);
    t = (0:length(baseband)-1)/Fs;
    passband = real(baseband .* exp(1j*2*pi*Fc*t));
    pad = zeros(1, round(0.5*Fs));
    tx_signal = [pad, passband, pad];
    tx_signal = 0.9 * tx_signal / max(abs(tx_signal));

    audiowrite(fullfile(d, 'tx_cable_audio.wav'), tx_signal(:), Fs);
    save(fullfile(d, params_file), 'Fs', 'Fc', 'baud_rate', 'sps', 'syms_per_block', ...
        'num_blocks', 'pilot_sym', 'preamble_bits', 'data_bits', 'tx_signal', 'audio_fs', 'audio_q', 'n_audio');
    fprintf('Da ghi tx_cable_audio.wav: %d mau am thanh = %d bit, %d block, khung dai %.1f s.\n', ...
        n_audio, numel(audio_bits), num_blocks, numel(tx_signal)/Fs);
    fprintf('Copy sang dien thoai, phat, roi chay Audio_qpsk(''rx'').\n');
else
    S = load(fullfile(d, params_file), 'tx_signal', 'Fs');
    record_time = numel(S.tx_signal)/S.Fs + 3; % khung dai vai chuc giay, Rx_qpsk mac dinh chi 5 s
    Rx_qpsk; % dung nguyen chuoi giai dieu che, doc params_file/rx_wav/audio_src/record_time o tren

    q = bin2dec(char(reshape(rx_bits(1:8*n_audio) + '0', 8, []).'));
    fprintf('Mau am thanh sai: %d / %d\n', nnz(q ~= double(audio_q(:))), n_audio);
    y = 2*q/255 - 1;
    audiowrite(fullfile(d, 'rx_audio.wav'), y, audio_fs);
    sound(y, audio_fs);
end
end
