Smart Route & Info Guide for Bagan Pagodas

Presented by:
Phyu Hnin Aung (2022-MIIT-CSE-040) - Leader
Kyaw Zay Ya Hein (2022-MIIT-CSE-014)

Instructor in charge : Dr. Myat Thuzar Tun
Project Supervisor   : Daw Khin Myat Nwe Win

Submitted in Partial Fulfilment of the Special Project
I Semester 2025-2026
Date : 24 December 2025
Myanmar Institute of Information Technology

---

ii
Abstract
Bagan, Myanmar, is renowned for its thousands of temples and pagodas spread across a large
area, making navigation challenging for tourists. A prior web-based Tour Guide Assistant
provided basic shortest-path routing but relied on continuous internet connectivity and lacked
mobile usability and personalization. This project proposes a mobile-first, offline-capable
solution titled "Smart Route & Info Guide for Bagan Pagodas," built with Flutter and Dart for
cross-platform deployment on Android devices.

The system redesigns navigation architecture to support on-device route computation using the
A* algorithm and cached OpenStreetMap tiles for reliable use in low-connectivity environments.
Planned functional modules extend the system beyond navigation, including Hotels and Restaurants
Discovery, Smart Itinerary Builder, Group Chat and Trip Rooms, Local Tips and Q/A Feed, and a
Safety and Emergency Toolkit. A context-aware, bilingual AI chatbot is also planned to provide
location-based historical information and travel guidance. The mid-term implementation focuses
on offline map navigation, pagoda information, favorites, trip planning, and bilingual UI; Firebase
authentication is integrated for optional online login, while cloud sync and social/community
features are planned for later phases when connectivity is available.

Overall, this project delivers a comprehensive, user-centric mobile solution that enhances
navigation, cultural engagement, and travel safety in Bagan, with advanced modules scheduled
for future development.

---

iii
Table of Contents
1. Abstract
2. Table of Contents
3. Chapters
   Chapter 1 : Introduction
     1.1 Background
     1.2 Objectives
     1.3 Scope
     1.4 Project Description
     1.5 Project Schedule
   Chapter 2 : System Overview and Components
     2.1 System Overview
     2.2 Components
     2.3 Data Sources and Licensing
   Chapter 3 : System Design and Flowchart
     3.1 System Design
     3.2 Flowchart
     3.3 Routing Algorithm Details
   Chapter 4 : System Implementation
     4.1 Implementation Steps
     4.2 Evaluation Plan and Metrics
   Chapter 5 : Conclusion
     5.1 Summary
     5.2 Future Enhancements
4. References

---

1
Chapter 1
Introduction

1.1 Background
Bagan is one of Myanmar's most significant cultural heritage regions, containing over 2,000
ancient pagodas distributed across a wide archaeological landscape. Due to limited signage,
large distances, and unreliable internet connectivity, tourists often face difficulties navigating
between pagodas efficiently. Traditional guides and printed maps are not sufficient for
optimized routing or real-time decision making. An earlier web-based Tour Guide Assistant
provided shortest-path navigation but required continuous internet access and server-side
processing, limiting practical use in Bagan.

This project addresses these limitations by designing an offline-first mobile architecture that
supports on-device routing, personalized navigation, and contextual guidance. In addition, it
introduces new modules for discovery, planning, social coordination, community knowledge,
and safety, extending the scope from navigation to a full tourism companion.

1.2 Objectives
The objectives of this project are (items marked as Planned will be completed in later phases):
- To design and develop an offline-first mobile navigation system for cultural heritage tourism.
- To implement on-device shortest-path routing using the A* algorithm.
- To support personalized navigation through user profiles, visited-place tracking, and favorites.
- To integrate OpenStreetMap with offline tiles for reliable navigation in low-connectivity
  environments.
- To develop a context-aware AI chatbot that provides location-based historical information and
  travel guidance. (Planned)
- To introduce new functional modules: discovery of nearby places, smart itinerary builder,
  group chat and trip rooms, local tips and Q/A feed, and a safety and emergency toolkit. (Planned)
- To provide a bilingual user interface (English and Myanmar) for accessibility and inclusiveness.
- To evaluate system performance and usability in a mobile environment. (Planned)

