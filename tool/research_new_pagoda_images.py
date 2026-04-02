import json
import mimetypes
import re
import time
from pathlib import Path
from typing import Any

import requests


ROOT = Path(__file__).resolve().parents[1]
SAMPLE_PATH = ROOT / "assets" / "data" / "sample_pagodas.json"
MANIFEST_PATH = ROOT / "assets" / "data" / "pagoda_image_sources.json"
TARGET_DIR = ROOT / "assets" / "images" / "pagodas" / "researched"

USER_AGENT = "BaganeticMobileApp/1.0 (image research sync)"


SOURCE_MAP: dict[str, dict[str, Any]] = {
    "shwesandaw": {
        "kind": "bagan_pagoda_page",
        "ref": "https://www.bagan-pagoda.com/17Shwesandaw.html",
        "confidence": "exact",
    },
    "mingalazedi": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Mingalazedi.jpg",
        "confidence": "exact",
    },
    "nagayon": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Nagayon.jpg",
        "confidence": "exact",
    },
    "nanpaya": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Nanpaya.jpg",
        "confidence": "exact",
    },
    "mahabodhi": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Mahabodhi.jpg",
        "confidence": "exact",
    },
    "myazedi": {
        "kind": "direct",
        "ref": "https://www.myanmars.net/images/bagan/myazedi.jpg",
        "confidence": "exact",
    },
    "payathonzu": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Payathonsu.jpg",
        "confidence": "exact",
    },
    "tayokpye": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/07/Tayokepyay.jpg",
        "confidence": "exact",
    },
    "bulethi": {
        "kind": "direct",
        "ref": "https://www.findawayphotography.com/wp-content/uploads/2018/01/bulethi-pagoda-in-bagan.jpg",
        "confidence": "exact",
    },
    "northguni": {
        "kind": "direct",
        "ref": "https://images.fineartamerica.com/images/artworkimages/mediumlarge/2/myanmar-bagan-north-guni-temple-suzy-bennett.jpg",
        "confidence": "likely",
    },
    "southguni": {
        "kind": "oriental_architecture_page",
        "ref": "https://www.orientalarchitecture.com/sid/1281/myanmar/bagan/south-guni-temple",
        "confidence": "exact",
    },
    "thitsarwadi": {
        "kind": "direct",
        "ref": "https://havecamerawilltravel.photography/wp-content/uploads/2016/10/bagan-exterior-of-thisa-wadi-temple-bagan-myanmar-burma-14-copyright-havecamerawilltravel-com.jpg",
        "confidence": "exact",
    },
    "wetkyiingubyaukgyi": {
        "kind": "oriental_architecture_page",
        "ref": "https://www.orientalarchitecture.com/sid/1223/myanmar/bagan/wetkyi-in-kubyauk-gyi",
        "confidence": "exact",
    },
    "abeyadana": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2020/07/abeyadana_01.jpg",
        "confidence": "exact",
    },
    "lemyethna": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Laymyethna.jpg",
        "confidence": "exact",
    },
    "nandamannya": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Nandamannya.jpg",
        "confidence": "exact",
    },
    "somingyi": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Somingyi_pagoda.jpg",
        "confidence": "exact",
    },
    "kyaukguumin": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Kyaukgu-umin.jpg",
        "confidence": "exact",
    },
    "pahtothamya": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Pahtothamya.jpg",
        "confidence": "exact",
    },
    "tantkyitaung": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Tantkyitaung.jpg",
        "confidence": "exact",
    },
    "thabeikhmauk": {
        "kind": "direct",
        "ref": "https://media.gody.vn/images/bagan/den-thabeik-hmauk-thabeik-hmauk/7c90f8de1045d5d15e0633444e88f1e73d0a07c7.jpg",
        "confidence": "exact",
    },
    "gubyauknge": {
        "kind": "direct",
        "ref": "https://www.gomyanmartours.com/wp-content/uploads/2015/09/Myinkaba-Gubyauk-Nge-Temple-Bagan.jpg",
        "confidence": "exact",
    },
    "kyaunggyi": {
        "kind": "direct",
        "ref": "https://media-cdn.tripadvisor.com/media/photo-s/13/2b/6d/4c/under-renovation-2017.jpg",
        "confidence": "likely",
    },
    "shweleiktoo": {
        "kind": "bagan_pagoda_page",
        "ref": "https://www.bagan-pagoda.com/12ShweLeikToo.html",
        "confidence": "exact",
    },
    "kyamingatemple": {
        "kind": "bagan_pagoda_page",
        "ref": "https://www.bagan-pagoda.com/14Khaymingha.html",
        "confidence": "exact",
    },
    "ashepetleik": {
        "kind": "direct",
        "ref": "https://www.myanmars.net/images/petleik_east_pagoda.jpg",
        "confidence": "exact",
    },
    "anaukpetleik": {
        "kind": "direct",
        "ref": "https://www.myanmars.net/images/petleik_west_pagoda.jpg",
        "confidence": "exact",
    },
    "nathlaungkyaung": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Nathlaung-kyaung.jpg",
        "confidence": "exact",
    },
    "lokahteikpan": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Lawkahteikpan_02.jpg",
        "confidence": "exact",
    },
    "tuywintaung": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/05/Tuyintaung.jpg",
        "confidence": "exact",
    },
    "mineyeingon": {
        "kind": "direct",
        "ref": "https://i2.pickpik.com/photos/765/840/62/bagan-myanmar-archaeological-area-panorama-preview.jpg",
        "confidence": "likely",
    },
    "thakyamuni": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Thetkyamuni.jpg",
        "confidence": "exact",
    },
    "shinbinthalyaung": {
        "kind": "bagan_pagoda_page",
        "ref": "https://www.bagan-pagoda.com/18Shinbinthalyaung.html",
        "confidence": "exact",
    },
    "letputkan": {
        "kind": "bagan_pagoda_page",
        "ref": "https://www.bagan-pagoda.com/27LetPutKan.html",
        "confidence": "exact",
    },
    "tawethpaya": {
        "kind": "direct",
        "ref": "https://images.ansharimages.com/photo/myanmar/bagan/dhammayan-gyi-temple-and-ta-wet-hpaya-bagan-myanmar.jpg",
        "confidence": "exact",
    },
    "lawkaousaung": {
        "kind": "direct",
        "ref": "https://viaggiatore.net/wp-content/uploads/2019/01/Law-Ka-Ou-Shaung-temple-with-a-traditionally-dressed-lady-with-umbrella-in-front-Bagan-Myanmar-.jpg",
        "confidence": "exact",
    },
    "kyansittharumin": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Kyansittha_Umin.jpg",
        "confidence": "exact",
    },
    "ngakywenataung": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Ngakywenadaung.jpg",
        "confidence": "exact",
    },
    "minochantha": {
        "kind": "oriental_architecture_page",
        "ref": "https://www.orientalarchitecture.com/sid/525/myanmar/bagan/minochantha-stupa-group",
        "confidence": "exact",
    },
    "hsutaungpyi": {
        "kind": "direct",
        "ref": "https://media.istockphoto.com/id/694106660/photo/hsu-taung-pyi-pagoda-bagan-myanmar.jpg?s=170667a&w=0&k=20&c=liYTPRTC-Cx9hb9SpwldlhXgzv1vrCWr-7eatPDeP0g=",
        "confidence": "exact",
    },
    "sapada": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Sapada.jpg",
        "confidence": "exact",
    },
    "pebingyaung": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Pebingyaung.jpg",
        "confidence": "exact",
    },
    "winido": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Winido.jpg",
        "confidence": "exact",
    },
    "sinphyushin": {
        "kind": "bagan_pagoda_page",
        "ref": "https://www.bagan-pagoda.com/30HsinPhyushin.html",
        "confidence": "exact",
    },
    "kondawgyi": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Kondawgyi.jpg",
        "confidence": "exact",
    },
    "kusinara": {
        "kind": "direct",
        "ref": "https://budsas.net/hh2004/04-kusinara/11-kusinara-a.jpg",
        "confidence": "exact",
    },
    "sittanagyi": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Sittanagyi.jpg",
        "confidence": "exact",
    },
    "khamaunggyi": {
        "kind": "direct",
        "ref": "https://www.losviajeros.net/fotos/asia/Myanmar/Bagan5.jpg",
        "confidence": "approximate",
    },
    "thandawkya": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Thandawgya.jpg",
        "confidence": "exact",
    },
    "thamanhpaya": {
        "kind": "oriental_architecture_page",
        "ref": "https://www.orientalarchitecture.com/sid/1228/myanmar/bagan/tha-man-hpaya-temple",
        "confidence": "exact",
    },
    "hgnetpyittaung": {
        "kind": "direct",
        "ref": "https://baganpaper.com/wp-content/uploads/2019/06/Hgnetpyit-taung.jpg",
        "confidence": "exact",
    },
}


