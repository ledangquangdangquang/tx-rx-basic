%% Rx.m - Ghi am / doc lai tin hieu va giai dieu che 2-PAM
% Can chay Tx.m truoc. Neu workspace bi mat (restart MATLAB, clear...) giua
% chung thi nap lai tham so tu tx_params.mat do Tx.m da luu.
if ~exist('Fs', 'var')
    load(fullfile(fileparts(mfilename('fullpath')), 'tx_params.mat'));
end

USE_LOOPBACK = true; % ponytail: bat true de tu-kiem-tra khong can dien thoai/cap that;
                      % chuyen false khi thu that qua cap tai nghe.

if USE_LOOPBACK
    rx_raw = tx_signal(:);
else
    record_time = 5; % ghi thu that: chua biet tx_signal dai bao nhieu, mac dinh 5s
    input_device_id = -1; % ponytail: -1 = thiet bi mac dinh he thong; neu bi thu nham
                           % mic laptop thay vi cap tai nghe, chay audiodevinfo(1) de
                           % xem danh sach ID roi gan so do vao day
    if input_device_id >= 0
        rec = audiorecorder(Fs, 16, 1, input_device_id);
    else
        rec = audiorecorder(Fs, 16, 1);
    end
    disp('Bat dau phat tx_cable.wav tren dien thoai ngay bay gio...');
    recordblocking(rec, record_time);
    rx_raw = getaudiodata(rec);
    fprintf('Muc tin hieu thu duoc: peak=%.4f, rms=%.4f (gan 0 nghia la thu nham thiet bi hoac chua cam cap)\n', ...
        max(abs(rx_raw)), rms(rx_raw));
    audiowrite(fullfile(fileparts(mfilename('fullpath')), 'rx_debug.wav'), rx_raw, Fs); % ponytail: de soi lai neu decode sai
end

% Ha tan xuong baseband phuc (I/Q)
t = (0:length(rx_raw)-1)'/Fs;
rx_bb = rx_raw .* exp(-1j*2*pi*Fc*t);

% Loc phoi hop (integrate-and-dump ~ trung binh truot do dai 1 ky hieu)
mf_out = conv(rx_bb, ones(sps,1)/sps, 'same');

% Dong bo: tuong quan cheo voi preamble da biet, quet qua luoi CFO ung vien truoc.
% Ly do: tuong quan coherent tren ca 50 ky hieu preamble se tu trieu tieu khi CFO
% that > ~1/(2*50ms) = 10Hz (pha troi het mot vong qua cua so), lam khoa nham dinh
% cham du "do tin cay" bao cao van cao. Quet tho +-500Hz (buoc 15Hz, ponytail: du
% mau de giu pha on dinh trong 1 preamble; CFO chinh xac se duoc polyfit tinh lai
% ben duoi sau khi da khoa dung) roi lay cap (do tre, CFO) cho dinh tuong quan cao nhat.
preamble_sym = 2*preamble_bits - 1;
preamble_ref = repelem(preamble_sym, sps).';
n_full = (0:length(mf_out)-1)';
cfo_grid = -500:15:500;
best_peak = -1;
for cfo_try = cfo_grid
    derot = mf_out .* exp(-1j*2*pi*cfo_try*n_full/Fs);
    [c_try, lags_try] = xcorr(derot, preamble_ref);
    [pv, pk_try] = max(abs(c_try));
    if pv > best_peak
        best_peak = pv; c = c_try; lags = lags_try; pk = pk_try;
    end
end
peak_val = best_peak;
start_idx = lags(pk) + 1;
sync_confidence = peak_val / median(abs(c)); % thap (~vai lan) nghia la khong that su tim thay preamble
fprintf('Dong bo: peak/median tuong quan = %.1f (cang cao cang chac chan tim dung preamble)\n', sync_confidence);

if start_idx < 1 || start_idx + length(preamble_ref) - 1 > length(mf_out)
    error('Khong tim thay preamble trong tin hieu thu duoc.');
end