1.3 Scope
The project focuses on a mobile application for tourists in Bagan. The system supports offline
navigation, pagoda information, favorites, and itinerary planning. It supports optional online
authentication when internet is available. Cloud sync and real-time group chat are planned for
later phases. The initial deployment targets Android devices. Administrative tools for managing
pagoda and service data are planned. The system is designed to be extensible to other heritage
sites.

1.4 Project Description
The Smart Route & Info Guide for Bagan Pagodas is a Flutter-based mobile application that
provides intelligent, personalized navigation. Tourists can view pagodas on an offline map,
compute shortest paths using on-device A*, access cultural information, and plan multi-stop
itineraries. The current implementation includes pagoda browsing, favorites, trip planning,
offline map support, and bilingual UI. Planned extensions include discovery of nearby amenities,
group trip coordination, community tips, safety tools, and a bilingual AI chatbot. Administrative
tools for data management and community moderation are planned.

1.5 Project Schedule
Weeks 1-2: Requirement analysis, limitation review, and offline-first architecture design.
Weeks 3-4: UI/UX design, Firebase setup, and dataset preparation.
Weeks 5-6: Offline map integration and GPS tracking.
Weeks 7-8: On-device routing algorithm implementation.
Weeks 9-10: Personalization and advanced module development.
Weeks 11-12: AI chatbot integration and community/safety features.
Weeks 13-14: Evaluation, optimization, testing, and finalization.

---

5
Chapter 2
System Overview and Components

2.1 System Overview
The system is organized as a mobile client with offline-first capabilities and optional cloud
synchronization. Core navigation functions operate without internet access using locally cached
map tiles and a stored graph dataset. When connectivity is available, Firebase services enable
user authentication, profile synchronization, and collaborative features such as group chat and
shared itineraries.

2.2 Components
Client Application (Flutter + Dart) - Current (Mid-term):
- Map UI, route visualization, and navigation controls.
- Offline tile cache for OpenStreetMap.
- On-device A* routing engine with local graph storage.
- Pagoda directory, details, and favorites.
- Itinerary builder with multi-stop planning.
- Bilingual UI (English/Myanmar).

Client Application - Planned Extensions:
- Discovery module for hotels, restaurants, and services.
- Group chat, trip rooms, and community feed.
- Safety toolkit and emergency features.
- Context-aware AI chatbot integration.

Backend Services (Firebase):
- Authentication for user accounts (current).
- Firestore for user profiles, favorites, trips, and chat content (planned sync).
- Cloud storage for media and data synchronization (planned).

Data Layer:
- Pagoda and POI dataset with metadata.
- Graph edges and nodes for routing.
- Local cache for offline discovery and tips (planned).

---

2.3 Data Sources and Licensing
Pagoda metadata and images are compiled from the prior web-based project dataset and
curated local assets used for the academic prototype. For public deployment, each image
and metadata entry must have verified licensing and attribution. The map layer uses
OpenStreetMap tiles. The application must display OpenStreetMap attribution and follow
the OpenStreetMap Tile Usage Policy. OpenStreetMap data is provided under the ODbL
license; any derived datasets or redistributions must comply with that license.

8
Chapter 3
System Design and Flowchart

3.1 System Design
The architecture follows an offline-first model. The client loads map tiles and routing data from
local storage. User requests for routes are computed on-device with A* using the stored graph.
When internet connectivity is available, the system supports Firebase authentication and can
extend to cloud synchronization. Social modules such as group chat and community feed are
planned and will include real-time updates with offline queuing.

Key design decisions include:
- Local routing engine to avoid dependency on external servers.
- Modular feature layout for discovery, itinerary, social, and safety modules.
- Bilingual content management with language toggling.
- AI chatbot bound to location context and user route state.

3.2 Flowchart
High-level user flow:
Start -> Open App -> Load Offline Map + Data
-> Select pagoda or POI -> Compute route (A*) -> Display route
-> Optional: Save favorites / Add to itinerary
-> Optional: Discover nearby places / Ask chatbot / Join group chat
-> End

---

3.3 Routing Algorithm Details
Two routing layers are used:
1) Trip optimization between selected pagodas uses A* on a pagoda graph.
2) Map route rendering uses an offline road/path graph to draw realistic polylines.

