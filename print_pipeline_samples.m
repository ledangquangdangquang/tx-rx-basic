%% print_pipeline_samples.m - chay Tx/Rx roi in 10 mau dau cua tin hieu o
% moi buoc bien doi, de xem no thay doi the nao qua tung giai doan.
% Script phu cho README, khong phai mot phan cua modem.
cd(fileparts(mfilename('fullpath')));
run('Tx.m');
run('Rx.m');

fprintf('\n--- 10 mau dau moi buoc (minh hoa cho README) ---\n');
fprintf('\n1) rx_raw (tin hieu tho, dang nam trong doan pad im lang dau file):\n');
disp(rx_raw(1:10).');
fprintf('2) rx_bb (sau ha tan xuong baseband phuc):\n');
disp(rx_bb(1:10).');
fprintf('3) mf_out (sau loc phoi hop, van con trong doan pad):\n');
disp(mf_out(1:10).');
fprintf('4) preamble_seg (10 mau dau cua DUNG doan preamble tim duoc, start_idx=%d):\n', start_idx);
disp(preamble_seg(1:10).');
fprintf('5) mf_corr (cung vi tri tren, sau khi bu CFO = %.2f Hz):\n', cfo_hz);
disp(mf_corr(1:10).');

% Tinh lai eq_sym cua rieng block 1 (Rx.m ghi de bien nay moi vong lap nen
% khong con luu lai tung block trong workspace) de in 10 ky hieu da can bang
% ung voi 10 bit data dau tien.
blk_off_nom = data_start;
pilot_idx_nom = blk_off_nom + round(sps/2) - 1;
cand = pilot_idx_nom + (-search_win:search_win);
cand = cand(cand >= 1 & cand <= length(mf_corr));
[~, best_k] = max(abs(mf_corr(cand)));
blk_off = blk_off_nom + (cand(best_k) - pilot_idx_nom);
g1 = mf_corr(blk_off + round(sps/2) - 1) / pilot_sym;
eq_sym_blk1 = mf_corr(blk_off + (1:bits_per_block)*sps + round(sps/2) - 1) / g1;
fprintf('6) eq_sym cua block 1 (sau can bang zero-forcing bang pilot, 1 gia tri/bit):\n');
disp(eq_sym_blk1.');
fprintf('7) rx_bits(1:10) sau slicer, so voi data_bits(1:10) goc:\n');
disp(rx_bits(1:10));
disp(data_bits(1:10));
