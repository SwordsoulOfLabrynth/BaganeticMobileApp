I Semester 2025-2026
Special Project: Project Outline








Smart Route & Info Guide for Bagan Pagodas












Date : 24th December 2025
 
Table of Contents

1.	Project Details	2
2.	Abstract	3
3.	Objectives	4
4.	Introduction	5
5.	Project Description	6
6.	Knowledge Requirements	8
7.	Project Schedule	9
8.	Conclusion	11


 

Project Details

Project Title		: Smart Route & Info Guide for Bagan Pagodas
Project Area	: Mobile Application Development for Intelligent Tourism
  Navigation
Project Members	:  1. Phyu Hnin Aung     (2022-MIIT-CSE-040)  –Leader
			   2. Kyaw Zay Ya Hein (2022-MIIT-CSE-014)
Instructor-in-charge	: Dr. Myat Thuzar Tun
Project Supervisor	: Daw Khin Myat Nwe Win
Offered in		: I Semester 2025-2026
		  (24th November 2025 –27th March 2026)
 

Abstract
	Bagan, a UNESCO World Heritage Site, faces significant navigation challenges due to its vast and complex terrain. While a previous web-based Tour Guide Assistant for Bagan provided basic route planning, it lacked offline functionality, personalization, and mobile usability. 
This project introduces a mobile-first, offline-capable intelligent tourism system named “Smart Route & Info Guide for Bagan Pagodas” developed using Flutter and Dart for cross-platform deployment on Android devices. Unlike the earlier web-based system, this project redesigns the navigation architecture to support on-device route computation using graph-based algorithm A*, and cached map data via OpenStreetMap for reliable use in low-connectivity environments.
Newly proposed modules significantly extend its functionality:
•	Hotels & Restaurants Discovery with offline caching and smart filtering.
•	Smart Itinerary Builder for multi-stop, interest-based day planning.
•	Group Chat + Trip Rooms for social navigation and coordination.
•	Local Tips & Q/A Feed for community-driven insights.
•	Safety & Emergency Toolkit for practical on-trip support.
Additionally, the system integrates a context-aware AI chatbot and bilingual guidance. Firebase supports user authentication, cloud synchronization, and personalized features when internet connectivity is available. The system represents a comprehensive, user-centric mobile solution that enhances navigation, cultural engagement, and travel safety in Bagan.

 
Objectives

The objectives of this project are:

1.	To design and develop an offline-first mobile navigation system for cultural heritage tourism.
2.	To implement on-device shortest-path routing using the A* (A-star) algorithm.
3.	To support personalized navigation through user profiles, visited-place tracking, and favorite pagodas.
4.	To integrate OpenStreetMap with offline map tiles for reliable navigation in low-connectivity environments.
5.	To develop a context-aware AI chatbot that provides location-based historical information and travel guidance.
6.	To introduce new functional modules:
•	Nearby Places Discovery (hotels, restaurants, ATMs, etc.).
•	Smart Itinerary Builder for personalized multi-stop trip planning.
•	Group Chat and Trip Rooms for social and coordinated travel.
•	Community-driven Local Tips & Q/A Feed.
•	Safety & Emergency Toolkit with offline support.
7.	To provide a bilingual user interface (English and Myanmar) to ensure accessibility and inclusiveness.
8.	To evaluate system performance and usability in a mobile environment.
 
Introduction
	Bagan is one of Myanmar’s most significant cultural heritage regions, containing over 2,000 ancient pagodas distributed across a wide and complex archaeological landscape. Due to limited signage, large distances, and unreliable internet connectivity, tourists often face difficulties navigating efficiently between pagodas.
The earlier web-based Tour Guide Assistant for Bagan Pagodas was developed to address this issue by providing shortest-path navigation and pagoda information through a browser-based platform. However, the system required continuous internet connectivity, relied on server-side processing, and offered limited personalization, making it unsuitable for real-world usage in many parts of Bagan.
This project extends beyond a simple platform migration by addressing new technical problems inherent to mobile environments. The proposed system introduces an offline-first mobile architecture, personalized navigation based on user state, and a context-aware AI assistant integrated with map and routing data. By redesigning the system architecture rather than replicating the previous solution, the project represents a functional, architectural, and experiential advancement over the earlier work.
Moreover, the introduction of five new modules—covering discovery, planning, social interaction, community knowledge, and safety—ensures the project delivers unique value and addresses real-world tourist needs comprehensively. This project thus not only resolves the limitations of the prior system but also establishes a new standard for intelligent tourism applications in heritage settings.
 
Project Description
	The Smart Route & Info Guide for Bagan Pagodas is a Flutter-based cross-platform mobile application designed to deliver intelligent, personalized, and socially enriched navigation and cultural engagement for tourists exploring Bagan.
Intended Users
Tourists and General Users
•	View pagodas and points of interest on an interactive offline map.
•	Calculate and visualize the shortest routes between selected landmarks using on-device A* algorithm.
•	Access detailed pagoda information, historical context, visiting tips, and cultural notes.
•	Generate optimized multi-stop itineraries based on time and interests.
•	Discover nearby amenities (hotels, restaurants, etc.) .
•	Participate in group trip planning and real-time coordination.
•	Access community tips and safety features.
•	Interact with AI chatbot for guidance.

