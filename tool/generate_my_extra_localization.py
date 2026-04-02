from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Iterable

from deep_translator import GoogleTranslator


ROOT = Path(__file__).resolve().parents[1]
SAMPLE_PATH = ROOT / "assets" / "data" / "sample_pagodas.json"
BASE_MY_PATH = ROOT / "assets" / "languages" / "my.json"
OUTPUT_PATH = ROOT / "assets" / "languages" / "my_extra.json"
CACHE_PATH = ROOT / "tool" / "my_translation_cache.json"

FIELD_MAPPINGS = [
    ("description", "description"),
    ("historicalInfo", "history"),
    ("architecturalStyle", "architecture"),
    ("legends", "legends"),
    ("religiousImportance", "religiousImportance"),
    ("preservationInfo", "preservation"),
    ("bestTimeToVisit", "bestTime"),
    ("visitorLocation", "visitorLocation"),
    ("openingHours", "openingHours"),
    ("dressCode", "dressCode"),
    ("entranceFee", "entranceFee"),
    ("photographyRules", "photographyRules"),
    ("finalWords", "finalWords"),
]

NAME_OVERRIDES = {
    "shwesandaw": "ရွှေဆံတော်စေတီ",
    "mingalazedi": "မင်္ဂလာစေတီ",
    "nagayon": "နဂါးရုံဘုရားကျောင်း",
    "nanpaya": "နန်းဘုရားကျောင်း",
    "mahabodhi": "မဟာဗောဓိဘုရားကျောင်း",
    "myazedi": "မြစေတီ",
    "payathonzu": "ဖယသုံဇူဘုရားကျောင်း",
    "tayokpye": "တရုတ်ပြေးဘုရားကျောင်း",
    "bulethi": "ဗူးလည်သီးစေတီ",
    "northguni": "မြောက်ဂူနီဘုရားကျောင်း",
    "southguni": "တောင်ဂူနီဘုရားကျောင်း",
    "thitsarwadi": "သစ္စာဝတီဘုရားကျောင်း",
    "wetkyiingubyaukgyi": "ဝက်ကြီးအင်း ဂူပြောက်ကြီးဘုရားကျောင်း",
    "abeyadana": "အဘေယဒနာဘုရားကျောင်း",
    "lemyethna": "လေးမျက်နှာဘုရားကျောင်း",
    "nandamannya": "နန္ဒမညာဘုရားကျောင်း",
    "somingyi": "စိုးမင်းကြီးဘုရား",
    "kyaukguumin": "ကျောက်ဂူဦးမင်",
    "pahtothamya": "ပထိုးသမ္မျာဘုရားကျောင်း",
    "tantkyitaung": "တန့်ကြည်တောင်စေတီ",
    "thabeikhmauk": "သပိတ်မှောက်ဘုရားကျောင်း",
    "gubyauknge": "ဂူပြောက်ငယ်ဘုရားကျောင်း",
    "kyaunggyi": "ကျောင်းကြီးဘုရား",
    "shweleiktoo": "ရွှေလိတ်ထူးဘုရားကျောင်း",
    "kyamingatemple": "ကျမင်းဂါဘုရားကျောင်း",
    "ashepetleik": "အရှေ့ပက်လက်စေတီ",
    "anaukpetleik": "အနောက်ပက်လက်စေတီ",
    "nathlaungkyaung": "နတ်လောင်းကျောင်း",
    "lokahteikpan": "လောကထိပ်ပန်ဘုရားကျောင်း",
    "tuywintaung": "တုယွင်တောင်စေတီ",
    "mineyeingon": "မီးငြိမ်းကုန်းစေတီ",
    "thakyamuni": "သကျမုနိဘုရား",
    "shinbinthalyaung": "ရှင်ပင်သာလျောင်းဘုရားကျောင်း",
    "letputkan": "လက်ပုတ်ကန်ဘုရားကျောင်း",
    "tawethpaya": "တဝက်ဘုရားကျောင်း",
    "lawkaousaung": "လောကဦးဆောင်",
    "kyansittharumin": "ကျန်စစ်သားဦးမင်",
    "ngakywenataung": "ငကျွဲနတောင်",
    "minochantha": "မင်းနိုချမ်းသာ",
    "hsutaungpyi": "ဆုတောင်းပြည့်စေတီ",
    "sapada": "စပဒစေတီ",
    "pebingyaung": "ပဲပင်ကျောင်းစေတီ",
    "winido": "ဝိနိဒိုဘုရားကျောင်း",
    "sinphyushin": "ဆင်ဖြူရှင်ဘုရားကျောင်း",
    "kondawgyi": "ကန်တော်ကြီးဘုရားကျောင်း",
    "kusinara": "ကုသိနာရုံဘုရားကျောင်း",
    "sittanagyi": "စစ်တနာကြီးစေတီ",
    "khamaunggyi": "ခမောက်ကြီးဘုရား",
    "thandawkya": "သံတော်ကြာဘုရား",
    "thamanhpaya": "သမန်ဘုရားကျောင်း",
    "hgnetpyittaung": "ငှက်ပျစ်တောင်ဘုရားကျောင်း",
}

