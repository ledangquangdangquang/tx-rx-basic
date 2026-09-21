%% Rx_qpsk.m - Ghi am / doc lai tin hieu va giai dieu che QPSK
% Ban QPSK cua Rx.m (khong dong vao Rx.m). Can chay Tx_qpsk.m truoc.
% Luon nap lai tx_params_qpsk.mat (khong dung bien con lai trong workspace) de
% khong ghep nham voi tx_signal/data_bits cua Tx.m (BPSK) -> BER~0.5.
% Audio_qpsk.m goi file nay trong workspace cua ham va dat san params_file/rx_wav/
% record_time/audio_src; chay tay thi cac bien nay lay mac dinh (hang so, khong lech).
if ~exist('params_file','var'), params_file = 'tx_params_qpsk.mat'; rx_wav = 'rx_debug_qpsk.wav'; end
load(fullfile(fileparts(mfilename('fullpath')), params_file));

RX_SOURCE = 'file'; % 'loopback' = tu-kiem-tra khong can dien thoai/cap that
                        % 'record'   = thu that qua cap tai nghe
                        % 'file'     = doc lai rx_debug_qpsk.wav da thu truoc do (chan doan lai
                        %              khong can thu lai lan nua)
if exist('audio_src','var'), RX_SOURCE = audio_src; end

if strcmp(RX_SOURCE, 'loopback')
    rx_raw = tx_signal(:);
elseif strcmp(RX_SOURCE, 'file')
    rx_raw = audioread(fullfile(fileparts(mfilename('fullpath')), rx_wav));
else
    if ~exist('record_time','var'), record_time = 5; end % mac dinh 5s; Audio_qpsk.m dat theo do dai khung
    input_device_id = -1; % ponytail: -1 = thiet bi mac dinh he thong; neu bi thu nham
                           % mic laptop thay vi cap tai nghe, chay audiodevinfo(1) de
                           % xem danh sach ID roi gan so do vao day
    if input_device_id >= 0
        rec = audiorecorder(Fs, 16, 1, input_device_id);
    else
        rec = audiorecorder(Fs, 16, 1);
    end
    disp('Bat dau phat file .wav (tx_cable_qpsk.wav hoac tx_cable_audio.wav) tren dien thoai ngay bay gio...');
    recordblocking(rec, record_time);
    rx_raw = getaudiodata(rec);
    fprintf('Muc tin hieu thu duoc: peak=%.4f, rms=%.4f (gan 0 nghia la thu nham thiet bi hoac chua cam cap)\n', ...
        max(abs(rx_raw)), rms(rx_raw));
    audiowrite(fullfile(fileparts(mfilename('fullpath')), rx_wav), rx_raw, Fs); % ponytail: de soi lai neu decode sai
end

% Ha tan xuong baseband phuc (I/Q)
t = (0:length(rx_raw)-1)'/Fs;
rx_bb = rx_raw .* exp(-1j*2*pi*Fc*t);

% Loc phoi hop (integrate-and-dump ~ trung binh truot do dai 1 ky hieu)
mf_out = conv(rx_bb, ones(sps,1)/sps, 'same');

% Dong bo: tuong quan cheo voi preamble da biet (+-1, thuc), quet qua luoi CFO
% ung vien truoc. Ly do: tuong quan coherent tren ca 50 ky hieu preamble se tu
% trieu tieu khi CFO that > ~1/(2*50ms) = 10Hz (pha troi het mot vong qua cua so),
% lam khoa nham dinh cham du "do tin cay" bao cao van cao. Quet tho +-500Hz (buoc
% 15Hz) roi lay cap (do tre, CFO) cho dinh tuong quan cao nhat; CFO chinh xac
% duoc tinh lai ben duoi sau khi da khoa dung.
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

