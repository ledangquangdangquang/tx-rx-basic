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

## Ý nghĩa từng biến trung gian trong `Rx.m`

Đi theo đúng thứ tự các bước trong file (xem thêm "Chuỗi giải điều chế" ở
trên), số liệu minh hoạ lấy từ một lần chạy thật (`RX_SOURCE = 'file'`, đọc
lại `rx_debug.wav`).

### 1. Hạ tần xuống baseband: `rx_bb`

`rx_bb` là tín hiệu **baseband phức** ngay sau bước hạ tần
(`rx_bb = rx_raw .* exp(-1j*2*pi*Fc*t)`): mỗi mẫu thực của `rx_raw` bị nhân
với một pha quay `exp(-j*2*pi*Fc*t)` nên có cả phần thực lẫn phần ảo — phần
thực mang thông tin biên độ ký hiệu (giống tín hiệu I truyền thống), phần
ảo là phần vuông pha (Q) sinh ra do phép nhân phức, sẽ bị lọc bỏ dần ở các
bước sau. 10 mẫu đầu tiên của file luôn rơi vào đoạn `pad` (khoảng lặng
im lặng Tx chèn vào đầu/cuối file), nên giá trị rất nhỏ và không theo quy
luật cố định — đó là nền nhiễu của mic/ADC/loa lúc chưa có tín hiệu thật,
không phải dữ liệu:

```
>> rx_bb(1:10)
  -0.0012 + 0.0000i   -0.0000 + 0.0000i    0.0002 + 0.0003i   -0.0001 - 0.0000i
   0.0001 - 0.0002i    0.0000 + 0.0000i   -0.0001 - 0.0000i    0.0002 - 0.0003i
  -0.0001 - 0.0001i    0.0000 + 0.0000i
```

### 2. Lọc phối hợp: `mf_out`

`mf_out` là `rx_bb` sau khi qua **lọc phối hợp** (`conv(rx_bb, ones(sps,1)/sps, 'same')`
— tương đương integrate-and-dump, lấy trung bình trượt trên đúng độ dài
`sps` mẫu của một ký hiệu). Vì vẫn đang xét đúng 10 mẫu đầu (vẫn nằm trong
`pad`), lọc này chỉ đang trung bình hoá đúng đoạn nhiễu đó — nên biên độ
càng nhỏ hơn nữa (nhỏ hơn cả bậc, `1e-4` so với `1e-3`+ của `rx_bb`) vì
trung bình cộng của nhiễu ngẫu nhiên qua nhiều mẫu có xu hướng dồn về 0
nhanh hơn từng mẫu riêng lẻ:

```
>> mf_out(1:10)
   1.0e-04 *
  -0.4609 - 0.1156i   -0.3338 - 0.3359i   -0.3688 - 0.3964i   -0.4514 - 0.3964i
  -0.4196 - 0.4515i   -0.4641 - 0.5286i   -0.4832 - 0.5286i   -0.3751 - 0.7158i
  -0.4800 - 0.8975i   -0.5054 - 0.8975i
```

So hai đoạn trên với nhau là cách trực quan thấy đúng việc lọc phối hợp
làm: **giảm nhiễu bằng cách trung bình hoá**, còn việc dựng lại đúng biên
độ ±1 của ký hiệu chỉ xảy ra khi lấy mẫu đúng vị trí giữa mỗi ký hiệu bên
trong đoạn preamble/data thật (xem `scatterplot` bên dưới) — 10 mẫu đầu
tiên (trong `pad`) không phản ánh việc đó.

### 3. Đồng bộ khung: `preamble_ref`, `cfo_grid`, `c`/`lags`, `start_idx`, `peak_val`, `sync_confidence`

`preamble_ref` là dạng sóng **kỳ vọng** của 50 bit preamble (đã biết trước
ở cả Tx lẫn Rx) sau khi trải mỗi bit thành `sps` mẫu — dùng làm mẫu để so
khớp, không phải tín hiệu thu được.

