# Phase 5 On-Device Test Checklist

**APK built from branch:** V0.2-Improve  
**Device:**  
**OS / OEM:**  
**Test date:**  

This checklist covers Phase 5c (native notification capture) and Phase 5d (in-app review UX) end to end. Work through the sections in order — later sections depend on earlier ones being green.

Mark each step: ✅ pass · ❌ fail · ⚠️ partial / unexpected behaviour  
Write observations in the **Result** block under each section.

---

## 1. Fresh install & basic launch

**How:**
1. Uninstall any previous MyFinance build.
2. Install the new APK.
3. Open the app and check that all four tabs load without errors (Ví, Giao dịch, Thống kê, Cài đặt).
4. Add at least one wallet (any name, any balance) so the rest of the tests have something to work with.

**Steps:**
- [ ] App installs without errors   ✅ pass
- [ ] All four tabs open cleanly    ✅ pass
- [ ] Wallet added successfully     ✅ pass

**Result:**
```
All tabs works perfectly fine funtionality-wise.
```

---

## 2. Notification listener permission (Phase 5c)

**How:**
1. Go to **Cài đặt → Nhà phát triển**.
2. Tap **"Cấp quyền nghe thông báo"**.
3. The system notification-listener settings screen should open.
4. Find **MyFinance** in the list and toggle it **on**.
5. Return to the app.

**Steps:**
- [ ] "Nhà phát triển" section visible in Settings ✅ pass
- [ ] Tapping the tile opens the system notification-listener screen ✅ pass
- [ ] MyFinance appears in the list ✅ pass
- [ ] Permission toggled on without errors ✅ pass
- [ ] Returning to the app does not crash ✅ pass

**Result:**
```
I have to first manually go into the App manager and then into the app to remove restriction first and then after that I can go into the app and enable the permissions after pressing the "Cấp quyền nghe thông báo" button.
```

---

## 3. Bank package discovery (Phase 5c)

**Context:** The app needs to know the exact package names used by OCB, MB, and Techcombank on this specific device. The "Gói ứng dụng đã thấy" tile shows every package whose notifications have been intercepted.

**How:**
1. Trigger a notification from each banking app you have installed (a push notification, SMS-style alert, or just open the app to provoke a balance notification).
2. Return to **Cài đặt → Nhà phát triển** and tap **"Gói ứng dụng đã thấy"**.
3. The dialog lists package names. Find the ones matching your banking apps.
4. Compare against the current constants in `lib/services/bank/bank_notification_parser.dart`:
   - OCB: `com.ocb.app`
   - MB: `com.mbmobile`
   - Techcombank: `com.techcombank.mb`

**Steps:**
- [ ] At least one bank notification triggered  ✅ pass
- [ ] "Gói ứng dụng đã thấy" dialog opens and shows package names ✅ pass
- [ ] Package names are selectable / copyable from the dialog ✅ pass
- [ ] OCB package name observed: 'vn.com.ocb.awe' (I have personally change the const name inside the code after seeing the package name and it does work after the change)
- [ ] MB package name observed: `com.mbmobile`
- [ ] Techcombank package name observed: 'vn.com.techcombank.bb.app' (Same case with OCB)
- [ ] Constants in `BankPackages` match (or note any mismatch) 

**Result:**
```
(write observations here — paste actual package names if they differ from the constants)
I have paste the actual package names of Techcombank and OCB into the bank_notification_parser.dart file. which made the bank notice works but instead of the bank name like OCB or Techcombank, It shows the package name. MB bank works fine.
```

---

## 4. Wallet bank-link setup (Phase 5d)

**How to add a bank-linked wallet:**
1. Go to **Ví** tab → tap **"Thêm ví"**.
2. Enter a name (e.g. "OCB"), set an initial balance, choose **Ngân hàng** type.
3. In the **"Ngân hàng liên kết"** dropdown, pick **OCB** (or whichever bank you have).
4. Tap **Lưu**. The wallet should appear in the list, subtitle showing the bank name.

