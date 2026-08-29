# PlaySpot V2

## Project Description
PlaySpot is a comprehensive platform designed to simplify the process of discovering and booking PlayStation lounges. The application provides a seamless user experience that enables players to find the nearest locations, browse details, and book sessions with ease.

## Key Features
- Authentication System: Supports email, Google, and Facebook login.
- Lounge Exploration: Displays a list of available lounges with advanced search and filtering options.
- Lounge Details: View photos, available services, geographical location, and ratings.
- Booking System: Ability to select rooms, timings, and session duration.
- Booking Management: Track upcoming and past bookings with QR code support for verification.
- Geographical Services: Location tracking using GPS and map integration for navigation.
- Notifications: Real-time alerts for booking updates and promotional offers.
- Favorites: Ability to save favorite places for quick access later.
- Language Support: The application fully supports both Arabic and English.

## Technologies Used
- Programming Language: Dart
- Framework: Flutter
- State Management: Flutter Bloc & Cubit
- Backend Services: Supabase (Authentication, Database, Storage)
- Navigation: GoRouter
- Dependency Injection: Get_It
- Networking: Dio
- Internationalization: Easy Localization
- Responsive Design: Flutter ScreenUtil
- Local Storage: GetStorage
- Image Processing: Cached Network Image & Photo View

## Project Structure
The project follows a Feature-driven Architecture to ensure code organization and maintainability:

- lib/core: Contains global configurations, utilities, routing setup, and themes.
- lib/art_core: Contains shared graphical components (Common Widgets) used across various interfaces.
- lib/features: Contains the functional modules of the project, where each feature is divided into:
    - data: Includes Models, Data Sources, and Repositories.
    - presentation: Includes UI components and State Management logic (Blocs/Cubits).

## Project Assets
- assets/lang: Contains translation files (ar.json and en.json).
- assets/fonts: Contains fonts used in the application, such as the Orbitron font.
- assets/images: Includes static images used in the interfaces.
- assets/icons: Includes application-specific icons.

## Requirements
- Flutter SDK version 3.11.4 or higher.
- Development Environment: Android Studio or Visual Studio Code.
- Supabase environment keys configuration.

## Getting Started
1. Clone the repository to your local machine.
2. Open the project folder in your preferred IDE.
3. Run the following command in the terminal: flutter pub get
4. Ensure a physical device or emulator is connected.
5. Start the application using the command: flutter run