Graph construction (pagoda graph):
- Nodes: pagodas with latitude/longitude.
- Edges: neighbors within a 5 km radius (fallback to nearest 3 neighbors if none).
- Weight: Haversine distance between pagodas.

Heuristic:
- h(n) = Haversine distance from node n to the goal pagoda.

Complexity:
- A* with a binary heap priority queue is typically O(E log V) time and O(V) memory.

Pseudocode (A*):
openSet = {start}
g(start) = 0
h(start) = Haversine(start, goal)
while openSet not empty:
  current = node in openSet with lowest f = g + h
  if current == goal: return reconstructPath(current)
  for each neighbor of current:
    tentative = g(current) + distance(current, neighbor)
    if tentative < g(neighbor):
      parent(neighbor) = current
      g(neighbor) = tentative
      h(neighbor) = Haversine(neighbor, goal)
      add neighbor to openSet if needed
return no path

Offline map routing:
- Uses the stored offline graph (nodes + edges + optional shapes) to build polylines.
- If no graph path is found, a curved fallback line connects points for user feedback.

9
Chapter 4
System Implementation

4.1 Implementation Steps
Completed (Mid-term):
- Prepare pagoda dataset and construct graph nodes/edges.
- Integrate Flutter Map and configure offline tile caching.
- Implement A* routing service and route rendering with polylines.
- Build UI screens for pagoda browsing, trip planning, and favorites.
- Add bilingual support (English/Myanmar).
- Integrate Firebase authentication for optional online login.

Planned Next:
- Add GPS tracking and user location marker.
- Build discovery screens for hotels and restaurants.
- Implement group chat, trip rooms, and community feed.
- Add safety toolkit features and emergency contacts.
- Integrate AI chatbot responses.
- Conduct offline testing, evaluation, and performance optimization.

---

4.2 Evaluation Plan and Metrics
The following metrics will be collected in the final phase to provide measurable results:

Metric | Method | Target / Notes
Route accuracy | Compare computed route length to a reference route for 30+ pairs | Report deviation (%)
Offline availability | Measure cached tile size for core Bagan area | Report size (MB) and coverage
Pathfinding latency | Time route computation for 2, 5, and 10 stops | Report average ms on target device
Battery impact | Measure battery drop during 30-minute navigation session | Report % drain/hour
Usability | Task completion rate + SUS survey with 8-12 users | Report SUS score and common issues

10
Chapter 5
Conclusion

5.1 Summary
This project proposes a mobile-first, offline-capable tourism guide for Bagan that improves on
an earlier web-based system. The mid-term implementation delivers on-device routing, offline maps,
pagoda information, favorites, trip planning, and bilingual UI. Advanced modules for discovery,
social coordination, community tips, safety, and the AI chatbot are planned for subsequent phases.
The architecture emphasizes reliability in low-connectivity environments while supporting cloud
features when available.

5.2 Future Enhancements
Future work may include AR-based on-site guidance, deeper AI personalization, support for
additional heritage sites, richer analytics for route suggestions, and expanded multilingual
support.

---

11
References
[1] P. E. Hart, N. J. Nilsson, and B. Raphael, "A formal basis for the heuristic determination
    of minimum cost paths," IEEE Transactions on Systems Science and Cybernetics, vol. 4, no. 2,
    pp. 100-107, 1968.
[2] OpenStreetMap contributors, "OpenStreetMap," https://www.openstreetmap.org
[3] OpenStreetMap, "Tile Usage Policy," https://operations.osmfoundation.org/policies/tiles/
[4] Open Data Commons, "Open Database License (ODbL) 1.0," https://opendatacommons.org/licenses/odbl/
[5] Flutter, "Flutter SDK," https://flutter.dev
[6] flutter_map, "flutter_map documentation," https://docs.fleaflet.dev
[7] flutter_map_tile_caching, "Package documentation," https://pub.dev/packages/flutter_map_tile_caching
[8] sqflite, "SQLite plugin for Flutter," https://pub.dev/packages/sqflite
[9] Firebase, "Firebase Authentication," https://firebase.google.com/docs/auth
[10] Firebase, "Cloud Firestore," https://firebase.google.com/docs/firestore