def build_session() -> requests.Session:
    session = requests.Session()
    session.headers.update({"User-Agent": USER_AGENT})
    return session


def guess_extension(url: str, content_type: str | None) -> str:
    content_type = (content_type or "").split(";")[0].strip().lower()
    if content_type:
        guessed = mimetypes.guess_extension(content_type)
        if guessed:
            return ".jpg" if guessed == ".jpe" else guessed

    match = re.search(r"\.([a-zA-Z0-9]+)(?:$|[?#])", url)
    if match:
        ext = f".{match.group(1).lower()}"
        if ext in {".jpg", ".jpeg", ".png", ".webp"}:
            return ext
    return ".jpg"


def fetch_html(session: requests.Session, url: str) -> str:
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            response = session.get(url, timeout=(30, 120))
            response.raise_for_status()
            return response.text
        except requests.RequestException as error:
            last_error = error
            time.sleep(max(1, attempt + 1))

    raise RuntimeError(f"Failed to load page: {url}") from last_error


def resolve_commons_file(session: requests.Session, title: str) -> tuple[str, str]:
    response = session.get(
        "https://commons.wikimedia.org/w/api.php",
        params={
            "action": "query",
            "titles": title,
            "prop": "imageinfo",
            "iiprop": "url",
            "iiurlwidth": 1200,
            "format": "json",
        },
        timeout=30,
    )
    response.raise_for_status()
    pages = response.json().get("query", {}).get("pages", {})
    page = next(iter(pages.values()))
    if "missing" in page:
        raise RuntimeError(f"Commons file not found: {title}")

    imageinfo = page["imageinfo"][0]
    return imageinfo.get("thumburl") or imageinfo["url"], imageinfo["descriptionurl"]