% Bam CFO + timing pilot theo doan ngan (M block), KHONG gia dinh 1 CFO/toc do troi co dinh
% ca khung. Tren cap that + dien thoai, ty le lech dong ho DOI giua khung (quan sat khung 10 s:
% CFO -24 Hz suot 2.6 s roi nhay sang ~+4 Hz) -> CFO toan khung + drift suy tu no lech qua
% ca ky hieu o cuoi khung, bat dau mat pilot hang loat. Moi doan: tinh chinh CFO bang do doc
% pha pilot (vi tri pilot neo tai dau doan nen sai so CFO chi nhan voi M block, khong nhan voi
% ca khung), roi chinh vi tri +-win mau theo do dong pha pilot cua ca doan (trung binh qua M
% block nen khong nhap nhang khi ky hieu ke bang pilot, khac max() |mf| tung block).
data_start = length(preamble_ref) + 1;
spb = (syms_per_block+1)*sps; % mau/block danh nghia
mfo = mf_out(start_idx:end); L = numel(mfo);
M = 10; win = 2;
pilot_idx = zeros(1, num_blocks); cfo_blk = zeros(1, num_blocks);
cfo_pre = cfo_hz;
p0 = data_start + round(sps/2) - 1; % vi tri pilot block 1 (so thuc, cong don qua cac doan)
for b0 = 1:M:num_blocks
    m = min(M, num_blocks - b0 + 1);
    for it = 1:2 % cfo -> vi tri pilot -> cfo
        drift = -cfo_hz / (Fc + cfo_hz);
        p = min(round(p0 + (0:m-1)'*spb*(1+drift)), L);
        if m >= 3
            ph = unwrap(angle(mfo(p) .* exp(-1j*2*pi*cfo_hz*(p-1)/Fs) / pilot_sym));
            pf = polyfit(p - p(1), ph, 1);
            cfo_hz = cfo_hz + pf(1)*Fs/(2*pi); % pha du +2*pi*d/Fs moi mau -> CFO that = cfo_hz + d
        end
    end
    drift = -cfo_hz / (Fc + cfo_hz);
    p = round(p0 + (0:m-1)'*spb*(1+drift));
    best_coh = -1; dbest = 0;
    for dd = [0 -1 1 -win win] % 0 truoc: hoa thi giu nguyen vi tri du doan
        pd = min(max(p + dd, 1), L);
        z = mfo(pd) .* exp(-1j*2*pi*cfo_hz*(pd-1)/Fs);
        coh = abs(sum(z)) / sum(abs(z));
        if coh > best_coh, best_coh = coh; dbest = dd; end
    end
    pilot_idx(b0:b0+m-1) = min(max(p + dbest, 1), L);
    cfo_blk(b0:b0+m-1) = cfo_hz;
    p0 = p0 + m*spb*(1+drift) + dbest;
end
cfo_hz = median(cfo_blk);
fprintf('CFO preamble %.2f Hz -> bam theo pilot (min / median / max): %.2f / %.2f / %.2f Hz\n', ...
    cfo_pre, min(cfo_blk), cfo_hz, max(cfo_blk));

rx_bits = zeros(1, num_blocks*syms_per_block*2);
bit_ptr = 1;
eq_all = [];
% Lay mau tung ky hieu, can bang kenh tren tung block bang pilot (zero-forcing).
% Pilot la so phuc nen g = bien do * pha kenh; chia eq_sym = mf/g sua ca hai,
% ke ca pha quay do lech pha mang (dieu QPSK can, BPSK chi can dau). CFO cua block
% (cfo_blk) chi con dung de quay not pha tu pilot den tung ky hieu trong block.
block_timing = pilot_idx - (data_start + (0:num_blocks-1)*spb + round(sps/2) - 1); % ponytail: chi de in chan doan
for blk = 1:num_blocks
    p = pilot_idx(blk); cb = cfo_blk(blk);
    drift = -cb / (Fc + cb);
    g = mfo(p) / pilot_sym; % pilot o dau block
    for b = 1:syms_per_block
        idx_c = min(p + b*sps + round(drift*b*sps), L); % drift trong block
        eq_sym = mfo(idx_c) * exp(-1j*2*pi*cb*(idx_c-p)/Fs) / g;
        eq_all(end+1) = eq_sym; % chi de ve scatterplot
        rx_bits(bit_ptr)   = real(eq_sym) > 0; % b1 -> I
        rx_bits(bit_ptr+1) = imag(eq_sym) > 0; % b2 -> Q
        bit_ptr = bit_ptr + 2;
    end
end
if num_blocks <= 300
    fprintf('Lech dinh pilot so voi danh nghia tung block (mau): %s\n', mat2str(block_timing));
else
    fprintf('Lech dinh pilot so voi danh nghia (mau): dau %d, giua %d, cuoi %d\n', block_timing(1), block_timing(ceil(end/2)), block_timing(end));
end

[num_err, ber] = biterr(data_bits, rx_bits);
fprintf('CFO uoc luong: %.2f Hz. So bit loi: %d / %d, BER = %.4f\n', ...
    cfo_hz, num_err, numel(data_bits), ber);

% EVM: do do tan cua cac cum sau can bang, min hon BER khi so bit it (BER=0 chi
% noi duoc BER < ~3/so bit). SNR uoc luong = -20*log10(EVM).
ideal = (sign(real(eq_all)) + 1j*sign(imag(eq_all))) / sqrt(2); % diem chom gan nhat
evm = rms(eq_all - ideal) / rms(ideal);
fprintf('EVM = %.1f %% (SNR ky hieu ~ %.1f dB)\n', 100*evm, -20*log10(evm));

% ponytail: chan doan - loi trai deu tren cac block hay tang dan ve cuoi frame?
% Tang dan = lech dong ho mau (clock drift) chua duoc bu, chu khong phai CFO/nhieu.
bits_per_block = 2*syms_per_block;
block_err = zeros(1, num_blocks);
for blk = 1:num_blocks
    idxs = (blk-1)*bits_per_block+1 : blk*bits_per_block;
    block_err(blk) = sum(rx_bits(idxs) ~= data_bits(idxs));
end
if num_blocks <= 300
    fprintf('Loi tung block (block 1..%d): %s\n', num_blocks, mat2str(block_err));
else
    bad = find(block_err > 0);
    fprintf('Block co loi: %d / %d (block loi dau tien: %s)\n', numel(bad), num_blocks, mat2str(bad(1:min(1,end))));
end

scatterplot(eq_all);
title('Ky hieu du lieu sau can bang pilot (mong doi 4 cum o (+-1+-j)/sqrt(2))');
figure; plot(real(rx_bb)); title('Baseband I sau ha tan');
