# Apple Pay → Shortcuts → Budget: setup guide

This guide gets Budget onto your iPhone and connects it to Apple Pay, so every tap-to-pay purchase is logged automatically. How it works is described in `docs/ARCHITECTURE.md` §5. In short, a Shortcuts **Wallet transaction automation** runs Budget's **Log Expense** action. That action saves the purchase in the background, without opening the app.

You need a Mac with **Xcode** (free on the Mac App Store), an iPhone on iOS 17 or later, a USB cable, and an Apple ID. A paid developer account is not required.

---

## A. Install the app on your iPhone with Xcode

1. Install **Xcode** from the Mac App Store and open it once. Accept the license, and when asked which platforms to install, include **iOS**.
2. In Terminal, generate the Xcode project from the repo root. The `.xcodeproj` is generated, not checked in.
   ```bash
   brew install xcodegen      # once
   cd ~/Desktop/budgeting-app
   xcodegen generate
   open Budgeting.xcodeproj
   ```
3. Add your Apple ID to Xcode: **Xcode → Settings… → Accounts → “+” → Apple ID**, then sign in.
4. In the Project navigator, click the blue **Budgeting** project. Select the **Budgeting** target and open the **Signing & Capabilities** tab.
5. Tick **Automatically manage signing**. Set **Team** to *Your Name (Personal Team)*.
6. Check the **Bundle Identifier**. It should read `com.cedrictanafranca.budgeting`. If Xcode says it is unavailable, see Troubleshooting → “Bundle identifier / App Group is taken”.
7. Turn on the **App Group**. On the same tab, find the **App Groups** section, which comes from `App/Budgeting/Budgeting.entitlements`:
   - Make sure the checkbox next to `group.com.cedrictanafranca.budgeting` is **ticked**.
   - If it is red or unticked, click the ↻ refresh button or untick and re-tick it. Xcode registers the group for your team.
   - If there is no App Groups section, click **“+ Capability” → App Groups**. Then click **“+”** in the new section and enter `group.com.cedrictanafranca.budgeting` exactly.
8. Optional, but saves repeating steps 5–7: running `xcodegen generate` again resets the team. To make the team stick, copy the team ID that Xcode shows in **Build Settings → Development Team**. Put it in `project.yml` under `settings.base.DEVELOPMENT_TEAM`.
9. Connect the iPhone with the cable. Unlock it and tap **Trust This Computer**.
10. Turn on Developer Mode on the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The phone restarts; after the restart, tap **Turn On** to confirm. The option only appears after Xcode has seen the phone once.
11. In Xcode's toolbar, choose your iPhone as the run destination. Press **⌘R** (Product → Run).
12. The first launch fails with “Untrusted Developer”. On the iPhone, open **Settings → General → VPN & Device Management**. Under *Developer App*, tap your Apple ID, then tap **Trust “Apple Development: …”** and confirm.
13. Press **⌘R** again. Budget opens with the default categories and accounts.
14. **Open Budget at least once after every install.** iOS registers the **Log Expense** action with Shortcuts when the app is installed and launched.

> With a free Personal Team, the app stops launching after **7 days**. Your data is kept. Connect the phone and press ⌘R in Xcode to renew it.

---

## B. Create the Apple Pay (Wallet) automation

1. Open the **Shortcuts** app and go to the **Automation** tab.
2. Tap **“+”** in the top-right corner. On a first automation, tap **New Automation** instead.
3. Scroll down and choose **Transaction**.
4. Under **Card**, tap **Choose** and select the Apple Pay cards you want to track. Leave **Category** and **Merchant** at *Any*.
5. Select **Run Immediately**, and turn **Notify When Run** **off**.
6. Tap **Next**, then choose **New Blank Automation**.
7. Tap **Add Action**. Search for **Log Expense** and pick the one with Budget's icon.
8. Map the Wallet data onto the action. Do this for each field below: tap the field, choose **Shortcut Input** in the variable bar above the keyboard, then tap the inserted blue *Shortcut Input* token and pick the property. Fields marked † are hidden at first: tap the **›** chevron on the action (*Show More*) to see them.

   | Log Expense field | Value |
   |---|---|
   | **Merchant** | Shortcut Input → **Merchant** |
   | **Amount** | Shortcut Input → **Amount** |
   | **Card** † | Shortcut Input → **Card** (on some iOS versions it is called **Card or Pass**) |
   | **Date** † | Shortcut Input → **Date**, if your iOS version offers it. Otherwise leave it empty: Budget uses the moment the automation runs, which is right after the tap. |

   Leave **Currency**, **Category**, **Note** and **Type** empty. Budget then uses your Budget currency, picks the category from the merchant, and logs the purchase as an Expense.
9. Tap **Done**.
10. Optional: to get a confirmation banner, add a **Show Notification** action after Log Expense and set its text to the **Log Expense** result. Its *Merchant*, *Amount* and *Category* properties are available too.

---

## C. Create a manual “Log Expense” shortcut (cash, non-Apple-Pay cards)

Budget also adds a ready-made **Log Expense** App Shortcut. It is listed under **Budget** in the Shortcuts app, and you can say *“Log expense in Budget”* to Siri. It asks for the merchant and amount. To build your own version, for example for the Home Screen or the Action button:

