import '../../core/utils/search_fold.dart';

/// One selectable emoji and the words that find it. Like the icon catalog, group
/// headings and display are language-neutral (an emoji renders the same in every
/// locale) and keywords carry en + tr + ru + tk terms side by side so a search
/// in any of the four languages reaches the glyph (spec §7b). Emoji are stored
/// as plain strings on the account — no font, no codepoint bookkeeping.
class EmojiEntry {
  const EmojiEntry(this.emoji, this.keywords);
  final String emoji;
  final List<String> keywords;
}

/// ~70 emoji grouped for the picker. Headings stay English, matching the icon
/// catalog's established convention (the deferred icon-picker-l10n decision).
const Map<String, List<EmojiEntry>> emojiGroups = {
  'Money': [
    EmojiEntry('💰', ['money', 'bag', 'para', 'kese', 'деньги', 'pul']),
    EmojiEntry('💵', ['cash', 'dollar', 'nakit', 'наличные', 'nagt']),
    EmojiEntry('💳', ['card', 'kart', 'карта', 'kart']),
    EmojiEntry('🏦', ['bank', 'banka', 'банк', 'bank']),
    EmojiEntry('🪙', ['coin', 'para', 'madeni', 'монета', 'teňňe']),
    EmojiEntry('💎', ['gem', 'diamond', 'elmas', 'mücevher', 'бриллиант', 'göwher']),
    EmojiEntry('📈', ['chart', 'growth', 'yatırım', 'artış', 'рост', 'ösüş']),
    EmojiEntry('📉', ['loss', 'düşüş', 'падение', 'peseliş']),
    EmojiEntry('🧾', ['receipt', 'fatura', 'fiş', 'счёт', 'hasap']),
    EmojiEntry('🏧', ['atm', 'bankamatik', 'банкомат']),
    EmojiEntry('💸', ['spend', 'harcama', 'расход', 'çykdajy']),
    EmojiEntry('🐷', ['piggy', 'savings', 'kumbara', 'birikim', 'копилка', 'gazna']),
  ],
  'Home & things': [
    EmojiEntry('🏠', ['home', 'house', 'ev', 'дом', 'öý']),
    EmojiEntry('🏡', ['house', 'garden', 'ev', 'дом', 'öý']),
    EmojiEntry('🏢', ['office', 'apartment', 'ofis', 'daire', 'офис', 'edara']),
    EmojiEntry('🔑', ['key', 'rent', 'anahtar', 'kira', 'ключ', 'açar']),
    EmojiEntry('💡', ['electricity', 'idea', 'elektrik', 'fikir', 'свет', 'elektrik']),
    EmojiEntry('💧', ['water', 'su', 'вода', 'suw']),
    EmojiEntry('🔥', ['gas', 'fire', 'gaz', 'ateş', 'газ', 'gaz']),
    EmojiEntry('📶', ['internet', 'wifi', 'net', 'интернет', 'internet']),
    EmojiEntry('📱', ['phone', 'telefon', 'телефон', 'telefon']),
    EmojiEntry('🛋️', ['furniture', 'mobilya', 'мебель', 'mebel']),
    EmojiEntry('🧹', ['cleaning', 'temizlik', 'уборка', 'arassaçylyk']),
    EmojiEntry('🎁', ['gift', 'hediye', 'подарок', 'sowgat']),
  ],
  'Transport': [
    EmojiEntry('🚗', ['car', 'araba', 'машина', 'awtoulag']),
    EmojiEntry('🚕', ['taxi', 'taksi', 'такси', 'taksi']),
    EmojiEntry('⛽', ['fuel', 'benzin', 'yakıt', 'бензин', 'ýangyç']),
    EmojiEntry('🚌', ['bus', 'otobüs', 'автобус', 'awtobus']),
    EmojiEntry('🚆', ['train', 'tren', 'поезд', 'otly']),
    EmojiEntry('✈️', ['flight', 'plane', 'uçak', 'самолёт', 'uçar']),
    EmojiEntry('🏍️', ['motorbike', 'motosiklet', 'мотоцикл', 'motosikl']),
    EmojiEntry('🚲', ['bike', 'bisiklet', 'велосипед', 'welosiped']),
    EmojiEntry('🚢', ['boat', 'ship', 'gemi', 'tekne', 'корабль', 'gämi']),
  ],
  'Food & shopping': [
    EmojiEntry('🛒', ['groceries', 'market', 'alışveriş', 'продукты', 'bazar']),
    EmojiEntry('🛍️', ['shopping', 'alışveriş', 'покупки', 'söwda']),
    EmojiEntry('🍽️', ['restaurant', 'food', 'restoran', 'yemek', 'еда', 'nahar']),
    EmojiEntry('☕', ['coffee', 'cafe', 'kahve', 'kafe', 'кофе', 'kofe']),
    EmojiEntry('🍔', ['fastfood', 'burger', 'yemek', 'еда', 'çalt nahar']),
    EmojiEntry('🍺', ['drinks', 'beer', 'içki', 'напитки', 'içgi']),
    EmojiEntry('🥕', ['vegetables', 'sebze', 'овощи', 'gök önüm']),
    EmojiEntry('🎂', ['cake', 'party', 'pasta', 'kutlama', 'торт', 'tort']),
  ],
  'Health & study': [
    EmojiEntry('❤️', ['health', 'heart', 'sağlık', 'здоровье', 'saglyk']),
    EmojiEntry('🏥', ['hospital', 'hastane', 'больница', 'keselhana']),
    EmojiEntry('💊', ['pharmacy', 'medicine', 'ilaç', 'eczane', 'лекарство', 'derman']),
    EmojiEntry('🏋️', ['gym', 'spor', 'фитнес', 'sport']),
    EmojiEntry('🎓', ['school', 'education', 'okul', 'eğitim', 'учёба', 'okuw']),
    EmojiEntry('📚', ['books', 'kitap', 'книги', 'kitap']),
    EmojiEntry('✏️', ['study', 'çalışma', 'учёба', 'okuw']),
    EmojiEntry('🔬', ['science', 'bilim', 'наука', 'ylym']),
  ],
  'Work & goals': [
    EmojiEntry('💼', ['work', 'briefcase', 'iş', 'çanta', 'работа', 'iş']),
    EmojiEntry('🧑‍💻', ['freelance', 'laptop', 'bilgisayar', 'фриланс', 'kompýuter']),
    EmojiEntry('🤝', ['deal', 'anlaşma', 'сделка', 'ylalaşyk']),
    EmojiEntry('🎯', ['goal', 'target', 'hedef', 'amaç', 'цель', 'maksat']),
    EmojiEntry('🏆', ['award', 'trophy', 'ödül', 'başarı', 'приз', 'baýrak']),
    EmojiEntry('⭐', ['star', 'favourite', 'yıldız', 'звезда', 'ýyldyz']),
    EmojiEntry('🚀', ['growth', 'rocket', 'roket', 'ракета', 'raketa']),
    EmojiEntry('💡', ['idea', 'project', 'fikir', 'проект', 'pikir']),
  ],
  'People & fun': [
    EmojiEntry('😀', ['smile', 'happy', 'gülümseme', 'улыбка', 'ýylgyryş']),
    EmojiEntry('👨‍👩‍👧', ['family', 'aile', 'семья', 'maşgala']),
    EmojiEntry('🐶', ['pet', 'dog', 'köpek', 'evcil', 'собака', 'it']),
    EmojiEntry('🐱', ['cat', 'kedi', 'кот', 'pişik']),
    EmojiEntry('🌱', ['plant', 'nature', 'bitki', 'растение', 'ösümlik']),
    EmojiEntry('🎮', ['games', 'oyun', 'игры', 'oýun']),
    EmojiEntry('🎬', ['cinema', 'movie', 'sinema', 'film', 'кино', 'kino']),
    EmojiEntry('🎵', ['music', 'müzik', 'музыка', 'saz']),
    EmojiEntry('🏖️', ['vacation', 'beach', 'tatil', 'plaj', 'отпуск', 'dynç alyş']),
    EmojiEntry('🐾', ['animal', 'hayvan', 'животное', 'haýwan']),
    EmojiEntry('🌍', ['world', 'travel', 'dünya', 'seyahat', 'мир', 'dünýä']),
    EmojiEntry('❤️‍🔥', ['love', 'aşk', 'любовь', 'söýgi']),
  ],
};

/// Filters the emoji catalog by a folded, locale-insensitive match on the
/// keywords (spec §7b).
List<EmojiEntry> searchEmoji(String query) {
  final q = foldSearch(query.trim());
  final out = <EmojiEntry>[];
  for (final entries in emojiGroups.values) {
    for (final e in entries) {
      final hay = foldSearch(e.keywords.join(' '));
      if (q.isEmpty || hay.contains(q)) out.add(e);
    }
  }
  return out;
}