def resolve_bagan_pagoda_page(
    session: requests.Session,
    page_url: str,
    image_index: int = 0,
) -> tuple[str, str]:
    response_text = fetch_html(session, page_url)
    images = re.findall(
        r'(?:https?://www\.bagan-pagoda\.com/)?(img/pagoda/[^"\']+\.(?:jpg|jpeg|png|webp))',
        response_text,
        flags=re.IGNORECASE,
    )
    unique_images = []
    for image in images:
        full_url = f"https://www.bagan-pagoda.com/{image.lstrip('/')}"
        if full_url not in unique_images:
            unique_images.append(full_url)

    if image_index >= len(unique_images):
        raise RuntimeError(f"No gallery image found for {page_url}")

    return unique_images[image_index], page_url


def resolve_oriental_architecture_page(
    session: requests.Session,
    page_url: str,
    image_index: int = 0,
) -> tuple[str, str]:
    response_text = fetch_html(session, page_url)
    images = re.findall(
        r'(https://www\.orientalarchitecture\.com/gallery/myanmar/bagan/[^"\']+\.(?:jpg|jpeg|png|webp)|/gallery/myanmar/bagan/[^"\']+\.(?:jpg|jpeg|png|webp))',
        response_text,
        flags=re.IGNORECASE,
    )
    unique_images = []
    for image in images:
        full_url = image
        if image.startswith("/"):
            full_url = f"https://www.orientalarchitecture.com{image}"
        if full_url not in unique_images:
            unique_images.append(full_url)

    if image_index >= len(unique_images):
        raise RuntimeError(f"No gallery image found for {page_url}")

    return unique_images[image_index], page_url