COMMON_REPLACEMENTS = {
    "AM": "AM",
    "PM": "PM",
}

TEXT_OVERRIDES = {
    "6:00 AM - 6:00 PM": "မနက် ၆:၀၀ မှ ညနေ ၆:၀၀",
    "As with many smaller monuments, visitor pressure and climbing can threaten fragile masonry.": "အခြားသေးငယ်သော အထိမ်းအမှတ်များကဲ့သို့ပင် ဧည့်သည်ဖိအားနှင့် တက်ရောက်လှည့်လည်မှုများကြောင့် နုနယ်သော အုတ်စီလက်ရာများ ပျက်စီးနိုင်သည်။",
    "As with many smaller monuments, visitor pressure and climbing can threaten fragile masonry. Preservation depends on respecting monument-access restrictions.": "အခြားသေးငယ်သော အထိမ်းအမှတ်များကဲ့သို့ပင် ဧည့်သည်ဖိအားနှင့် တက်ရောက်လှည့်လည်မှုများကြောင့် နုနယ်သော အုတ်စီလက်ရာများ ပျက်စီးနိုင်သည်။ ထိန်းသိမ်းရေးသည် အထိမ်းအမှတ်ဝင်ရောက်ခွင့်ကန့်သတ်ချက်များကို လေးစားလိုက်နာခြင်းပေါ် မူတည်သည်။",
    "Bulbous Pyu-Type Form": "ဖောင်းလုံးသော ပျူပုံစံ",
    "Early Mature Style": "အစောပိုင်း ပြည့်ဝလာသော လက်ရာပုံစံ",
    "Queen's Foundation": "မိဖုရား၏ တည်ထောင်မှု",
    "Hybrid Iconography": "ရောစပ်သင်္ကေတပုံရိပ်များ",
    "Landscape Context": "ပတ်ဝန်းကျင်ရှုခင်းဆက်စပ်မှု",
    "Myinkaba Cluster Site": "မြင်းကပါအစုအဖွဲ့နယ်မြေ",
    "Ananda Hinterland Site": "အာနန္ဒာအနောက်ဖက်နယ်မြေ",
    "The monument's main continuity appears to be through local naming rather than through a widely circulated royal or pilgrimage legend.": "ဤအထိမ်းအမှတ်၏ အဓိကဆက်လက်မှတ်ဉာဏ်သည် လူသိများသော မင်းဆက်ဒဏ္ဍာရီ သို့မဟုတ် ဘုရားဖူးပုံပြင်များမှတစ်ဆင့် မဟုတ်ဘဲ ဒေသခံအမည်ခေါ်ဝေါ်ပုံမှတစ်ဆင့် ပိုမိုဆက်လက်ရှင်သန်နေသည်။",
    "Local Place-Memory": "ဒေသခံနေရာမှတ်ဉာဏ်",
    "Pan-Buddhist Symbolism": "ဗုဒ္ဓဘာသာအနှံ့ သင်္ကေတအဓိပ္ပါယ်",
    "Theravada Reform Context": "ထေရဝါဒ ပြုပြင်ပြောင်းလဲမှုဆက်စပ်မှု",
    "Myinkaba-Side Setting": "မြင်းကပါဘက် တည်နေရာ",
    "Cluster Context": "အစုအဖွဲ့ဆက်စပ်မှု",
    "Quiet Alternative": "တိတ်ဆိတ်သော ရွေးချယ်စရာ",
    "Wetkyi-In Identity": "ဝက်ကြီးအင်း၏ လက္ခဏာ",
}

