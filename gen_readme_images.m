%% gen_readme_images.m - chay Tx/Rx roi luu lai cac hinh minh hoa cho README
% Script phu, khong phai mot phan cua modem - chi de tao anh add vao README.
% Chay 1 lan roi xoa cung duoc, giu lai de tao lai anh khi doi tham so.
cd(fileparts(mfilename('fullpath')));
run('Tx.m');
run('Rx.m');

mkdir('img');
figs = findobj(0, 'Type', 'figure');
[~, ord] = sort([figs.Number]);
figs = figs(ord);
names = {'img/constellation.png', 'img/baseband_I.png'};
for i = 1:numel(figs)
    exportgraphics(figs(i), names{i});
end

figure('Visible', 'off');
spectrogram(rx_raw, 256, 200, 256, Fs, 'yaxis');
title('Spectrogram tin hieu thu duoc (thay CFO/nhieu theo thoi gian)');
exportgraphics(gcf, 'img/spectrogram.png');

plot_spectrum(rx_raw, Fs, 'Pho tan rx-raw (tin hieu tho, passband quanh Fc)', 'img/spectrum_rx_raw.png');
plot_spectrum(rx_bb, Fs, 'Pho tan rx-bb (baseband phuc, sau ha tan)', 'img/spectrum_rx_bb.png');
plot_spectrum(mf_out, Fs, 'Pho tan mf-out (sau loc phoi hop)', 'img/spectrum_mf_out.png');

fprintf('Da luu anh vao %s/img/\n', pwd);

function plot_spectrum(sig, Fs, ttl, fname)
% ponytail: dung chung cho ca tin hieu thuc (rx_raw) lan phuc (rx_bb/mf_out) -
% fftshift luon hop le, voi tin hieu thuc pho chi doi xung qua 0.
N = length(sig);
f = (-N/2:N/2-1) * (Fs/N);
figure('Visible', 'off');
plot(f, abs(fftshift(fft(sig))));
xlabel('Tan so (Hz)'); ylabel('Bien do'); grid on; title(ttl);
exportgraphics(gcf, fname);
end