**How to edit an existing wallet's link (long-press):**
1. Long-press a wallet card.
2. A bottom sheet appears with two options: **"Sửa liên kết ngân hàng"** and **"Xoá ví"**.
3. Tap **"Sửa liên kết ngân hàng"**.
4. Change the linked bank or clear it, tap **Lưu**.

**How to test the uniqueness guard:**
1. Create two wallets — link the first to OCB.
2. Long-press the second wallet → **"Sửa liên kết ngân hàng"** → pick OCB.
3. A dialog should appear: **"Ngân hàng đã được liên kết"** with an offer to move the link.
4. Tap **Chuyển**. The second wallet should now show OCB; the first wallet should lose it.
5. Verify by checking both wallet subtitles.

**Steps:**
- [ ] Add-wallet dialog shows "Ngân hàng liên kết" dropdown ✅ pass
- [ ] Wallet created with bank link; subtitle shows bank name correctly ✅ pass
- [ ] Long-press opens bottom sheet with both options ✅ pass
- [ ] "Sửa liên kết ngân hàng" opens a picker pre-filled with current bank ✅ pass
- [ ] Clearing the link (pick "— Không liên kết —") works ✅ pass
- [ ] Uniqueness conflict dialog appears when picking an already-linked bank ✅ pass
- [ ] "Chuyển" atomically moves the link (old wallet loses it, new wallet gets it) ✅ pass
- [ ] Cancelling the conflict dialog leaves data unchanged ✅ pass

**Result:**
```
Works perfectly fine
```

---

## 5. Capture drain on launch / resume (Phase 5c)

**Context:** The app drains buffered notifications when it starts and every time it resumes from the background. Captures are written to the DB before the native buffer is cleared.

**How:**
1. Ensure the notification listener is enabled (Section 2) and a bank-linked wallet exists (Section 4).
2. With the app **closed** (or moved to background), trigger a real bank notification — a payment push, or transfer alert from your banking app.
3. Open (or foreground) MyFinance.
4. Go to **Giao dịch** tab.
5. If there is a pending capture, a banner card should appear at the top of the list: **"X thông báo ngân hàng chờ xác nhận"**.

**Steps:**
- [ ] Bank notification triggered while app was in background ✅ pass
- [ ] Returning to app drains the buffer without crashing ✅ pass
- [ ] Banner card appears in Giao dịch tab (if capture was filed) ✅ pass
- [ ] Badge number on the Giao dịch tab icon matches the banner count ✅ pass

**Result:**
```
(write observations here — if no banner appears, note whether the notification showed in the "Gói đã thấy" dialog)
After all settings are good, I tried doing a bunch of notifications with some apps (bank and non-bank). All of which are capture in "Gói đã thấy" dialog. Banks notifications (specifically the transactions) were captured perfectly and put into the Giao dịch "notification" banner. Any other notifications apart from those were not captured so there has been no "Unparsed" situation observed yet.

**Note: This case may need to be further examined in the future. Basically when I first downloaded the new apk and test it a week ago, it worked fine but today when I tried testing the notification again, it doesn't work but then I redownloaded the apk and it works again. Will be further noticed once I've seen the consistency of this case. 
```

---

## 6. Captures inbox (Phase 5d)

**How:**
1. Tap the banner card in the Giao dịch tab (or tap the Giao dịch tab when the badge is showing).
2. The **"Thông báo ngân hàng"** screen opens listing pending captures.
3. Check that the tile shows: wallet/bank name, amount with +/− sign, timestamp.

**Three tile styles to verify** (you may need to seed different captures if you only have one type):
- **Parsed** (parseStatus = parsed): normal icon, primary colour, no status chip
- **Needs review** (parseStatus = needsReview): orange `?` icon, **"Cần xem lại"** chip
- **Unparsed** (parseStatus = unparsed): red ⚠ icon, **"Chưa đọc được"** chip, amount shows "—"

