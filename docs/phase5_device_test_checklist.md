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
- [ ] "Nhà phát triển" section visible in Settings
- [ ] Tapping the tile opens the system notification-listener screen
- [ ] MyFinance appears in the list
- [ ] Permission toggled on without errors
- [ ] Returning to the app does not crash

**Result:**
```
(write observations here)
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
- [ ] At least one bank notification triggered
- [ ] "Gói ứng dụng đã thấy" dialog opens and shows package names
- [ ] Package names are selectable / copyable from the dialog
- [ ] OCB package name observed: ________________
- [ ] MB package name observed: ________________
- [ ] Techcombank package name observed: ________________
- [ ] Constants in `BankPackages` match (or note any mismatch)

**Result:**
```
(write observations here — paste actual package names if they differ from the constants)
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
- [ ] Add-wallet dialog shows "Ngân hàng liên kết" dropdown
- [ ] Wallet created with bank link; subtitle shows bank name correctly
- [ ] Long-press opens bottom sheet with both options
- [ ] "Sửa liên kết ngân hàng" opens a picker pre-filled with current bank
- [ ] Clearing the link (pick "— Không liên kết —") works
- [ ] Uniqueness conflict dialog appears when picking an already-linked bank
- [ ] "Chuyển" atomically moves the link (old wallet loses it, new wallet gets it)
- [ ] Cancelling the conflict dialog leaves data unchanged

**Result:**
```
(write observations here)
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
- [ ] Bank notification triggered while app was in background
- [ ] Returning to app drains the buffer without crashing
- [ ] Banner card appears in Giao dịch tab (if capture was filed)
- [ ] Badge number on the Giao dịch tab icon matches the banner count

**Result:**
```
(write observations here — if no banner appears, note whether the notification showed in the "Gói đã thấy" dialog)
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
- [ ] Banner / badge taps open the inbox screen
- [ ] Inbox title is "Thông báo ngân hàng"
- [ ] At least one capture visible with correct wallet name
- [ ] Amount and direction sign are correct
- [ ] Timestamp matches when the notification was received (not today if it was older)
- [ ] At least one tile style verified (note which: parsed / needsReview / unparsed)
- [ ] Empty state message shows when inbox is empty

**Result:**
```
(write observations here)
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
- [ ] Confirm screen opens with pre-filled direction
- [ ] Confirm screen opens with pre-filled amount
- [ ] Confirm screen opens with pre-filled wallet
- [ ] Date field shows `capturedAt` timestamp (not today)
- [ ] Raw notification text visible as reference card at bottom
- [ ] "Ví *" label indicates wallet is required
- [ ] Confirm without selecting a wallet shows an error snackbar
- [ ] Confirm succeeds after wallet is selected
- [ ] Confirmed capture removed from inbox; badge decrements
- [ ] Transaction appears in Giao dịch with **correct date** (matches capturedAt)
- [ ] Transaction source is bank notification (tile shows correctly)

**Result:**
```
(write observations here)
```

---

## 8. Confirm screen — unparsed capture (Phase 5d)

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
- [ ] "Bỏ qua" button visible in the app bar
- [ ] Confirmation dialog appears before dismissing
- [ ] Cancelling the dialog leaves the capture in the inbox
- [ ] Confirming dismiss removes the capture from the inbox
- [ ] Badge decrements correctly
- [ ] No transaction created in Giao dịch tab

**Result:**
```
(write observations here)
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
- [ ] Confirm screen shows `capturedAt` date in the time field (not now)
- [ ] After confirming, transaction date in Giao dịch matches `capturedAt`
- [ ] Analytics page (Thống kê) shows the transaction in the correct month

**Result:**
```
(write observations here — note both the capturedAt time and the transaction timestamp you see in the list)
```

---

## 11. Full end-to-end flow

A single pass through the entire Phase 5 journey.

| Step | Action | Expected |
|------|--------|----------|
| 1 | Permission granted (Section 2) | Listener active |
| 2 | Bank-linked wallet created (Section 4) | Wallet shows bank name in subtitle |
| 3 | Real bank transaction triggered (e.g. transfer) | Notification appears on device |
| 4 | App foregrounded | Drain runs silently |
| 5 | Giao dịch tab | Badge shows count; banner visible |
| 6 | Banner tapped | Inbox opens, capture listed |
| 7 | Capture tapped | Confirm screen with pre-filled wallet |
| 8 | Confirm tapped | Inbox clears; badge drops to 0 |
| 9 | Giao dịch tab | New transaction visible, correct date |
| 10 | Thống kê tab | New transaction counted in correct month |

**Result:**
```
(write observations here — note any step that didn't match the expected column)
```

---

## 12. BankPackages TODO — constants update

After completing Sections 3 and 5, fill in the verified package names here. These need to be updated in `lib/services/bank/bank_notification_parser.dart` if any mismatch was found.

| Bank | Current constant | Observed on device | Match? |
|------|-----------------|-------------------|--------|
| OCB | `com.ocb.app` | | |
| MB | `com.mbmobile` | | |
| Techcombank | `com.techcombank.mb` | | |

If any package name differs, the parser will never match notifications from that bank — all captures will land as `unparsed`. Update the constant and rebuild before the final sign-off.

**Result:**
```
(record final verified constants here)
```

---

## Sign-off

| Area | Status | Notes |
|------|--------|-------|
| Notification listener permission | | |
| Package discovery / BankPackages constants | | |
| Wallet bank-link (add + edit + uniqueness) | | |
| Capture drain on launch/resume | | |
| Inbox (badge, banner, tile styles) | | |
| Confirm — parsed capture | | |
| Confirm — unparsed capture | | |
| Dismiss | | |
| Transaction date correctness | | |
| Full end-to-end | | |

**Overall:** ☐ Ready to merge &nbsp;&nbsp; ☐ Needs fixes (see sections above)