SUBSTRING_REPLACEMENTS = {
    "Abeyadana": "အဘေယဒနာ",
    "Ashe": "အရှေ့",
    "Anauk": "အနောက်",
    "Balloon Temple": "မီးပုံးပျံဘုရားကျောင်း",
    "Balloon-Era": "မီးပုံးပျံခေတ်",
    "Balloon": "မီးပုံးပျံ",
    "Bulethi": "ဗူးလည်သီး",
    "Bupaya": "ဗူးဘုရား",
    "Cave-Type": "ဂူပုံစံ",
    "Epigraphic": "ကျောက်စာဆိုင်ရာ",
    "Flash": "ဖလက်ရှ်",
    "Formative-Period": "အစပြုခေတ်",
    "Glazed": "စဉ့်ကပ်",
    "Great": "ကြီးမြတ်သော",
    "Gubyaukgyi": "ဂူပြောက်ကြီး",
    "Gubyauk": "ဂူပြောက်",
    "Guni": "ဂူနီ",
    "Hgnet Pyit Taung": "ငှက်ပျစ်တောင်",
    "Hilltop": "တောင်ထိပ်",
    "Holy": "မြင့်မြတ်သော",
    "Hpaya": "ဘုရား",
    "Identity": "လက္ခဏာ",
    "IV": "စတုတ္ထ",
    "Kha-maung-gyi": "ခမောက်ကြီး",
    "Khay Min Gha": "ခေမင်းဂါ",
    "Khay-Min-Ga": "ခေမင်းဂါ",
    "Kondawgyi": "ကန်တော်ကြီး",
    "Kyanzitha": "ကျန်စစ်သား",
    "Kyanzittha": "ကျန်စစ်သား",
    "Kya Min Ga": "ကျမင်းဂါ",
    "Lemyethna": "လေးမျက်နှာ",
    "Let Put Kan": "လက်ပုတ်ကန်",
    "Loka-ok-shaung": "လောကဦးဆောင်",
    "Lokahteikpan": "လောကထိပ်ပန်",
    "Lokahtikpan": "လောကထိပ်ပန်",
    "Monument": "အထိမ်းအမှတ်",
    "Monuments": "အထိမ်းအမှတ်များ",
    "Mound": "ကုန်း",
    "Mucalinda": "မုစလိန္ဒာနဂါးမင်း",
    "Minnanthu": "မင်းနံသူ",
    "Myinkaba": "မြင်းကပါ",
    "Nagayon": "နဂါးရုံ",
    "Nandamannya": "နန္ဒမညာ",
    "Nanpaya": "နန်းဘုရား",
    "Nathlaung Kyaung": "နတ်လောင်းကျောင်း",
    "North Guni Temple": "မြောက်ဂူနီဘုရားကျောင်း",
    "North Guni": "မြောက်ဂူနီ",
    "North": "မြောက်",
    "Niche-Covered": "နံရံကွက်များဖြင့်ဖုံးလွှမ်းသော",
    "Open-Field": "လယ်ကွင်းဖွင့်နေရာ",
    "Payathonzu": "ဖယသုံဇူ",
    "Paya Ni": "အနီဘုရား",
    "Paya": "ဘုရား",
    "Pebingyaung": "ပဲပင်ကျောင်း",
    "Pahto Thamya": "ပထိုးသမ္မျာ",
    "Petleik Twin": "ပက်လက်အတွဲ",
    "Petleik": "ပက်လက်",
    "Pyu-Type": "ပျူပုံစံ",
    "Quiet": "တိတ်ဆိတ်သော",
    "Rajakumar": "ရာဇကုမာရ်",
    "Royal Voice": "တော်ဝင်အမည်",
    "Royal": "တော်ဝင်",
    "Secondary Monument": "ဒုတိယအထိမ်းအမှတ်",
    "Secondary": "ဒုတိယ",
    "Shinthalyung": "ရှင်ပင်သာလျောင်း",
    "Shrine": "ဘုရားဆောင်",
    "Sikhara": "ရှိခရာ",
    "Sin-phyu-shin": "ဆင်ဖြူရှင်",
    "Sinhalese": "သီဟိုဠ်",
    "South Guni Temple": "တောင်ဂူနီဘုရားကျောင်း",
    "South Guni": "တောင်ဂူနီ",
    "South": "တောင်",
    "Stucco": "စတုက္ကို",
    "Ta Wet Hpaya": "တဝက်ဘုရား",
    "Taung": "တောင်",
    "Tayok Pye": "တရုတ်ပြေး",
    "Tayok": "တရုတ်",
    "Temple": "ဘုရားကျောင်း",
    "Terrace": "လှေကားထစ်",
    "Thambula": "သမ္ဘူလ",
    "Thamana Konhtin": "သမနကုန်ထင်",
    "Tha-man-hpaya": "သမန်ဘုရား",
    "Thitsarwadi Temple": "သစ္စာဝတီဘုရားကျောင်း",
    "Thitsarwadi": "သစ္စာဝတီ",
    "Transitional": "ကူးပြောင်းကာလ",
    "Twin": "အတွဲ",
    "Ta Wet": "တဝက်",
    "Tuyin Taung Zedi": "တုယင်တောင်စေတီ",
    "Tuyin Taung": "တုယင်တောင်",
    "Tuyin": "တုယင်",
    "Tuywin Taung": "တုယွင်တောင်",
    "Tuywin": "တုယွင်",
    "Umin": "ဦးမင်",
    "Voice": "အသံ",
    "Wetkyi-In": "ဝက်ကြီးအင်း",
    "Wetkyi-in": "ဝက်ကြီးအင်း",
    "Winido": "ဝိနိဒို",
    "Sapada": "စပဒ",
    "Somingyi": "စိုးမင်းကြီး",
    "Manuha": "မနူဟာ",
    "Lawkananda": "လောကနန္ဒာ",
    "Nge": "ငယ်",
    "Bulbous": "ဖောင်းလုံးသော",
    "chinthe": "ခြင်္သေ့",
    "gu-hpaya": "ဂူဘုရား",
    "Mature": "ပြည့်ဝလာသော",
    "Zedi": "စေတီ",
    "Zedis": "စေတီများ",
    "core": "ဗဟိုအနှစ်သာရ",
    "circuit": "လည်ပတ်လမ်းကြောင်း",
    "flash": "ဖလက်ရှ်",
    "nge": "ငယ်",
    "niches": "နံရံကွက်များ",
    "site": "နေရာ",
}


