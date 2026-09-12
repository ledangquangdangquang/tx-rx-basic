# tx_rx_basic

Modem 2-PAM (BPSK) qua dây: laptop phát `tx_cable.wav`, copy sang điện thoại
phát lại, laptop ghi âm qua cáp tai nghe (line-in/mic) rồi giải mã lại thành
bit gốc và tính BER. "Kênh truyền" chỉ là dây cáp + loa/DAC điện thoại +
ADC laptop — không multipath, nhưng có lệch tần số/đồng hồ lấy mẫu thật
giữa hai máy.

Đây là bản sao độc lập của `Tx.m`/`Rx.m` (đã tách thành repo git riêng, push
lên https://github.com/ledangquangdangquang/tx-rx-basic). Sửa ở đây không tự
động đồng bộ ngược về thư mục gốc `code_Matlab` và ngược lại — copy tay
nếu cần.

## Chạy thế nào

1. Chạy `Tx.m` trước — sinh bit ngẫu nhiên (preamble 50 bit dùng để đồng bộ
   và ước lượng CFO, + 20 block dữ liệu, mỗi block gồm 1 bit pilot + 10 bit
   data), điều chế thành xung vuông NRZ ở tần số mang `Fc`, ghi ra
   `tx_cable.wav` và lưu toàn bộ tham số/bit vào `tx_params.mat`. Copy
   `tx_cable.wav` sang điện thoại.
2. Chạy `Rx.m`. Chọn nguồn tín hiệu qua biến `RX_SOURCE`:
   - `'loopback'` (mặc định) — tự kiểm tra bằng cách giải mã lại đúng
     `tx_signal` đang có trong workspace, không cần điện thoại/cáp (BER
     phải ra đúng 0).
   - `'record'` — ghi âm thật qua `audiorecorder` (bản ghi được lưu ra
     `rx_debug.wav` để soi lại nếu giải mã sai).
   - `'file'` — đọc lại `rx_debug.wav` đã ghi từ lần `'record'` trước đó,
     giải mã lại mà không cần cắm cáp/thu lại. **Lưu ý**: `rx_debug.wav`
     phải cùng lần chạy với `tx_params.mat` đang nạp (cùng `data_bits`) —
     nếu chạy lại `Tx.m` sau khi thu âm, `tx_params.mat` bị ghi đè và giải
     mã file cũ sẽ ra BER ~0.5 (so nhầm với bit của lần chạy khác, không
     phải lỗi kênh truyền).
3. Nếu workspace bị mất (restart MATLAB), `Rx.m` tự nạp lại tham số từ
   `tx_params.mat` — file này chỉ được tạo sau khi `Tx.m` đã chạy ít nhất
   một lần.

## Kênh truyền và tham số

Kênh truyền dùng dây cáp tai nghe (headphone cable) nối trực tiếp ngõ ra
loa/tai nghe của điện thoại vào ngõ vào line-in/mic của laptop — không
qua không khí (không phải kênh âm thanh vô tuyến).

- `Fs = 48000` Hz (sample rate), `Fc = 8000` Hz (tần số mang),
  `baud_rate = 1000` bit/s → `sps = 48` mẫu/ký hiệu.
- Khung: preamble 50 bit + 20 block × (1 bit pilot + 10 bit data) = 250 bit
  data thực (`bits_per_block = 10`, `num_blocks = 20`).
- **Mức âm lượng khi thu thật (`RX_SOURCE = 'record'`)**:
  - Điện thoại (phát): để loa ở mức ~30%.
  - Laptop (thu): input line-in/mic ở chế độ **stereo**, mức thu ~30%.
  - Chỉnh 2 mức này tương ứng để tránh clipping (quá to, méo tín hiệu) hoặc
    tín hiệu quá nhỏ lẫn vào nhiễu nền (quá nhỏ) — cả hai đều làm tăng BER.

### Ghi chú môi trường Linux

Để `audiorecorder`/`audiodevinfo` trong MATLAB nhận đúng thiết bị vào/ra
mặc định qua PulseAudio (thay vì ALSA không tìm thấy hoặc bắt nhầm thiết
bị), `~/.asoundrc` đã được chỉnh để trỏ `pcm.!default`/`ctl.!default` sang
`type pulse`:

```
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
```

Nếu `RX_SOURCE = 'record'` không thu được gì (peak/rms gần 0) hoặc
`audiorecorder` báo lỗi thiết bị, kiểm tra lại file này trước.

## Chuỗi giải điều chế ở `Rx.m`

Hạ tần xuống baseband phức (I/Q) → lọc phối hợp (integrate-and-dump) →
đồng bộ bằng tương quan chéo với preamble (quét thô CFO trước để tránh
tương quan tự triệt tiêu khi lệch tần số thật lớn) → ước lượng CFO từ độ
lệch pha giữa các ký hiệu liên tiếp của preamble (không unwrap tích luỹ cả
preamble, tránh nhảy sai 2π khi có mẫu nhiễu) → lấy mẫu từng ký hiệu, có
bám trôi đồng hồ lấy mẫu bằng tìm lại đỉnh pilot mỗi block (early-late đơn
giản) → cân bằng kênh zero-forcing theo pilot → slicer 2-PAM → `biterr`.
Thứ tự các bước này không đổi được tuỳ tiện — xem `CLAUDE.md` ở thư mục gốc
để biết chi tiết.

Biến workspace giữ nguyên quy ước: `Fs`, `Fc`, `baud_rate`, `sps`.
