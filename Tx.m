%% Tx.m - Sinh khung 2-PAM (preamble + pilot moi 10 bit) va ghi ra tx_cable.wav
% Chay file nay truoc, sau do copy tx_cable.wav sang dien thoai va phat.
% Cac bien duoi day o lai trong workspace de Rx.m dung.

Fs = 48000;         % sample rate
Fc = 8000;          % tan so mang
baud_rate = 1000;   % toc do ky hieu
sps = Fs/baud_rate; % mau/ky hieu (48)

bits_per_block = 10;
num_blocks = 20;
pilot_val = 1;      % bit pilot da biet, co dinh o dau moi block

preamble_bits = randi([0 1], 1, 50); % chuoi biet truoc de dong bo + uoc luong CFO
data_bits = randi([0 1], 1, num_blocks*bits_per_block);

frame_bits = zeros(1, num_blocks*(bits_per_block+1));
for k = 1:num_blocks
    blk = data_bits((k-1)*bits_per_block+1 : k*bits_per_block);
    frame_bits((k-1)*(bits_per_block+1)+1 : k*(bits_per_block+1)) = [pilot_val, blk];
end
tx_bits = [preamble_bits, frame_bits];

symbols = 2*tx_bits - 1;              % 0->-1, 1->+1
baseband = repelem(symbols, sps);     % xung vuong, integrate-and-dump o Rx se khop

t = (0:length(baseband)-1)/Fs;
passband = baseband .* cos(2*pi*Fc*t);

pad = zeros(1, round(0.5*Fs));        % khoang lang dau/cuoi cho de bat dau ghi am
tx_signal = [pad, passband, pad];
tx_signal = 0.9 * tx_signal / max(abs(tx_signal));

audiowrite('tx_cable.wav', tx_signal(:), Fs);
save('tx_params.mat', 'Fs', 'Fc', 'baud_rate', 'sps', 'bits_per_block', ...
    'num_blocks', 'pilot_val', 'preamble_bits', 'data_bits', 'tx_bits', 'tx_signal');
fprintf('Da ghi tx_cable.wav: %d bit du lieu trong %d block (preamble %d bit).\n', ...
    numel(data_bits), num_blocks, numel(preamble_bits));
fprintf('Copy file sang dien thoai, phat, roi chay Rx.m.\n');
