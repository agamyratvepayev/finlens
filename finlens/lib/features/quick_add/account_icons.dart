import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/utils/search_fold.dart';

/// One selectable account glyph and the words that find it. Keywords are stored
/// **per locale-neutral fold** (see [searchAccountIcons]); English and Turkish
/// terms sit side by side so a user typing `araba` and one typing `car` both
/// reach the car icon (spec §5.6).
class AccountIconEntry {
  const AccountIconEntry(this.icon, this.name, this.keywords);

  final IconData icon;
  final String name;
  final List<String> keywords;
}

/// ~100 glyphs in the app's shipped Material set, grouped for the full picker.
/// Every icon here is a `const IconData`, so the tree-shaker still prunes the
/// font.
const Map<String, List<AccountIconEntry>> accountIconGroups = {
  'Banking & cash': [
    AccountIconEntry(Icons.account_balance_rounded, 'Bank', ['bank', 'banka']),
    AccountIconEntry(Icons.account_balance_wallet_rounded, 'Wallet',
        ['wallet', 'cüzdan', 'cuzdan']),
    AccountIconEntry(Icons.payments_rounded, 'Cash', ['cash', 'nakit', 'para']),
    AccountIconEntry(Icons.attach_money_rounded, 'Money', ['money', 'para', 'dollar']),
    AccountIconEntry(Icons.savings_rounded, 'Piggy bank',
        ['savings', 'kumbara', 'birikim']),
    AccountIconEntry(Icons.account_balance_wallet_outlined, 'Purse',
        ['purse', 'wallet', 'cüzdan']),
    AccountIconEntry(Icons.money_rounded, 'Banknote', ['note', 'banknot', 'para']),
    AccountIconEntry(Icons.currency_exchange_rounded, 'Exchange',
        ['exchange', 'döviz', 'doviz', 'kur']),
    AccountIconEntry(Icons.atm_rounded, 'ATM', ['atm', 'bankamatik']),
  ],
  'Cards': [
    AccountIconEntry(Icons.credit_card_rounded, 'Credit card',
        ['card', 'kart', 'kredi']),
    AccountIconEntry(Icons.credit_score_rounded, 'Credit score',
        ['credit', 'kredi', 'skor']),
    AccountIconEntry(Icons.card_membership_rounded, 'Membership',
        ['membership', 'üyelik', 'uyelik']),
    AccountIconEntry(Icons.card_giftcard_rounded, 'Gift card',
        ['gift', 'hediye', 'kart']),
    AccountIconEntry(Icons.payment_rounded, 'Payment', ['payment', 'ödeme', 'odeme']),
    AccountIconEntry(Icons.local_atm_rounded, 'Cash card', ['card', 'kart', 'atm']),
    AccountIconEntry(Icons.contactless_rounded, 'Contactless',
        ['contactless', 'temassız', 'temassiz']),
  ],
  'Work & income': [
    AccountIconEntry(Icons.work_rounded, 'Work', ['work', 'iş', 'is', 'çalışma']),
    AccountIconEntry(Icons.business_center_rounded, 'Briefcase',
        ['briefcase', 'çanta', 'canta', 'iş']),
    AccountIconEntry(Icons.badge_rounded, 'Badge', ['badge', 'kimlik', 'personel']),
    AccountIconEntry(Icons.laptop_rounded, 'Freelance',
        ['freelance', 'laptop', 'bilgisayar']),
    AccountIconEntry(Icons.handshake_rounded, 'Deal', ['deal', 'anlaşma', 'anlasma', 'el sıkışma']),
    AccountIconEntry(Icons.request_quote_rounded, 'Invoice',
        ['invoice', 'fatura', 'teklif']),
    AccountIconEntry(Icons.receipt_long_rounded, 'Receipt', ['receipt', 'fiş', 'fis', 'makbuz']),
    AccountIconEntry(Icons.trending_up_rounded, 'Raise', ['raise', 'artış', 'artis', 'gelir']),
    AccountIconEntry(Icons.people_rounded, 'People', ['people', 'insanlar', 'aile']),
    AccountIconEntry(Icons.person_rounded, 'Person', ['person', 'kişi', 'kisi']),
  ],
  'Home & bills': [
    AccountIconEntry(Icons.home_rounded, 'Home', ['home', 'house', 'ev']),
    AccountIconEntry(Icons.home_work_rounded, 'Rent', ['rent', 'kira', 'ev']),
    AccountIconEntry(Icons.apartment_rounded, 'Apartment',
        ['apartment', 'daire', 'apartman']),
    AccountIconEntry(Icons.bolt_rounded, 'Electricity',
        ['electricity', 'elektrik', 'fatura']),
    AccountIconEntry(Icons.water_drop_rounded, 'Water', ['water', 'su', 'fatura']),
    AccountIconEntry(Icons.local_fire_department_rounded, 'Gas',
        ['gas', 'gaz', 'doğalgaz', 'dogalgaz']),
    AccountIconEntry(Icons.wifi_rounded, 'Internet', ['internet', 'wifi', 'net']),
    AccountIconEntry(Icons.phone_iphone_rounded, 'Phone', ['phone', 'telefon']),
    AccountIconEntry(Icons.cleaning_services_rounded, 'Cleaning',
        ['cleaning', 'temizlik']),
    AccountIconEntry(Icons.chair_rounded, 'Furniture', ['furniture', 'mobilya', 'koltuk']),
  ],
  'Transport': [
    AccountIconEntry(Icons.directions_car_rounded, 'Car', ['car', 'araba', 'oto']),
    AccountIconEntry(Icons.directions_car_filled_rounded, 'Auto loan',
        ['car', 'araba', 'taşıt', 'tasit']),
    AccountIconEntry(Icons.local_gas_station_rounded, 'Fuel',
        ['fuel', 'benzin', 'yakıt', 'yakit']),
    AccountIconEntry(Icons.directions_bus_rounded, 'Bus', ['bus', 'otobüs', 'otobus']),
    AccountIconEntry(Icons.train_rounded, 'Train', ['train', 'tren']),
    AccountIconEntry(Icons.local_taxi_rounded, 'Taxi', ['taxi', 'taksi']),
    AccountIconEntry(Icons.two_wheeler_rounded, 'Motorbike',
        ['motorbike', 'motosiklet', 'motor']),
    AccountIconEntry(Icons.pedal_bike_rounded, 'Bike', ['bike', 'bisiklet']),
    AccountIconEntry(Icons.flight_rounded, 'Flight', ['flight', 'uçak', 'ucak', 'uçuş']),
  ],
  'Food & shopping': [
    AccountIconEntry(Icons.shopping_cart_rounded, 'Groceries',
        ['groceries', 'market', 'alışveriş', 'alisveris']),
    AccountIconEntry(Icons.shopping_bag_rounded, 'Shopping',
        ['shopping', 'alışveriş', 'alisveris', 'çanta']),
    AccountIconEntry(Icons.shopping_basket_rounded, 'Basket',
        ['basket', 'sepet', 'market']),
    AccountIconEntry(Icons.local_mall_rounded, 'Mall', ['mall', 'avm', 'mağaza']),
    AccountIconEntry(Icons.restaurant_rounded, 'Restaurant',
        ['restaurant', 'restoran', 'yemek']),
    AccountIconEntry(Icons.local_cafe_rounded, 'Cafe', ['cafe', 'kafe', 'kahve']),
    AccountIconEntry(Icons.fastfood_rounded, 'Fast food',
        ['food', 'yemek', 'fast food']),
    AccountIconEntry(Icons.local_grocery_store_rounded, 'Store',
        ['store', 'market', 'bakkal']),
    AccountIconEntry(Icons.liquor_rounded, 'Drinks', ['drinks', 'içki', 'icki']),
  ],
  'Health': [
    AccountIconEntry(Icons.favorite_rounded, 'Health', ['health', 'sağlık', 'saglik']),
    AccountIconEntry(Icons.local_hospital_rounded, 'Hospital',
        ['hospital', 'hastane', 'sağlık']),
    AccountIconEntry(Icons.medical_services_rounded, 'Doctor',
        ['doctor', 'doktor', 'sağlık']),
    AccountIconEntry(Icons.medication_rounded, 'Pharmacy',
        ['pharmacy', 'eczane', 'ilaç', 'ilac']),
    AccountIconEntry(Icons.fitness_center_rounded, 'Gym', ['gym', 'spor', 'fitness']),
    AccountIconEntry(Icons.spa_rounded, 'Wellness', ['spa', 'bakım', 'bakim', 'wellness']),
    AccountIconEntry(Icons.self_improvement_rounded, 'Personal',
        ['personal', 'kişisel', 'kisisel', 'yoga']),
  ],
  'Education': [
    AccountIconEntry(Icons.school_rounded, 'School', ['school', 'okul', 'eğitim', 'egitim']),
    AccountIconEntry(Icons.menu_book_rounded, 'Books', ['books', 'kitap', 'ders']),
    AccountIconEntry(Icons.science_rounded, 'Science', ['science', 'bilim', 'laboratuvar']),
    AccountIconEntry(Icons.laptop_chromebook_rounded, 'Course',
        ['course', 'kurs', 'ders']),
    AccountIconEntry(Icons.edit_rounded, 'Study', ['study', 'çalışma', 'calisma', 'ödev']),
    AccountIconEntry(Icons.workspace_premium_rounded, 'Diploma',
        ['diploma', 'sertifika', 'başarı']),
  ],
  'Travel & leisure': [
    AccountIconEntry(Icons.beach_access_rounded, 'Vacation',
        ['vacation', 'tatil', 'plaj']),
    AccountIconEntry(Icons.luggage_rounded, 'Luggage', ['luggage', 'bavul', 'valiz']),
    AccountIconEntry(Icons.hotel_rounded, 'Hotel', ['hotel', 'otel', 'konaklama']),
    AccountIconEntry(Icons.map_rounded, 'Trip', ['trip', 'gezi', 'seyahat', 'harita']),
    AccountIconEntry(Icons.sports_esports_rounded, 'Games', ['games', 'oyun']),
    AccountIconEntry(Icons.movie_rounded, 'Cinema', ['cinema', 'sinema', 'film']),
    AccountIconEntry(Icons.music_note_rounded, 'Music', ['music', 'müzik', 'muzik']),
    AccountIconEntry(Icons.celebration_rounded, 'Party', ['party', 'parti', 'kutlama']),
  ],
  'Investments & savings': [
    AccountIconEntry(Icons.trending_up_rounded, 'Growth', ['growth', 'yatırım', 'yatirim', 'artış']),
    AccountIconEntry(Icons.show_chart_rounded, 'Stocks', ['stocks', 'hisse', 'borsa']),
    AccountIconEntry(Icons.candlestick_chart_rounded, 'Trading',
        ['trading', 'borsa', 'işlem', 'islem']),
    AccountIconEntry(Icons.pie_chart_rounded, 'Portfolio',
        ['portfolio', 'portföy', 'portfoy', 'dağılım']),
    AccountIconEntry(Icons.currency_bitcoin_rounded, 'Crypto',
        ['crypto', 'bitcoin', 'kripto']),
    AccountIconEntry(Icons.workspace_premium_rounded, 'Gold',
        ['gold', 'altın', 'altin', 'değerli']),
    AccountIconEntry(Icons.savings_rounded, 'Pension',
        ['pension', 'emeklilik', 'bes', 'birikim']),
    AccountIconEntry(Icons.stacked_line_chart_rounded, 'Fund',
        ['fund', 'fon', 'yatırım']),
  ],
  'Property & valuables': [
    AccountIconEntry(Icons.villa_rounded, 'Property', ['property', 'emlak', 'ev', 'villa']),
    AccountIconEntry(Icons.diamond_rounded, 'Jewellery',
        ['jewellery', 'mücevher', 'mucevher', 'elmas']),
    AccountIconEntry(Icons.watch_rounded, 'Watch', ['watch', 'saat', 'kol saati']),
    AccountIconEntry(Icons.laptop_mac_rounded, 'Electronics',
        ['electronics', 'elektronik', 'bilgisayar']),
    AccountIconEntry(Icons.chair_alt_rounded, 'Assets', ['assets', 'eşya', 'esya', 'varlık']),
    AccountIconEntry(Icons.landscape_rounded, 'Land', ['land', 'arsa', 'arazi']),
    AccountIconEntry(Icons.directions_boat_rounded, 'Boat', ['boat', 'tekne', 'yat']),
    AccountIconEntry(Icons.camera_alt_rounded, 'Camera', ['camera', 'kamera', 'fotoğraf']),
  ],
  'Other': [
    AccountIconEntry(Icons.category_rounded, 'General', ['general', 'genel', 'diğer', 'diger']),
    AccountIconEntry(Icons.star_rounded, 'Star', ['star', 'yıldız', 'yildiz', 'favori']),
    AccountIconEntry(Icons.pets_rounded, 'Pets', ['pets', 'evcil', 'hayvan']),
    AccountIconEntry(Icons.child_care_rounded, 'Kids', ['kids', 'çocuk', 'cocuk']),
    AccountIconEntry(Icons.volunteer_activism_rounded, 'Charity',
        ['charity', 'bağış', 'bagis', 'yardım']),
    AccountIconEntry(Icons.redeem_rounded, 'Gift', ['gift', 'hediye']),
    AccountIconEntry(Icons.flag_rounded, 'Goal', ['goal', 'hedef', 'amaç']),
    AccountIconEntry(Icons.lightbulb_rounded, 'Idea', ['idea', 'fikir', 'proje']),
  ],
};