def chunked(items: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(items), size):
        yield items[index : index + size]


def has_myanmar(text: str) -> bool:
    return any("\u1000" <= char <= "\u109f" for char in text)


def load_cache() -> dict[str, str]:
    if not CACHE_PATH.exists():
        return {}
    return json.loads(CACHE_PATH.read_text(encoding="utf-8"))


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.write_text(
        json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def pack_requests(texts: list[str], max_chars: int = 2500) -> Iterable[list[str]]:
    current: list[str] = []
    current_len = 0
    for text in texts:
        estimated = len(text) + 20
        if current and current_len + estimated > max_chars:
            yield current
            current = []
            current_len = 0
        current.append(text)
        current_len += estimated
    if current:
        yield current


def translate_group(translator: GoogleTranslator, texts: list[str]) -> dict[str, str]:
    markers = [f"__SEG{index}__" for index in range(len(texts))]
    payload = "\n".join(
        f"{marker}\n{text}" for marker, text in zip(markers, texts, strict=True)
    )
    translated_payload = translate_single(translator, payload)
    parts: dict[str, str] = {}
    for index, marker in enumerate(markers):
        start = translated_payload.find(marker)
        if start == -1:
            raise ValueError(f"Missing marker {marker}")
        start += len(marker)
        end = (
            translated_payload.find(markers[index + 1], start)
            if index + 1 < len(markers)
            else len(translated_payload)
        )
        parts[texts[index]] = translated_payload[start:end].strip()
    return parts


def translate_batch(
    translator: GoogleTranslator,
    texts: list[str],
    cache: dict[str, str],
) -> dict[str, str]:
    translated = dict(cache)
    missing_texts = [text for text in texts if text not in translated]
    for batch in pack_requests(missing_texts):
        if not batch:
            continue
        for attempt in range(3):
            try:
                translated.update(translate_group(translator, batch))
                save_cache(translated)
                break
            except Exception:
                if attempt == 2:
                    for text in batch:
                        translated[text] = translate_single(translator, text)
                    save_cache(translated)
                    break
                time.sleep(1.5 * (attempt + 1))
        time.sleep(0.5)
    return translated


def translate_single(translator: GoogleTranslator, text: str) -> str:
    for attempt in range(3):
        try:
            return translator.translate(text)
        except Exception:
            if attempt == 2:
                raise
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError("Unreachable")


def normalize_translation(text: str, name_map: dict[str, str]) -> str:
    normalized = text.replace("ဧည့်သည်များသည်", "ဧည့်သည်များ")
    for source, target in COMMON_REPLACEMENTS.items():
        normalized = normalized.replace(source, target)
    for source_name, translated_name in name_map.items():
        normalized = normalized.replace(source_name, translated_name)
    for source, target in SUBSTRING_REPLACEMENTS.items():
        normalized = normalized.replace(source, target)
    return normalized.strip()


def main() -> None:
    sample = json.loads(SAMPLE_PATH.read_text(encoding="utf-8"))
    base_my = json.loads(BASE_MY_PATH.read_text(encoding="utf-8"))
    target_items = [
        item for item in sample if f"pagoda.{item['id']}.name" not in base_my
    ]

    if not target_items:
        OUTPUT_PATH.write_text("{}\n", encoding="utf-8")
        return

    translator = GoogleTranslator(source="en", target="my")
    cache = load_cache()
    source_texts: dict[str, str] = {}

    name_sources = {
        item["name"]: NAME_OVERRIDES.get(item["id"], item["name"])
        for item in target_items
    }

    for item in target_items:
        for source_field, _ in FIELD_MAPPINGS:
            value = (item.get(source_field) or "").strip()
            if value:
                source_texts[value] = value
        for feature in item.get("uniqueFeatures", []):
            for field in ("title", "description"):
                value = (feature.get(field) or "").strip()
                if value:
                    source_texts[value] = value

    translations = translate_batch(translator, list(source_texts), cache)
    localized: dict[str, str] = {}

    for item in target_items:
        pagoda_id = item["id"]
        localized[f"pagoda.{pagoda_id}.name"] = NAME_OVERRIDES.get(
            pagoda_id,
            normalize_translation(
                translate_single(translator, item["name"]),
                name_sources,
            ),
        )

        for source_field, localized_field in FIELD_MAPPINGS:
            value = (item.get(source_field) or "").strip()
            if not value:
                continue
            translated = TEXT_OVERRIDES.get(
                value,
                normalize_translation(translations[value], name_sources),
            )
            if not has_myanmar(translated):
                translated = value
            localized[f"pagoda.{pagoda_id}.{localized_field}"] = translated

        for index, feature in enumerate(item.get("uniqueFeatures", [])):
            title = (feature.get("title") or "").strip()
            description = (feature.get("description") or "").strip()
            if title:
                localized[
                    f"pagoda.{pagoda_id}.uniqueFeatures.{index}.title"
                ] = TEXT_OVERRIDES.get(
                    title,
                    normalize_translation(translations[title], name_sources),
                )
            if description:
                localized[
                    f"pagoda.{pagoda_id}.uniqueFeatures.{index}.description"
                ] = TEXT_OVERRIDES.get(
                    description,
                    normalize_translation(translations[description], name_sources),
                )

    OUTPUT_PATH.write_text(
        json.dumps(localized, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
