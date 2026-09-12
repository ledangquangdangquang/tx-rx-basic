# tx_rx_basic

Bản Tx/Rx tách file (song song với `all_Test.m` ở thư mục gốc, gộp cả hai bước
vào một script). Cùng ý tưởng modem 2-PAM qua dây: laptop phát ra file wav,
copy sang điện thoại phát lại, laptop ghi âm qua cáp tai nghe rồi giải mã.

## Chạy thế nào

1. Chạy `Tx.m` trước — sinh bit ngẫu nhiên (preamble 50 bit + 20 block dữ
   liệu, mỗi block 1 bit pilot + 10 bit data), ghi ra `tx_cable.wav` và lưu
   tham số vào `tx_params.mat`. Copy `tx_cable.wav` sang điện thoại.
2. Chạy `Rx.m`. Mặc định `USE_LOOPBACK = true` — tự kiểm tra bằng cách giải
   mã lại đúng `tx_signal` trong workspace, không cần điện thoại/cáp (BER
   phải ra 0). Đổi thành `false` để ghi âm thật qua `audiorecorder`.
3. Nếu workspace bị mất (restart MATLAB), `Rx.m` tự nạp lại từ
   `tx_params.mat` — nhưng file đó chỉ được tạo sau khi `Tx.m` đã chạy ít
   nhất một lần trong thư mục này.

## Khác gì với `all_Test.m`

Không nhiều — cả hai đều: hạ tần → lọc phối hợp (integrate-and-dump) →
đồng bộ bằng tương quan chéo với preamble (quét thô CFO trước để tránh
tương quan tự triệt tiêu) → ước lượng CFO từ độ trôi pha giữa các ký hiệu
liên tiếp của preamble → lấy mẫu từng ký hiệu, cân bằng kênh zero-forcing
theo pilot mỗi block, có bám trôi đồng hồ lấy mẫu (early-late đơn giản)
→ slicer 2-PAM → `biterr`. Khác biệt chính chỉ là tách thành 2 file thay vì
1.

Biến workspace giữ nguyên quy ước: `Fs`, `Fc`, `baud_rate`, `sps`.