**Steps:**
- [ ] Banner / badge taps open the inbox screen ✅ pass
- [ ] Inbox title is "Thông báo ngân hàng" ✅ pass
- [ ] At least one capture visible with correct wallet name ✅ pass
- [ ] Amount and direction sign are correct ✅ pass
- [ ] Timestamp matches when the notification was received (not today if it was older) ✅ pass
- [ ] At least one tile style verified (note which: parsed / needsReview / unparsed) ✅ pass (parsed)
- [ ] Empty state message shows when inbox is empty ✅ pass

**Result:**
```
So far I've only encountered the parsed tile so I can't say more about the other tiles style.
```

---

## 7. Confirm screen — parsed capture (Phase 5d)

**How:**
1. From the inbox, tap a **parsed** capture.
2. Verify the form is pre-filled: direction (Chi tiêu / Thu nhập), amount, wallet.
3. Scroll down — the raw notification text should appear in a card at the bottom for reference.
4. Check the **"Thời gian giao dịch"** field — it must show the notification's original time, **not** today's time.
5. (Optional) Change the date, swap the wallet, pick a category.
6. Tap **"Xác nhận giao dịch"**.
7. You are returned to the inbox; the confirmed capture disappears.
8. Go to **Giao dịch** tab and verify the new transaction appears with the correct date, amount, wallet.

**Steps:**
- [ ] Confirm screen opens with pre-filled direction ✅ pass
- [ ] Confirm screen opens with pre-filled amount ✅ pass
- [ ] Confirm screen opens with pre-filled wallet ✅ pass
- [ ] Date field shows `capturedAt` timestamp (not today) ✅ pass
- [ ] Raw notification text visible as reference card at bottom ✅ pass
- [ ] "Ví *" label indicates wallet is required ✅ pass
- [ ] Confirm without selecting a wallet shows an error snackbar ✅ pass
- [ ] Confirm succeeds after wallet is selected ✅ pass
- [ ] Confirmed capture removed from inbox; badge decrements ✅ pass
- [ ] Transaction appears in Giao dịch with **correct date** (matches capturedAt) ✅ pass
- [ ] Transaction source is bank notification (tile shows correctly) ✅ pass

**Result:**
```
No problems here.
```

---

## 8. Confirm screen — unparsed capture (Phase 5d) // Will check later

**Context:** An unparsed capture means the parser couldn't read the notification. The user must enter amount and direction manually; the raw text is shown prominently so they can read it.

