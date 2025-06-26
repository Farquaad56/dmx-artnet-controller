# DMX ArtNet Controller

Logiciel de contrôle DMX ArtNet pour projecteurs de lumière développé avec Flutter.

## 📋 Description

Application mobile Android pour contrôler 2 projecteurs de lumière DMX identiques via le protocole ArtNet. Compatible avec le boîtier Eurolite ARTNET/DMX freeDMX AP.

## ✨ Fonctionnalités

### Contrôles Master
- **Blanc Froid** : 25%, 50%, 75%, 100%
- **Blanc Chaud** : 25%, 50%, 75%, 100%
- **ALL OFF** : Extinction complète des projecteurs

### Contrôles Avancés
- Contrôle individuel de chaque canal (1-5) pour les 2 projecteurs
- Sliders pour ajustement précis des valeurs DMX (0-255)

### Fonctionnalités Techniques
- **Connexion ArtNet** : Communication UDP avec test de connexion automatique
- **Configuration flexible** : Modification de l'IP et du port UDP
- **Mode Debug** : Logs de communication pour diagnostic
- **Gestion des permissions** : Compatible Android 10+

## 🔧 Configuration DMX

### Projecteurs (Mode 5 canaux)
| Canal | Fonction | Valeurs |
|-------|----------|---------|
| 1 | Intensité blanc froid | 0-255 (0% à 100%) |
| 2 | Intensité blanc chaud | 0-255 (0% à 100%) |
| 3 | Effet strobe | 0-15: Désactivé, 16-255: 24 vitesses |
| 4 | Programmes prédéfinis | 0-15: Désactivé, 16-255: 31 programmes |
| 5 | Dimmer général | 0-255 (0% à 100%) |

### Architecture DMX
- **Projecteur 1** : Canaux DMX 1-5 (indices 0-4)
- **Projecteur 2** : Canaux DMX 6-10 (indices 5-9)
- **Universe 0** : Les deux projecteurs dans le même univers ArtNet

### Configuration Réseau par défaut
- **IP** : 192.168.4.1
- **Port UDP** : 6454
- **Protocole** : ArtNet

## 🛠️ Installation et Développement

### Prérequis
- Flutter 3.32.4 ou supérieur
- Android SDK (API minimum 33)
- Kotlin DSL

### Dépendances
```yaml
dependencies:
  flutter:
    sdk: flutter
  permission_handler: ^11.3.1
  shared_preferences: ^2.2.3
```

### Installation
1. Cloner le repository
```bash
git clone https://github.com/votre-username/dmx-artnet-controller.git
cd dmx-artnet-controller
```

2. Installer les dépendances
```bash
flutter pub get
```

3. Compiler et installer sur Android
```bash
flutter run
```

## 📱 Utilisation

1. **Connexion** : Appuyer sur "Connecter" pour établir la connexion ArtNet
2. **Contrôles Master** : Utiliser les boutons prédéfinis pour un contrôle rapide
3. **Contrôles Avancés** : Ajuster individuellement chaque canal avec les sliders
4. **Configuration** : Modifier l'IP et le port via le bouton paramètres
5. **Debug** : Activer le mode debug pour voir les logs de communication

## 🔒 Permissions Android

L'application nécessite les permissions suivantes :
- `INTERNET` : Communication réseau
- `ACCESS_NETWORK_STATE` : État du réseau
- `ACCESS_WIFI_STATE` : État WiFi
- `CHANGE_WIFI_STATE` : Modification WiFi
- `ACCESS_FINE_LOCATION` : Localisation (Android 10+)
- `ACCESS_COARSE_LOCATION` : Localisation approximative (Android 10+)

## 🎯 Compatibilité

- **Android** : API 33+ (Android 13+)
- **Flutter** : 3.32.4+
- **Protocole** : ArtNet standard
- **Boîtier testé** : Eurolite ARTNET/DMX freeDMX AP

## 🐛 Dépannage

### Problèmes de connexion
1. Vérifier que l'IP et le port sont corrects
2. S'assurer que le smartphone est sur le même réseau WiFi
3. Activer le mode debug pour voir les logs de communication
4. Vérifier que le boîtier ArtNet est allumé et connecté

### Permissions refusées
1. Aller dans Paramètres > Applications > DMX ArtNet Controller
2. Activer toutes les permissions demandées
3. Redémarrer l'application

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 🤝 Contribution

Les contributions sont les bienvenues ! N'hésitez pas à :
1. Fork le projet
2. Créer une branche pour votre fonctionnalité
3. Commit vos changements
4. Push vers la branche
5. Ouvrir une Pull Request

## 📧 Contact

Pour toute question ou suggestion, n'hésitez pas à ouvrir une issue sur GitHub.

---

**Développé avec ❤️ en Flutter**