`cfo_grid = -500:15:500` là danh sách các mức lệch tần số mang (Hz) đem thử
trước khi tương quan. Lý do phải quét thay vì tương quan thẳng `mf_out` với
`preamble_ref`: nếu CFO thật đủ lớn, pha trôi hết một vòng trong lúc tương
quan trên cả 50 ký hiệu preamble làm phép cộng tương quan tự triệt tiêu lẫn
nhau (tưởng như không tìm thấy preamble dù nó vẫn ở đó). Với mỗi mức thử
trong `cfo_grid`, `derot = mf_out .* exp(-j*2*pi*cfo_try*n/Fs)` xoay ngược
thử tín hiệu theo mức đó rồi `xcorr` với `preamble_ref` ra `c_try`/`lags_try`;
mức nào cho đỉnh tương quan `pv` cao nhất được giữ lại làm `c`, `lags`, `pk`.

- `peak_val` = độ lớn đỉnh tương quan cao nhất tìm được.
- `start_idx = lags(pk) + 1` = vị trí mẫu (trong `mf_out`) mà preamble thật
  sự bắt đầu — mọi chỉ số phía sau (`data_start`, `blk_off`...) đều tính
  từ mốc này.
- `sync_confidence = peak_val / median(abs(c))` = tỉ lệ đỉnh/nền tương
  quan. Ví dụ một lần chạy thật: `sync_confidence ≈ 99696` — rất cao nghĩa
  là đỉnh nổi bật hẳn so với nền, gần như chắc chắn đúng preamble; nếu chỉ
  vài lần (vài chục) thì đỉnh đó có thể chỉ là trùng hợp ngẫu nhiên, không
  nên tin `start_idx` tìm được.

### 4. Ước lượng CFO: `preamble_seg`, `sym_val`, `diffs`, `avg_step`, `cfo_hz`

`preamble_seg` = đúng đoạn `mf_out` tương ứng 50 ký hiệu preamble, cắt ra
từ `start_idx`. `sym_val(k)` lấy 1 mẫu giữa mỗi ký hiệu preamble rồi nhân
với `preamble_sym(k)` (±1 đã biết trước) để bù dấu — nếu không có CFO/nhiễu,
mọi phần tử của `sym_val` sẽ có cùng một pha (chỉ khác biên độ do nhiễu).

`diffs = sym_val(2:end) .* conj(sym_val(1:end-1))` là **hiệu pha giữa hai
ký hiệu liên tiếp** (nhân với liên hợp phức = trừ pha). CFO làm pha trôi
đều đặn theo thời gian nên mỗi `diffs(k)` xoay cùng một góc — `avg_step`
lấy góc của **trung bình vector** (không phải trung bình góc thô, để bền
với nhiễu wraparound quanh ±π). Từ đó suy ra tần số:
`cfo_hz = avg_step / (2*pi*sps/Fs)` — góc trôi mỗi ký hiệu, chia cho thời
gian một ký hiệu (`sps/Fs` giây), ra đơn vị Hz. Ví dụ thực tế: `cfo_hz ≈
-22.03 Hz` — điện thoại và laptop lệch đồng hồ tạo dao động khoảng đó,
không cố định giữa các lần chạy/thiết bị.

*Vì sao tính hiệu pha từng cặp thay vì `unwrap` rồi `polyfit` trên cả 50
điểm*: một mẫu nhiễu/méo bất thường (rất dễ gặp trên cáp thật) có thể làm
`unwrap` nhảy sai hẳn 2π, kéo theo `polyfit` suy ra một CFO giả rất lớn.
Tính từng cặp liên tiếp giới hạn thiệt hại của 1 mẫu lỗi vào đúng 1 cặp đó.

10 mẫu đầu của `preamble_seg` — tức đúng 10 mẫu đầu của `mf_out` nhưng lấy
từ `start_idx` trở đi thay vì từ đầu file — đã là tín hiệu thật (biên độ
`~0.07-0.09`), khác hẳn phần nhiễu nền `~1e-4` ở bước 1-2 vì giờ đây không
còn nằm trong đoạn `pad` nữa:

```
>> preamble_seg(1:10)
  -0.0743 + 0.0020i   -0.0758 + 0.0047i   -0.0771 + 0.0025i   -0.0821 + 0.0025i
  -0.0837 + 0.0053i   -0.0849 + 0.0032i   -0.0900 + 0.0032i   -0.0915 + 0.0059i
  -0.0927 + 0.0039i   -0.0979 + 0.0039i
```