**How to get an unparsed capture** (if you don't have one naturally):
- Trigger a notification from a bank app that isn't in the supported list, or send yourself an unusual-format alert.
- It will appear in the inbox with a red ⚠ tile and "Chưa đọc được".

**How to confirm:**
1. Tap an **unparsed** capture.
2. The raw notification text should appear at the **top** of the screen in a red/error-coloured card.
3. The amount field should be **blank** (not pre-filled).
4. The direction segmented button should default to **Chi tiêu**.
5. Try tapping **"Xác nhận giao dịch"** with no amount — it should refuse with a snackbar.
6. Try confirming with no wallet selected — it should refuse.
7. Enter an amount, select a wallet, tap Confirm.
8. Verify the transaction lands with the correct wallet and amount.

**Steps:**
- [ ] Unparsed tile tapped opens the confirm screen with "Nhập thủ công" title
- [ ] Raw notification text visible prominently at the top in an error-coloured card
- [ ] Amount field is blank
- [ ] Confirm without amount shows error snackbar
- [ ] Confirm without wallet shows error snackbar
- [ ] Manual amount + wallet → confirm succeeds
- [ ] Transaction created with manually entered values

**Result:**
```
(write observations here)
```

---

## 9. Dismiss a capture (Phase 5d)

**How:**
1. Open any pending capture in the confirm screen.
2. Tap **"Bỏ qua"** in the top-right of the app bar.
3. A confirmation dialog appears: **"Bỏ qua thông báo này?"**.
4. Tap **"Bỏ qua"** to confirm.
5. You are returned to the inbox; the dismissed capture disappears.
6. No transaction should be created.

**Steps:**
- [ ] "Bỏ qua" button visible in the app bar ✅ pass
- [ ] Confirmation dialog appears before dismissing ✅ pass
- [ ] Cancelling the dialog leaves the capture in the inbox ✅ pass
- [ ] Confirming dismiss removes the capture from the inbox ✅ pass
- [ ] Badge decrements correctly ✅ pass
- [ ] No transaction created in Giao dịch tab ✅ pass

**Result:**
```
Works fine.
```

---

## 10. Transaction date correctness (Phase 5d — critical)

**Context:** The biggest correctness risk in Phase 5d. The confirmed transaction must use `capturedAt` (when the bank event happened), not the time you reviewed the inbox. If you confirm a notification from two days ago today, the transaction must be dated two days ago — not today.

**How:**
1. If possible, let a bank notification sit unreviewed for at least a few hours (or check the timestamp of a capture that arrived yesterday).
2. Open the capture in the confirm screen and note the date shown in **"Thời gian giao dịch"**.
3. Confirm it without changing the date.
4. Go to **Giao dịch** → find the new transaction.
5. Verify the transaction date matches `capturedAt`, not today's date.

**Steps:**
- [ ] Confirm screen shows `capturedAt` date in the time field (not now) ✅ pass
- [ ] After confirming, transaction date in Giao dịch matches `capturedAt` ✅ pass
- [ ] Analytics page (Thống kê) shows the transaction in the correct month ✅ pass

**Result:**
```
(write observations here — note both the capturedAt time and the transaction timestamp you see in the list)
Works fine.
```

---

## 11. Full end-to-end flow

A single pass through the entire Phase 5 journey.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Permission granted (Section 2) | Listener active | ✅ pass
| 2 | Bank-linked wallet created (Section 4) | Wallet shows bank name in subtitle | ✅ pass
| 3 | Real bank transaction triggered (e.g. transfer) | Notification appears on device | ✅ pass
| 4 | App foregrounded | Drain runs silently | ✅ pass
| 5 | Giao dịch tab | Badge shows count; banner visible | ✅ pass
| 6 | Banner tapped | Inbox opens, capture listed | ✅ pass
| 7 | Capture tapped | Confirm screen with pre-filled wallet | ✅ pass
| 8 | Confirm tapped | Inbox clears; badge drops to 0 | ✅ pass
| 9 | Giao dịch tab | New transaction visible, correct date | ✅ pass
| 10 | Thống kê tab | New transaction counted in correct month | ✅ pass

**Result:**
```
Runs perfectly fine.
```

---

## 12. BankPackages TODO — constants update

After completing Sections 3 and 5, fill in the verified package names here. These need to be updated in `lib/services/bank/bank_notification_parser.dart` if any mismatch was found.

| Bank | Current constant | Observed on device | Match? |
|------|-----------------|-------------------|--------|
| OCB | `com.ocb.app` |vn.com.ocb.awe | No |  
| MB | `com.mbmobile` |com.mbmobile | Yes |
| Techcombank | `com.techcombank.mb` |vn.com.techcombank.bb.app | No |

If any package name differs, the parser will never match notifications from that bank — all captures will land as `unparsed`. Update the constant and rebuild before the final sign-off.

**Result:**
```
(record final verified constants here)
I have already detail stuff related to this in section 3 and 5 so refer back to them.
```

---

## Sign-off

| Area | Status | Notes |
|------|--------|-------|
| Notification listener permission | Good | |
| Package discovery / BankPackages constants | Good | |
| Wallet bank-link (add + edit + uniqueness) | Good | |
| Capture drain on launch/resume | Work but still Unknown overall | Need to be further used to check |
| Inbox (badge, banner, tile styles) | Good | Unparsed still not been checked yet |
| Confirm — parsed capture | Good | |
| Confirm — unparsed capture | Unknown | |
| Dismiss | Good | |
| Transaction date correctness | Good | |
| Full end-to-end | Good | |

**Overall:** ☐ Ready to merge &nbsp;&nbsp; ☐ Needs fixes (see sections above)