% Uoc luong CFO tu do troi pha cua preamble
% ponytail: dung do lech pha GIUA HAI KY HIEU LIEN TIEP (moi buoc tu wrap ve +-pi),
% khong unwrap tich luy ca 50 diem nua - 1 mau nhieu/meo (rat de gap tren cap that)
% co the lam unwrap nhay sai 2*pi va polyfit doc ra ca mot CFO gia rat lon.
preamble_seg = mf_out(start_idx : start_idx + length(preamble_ref) - 1);
sym_val = zeros(length(preamble_bits), 1);
for k = 1:length(preamble_bits)
    idx_c = (k-1)*sps + round(sps/2);
    sym_val(k) = preamble_seg(idx_c) * preamble_sym(k); % bu dau +-1
end
diffs = sym_val(2:end) .* conj(sym_val(1:end-1));
avg_step = angle(mean(diffs)); % trung binh vector, ben vung voi wraparound hon trung binh goc truc tiep
cfo_hz = avg_step / (2*pi*sps/Fs);

% Bu CFO tu vi tri preamble tro di
n = (0:length(mf_out)-start_idx)';
mf_corr = mf_out(start_idx:end) .* exp(-1j*2*pi*cfo_hz*n/Fs);

% Lay mau tung ky hieu, can bang kenh tren tung block bang pilot (zero-forcing)
% Bam duoi lech dong ho mau (clock drift) giua dien thoai/laptop: dinh pilot
% thuc te se troi dan khoi vi tri danh nghia (blk_off) theo thoi gian. Moi
% block tim lai dinh pilot trong 1 cua so nho quanh vi tri du doan (danh nghia
% + lech luy ke tu block truoc), roi mang lech do sang block sau - early-late
% tracking dun gian, khong can uoc luong ty le drift day du.
data_start = length(preamble_ref) + 1;
pilot_sym = 2*pilot_val - 1;
rx_bits = zeros(1, num_blocks*bits_per_block);
bit_ptr = 1;
timing_off = 0; % lech luy ke (mau) so voi vi tri danh nghia
search_win = round(sps/4); % ponytail: du bu drift GIUA 2 BLOCK lien tiep; drift nhanh hon thi tang so nay
block_timing = zeros(1, num_blocks); % ponytail: de in ra chan doan, khong dung de giai ma
for blk = 1:num_blocks
    blk_off_nom = data_start + (blk-1)*(bits_per_block+1)*sps;
    pilot_idx_nom = blk_off_nom + timing_off + round(sps/2) - 1;
    cand = pilot_idx_nom + (-search_win:search_win);
    cand = cand(cand >= 1 & cand <= length(mf_corr));
    [~, best_k] = max(abs(mf_corr(cand)));
    pilot_idx = cand(best_k);
    timing_off = pilot_idx - (blk_off_nom + round(sps/2) - 1); % cap nhat cho block sau
    block_timing(blk) = timing_off;
    blk_off = blk_off_nom + timing_off;
    g = mf_corr(blk_off + round(sps/2) - 1) / pilot_sym; % pilot o dau block
    for b = 1:bits_per_block
        idx_c = blk_off + b*sps + round(sps/2) - 1;
        eq_sym = mf_corr(idx_c) / g;
        rx_bits(bit_ptr) = real(eq_sym) > 0;
        bit_ptr = bit_ptr + 1;
    end
end
fprintf('Lech dinh pilot tich luy tung block (mau, +-%d la cua so tim): %s\n', search_win, mat2str(block_timing));

[num_err, ber] = biterr(data_bits, rx_bits);
fprintf('CFO uoc luong: %.2f Hz. So bit loi: %d / %d, BER = %.4f\n', ...
    cfo_hz, num_err, numel(data_bits), ber);

% ponytail: chan doan - loi trai deu tren cac block hay tang dan ve cuoi frame?
% Tang dan = lech dong ho mau (clock drift) chua duoc bu, chu khong phai CFO/nhieu.
block_err = zeros(1, num_blocks);
for blk = 1:num_blocks
    idxs = (blk-1)*bits_per_block+1 : blk*bits_per_block;
    block_err(blk) = sum(rx_bits(idxs) ~= data_bits(idxs));
end
fprintf('Loi tung block (block 1..%d): %s\n', num_blocks, mat2str(block_err));

scatterplot(mf_corr(data_start:end));
title('Ky hieu du lieu sau can bang pilot');
figure; plot(real(rx_bb)); title('Baseband I sau ha tan');