### 5. Bù CFO: `mf_corr`

`mf_corr = mf_out(start_idx:end) .* exp(-j*2*pi*cfo_hz*n/Fs)` — áp `cfo_hz`
vừa ước lượng để xoay ngược pha, bắt đầu tính từ `start_idx` (bỏ hẳn phần
`pad`/nhiễu trước preamble). Từ đây trở đi lý tưởng là mỗi ký hiệu đã đứng
yên về pha, chỉ còn lệch biên độ/pha hằng số do kênh truyền (dây cáp +
loa + mic) — phần đó do bước cân bằng pilot ở dưới xử lý tiếp.

10 mẫu đầu của `mf_corr` — đúng cùng vị trí với `preamble_seg` ở trên, chỉ
khác là đã xoay bù CFO. Phần thực gần như không đổi (biên độ ký hiệu không
phụ thuộc CFO), nhưng phần ảo co lại rõ rệt (ví dụ mẫu thứ 8: từ `+0.0059i`
xuống `+0.0040i`) — đúng cái CFO làm: kéo pha đứng yên lại thay vì trôi dần:

```
>> mf_corr(1:10)
  -0.0743 + 0.0020i   -0.0758 + 0.0045i   -0.0771 + 0.0021i   -0.0822 + 0.0018i
  -0.0838 + 0.0043i   -0.0849 + 0.0020i   -0.0900 + 0.0017i   -0.0916 + 0.0040i
  -0.0927 + 0.0018i   -0.0980 + 0.0014i
```

### 6. Lấy mẫu + cân bằng từng block: vòng lặp `for blk = 1:num_blocks`

Mỗi block gồm 1 bit pilot (giá trị đã biết, `pilot_val`) rồi tới
`bits_per_block` bit data. Vòng lặp làm hai việc cùng lúc: **bám trôi
đồng hồ lấy mẫu** và **cân bằng biên độ/pha theo pilot**.

- `blk_off_nom` = vị trí *lý thuyết* của block (nếu đồng hồ hai máy khớp
  tuyệt đối), tính thẳng từ `data_start` và số thứ tự block.
- `timing_off` = độ lệch **luỹ kế** (tính bằng số mẫu) so với lý thuyết,
  mang từ block trước sang — đại diện cho việc đồng hồ lấy mẫu của điện
  thoại/laptop trôi dần theo thời gian.
- `pilot_idx_nom` = vị trí dự đoán của đỉnh pilot (lý thuyết + lệch luỹ kế
  từ block trước), `cand` là một cửa sổ nhỏ (`±search_win`, ở đây
  `search_win = round(sps/4) = 12` mẫu) quanh vị trí dự đoán đó.
- `pilot_idx` = vị trí trong `cand` có biên độ `|mf_corr|` lớn nhất — coi
  đó là đỉnh pilot thật của block này (early-late tracking đơn giản: tìm
  lại đỉnh thay vì tin cứng vị trí lý thuyết).
- `timing_off` được cập nhật lại = chênh lệch giữa `pilot_idx` thật và vị
  trí lý thuyết, mang tiếp sang block sau. `block_timing` chỉ lưu lại dãy
  `timing_off` qua từng block để in ra chẩn đoán, không dùng để giải mã.
  Ví dụ thực tế, lệch tăng dần đều: `[3 8 8 8 9 11 11 14 14 20 19 21 22 24
  27 16 26 29 33 30]` (mẫu) — tăng dần chứng tỏ có clock drift thật giữa
  hai máy, không phải nhiễu ngẫu nhiên (nhiễu ngẫu nhiên sẽ dao động quanh
  0, không trôi một chiều).
- `g = mf_corr(...pilot...) / pilot_sym` = **hệ số kênh** ước lượng từ
  chính pilot: lấy mẫu tại đỉnh pilot rồi chia cho giá trị pilot đã biết
  (`pilot_sym = ±1`) — vì kênh (cáp + loa + mic) chỉ nhân tín hiệu với một
  hệ số phức gần như không đổi trong 1 block ngắn, `g` gần đúng bằng đúng
  hệ số đó.