/// Six suggestion glyphs for the inline row, keyed to the group (spec §5.5).
List<IconData> iconSuggestionsFor(AccountGroup group) {
  switch (group) {
    case AccountGroup.spendable:
      return const [
        Icons.account_balance_rounded,
        Icons.payments_rounded,
        Icons.account_balance_wallet_rounded,
        Icons.people_rounded,
        Icons.savings_rounded,
        Icons.attach_money_rounded,
      ];
    case AccountGroup.setAside:
      // Saving-toward-a-goal cash — never a lock/padlock; the money is not
      // restricted, only mentally reserved.
      return const [
        Icons.savings_rounded,
        Icons.flag_rounded,
        Icons.redeem_rounded,
        Icons.volunteer_activism_rounded,
        Icons.account_balance_wallet_rounded,
        Icons.attach_money_rounded,
      ];
    case AccountGroup.receivables:
      return const [
        Icons.handshake_rounded,
        Icons.receipt_long_rounded,
        Icons.request_quote_rounded,
        Icons.person_rounded,
        Icons.schedule_rounded,
        Icons.assignment_return_rounded,
      ];
    case AccountGroup.investments:
      return const [
        Icons.trending_up_rounded,
        Icons.show_chart_rounded,
        Icons.currency_bitcoin_rounded,
        Icons.workspace_premium_rounded,
        Icons.pie_chart_rounded,
        Icons.savings_rounded,
      ];
    case AccountGroup.valuables:
      return const [
        Icons.diamond_rounded,
        Icons.home_rounded,
        Icons.directions_car_rounded,
        Icons.watch_rounded,
        Icons.laptop_mac_rounded,
        Icons.landscape_rounded,
      ];
    case AccountGroup.creditCards:
      return const [
        Icons.credit_card_rounded,
        Icons.local_mall_rounded,
        Icons.shopping_bag_rounded,
        Icons.card_membership_rounded,
        Icons.payment_rounded,
        Icons.card_giftcard_rounded,
      ];
    case AccountGroup.payables:
      return const [
        Icons.description_rounded,
        Icons.home_work_rounded,
        Icons.bolt_rounded,
        Icons.wifi_rounded,
        Icons.water_drop_rounded,
        Icons.receipt_long_rounded,
      ];
    case AccountGroup.bankLoans:
      return const [
        Icons.account_balance_rounded,
        Icons.apartment_rounded,
        Icons.directions_car_filled_rounded,
        Icons.school_rounded,
        Icons.business_center_rounded,
        Icons.home_rounded,
      ];
  }
}

/// The default glyph chosen the instant a group is picked (spec §5.5).
IconData defaultIconFor(AccountGroup group) => iconSuggestionsFor(group).first;

/// Filters the catalog by a folded, locale-insensitive match on the icon name
/// and its keywords, so `araba` and `car` both surface the car (spec §5.6).
List<AccountIconEntry> searchAccountIcons(String query) {
  final q = foldSearch(query.trim());
  final out = <AccountIconEntry>[];
  for (final entries in accountIconGroups.values) {
    for (final e in entries) {
      final hay = foldSearch([e.name, ...e.keywords].join(' '));
      if (q.isEmpty || hay.contains(q)) out.add(e);
    }
  }
  return out;
}
