part of flutter_native_splash_supported_platform;

// Image template
class _IosLaunchImageTemplate {
  final String fileName;
  final double divider;

  _IosLaunchImageTemplate({this.fileName, this.divider});
}

final List<_IosLaunchImageTemplate> _iOSSplashImages =
    <_IosLaunchImageTemplate>[
  _IosLaunchImageTemplate(fileName: 'LaunchImage.png', divider: 3),
  _IosLaunchImageTemplate(fileName: 'LaunchImage@2x.png', divider: 2),
  _IosLaunchImageTemplate(
      fileName: 'LaunchImage@3x.png', divider: 1), // original image must be @3x
];

final List<_IosLaunchImageTemplate> _iOSSplashImagesDark =
    <_IosLaunchImageTemplate>[
  _IosLaunchImageTemplate(fileName: 'LaunchImageDark.png', divider: 3),
  _IosLaunchImageTemplate(fileName: 'LaunchImageDark@2x.png', divider: 2),
  _IosLaunchImageTemplate(fileName: 'LaunchImageDark@3x.png', divider: 1),
  // original image must be @3x
];

/// Create iOS splash screen
void _createiOSSplash(String imagePath, String darkImagePath, String color,
    String darkColor, List<String> plistFiles) async {
  if (imagePath.isNotEmpty) {
    await _applyImageiOS(imagePath);
  }
  if (darkImagePath.isNotEmpty) {
    await _applyImageiOS(darkImagePath, dark: true);
  }

  await _applyLaunchScreenStoryboard(imagePath);
  await _createBackgroundColor(color, darkColor, darkColor.isNotEmpty);
  await _applyInfoPList(plistFiles);
  await _applyAppDelegate();
}

/// Create splash screen images for original size, @2x and @3x
void _applyImageiOS(String imagePath, {bool dark = false}) {
  print('[iOS] Creating ' + (dark ? 'dark mode ' : '') + 'splash images');

  final file = File(imagePath);

  if (!file.existsSync()) {
    throw _NoImageFileFoundException('The file $imagePath was not found.');
  }

  final image = decodeImage(File(imagePath).readAsBytesSync());

  for (var template in dark ? _iOSSplashImagesDark : _iOSSplashImages) {
    _saveImageiOS(template, image);
  }
  File(_iOSAssetsLaunchImageFolder + 'Contents.json')
      .create(recursive: true)
      .then((File file) {
    file.writeAsStringSync(dark ? _iOSContentsJsonDark : _iOSContentsJson);
  });
}

/// Saves splash screen image to the project
void _saveImageiOS(_IosLaunchImageTemplate template, Image image) {
  var newFile = copyResize(
    image,
    width: image.width ~/ template.divider,
    height: image.height ~/ template.divider,
    interpolation: Interpolation.linear,
  );

  File(_iOSAssetsLaunchImageFolder + template.fileName)
      .create(recursive: true)
      .then((File file) {
    file.writeAsBytesSync(encodePng(newFile));
  });
}

/// Update LaunchScreen.storyboard adding width, height and color
Future _applyLaunchScreenStoryboard(String imagePath) {
  final file = File(_iOSLaunchScreenStoryboardFile);

  if (file.existsSync()) {
    print('[iOS] Updating LaunchScreen.storyboard with width, and height');
    return _updateLaunchScreenStoryboard(imagePath);
  } else {
    print('[iOS] No LaunchScreen.storyboard file found in your iOS project');
    print(
        '[iOS] Creating LaunchScreen.storyboard file and adding it to your iOS project');
    return _createLaunchScreenStoryboard(imagePath);
  }
}

