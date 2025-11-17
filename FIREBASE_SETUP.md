# Configuration Firebase pour Sapemoi

## 📱 Configuration Firebase

### 1. Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Cliquez sur "Ajouter un projet"
3. Nommez-le "sapemoi-app"
4. Suivez les étapes

### 2. Ajouter les applications iOS et Android

#### Pour iOS :
1. Dans Firebase Console, cliquez sur l'icône iOS
2. Bundle ID: `com.sapemoi.app` (ou votre bundle ID)
3. Téléchargez `GoogleService-Info.plist`
4. Placez-le dans `ios/Runner/`

#### Pour Android :
1. Dans Firebase Console, cliquez sur l'icône Android
2. Package name: `com.sapemoi.app` (ou votre package)
3. Téléchargez `google-services.json`
4. Placez-le dans `android/app/`

### 3. Activer l'authentification

1. Dans Firebase Console, allez dans **Authentication**
2. Cliquez sur **Get Started**
3. Activez les fournisseurs :
   - ✅ **Email/Password**
   - ✅ **Google**
   - ✅ **Apple** (iOS uniquement)

### 4. Configuration Google Sign-In

#### iOS :
1. Ouvrez `ios/Runner/Info.plist`
2. Ajoutez :
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

#### Android :
1. Le fichier `google-services.json` contient déjà tout

### 5. Configuration Apple Sign-In (iOS uniquement)

1. Dans votre compte développeur Apple :
   - Activez **Sign in with Apple** pour votre App ID
   - Créez un Service ID
   - Configurez les domaines et redirections

2. Dans Firebase Console → Authentication → Sign-in method → Apple :
   - Activez Apple
   - Ajoutez votre Service ID

3. Dans Xcode :
   - Ouvrez `ios/Runner.xcworkspace`
   - Sélectionnez Runner → Signing & Capabilities
   - Cliquez sur "+ Capability"
   - Ajoutez **Sign in with Apple**

### 6. Mettre à jour firebase_options.dart

Après avoir configuré Firebase, exécutez :

```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

Cela mettra à jour automatiquement `lib/firebase_options.dart` avec vos vraies clés.

### 7. Configuration Android supplémentaire

Modifiez `android/build.gradle` :

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

Modifiez `android/app/build.gradle` :

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 8. Tester l'authentification

```bash
flutter run
```

Vous devriez voir :
- Page de connexion
- Boutons Google et Apple (sur iOS)
- Possibilité de créer un compte email/password

## 🔐 Sécurité

- Les mots de passe sont gérés par Firebase Authentication
- Les tokens sont automatiquement rafraîchis
- La session persiste entre les redémarrages

## 📊 Base de données

Chaque utilisateur a son propre vestiaire :
- Table `users` avec uid, email, displayName
- Table `clothing` avec foreign key vers `users.uid`
- Isolation complète des données par utilisateur

## ✅ Fonctionnalités

- ✅ Connexion Google
- ✅ Connexion Apple (iOS)
- ✅ Email/Password
- ✅ Page de profil
- ✅ Déconnexion
- ✅ Vestiaire par utilisateur
- ✅ Persistance de session