Administrators
•	Manage pagoda, hotel, and restaurant data
•	Moderate community posts and reported content
•	Maintain data accuracy and system reliability
Core Functions & Technical Architecture
•	Cross-Platform Development: Built with Flutter and Dart for consistent performance on Android and iOS.
•	Offline Mapping: Integration of OpenStreetMap using the Flutter Map library with offline tile caching for uninterrupted navigation.
•	On-Device Routing: Implementation of A* for efficient, offline-capable pathfinding.
•	Context-Aware AI Chatbot: A conversational assistant powered by natural language processing, providing bilingual responses tied to user location and route context.
•	Firebase Backend: Used for user authentication, cloud Firestore database, real-time synchronization, and storage of user data (favorites, profiles, trip rooms).
•	New Advanced and Extension Modules:
1.	Discovery Module: Offline-cached directory of nearby services with intelligent filtering and one-tap actions (call, navigate, save).
2.	Itinerary Builder: Multi-stop route optimizer that considers time, interests, and travel mode to create personalized day plans.
3.	Social Navigation Layer: Real-time group chat, shared itineraries, live location sharing, and offline message queuing.
4.	Community Feed: Location-tagged Q/A system with upvoting and photo support for crowd-sourced tips.
5.	Safety Toolkit: Offline emergency resources, coordinate sharing, and contextual health reminders.
•	Bilingual Interface: Fully supported in English and Myanmar languages to ensure accessibility and inclusiveness.

 
Knowledge Requirements
• Mobile Application Development: Flutter framework and Dart programming language.
• Mapping and Geolocation: OpenStreetMap (OSM) using the Flutter Map library integration, markers, polylines, and geolocation services.
• Algorithm Design: Strong understanding of graph algorithms such as A* for route optimization.
• State Management: Familiarity with Flutter state management solutions (Provider, Riverpod, or Bloc).
• Cloud Backend Services: Firebase Authentication, Firestore database, Cloud Functions, and Storage.
• AI and NLP Basics: Knowledge of chatbot systems and natural language processing concepts.
• UI/UX Design: Ability to design intuitive and responsive interfaces following Material Design principles.
• Offline Data Management: Local caching strategies and sync mechanisms.
• Social Features Implementation: Real-time chat, group coordination, live location sharing.
• Version Control: Experience using Git for source code management and collaboration

 
Project Schedule
Weeks 1–2: Requirement Analysis & System Redesign
•	Review limitations of the previous web-based system
•	Define new technical problems: offline navigation, personalization, and mobile constraints
•	Specify functional and non-functional requirements
•	Design offline-first system architecture
Weeks 3–4: UI/UX Design & Backend Setup
•	Design mobile UI/UX optimized for small screens
•	Design user flow for personalized navigation
•	Set up Firebase Authentication and Firestore
•	Prepare pagoda dataset and graph structure
Weeks 5–6: Offline Map & Core Mobile Development
•	Integrate OpenStreetMap with Flutter Map
•	Implement offline map tile caching
•	Implement real-time GPS tracking
•	Display pagodas, markers, and basic routes
Weeks 7–8: On-Device Routing Algorithm Implementation
•	Implement algorithms on mobile
•	Store graph data locally for offline computation
•	Generate routes without internet connectivity
•	Compare basic performance metric
Weeks 9–10: Personalization & Advanced Module Development
•	Implement user profiles, favorites, and visited tracking
•	Develop the Smart Itinerary Builder with multi-stop optimization and time estimation.
•	Build the Hotels & Restaurants Discovery module with filtering, sorting, and offline caching.
•	Begin integration of the Group Chat + Trip Rooms feature with real-time messaging.

Weeks 11–12: AI Chatbot & Community/Safety Features Integration
•	Integrate AI chatbot
•	Enable chatbot responses based on user location and route context
•	Develop the Local Tips & Q/A Feed with posting, upvoting, and location tagging.
•	Implement the Safety & Emergency Toolkit including offline contacts, “I’m lost” button, and health reminders.
•	Add bilingual support (English/Myanmar)
Weeks 13–14: System Evaluation, Optimization & Finalization
•	Evaluate routing performance
•	Test offline vs online navigation accuracy
•	Optimize battery usage and performance
•	Conduct usability testing
•	Final system integration
•	Fix bugs and improve UI
•	Prepare project report and presentation
•	Final demonstration and submission
 
Conclusion
	The Smart Route & Info Guide for Bagan Pagodas represents a meaningful evolution from its web-based predecessor. By introducing an offline-first mobile architecture, on-device intelligent routing, and five new modules (Discovery, Itinerary Builder, Social Trip Rooms, Community Feed, and Safety Toolkit), this project transforms basic navigation into a comprehensive, intelligent tourism companion.
The system directly addresses practical tourist challenges—offering personalized planning, real-time coordination, crowd-sourced insights, and essential safety features. The integration of a context-aware AI chatbot and bilingual support further enhances accessibility and engagement.
Technically, the project demonstrates effective use of mobile development, graph algorithms, offline strategies, and cloud integration, showcasing how academic prototypes evolve into user-centric solutions with real-world impact.
Designed for scalability, the system can be extended to other heritage sites or enhanced with future features like AR guides or deeper AI personalization. Ultimately, it highlights how smart technology can enrich cultural exploration, foster community, and promote safer travel.