/// Updates LaunchScreen.storyboard adding splash image path
Future _updateLaunchScreenStoryboard(String imagePath) async {
  final file = File(_iOSLaunchScreenStoryboardFile);
  final lines = await file.readAsLines();

  var foundExistingBackgroundImage = false;

  var foundExistingImage = false;
  int imageLine;

  var foundExistingLaunchBackgroundSubview = false;

  var subviewCount = 0;
  int subviewTagLine;

  var constraintCount = 0;
  int constraintClosingTagLine;

  for (var x = 0; x < lines.length; x++) {
    var line = lines[x];

    if (line.contains('<image name="LaunchImage"')) {
      foundExistingImage = true;
      imageLine = x;
    }

    if (line.contains('<image name="LaunchBackground"')) {
      foundExistingBackgroundImage = true;
    }

    if (line.contains('image="LaunchBackground"')) {
      foundExistingLaunchBackgroundSubview = true;
    }

    if (line.contains('<subviews>')) {
      subviewCount++;
      subviewTagLine = x;
    }

    if (line.contains('</constraints>')) {
      constraintCount++;
      constraintClosingTagLine = x;
    }
  }

  // Found the image line, replace with new image information
  if (foundExistingImage) {
    if (!foundExistingLaunchBackgroundSubview) {
      if (subviewCount != 1) {
        throw _LaunchScreenStoryboardModified(
            'Multiple subviews found.   Did you modify your default LaunchScreen.storyboard file?');
      }
      if (constraintCount != 1) {
        throw _LaunchScreenStoryboardModified(
            'Multiple constraint blocks found.   Did you modify your default LaunchScreen.storyboard file?');
      }
      lines[subviewTagLine] =
          lines[subviewTagLine] + '\n' + _iOSLaunchBackgroundSubview;
      lines[constraintClosingTagLine] =
          _iOSLaunchBackgroundConstraints + lines[constraintClosingTagLine];
    }

    if (imagePath.isNotEmpty) {
      final file = File(imagePath);

      if (!file.existsSync()) {
        throw _NoImageFileFoundException('The file $imagePath was not found.');
      }

      final image = decodeImage(File(imagePath).readAsBytesSync());
      var width = image.width;
      var height = image.height;

      lines[imageLine] =
          '        <image name="LaunchImage" width="$width" height="$height"/>';
    }
    // Existing background image was not found, add it before the image line:
    if (!foundExistingBackgroundImage) {
      lines[imageLine] =
          '        <image name="LaunchBackground" width="1" height="1"/>\n' +
              lines[imageLine];
    }
  } else {
    throw _LaunchScreenStoryboardModified(
        "Not able to find 'LaunchImage' image tag in LaunchScreen.storyboard. Image for splash screen not updated. Did you modify your default LaunchScreen.storyboard file?");
  }

  await file.writeAsString(lines.join('\n'));
}

/// Creates LaunchScreen.storyboard with splash image path
Future _createLaunchScreenStoryboard(String imagePath) async {
  var file = await File(_iOSLaunchScreenStoryboardFile).create(recursive: true);
  await file.writeAsString(_iOSLaunchScreenStoryboardContent);

  return _updateLaunchScreenStoryboard(imagePath);
}

Future<void> _createBackgroundColor(
    String colorString, String darkColorString, bool dark) async {
  var background = Image(1, 1);
  var redChannel = int.parse(colorString.substring(0, 2), radix: 16);
  var greenChannel = int.parse(colorString.substring(2, 4), radix: 16);
  var blueChannel = int.parse(colorString.substring(4, 6), radix: 16);
  background.fill(
      0xFF000000 + (blueChannel << 16) + (greenChannel << 8) + redChannel);
  await File(_iOSAssetsLaunchImageBackgroundFolder + 'background.png')
      .create(recursive: true)
      .then((File file) => file.writeAsBytesSync(encodePng(background)));

  if (darkColorString.isNotEmpty) {
    redChannel = int.parse(darkColorString.substring(0, 2), radix: 16);
    greenChannel = int.parse(darkColorString.substring(2, 4), radix: 16);
    blueChannel = int.parse(darkColorString.substring(4, 6), radix: 16);
    background.fill(
        0xFF000000 + (blueChannel << 16) + (greenChannel << 8) + redChannel);
    await File(_iOSAssetsLaunchImageBackgroundFolder + 'darkbackground.png')
        .create(recursive: true)
        .then((File file) => file.writeAsBytesSync(encodePng(background)));
  }

  return File(_iOSAssetsLaunchImageBackgroundFolder + 'Contents.json')
      .create(recursive: true)
      .then((File file) {
    file.writeAsStringSync(
        dark ? _iOSLaunchBackgroundDarkJson : _iOSLaunchBackgroundJson);
  });
}