def resolve_source(session: requests.Session, source: dict[str, Any]) -> tuple[str, str]:
    kind = source["kind"]
    ref = source["ref"]
    image_index = source.get("image_index", 0)

    if kind == "commons":
        return resolve_commons_file(session, ref)
    if kind == "direct":
        return ref, ref
    if kind == "bagan_pagoda_page":
        return resolve_bagan_pagoda_page(session, ref, image_index=image_index)
    if kind == "oriental_architecture_page":
        return resolve_oriental_architecture_page(
            session,
            ref,
            image_index=image_index,
        )

    raise ValueError(f"Unsupported source kind: {kind}")


def download_image(session: requests.Session, url: str, destination_base: Path) -> Path:
    existing = list(destination_base.parent.glob(f"{destination_base.name}.*"))
    if existing:
        return existing[0]

    last_error: Exception | None = None
    for attempt in range(5):
        try:
            with session.get(url, timeout=(30, 180), stream=True) as response:
                if response.status_code == 429:
                    delay = max(2, 2**attempt)
                    time.sleep(delay)
                    last_error = requests.HTTPError(
                        f"429 while downloading {url}",
                        response=response,
                    )
                    continue

                response.raise_for_status()

                extension = guess_extension(url, response.headers.get("Content-Type"))
                destination = destination_base.with_suffix(extension)
                with destination.open("wb") as file_handle:
                    for chunk in response.iter_content(chunk_size=1024 * 1024):
                        if chunk:
                            file_handle.write(chunk)

                time.sleep(1)
                return destination
        except requests.RequestException as error:
            last_error = error
            partial_files = list(destination_base.parent.glob(f"{destination_base.name}.*"))
            for partial_file in partial_files:
                partial_file.unlink(missing_ok=True)
            time.sleep(max(1, attempt + 1))
            continue

    raise RuntimeError(f"Failed to download {url}") from last_error


def update_sample_json(asset_paths: dict[str, str]) -> list[dict[str, Any]]:
    data = json.loads(SAMPLE_PATH.read_text(encoding="utf-8"))

    new_pagoda_ids = [item["id"] for item in data[19:]]
    mapped_ids = sorted(SOURCE_MAP)
    if sorted(new_pagoda_ids) != mapped_ids:
        missing = sorted(set(new_pagoda_ids) - set(mapped_ids))
        extra = sorted(set(mapped_ids) - set(new_pagoda_ids))
        raise RuntimeError(
            f"Source map mismatch. missing={missing} extra={extra}",
        )

    for item in data:
        if item["id"] not in asset_paths:
            continue
        asset_path = asset_paths[item["id"]]
        item["imageUrl"] = asset_path
        item["images"] = [asset_path]

    SAMPLE_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return data


def main() -> None:
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    session = build_session()

    manifest: list[dict[str, Any]] = []
    asset_paths: dict[str, str] = {}

    sample_data = json.loads(SAMPLE_PATH.read_text(encoding="utf-8"))
    pagodas_by_id = {item["id"]: item for item in sample_data}

    for pagoda_id, source in SOURCE_MAP.items():
        pagoda = pagodas_by_id[pagoda_id]
        existing_files = list(TARGET_DIR.glob(f"{pagoda_id}.*"))
        if existing_files:
            destination = existing_files[0]
            resolved_url = source["ref"]
            source_page = source["ref"]
        else:
            resolved_url, source_page = resolve_source(session, source)
            destination = download_image(session, resolved_url, TARGET_DIR / pagoda_id)
        asset_path = destination.relative_to(ROOT).as_posix()
        asset_paths[pagoda_id] = asset_path

        manifest.append(
            {
                "id": pagoda_id,
                "name": pagoda["name"],
                "assetPath": asset_path,
                "sourceKind": source["kind"],
                "sourceRef": source["ref"],
                "sourcePage": source_page,
                "resolvedUrl": resolved_url,
                "confidence": source["confidence"],
            },
        )

        print(f"{pagoda_id}: {asset_path}")

    update_sample_json(asset_paths)
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Updated {len(asset_paths)} pagodas")
    print(f"Wrote manifest to {MANIFEST_PATH.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
