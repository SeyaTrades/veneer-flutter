# Veneer Room Planner · Flutter

[Open the Flutter room planner](https://seyatrades.github.io/veneer-flutter-web/)

Pick a room in **Studio** and tap a piece of furniture to add it. Drag it around to see what fits. **Top Plan** shows the room from above, and **Wall** shows it from the side. The total uses sample prices in pesos.

To save a room, open **Account** and tap **Use demo account**. Go back to **Studio**, tap **Save**, and give the room a name. You can find it later in **Storage** on the same browser or device.

## Run it on your computer

This version uses Flutter and Dart. It was built with Flutter 3.47.4. In this folder, run:

```sh
flutter pub get
flutter run -d chrome
```

## Update the website

```sh
flutter build web --release --no-web-resources-cdn --base-href /veneer-flutter-web/
```

Copy the contents of `build/web` into the [website repo](https://github.com/SeyaTrades/veneer-flutter-web). Keep its `.nojekyll` file so GitHub serves the build as it is.
