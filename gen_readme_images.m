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

fprintf('Da luu anh vao %s/img/\n', pwd);
