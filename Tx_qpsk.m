%% Tx_qpsk.m - Sinh khung QPSK (preamble +-1 + pilot moi 5 ky hieu) va ghi ra tx_cable_qpsk.wav
% Ban QPSK cua Tx.m (khong dong vao Tx.m). Chay file nay truoc, sau do copy
% tx_cable_qpsk.wav sang dien thoai va phat, roi chay Rx_qpsk.m.

Fs = 48000;         % sample rate
Fc = 8000;          % tan so mang
baud_rate = 1000;   % toc do ky hieu (2 bit/ky hieu -> 2 kbps)
sps = Fs/baud_rate; % mau/ky hieu (48)

syms_per_block = 5; % 5 ky hieu QPSK = 10 bit du lieu moi block
num_blocks = 200;   % 2000 bit, khung ~1.25 s (record_time 5 s trong Rx du chua); 20 block chi 200 bit qua it de do BER
pilot_sym = (1+1j)/sqrt(2); % ky hieu pilot da biet, co dinh o dau moi block

preamble_bits = randi([0 1], 1, 50); % giu +-1 (BPSK) de Rx dong bo + uoc luong CFO nhu cu
data_bits = randi([0 1], 1, num_blocks*syms_per_block*2);

% Anh xa Gray: cap bit (b1,b2) -> I=2*b1-1, Q=2*b2-1, chia sqrt(2) cho |s|=1
data_syms = ((2*data_bits(1:2:end)-1) + 1j*(2*data_bits(2:2:end)-1)) / sqrt(2);

frame_syms = zeros(1, num_blocks*(syms_per_block+1));
for k = 1:num_blocks
    blk = data_syms((k-1)*syms_per_block+1 : k*syms_per_block);
    frame_syms((k-1)*(syms_per_block+1)+1 : k*(syms_per_block+1)) = [pilot_sym, blk];
end
symbols = [2*preamble_bits - 1, frame_syms];
tx_bits = [preamble_bits, data_bits];  % chi de tham khao, Rx dung data_bits

baseband = repelem(symbols, sps);     % xung vuong, integrate-and-dump o Rx se khop

t = (0:length(baseband)-1)/Fs;
passband = real(baseband .* exp(1j*2*pi*Fc*t)); % I*cos - Q*sin

pad = zeros(1, round(0.5*Fs));        % khoang lang dau/cuoi cho de bat dau ghi am
tx_signal = [pad, passband, pad];
tx_signal = 0.9 * tx_signal / max(abs(tx_signal));

audiowrite('tx_cable_qpsk.wav', tx_signal(:), Fs);
save('tx_params_qpsk.mat', 'Fs', 'Fc', 'baud_rate', 'sps', 'syms_per_block', ...
    'num_blocks', 'pilot_sym', 'preamble_bits', 'data_bits', 'tx_bits', 'tx_signal');
fprintf('Da ghi tx_cable_qpsk.wav: %d bit du lieu (%d ky hieu QPSK) trong %d block (preamble %d ky hieu).\n', ...
    numel(data_bits), numel(data_syms), num_blocks, numel(preamble_bits));
fprintf('Copy file sang dien thoai, phat, roi chay Rx_qpsk.m.\n');
