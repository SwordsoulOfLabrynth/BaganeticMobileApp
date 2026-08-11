import fs from 'node:fs/promises';
import { Presentation, PresentationFile } from '@oai/artifact-tool';

const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });
const OUT = 'D:/Project/Project/baganetic_mobile_stitch_redesign_fixed/deliverables/Baganetic_10_Minute_Pitch.pptx';
const ASSET = 'D:/Project/Project/baganetic_mobile_stitch_redesign_fixed/assets/images/stitch';
const TEMP = 'C:/Users/KYAWZA~1/AppData/Local/Temp';

const C = {
  paper: '#F7F2E9',
  ink: '#2B1D14',
  brown: '#3A2215',
  terracotta: '#B65331',
  gold: '#C99E42',
  muted: '#806F65',
  line: '#DBCDBD',
  white: '#FFFFFF',
};

const img = async (path) => {
  const bytes = await fs.readFile(path);
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
};

const writeBlob = async (path, blob) => {
  await fs.writeFile(path, new Uint8Array(await blob.arrayBuffer()));
};

const addText = (slide, text, position, style = {}) => {
  const shape = slide.shapes.add({
    geometry: 'textbox',
    position,
    fill: 'none',
    line: { style: 'solid', fill: 'none', width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    typeface: style.typeface ?? 'Aptos',
    fontSize: style.fontSize ?? 24,
    color: style.color ?? C.ink,
    bold: style.bold ?? false,
    italic: style.italic ?? false,
    alignment: style.alignment ?? 'left',
    verticalAlignment: style.verticalAlignment ?? 'top',
    ...style,
  };
  return shape;
};

const addRect = (slide, position, fill, radius = 0, line = 'none') =>
  slide.shapes.add({
    geometry: radius ? 'roundRect' : 'rect',
    position,
    fill,
    line: { style: 'solid', fill: line, width: line === 'none' ? 0 : 1 },
    ...(radius ? { borderRadius: radius } : {}),
  });

const addRule = (slide, left, top, width, fill = C.line) =>
  slide.shapes.add({
    geometry: 'line',
    position: { left, top, width, height: 0 },
    fill: 'none',
    line: { style: 'solid', fill, width: 1.4 },
  });

const addImage = async (slide, path, position, alt, fit = 'cover', radius = 'rounded-xl', crop) =>
  slide.images.add({
    blob: await img(path),
    contentType: path.endsWith('.png') ? 'image/png' : 'image/jpeg',
    alt,
    fit,
    position,
    geometry: 'roundRect',
    borderRadius: radius,
    ...(crop ? { crop } : {}),
  });

const addEyebrow = (slide, text, page = 1) => {
  addText(slide, text.toUpperCase(), { left: 72, top: 44, width: 700, height: 26 }, {
    fontSize: 13, bold: true, color: C.terracotta, typeface: 'Aptos',
    characterSpacing: 1.8,
  });
  addText(slide, String(page).padStart(2, '0'), { left: 1155, top: 45, width: 54, height: 24 }, {
    fontSize: 13, bold: true, color: C.muted, alignment: 'right', characterSpacing: 1.4,
  });
};

const addFooter = (slide) => {
  addRule(slide, 72, 666, 1136, C.line);
  addText(slide, 'BAGANETIC  •  EXPLORE WITH CONTEXT', { left: 72, top: 680, width: 400, height: 20 }, {
    fontSize: 10, bold: true, color: C.muted, characterSpacing: 1.2,
  });
};

const addNotes = (slide, body, sources) => {
  slide.speakerNotes.textFrame.setText(`${body}\n\n[Sources]\n${sources}\n[/Sources]`);
  slide.speakerNotes.setVisible(true);
};

// 1. Opening
{
  const s = deck.slides.add();
  s.background.fill = C.brown;
  await addImage(s, `${ASSET}/bagan_sunrise.jpg`, { left: 0, top: 0, width: 1280, height: 720 }, 'Mist-covered Bagan pagodas at sunrise', 'cover', 0);
  addRect(s, { left: 0, top: 0, width: 1280, height: 720 }, '#24140DB8');
  addText(s, 'BAGANETIC', { left: 76, top: 74, width: 500, height: 42 }, {
    fontSize: 18, color: C.gold, bold: true, characterSpacing: 4,
  });
  addText(s, 'A more meaningful\nway to explore Bagan', { left: 76, top: 205, width: 740, height: 210 }, {
    fontSize: 64, typeface: 'Georgia', color: C.white, bold: true,
  });
  addText(s, 'Heritage discovery, trip planning, and local travel context in one mobile journal.', { left: 80, top: 455, width: 620, height: 70 }, {
    fontSize: 24, color: '#F7EBDD',
  });
  addRule(s, 80, 570, 230, C.gold);
  addText(s, 'WORKING ANDROID PROTOTYPE  •  10-MINUTE PITCH', { left: 80, top: 590, width: 620, height: 28 }, {
    fontSize: 13, color: C.white, bold: true, characterSpacing: 1.8,
  });
  addNotes(s, '0:00–0:30. Open with the central promise: Baganetic makes a visit to Bagan easier to plan and richer to experience. The slides show the working Android result, not only a concept.', '- Project asset: assets/images/stitch/bagan_sunrise.jpg (Baganetic workspace).');
}

// 2. The value proposition
{
  const s = deck.slides.add();
  s.background.fill = C.paper;
  addEyebrow(s, 'The opportunity', 2);
  addText(s, 'Bagan is not just a place\nto pin on a map.', { left: 72, top: 108, width: 580, height: 150 }, {
    fontSize: 48, typeface: 'Georgia', bold: true,
  });
  addText(s, 'Visitors need routes, but they also need stories, context, and confidence in the next stop.', { left: 72, top: 290, width: 520, height: 110 }, {
    fontSize: 25, color: C.muted,
  });
  addRule(s, 72, 442, 494, C.terracotta);
  const points = [
    ['Discover', 'Find sacred sites with a visual, searchable catalogue.'],
    ['Plan', 'Turn saved places into a practical journey.'],
    ['Experience', 'Keep local context and traveller knowledge together.'],
  ];
  points.forEach(([title, text], i) => {
    const top = 480 + i * 60;
    addText(s, `0${i + 1}`, { left: 74, top, width: 48, height: 30 }, { fontSize: 15, color: C.gold, bold: true });
    addText(s, title, { left: 132, top: top - 2, width: 130, height: 30 }, { fontSize: 20, bold: true });
    addText(s, text, { left: 270, top, width: 430, height: 30 }, { fontSize: 17, color: C.muted });
  });
  await addImage(s, `${ASSET}/shwesandaw_postcard.jpg`, { left: 780, top: 110, width: 330, height: 455 }, 'Shwesandaw Pagoda image in postcard style', 'cover', 'rounded-2xl');
  addText(s, 'A travel companion\nrooted in place', { left: 758, top: 584, width: 390, height: 64 }, {
    fontSize: 24, typeface: 'Georgia', bold: true, alignment: 'center',
  });
  addFooter(s);
  addNotes(s, '0:30–1:30. Make the problem personal: planning a Bagan day usually splits between maps, searches, notes, and social advice. Baganetic brings these actions into one coherent journey.', '- Project asset: assets/images/stitch/shwesandaw_postcard.jpg (Baganetic workspace).');
}

// 3. Discovery experience
{
  const s = deck.slides.add();
  s.background.fill = C.paper;
  addEyebrow(s, 'Working result • discovery', 3);
  addText(s, 'Start with atmosphere.\nContinue with detail.', { left: 72, top: 102, width: 570, height: 128 }, {
    fontSize: 46, typeface: 'Georgia', bold: true,
  });
  addText(s, 'The home screen presents Bagan as a visual journal; the pagoda catalogue makes the next site easy to find and save.', { left: 72, top: 252, width: 540, height: 85 }, {
    fontSize: 23, color: C.muted,
  });
  await addImage(s, `${TEMP}/baganetic-phone-20260812.png`, { left: 690, top: 78, width: 218, height: 510 }, 'Baganetic Home screen on Android', 'contain', 'rounded-2xl');
  await addImage(s, `${TEMP}/baganetic-phone-pagodas-header-align-20260812.png`, { left: 950, top: 78, width: 218, height: 510 }, 'Baganetic Pagodas list on Android', 'contain', 'rounded-2xl');
  addText(s, 'HOME', { left: 720, top: 612, width: 160, height: 24 }, { fontSize: 12, bold: true, color: C.terracotta, alignment: 'center', characterSpacing: 1.4 });
  addText(s, 'PAGODA CATALOGUE', { left: 950, top: 612, width: 218, height: 24 }, { fontSize: 12, bold: true, color: C.terracotta, alignment: 'center', characterSpacing: 1.2 });
  addText(s, 'Visual cards make heritage feel inviting—not like a database.', { left: 72, top: 500, width: 510, height: 58 }, {
    fontSize: 26, typeface: 'Georgia', bold: true, color: C.brown,
  });
  addFooter(s);
  addNotes(s, '1:30–3:00. Show these two screens briefly. Point out the visual home experience, featured pagodas, search, reading-friendly detail, and bookmark action. Then move to the map, where a saved place becomes a route.', '- Android screenshots: self-captured from the Baganetic running build on a Galaxy A56, 12 Aug 2026.');
}

// 4. Map and route planning
{
  const s = deck.slides.add();
  s.background.fill = C.brown;
  await addImage(s, `${TEMP}/baganetic-phone-map-fallback-20260812.png`, { left: 736, top: 34, width: 332, height: 620 }, 'Baganetic Map and Trips screen running on Android', 'contain', 'rounded-2xl');
  addText(s, 'A map that\nturns intent\ninto a journey.', { left: 72, top: 104, width: 550, height: 208 }, {
    fontSize: 52, typeface: 'Georgia', bold: true, color: C.white,
  });
  addText(s, 'Browse sites, compare routes, and plan a trip directly inside the app.', { left: 76, top: 360, width: 500, height: 78 }, {
    fontSize: 24, color: '#E9D9C8',
  });
  addRule(s, 76, 482, 490, C.gold);
  addText(s, 'MAP RELIABILITY', { left: 76, top: 510, width: 300, height: 22 }, { fontSize: 13, bold: true, color: C.gold, characterSpacing: 1.7 });
  addText(s, 'The Android build now uses a primary tile source with automatic OpenStreetMap fallback—so a traveller is not dependent on one map server.', { left: 76, top: 548, width: 510, height: 82 }, {
    fontSize: 18, color: '#F7EBDD',
  });
  addText(s, 'WORKING ON A PHYSICAL ANDROID DEVICE', { left: 76, top: 672, width: 530, height: 20 }, { fontSize: 11, bold: true, color: C.gold, characterSpacing: 1.5 });
  addNotes(s, '3:00–4:30. This is the key proof slide. Show the working map on the physical Android build. Explain that map markers represent the pagodas and the app offers Browse, Shortest, and Plan Trip modes. Mention the practical reliability improvement only briefly.', '- Android screenshot: self-captured from the Baganetic running build on a Galaxy A56, 12 Aug 2026.\n- Map tiles: OpenStreetMap-compatible public tile services, rendered in the app.');
}

// 5. Personal and local
{
  const s = deck.slides.add();
  s.background.fill = C.paper;
  addEyebrow(s, 'Working result • personal journey', 5);
  addText(s, 'The visit becomes\na personal journal.', { left: 72, top: 102, width: 560, height: 128 }, {
    fontSize: 46, typeface: 'Georgia', bold: true,
  });
  addText(s, 'Saved pagodas, planned journeys, profile preferences, and community posts keep the experience useful before, during, and after the trip.', { left: 72, top: 255, width: 545, height: 108 }, {
    fontSize: 23, color: C.muted,
  });
  addRule(s, 72, 413, 540, C.line);
  addText(s, 'Built for the visitor journey—not just the visit.', { left: 72, top: 452, width: 530, height: 65 }, {
    fontSize: 28, typeface: 'Georgia', bold: true,
  });
  addText(s, '• Save meaningful places\n• Shape a route around time and travel mode\n• Keep a local travel identity\n• Participate through tips and questions', { left: 74, top: 548, width: 525, height: 110 }, {
    fontSize: 19, color: C.ink,
  });
  await addImage(s, `${TEMP}/baganetic-phone-pagodas-title-v3-20260812.png`, { left: 735, top: 84, width: 190, height: 525 }, 'Pagoda browse screen on Baganetic Android app', 'contain', 'rounded-2xl');
  await addImage(s, `${TEMP}/baganetic-phone-map-fixed-20260812.png`, { left: 962, top: 84, width: 190, height: 525 }, 'Map screen on Baganetic Android app', 'contain', 'rounded-2xl');
  addFooter(s);
  addNotes(s, '4:30–6:00. Connect features to a single traveller story: discover Ananda, save it, add it to a journey, then return to the map. Community and profile complete the product as an ongoing travel journal.', '- Android screenshots: self-captured from the Baganetic running build on a Galaxy A56, 12 Aug 2026.');
}

// 6. Demo sequence
{
  const s = deck.slides.add();
  s.background.fill = C.paper;
  addEyebrow(s, 'Live demo', 6);
  addText(s, 'One traveller journey.\nFour simple actions.', { left: 72, top: 102, width: 620, height: 126 }, {
    fontSize: 46, typeface: 'Georgia', bold: true,
  });
  const steps = [
    ['01', 'Explore', 'Open the home feed and discover a pagoda.'],
    ['02', 'Save', 'Bookmark a place worth returning to.'],
    ['03', 'Plan', 'Add saved stops to a journey on the map.'],
    ['04', 'Go', 'Use the route view to explore with confidence.'],
  ];
  steps.forEach(([number, title, copy], i) => {
    const left = 72 + i * 282;
    addText(s, number, { left, top: 338, width: 80, height: 36 }, { fontSize: 18, color: C.gold, bold: true, characterSpacing: 1.6 });
    addText(s, title, { left, top: 393, width: 225, height: 42 }, { fontSize: 30, typeface: 'Georgia', bold: true });
    addText(s, copy, { left, top: 452, width: 220, height: 75 }, { fontSize: 18, color: C.muted });
    if (i < 3) addRule(s, left + 236, 404, 32, C.terracotta);
  });
  addRect(s, { left: 72, top: 576, width: 1136, height: 60 }, '#F0E5D4', 16);
  addText(s, 'Live proof matters: the pitch can move straight from this slide into the Android app.', { left: 100, top: 592, width: 1080, height: 28 }, {
    fontSize: 21, color: C.brown, alignment: 'center', bold: true,
  });
  addFooter(s);
  addNotes(s, '6:00–8:30. Use this slide as the handoff to the live demo. Spend roughly 30 seconds per action. If time is short, show Explore → Save → Plan only; the audience will still see the complete loop.', '- Product flow reflects the working Baganetic Android build.');
}

// 7. Delivery proof
{
  const s = deck.slides.add();
  s.background.fill = C.paper;
  addEyebrow(s, 'What has been delivered', 7);
  addText(s, 'A working result—\nnot a static concept.', { left: 72, top: 100, width: 560, height: 125 }, {
    fontSize: 46, typeface: 'Georgia', bold: true,
  });
  const rows = [
    ['Flutter mobile app', 'Responsive mobile interface and app navigation'],
    ['Pagoda discovery', 'Searchable, detail-rich sacred-site catalogue'],
    ['Map & trips', 'Interactive map, markers, planning modes, and tile fallback'],
    ['Personal experience', 'Saved places, journeys, profile, and community modules'],
    ['Physical-device validation', 'Built and tested as an Android arm64 application'],
  ];
  rows.forEach(([label, copy], i) => {
    const y = 282 + i * 65;
    addText(s, '•', { left: 74, top: y - 4, width: 24, height: 32 }, { fontSize: 25, color: C.gold, bold: true });
    addText(s, label, { left: 108, top: y, width: 260, height: 28 }, { fontSize: 19, bold: true });
    addText(s, copy, { left: 390, top: y, width: 485, height: 28 }, { fontSize: 18, color: C.muted });
    addRule(s, 108, y + 42, 765, C.line);
  });
  await addImage(s, `${ASSET}/ananda_postcard.jpg`, { left: 957, top: 102, width: 220, height: 480 }, 'Ananda Temple postcard asset', 'cover', 'rounded-2xl');
  addText(s, 'A focused foundation\nfor traveller feedback.', { left: 930, top: 600, width: 274, height: 62 }, { fontSize: 18, typeface: 'Georgia', bold: true, alignment: 'center' });
  addFooter(s);
  addNotes(s, '8:30–9:30. Summarize the tangible output. Keep the language grounded: this is a working prototype that proves the main experience and is ready to be tested with real travellers.', '- Project asset: assets/images/stitch/ananda_postcard.jpg (Baganetic workspace).\n- Physical-device validation: Baganetic Android arm64 build tested on Galaxy A56, 12 Aug 2026.');
}

// 8. Close
{
  const s = deck.slides.add();
  s.background.fill = C.brown;
  await addImage(s, `${ASSET}/bagan_sunrise.jpg`, { left: 0, top: 0, width: 1280, height: 720 }, 'Bagan pagodas at sunrise', 'cover', 0);
  addRect(s, { left: 0, top: 0, width: 1280, height: 720 }, '#2B1D14C8');
  addText(s, 'BAGANETIC', { left: 76, top: 78, width: 480, height: 34 }, { fontSize: 17, color: C.gold, bold: true, characterSpacing: 4 });
  addText(s, 'Explore Bagan\nwith context.', { left: 76, top: 210, width: 680, height: 170 }, { fontSize: 62, typeface: 'Georgia', color: C.white, bold: true });
  addText(s, 'A working mobile journal for discovery, planning, and a more personal journey through Bagan.', { left: 80, top: 430, width: 610, height: 72 }, { fontSize: 24, color: '#F7EBDD' });
  addRule(s, 80, 560, 260, C.gold);
  addText(s, 'READY FOR A LIVE DEMO', { left: 80, top: 584, width: 390, height: 28 }, { fontSize: 15, color: C.gold, bold: true, characterSpacing: 1.8 });
  addNotes(s, '9:30–10:00. Close by returning to the promise: Baganetic lets a visitor move from curiosity to a more meaningful, better-planned day in Bagan. Invite the audience to watch the live demo or ask questions.', '- Project asset: assets/images/stitch/bagan_sunrise.jpg (Baganetic workspace).');
}

await fs.mkdir('D:/Project/Project/baganetic_mobile_stitch_redesign_fixed/deliverables', { recursive: true });
const renderDir = 'D:/Project/Project/baganetic_mobile_stitch_redesign_fixed/pitch_build/rendered';
await fs.mkdir(renderDir, { recursive: true });
for (const [index, slide] of deck.slides.items.entries()) {
  await writeBlob(
    `${renderDir}/slide-${String(index + 1).padStart(2, '0')}.png`,
    await deck.export({ slide, format: 'png', scale: 1 }),
  );
}
await writeBlob(`${renderDir}/montage.webp`, await deck.export({ format: 'webp', montage: true, scale: 1 }));
const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(OUT);
console.log(OUT);