- Với mỗi bit data trong block: `eq_sym = mf_corr(idx_c) / g` — **cân bằng
  zero-forcing**, chia cho `g` để "gỡ" ảnh hưởng kênh, đưa ký hiệu về gần
  lại đúng ±1 gốc. `rx_bits(bit_ptr) = real(eq_sym) > 0` là **slicer 2-PAM**
  cuối cùng: chỉ cần dấu phần thực để quyết định bit 0/1.

10 ký hiệu đã cân bằng của block 1 (đúng `bits_per_block = 10` giá trị,
1 giá trị/bit data) — so với biên độ `~0.07-0.09` lúc chưa cân bằng ở bước
4-5, giờ phần thực đã kéo về sát ±1 và phần ảo gần như triệt tiêu, đúng
việc `g` (hệ số kênh ước lượng từ pilot) làm — gỡ bỏ suy hao/lệch pha do
dây cáp + loa + mic:

```
>> eq_sym_blk1  % = mf_corr(...) / g, 1 gia tri / bit data trong block 1
  -0.9574 + 0.0393i    0.9565 - 0.0356i    0.9988 + 0.0046i   -0.9577 + 0.0329i
  -0.9980 - 0.0078i   -0.9986 - 0.0075i    0.9538 - 0.0189i   -0.9493 + 0.0127i
   0.9435 - 0.0051i   -0.9345 - 0.0010i
```

### 7. Kết quả: `num_err`, `ber`, `block_err`

`[num_err, ber] = biterr(data_bits, rx_bits)` so trực tiếp bit gốc (Tx) với
bit vừa giải mã, ra số bit sai và tỉ lệ lỗi bit. `block_err(blk)` đếm lỗi
riêng từng block để phân biệt hai kiểu lỗi: lỗi rải đều ngẫu nhiên trên các
block (nghi nhiễu nền) so với lỗi **tăng dần về cuối khung** (nghi do trôi
đồng hồ lấy mẫu chưa bám kịp, xem thêm `bai_hoc.md`/`CLAUDE.md` ở thư mục
gốc). Ở lần chạy minh hoạ trên, `block_err` toàn số 0 (`ber = 0`) — cân
bằng + bám trôi đã đủ tốt cho lần thu đó, dù `timing_off` vẫn trôi dần.

10 bit đầu tiên sau slicer (`> 0` trên phần thực của `eq_sym_blk1` ở trên)
khớp đúng 10 bit gốc `data_bits(1:10)` — chốt lại toàn bộ chuỗi: nhiễu nền
`~1e-4` → tín hiệu preamble thật `~0.08` → pha đứng yên sau bù CFO →
biên độ ±1 sau cân bằng pilot → bit 0/1:

```
>> rx_bits(1:10)      0  1  1  0  0  0  1  0  1  0
>> data_bits(1:10)    0  1  1  0  0  0  1  0  1  0
```

Toàn bộ số liệu ở trên lấy từ script `print_pipeline_samples.m` (chạy
`Tx.m` + `Rx.m` rồi in 10 mẫu đầu ở mỗi bước) — chạy lại file này để lấy
số liệu mới nếu đổi tham số hoặc thu âm mới.

## Hình minh họa

Sinh bằng cách chạy `gen_readme_images.m` (chạy `Tx.m` + `Rx.m` rồi lưu các
hình ra `img/`) — chạy lại file này để tạo hình mới nếu đổi tham số.

![Chòm sao ký hiệu dữ liệu sau cân bằng pilot](img/constellation.png)

Chòm sao 2-PAM sau cân bằng: hai cụm điểm tách rõ quanh trục thực (bit 0/1),
độ tán ra theo trục ảo là nhiễu pha còn sót lại sau bù CFO.

![Baseband I sau hạ tần](img/baseband_I.png)

Phần I của tín hiệu sau hạ tần: đoạn giữa có biên độ lớn là khung tín hiệu
thật (preamble + data), hai bên là khoảng lặng `pad` — nhìn hình này để
kiểm tra khung có nằm giữa khoảng lặng đầu/cuối như kỳ vọng không.

![Spectrogram tín hiệu thu được](img/spectrogram.png)

Spectrogram: dải năng lượng quanh `Fc = 8000 Hz` chỉ xuất hiện đúng lúc
khung tín hiệu được phát, hữu ích để soi CFO/nhiễu trôi theo thời gian rõ
hơn xem FFT tĩnh trên cả file.
