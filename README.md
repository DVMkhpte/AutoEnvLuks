# AutoEnvLuks

Objectif : Script permettant de mettre en place, d’ouvrir et fermer un environnement sécurisé dans un fichier.

Dans un fichier
→ LUKS
→ ext4

• Permettre avec l’appel du script d’installer l’environnement

• Permettre avec l’appel du script d’ouvrir l’environnement

• Permettre avec l’appel du script de fermer l’environnement


Usage : 
```bash
sudo ./script.sh <action> [options]
```

Actions:
  
  install : Créer et initialiser l'environnement
  
  open : Ouvrir (déverrouiller + monter)
  
  close : Fermer (démonter + verrouiller)

Options:
  
  -d, --dir DIRECTORY     Répertoire de création (défaut : .)
  
  -s, --size SIZE        Taille du conteneur (ex: 500M, 5G / défaut : 5G)
  
  -p, --password PASS    Mot de passe à utiliser (défaut : azerty11)
  
  -h, --help             Afficher cette aide

Exemples :
  
  install -s 2G
  
  open
  
  close