1. In **Shortcuts**, open the **Shortcuts** tab and tap **“+”**.
2. Tap **Add Action**, search for **Log Expense**, and add it.
3. Tap the **Merchant** field and choose **Ask Each Time**.
4. Tap the **Amount** field and choose **Ask Each Time**.
5. Optional: tap **›** to show more fields. You can set **Card** to e.g. `Cash` so the expense lands on your Cash account, or set **Category** to **Ask Each Time**.
6. Rename the shortcut to *Log Expense* using the name at the top. Then add it to the Home Screen through the share sheet, or assign it in **Settings → Action Button**.

Each run asks “Where did you spend it?” and “How much did you spend?”. Type a number like `12.50`.

---

## D. Optional: match Wallet cards to accounts

Every Apple Pay purchase passes the card's Wallet name, such as “Amex Cobalt” or “TD Visa”. Budget matches it against your accounts. It checks each account's **Card identifier** first, then the account **name**, ignoring case. An exact match comes first, then a match where either text contains the other. If nothing matches, the expense goes to your default expense account.

1. To find the exact card name, open **Wallet** and look at the card's title. You can also run the automation once and read the logged transaction's details.
2. In Budget, open **Accounts** and choose the account. Set **Card identifier** to the Wallet name, or to a distinctive part of it such as `Cobalt` or `1234`.
3. Repeat for each card.

---

## E. Test it on the device

1. Run the manual shortcut from section C. Enter `Test Coffee` and `6.45`.
2. Shortcuts shows **“Logged CA$6.45 at Test Coffee → …”**.
3. Open Budget. The expense appears on the dashboard and in Transactions. If Budget was already open in the background, the list refreshes when the app becomes active again.
4. Within 10 minutes, run the shortcut **again with the same values**. Shortcuts now shows **“Already logged CA$6.45 at Test Coffee (skipped)”**, and no second row appears.
5. Delete the test transaction in the app.
6. Make a real Apple Pay purchase with a card you selected in section B. The expense should appear within a few seconds.

---

## F. Troubleshooting

- **Log Expense isn't in the Shortcuts action list.** Launch Budget once after installing. Then force-quit Shortcuts and search again for “Log Expense” or “Budget”. If it is still missing, restart the iPhone.
- **“Budget needs an amount greater than zero”.** On some iOS versions the Wallet *Amount* arrives as text, such as `CA$6.45`. In the automation, add a **Get Numbers from Input** action on *Shortcut Input → Amount* before Log Expense. Then map **Amount** to the *Numbers* result.
- **“Already logged … (skipped)”.** This is expected. Budget saw the same merchant and amount within 10 minutes, or the same purchase fingerprint (merchant + amount + 5-minute window). This protects you from automations that fire twice, and from purchases you also typed in by hand. If you really bought two identical items in a row, add the second one in the app.
- **The expense landed on the wrong account.** Set the account's Card identifier (section D). Nothing matched, so Budget used the default expense account.
- **The category is wrong.** Change it on the transaction in the app. Budget remembers your choice for that merchant, and the next purchase there is categorized the same way.
- **Shortcuts shows an error.** Budget never drops a purchase silently: when it can't save, the action fails and Shortcuts shows the reason. Re-run the manual shortcut, or add the expense in the app.
- **Bundle identifier / App Group is taken.** IDs are global across all Apple accounts. Pick your own, e.g. `com.yourname.budgeting` and `group.com.yourname.budgeting`, and change it in **all three** places:
  - `PRODUCT_BUNDLE_IDENTIFIER` and the entitlements group in `project.yml`
  - `BudgetPersistence.appGroupID` in `Packages/BudgetPersistence/Sources/BudgetPersistence/BudgetPersistence.swift`
  
  Then run `xcodegen generate` and redo section A, steps 4–7.
- **The app was installed before the App Group was enabled.** The data then lives in the app's private container. It shows up empty after you enable the group, because the store moves to the shared container. Either re-enter the data or back it up and restore it before you switch.
- **The app won't launch after a week.** The free provisioning profile expired. Connect the phone and press ⌘R in Xcode.

## Limitations

- **Only tap-to-pay purchases trigger the automation.** Physical card swipes or inserts, online and in-app Apple Pay, and cards that aren't in Wallet do not trigger it. Apple Watch purchases may not trigger it either; test this on your setup. Use the manual shortcut for everything else.
- **Merchant names are raw.** Wallet passes strings like `SQ *BLUE BOTTLE #12`. Budget tidies them, and recategorizing teaches it the merchant, but some names may still look odd. Rename them in the app.
- **Refunds have no sign.** A refund arrives as a positive amount and is logged as an expense; edit or delete it in the app. If an automation or manual shortcut passes **Type = Income**, or a negative amount, Budget logs a refund instead.
- **The iPhone must be unlocked.** Automations only run when the phone has been unlocked recently. iOS may also delay them by a few seconds, or longer under Low Power Mode.
- **There is no direct Wallet access.** Apps can't read Apple Pay history, so purchases made while the automation was off, or that failed to log, are not backfilled. Add them by hand.
- **Currency.** Amounts are logged in your Budget currency (CAD by default) unless the shortcut passes **Currency**. Foreign purchases show the Wallet amount, which is usually the amount in the card's currency.