/// Update Info.plist for status bar behaviour (hidden/visible)
Future _applyInfoPList(List<String> plistFiles) async {
  if (plistFiles == null) {
    plistFiles = [];
    plistFiles.add(_iOSInfoPlistFile);
  }

  plistFiles.forEach((plistFile) async {
    if (!await File(plistFile).exists()) {
      throw _CantFindInfoPlistFile(
          'File $plistFile not found.  If you renamed the file, make sure to '
          'specify it in the info_plist_files section of your '
          'flutter_native_splash configuration.');
    }

    final infoPlistFile = File(plistFile);

    final lines = await infoPlistFile.readAsLines();

    if (_needToUpdateInfoPlist(lines)) {
      print('[iOS] Updating $infoPlistFile for status bar hidden/visible');
      await _updateInfoPlistFile(infoPlistFile, lines);
    }
  });
}

/// Check if Info.plist needs to be updated with code required for status bar hidden
bool _needToUpdateInfoPlist(List<String> lines) {
  var foundExisting = false;

  for (var x = 0; x < lines.length; x++) {
    var line = lines[x];

    // if file contains our variable we're assuming it contains all required code
    // it's okay to check only for the key because the key doesn't come on default create
    if (line.contains('<key>UIStatusBarHidden</key>')) {
      foundExisting = true;
      break;
    }
  }

  return !foundExisting;
}

/// Update Infop.list with status bar hidden directive
Future _updateInfoPlistFile(File infoPlistFile, List<String> lines) async {
  var newLines = <String>[];
  int lastDictLine;

  for (var x = 0; x < lines.length; x++) {
    var line = lines[x];

    // Find last `</dict>` on file
    if (line.contains('</dict>')) {
      lastDictLine = x;
    }

    newLines.add(line);
  }

  // Before last '</dict>' add the lines
  newLines.insert(lastDictLine, _iOSInfoPlistLines);

  await infoPlistFile.writeAsString(newLines.join('\n'));
}

/// Add the code required for removing full screen mode of splash screen after app loaded
Future _applyAppDelegate() async {
  String language = await _objectiveCOrSwift();
  String appDelegatePath;

  if (language == 'objective-c') {
    appDelegatePath = _iOSAppDelegateObjCFile;
  } else if (language == 'swift') {
    appDelegatePath = _iOSAppDelegateSwiftFile;
  }

  final appDelegateFile = File(appDelegatePath);
  final lines = await appDelegateFile.readAsLines();

  if (_needToUpdateAppDelegate(language, lines)) {
    print('[iOS] Updating AppDelegate for status bar hidden/visible');
    await _updateAppDelegate(language, appDelegateFile, lines);
  }
}

Future _objectiveCOrSwift() async {
  if (File(_iOSAppDelegateObjCFile).existsSync()) {
    return 'objective-c';
  } else if (File(_iOSAppDelegateSwiftFile).existsSync()) {
    return 'swift';
  } else {
    throw _CantFindAppDelegatePath('Not able to determinate AppDelegate path.');
  }
}

/// Check if AppDelegate needs to be updated with code required for splash screen
bool _needToUpdateAppDelegate(String language, List<String> lines) {
  var foundExisting = false;

  var objectiveCLine = 'int flutter_native_splash = 1;';
  var swiftLine = 'var flutter_native_splash = 1';

  for (var x = 0; x < lines.length; x++) {
    var line = lines[x];

    // if file contains our variable we're assuming it contains all required code
    if (line
        .contains((language == 'objective-c') ? objectiveCLine : swiftLine)) {
      foundExisting = true;
      break;
    }
  }

  return !foundExisting;
}

/// Update AppDelegate with code to remove status bar hidden property after app loaded
Future _updateAppDelegate(
    String language, File appDelegateFile, List<String> lines) async {
  var newLines = <String>[];

  var objectiveCReferenceLine =
      '[GeneratedPluginRegistrant registerWithRegistry:self];';
  var swiftReferenceLine = 'GeneratedPluginRegistrant.register(with: self)';

  for (var x = 0; x < lines.length; x++) {
    var line = lines[x];

    if (language == 'objective-c') {
      // Before '[GeneratedPlugin ...' add the following lines
      if (line.contains(objectiveCReferenceLine)) {
        newLines.add(_iOSAppDelegateObjectiveCLines);
      }

      newLines.add(line);
    }

    if (language == 'swift') {
      // Before 'GeneratedPlugin ...' add the following lines
      if (line.contains(swiftReferenceLine)) {
        newLines.add(_iOSAppDelegateSwiftLines);
      }

      newLines.add(line);
    }
  }

  await appDelegateFile.writeAsString(newLines.join('\n'));
}
