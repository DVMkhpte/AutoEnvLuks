#!/bin/bash

if [ "${EUID:-0}" -ne 0 ]; then
  echo "Erreur : ce script doit être lancé en root." >&2
  exit 1
fi

for cmd in figlet dd cryptsetup mkfs.ext4 mount umount; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Erreur : la commande '$cmd' n'est pas installée. Installez-la avant de continuer." >&2
    exit 1
  fi
done

# On a toujours besoin d'un help
usage() {
    cat <<EOF
Usage: $0 <action> [options]

Actions:
  install     Créer et initialiser l'environnement
  open        Ouvrir (déverrouiller + monter)
  close       Fermer (démonter + verrouiller)

Options:
  -d, --dir DIRECTORY     Répertoire de création (défaut : .)
  -s, --size SIZE        Taille du conteneur (ex: 500M, 5G / défaut : 5G)
  -p, --password PASS    Mot de passe à utiliser (défaut : azerty11)
  -h, --help             Afficher cette aide

Exemples :
  $0 install -s 2G
  $0 open
  $0 close
EOF
  exit 1
}

# Toujours balancer le help au nuloss
if [ $# -lt 1 ]; then
  usage
fi

ACTION="$1"
shift


# La taille et le password par default
SIZE="5G"
PASSWORD="azerty11"  #Bel exemple de cybersécurité
DIR="."

# On parse ici les options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--size) SIZE="$2"; shift 2 ;;
    -p|--password) PASSWORD="$2"; shift 2 ;;
    -d|--dir)  DIR="$2";  shift 2 ;;
    -h|--help) usage ;; 
    *) echo "Option inconnue : $1" >&2; usage ;;
  esac
done

install_env() {
    figlet "Install ton env stp"
    echo "Installation avec size=${SIZE}, password=${PASSWORD:-<prompt>}"
    
    read -p "Nom de votre fichier sans extention : " NAME

    if [[ "$NAME" =~ [^a-zA-Z0-9._-] ]]; then
    echo "Erreur : nom invalide." >&2; exit 1
    fi

    FILEPATH="${DIR%/}/$NAME.img"

    if [ -e "$FILEPATH" ]; then
        echo "Erreur : le fichier $FILEPATH existe déjà !" >&2
        exit 1
    fi

    MOUNTPOINT="/mnt/$NAME" # un filepath different ne veut pas forcement dire un name different

    if [ -e "$MOUNTPOINT" ]; then
        echo "Erreur : le fichier avec le nom $NAME et est deja mount !" >&2
        exit 1
    fi

    cleanup() { 
      rm -f "$FILEPATH" 
      }

    trap cleanup ERR # On pose des pieges

    mkdir -p "$(dirname "$FILEPATH")"

    dd if=/dev/zero of="$FILEPATH" bs="$SIZE" count=1  # Creation du fichier remplie de 0

    cryptsetup  -q luksFormat "$FILEPATH" --key-file <(echo -n "$PASSWORD")
    cryptsetup open "$FILEPATH" "$NAME" --key-file <(echo -n "$PASSWORD")  # On le crypt et on l'ouvre pour le mount

    mkfs.ext4 /dev/mapper/"$NAME"
    
    cryptsetup close "$NAME" # On est dans la cybersécurité donc on pense a fermer le fichier
    
    trap - ERR # Ah bah non enfaite

    echo "Install terminée"

}

open_env() {
    figlet "OPEN"
    echo "Ouverture de l'environnement (mot de passe demandé si non fourni)"

    read -p "Nom de votre fichier sans extension : " NAME
    FILEPATH="${DIR%/}/$NAME.img"

    
    if [ ! -e "$FILEPATH" ]; then
        echo "Erreur : le fichier $FILEPATH n'existe pas !" >&2
        exit 1
    fi

    if [ "$PASSWORD" = "azerty11" ]; then   # l'option -p existe mais faut quand meme faire ca pour ceux qui oublie
        read -s -p "Entrez le mot de passe (laisser vide pour conserver 'azerty11'): " input_pass
        echo
        if [ -n "$input_pass" ]; then
            PASSWORD="$input_pass"
        fi
    fi
  
    cryptsetup open "$FILEPATH" "$NAME" --key-file <(echo -n "$PASSWORD")

    MOUNTPOINT="/mnt/$NAME"  # Point de montage dynamique pour eviter les conflits

    mkdir -p "$MOUNTPOINT"
    mount /dev/mapper/"$NAME" "$MOUNTPOINT"

    if cryptsetup status "$NAME" | grep -q "is active"; then
        echo "✔ LUKS est ouvert."
    else
        echo "Échec de l’ouverture LUKS !" >&2
        exit 1
    fi

    if mountpoint -q "$MOUNTPOINT"; then
        echo "Monté sur $MOUNTPOINT."
    else
        echo "Montage non trouvée !" >&2
        exit 1
    fi
}
  

close_env() {
  figlet "CLOSE"
  echo "Fermeture…"

  read -p "Nom de votre fichier sans extension : " NAME
  FILEPATH="${DIR%/}/$NAME.img"
  MOUNTPOINT="/mnt/$NAME"

  if [ ! -e "$FILEPATH" ]; then
      echo "Erreur : le fichier $FILEPATH n'existe pas !" >&2
      exit 1
  fi

  if [ ! -e "$MOUNTPOINT" ]; then
      echo "Erreur : $MOUNTPOINT n'existe pas !" >&2
      exit 1
  fi

  umount "$MOUNTPOINT" || { echo "Erreur démontage !" >&2; exit 1; }
  cryptsetup close "$NAME"   || { echo "Erreur verrouillage !" >&2; exit 1; }

  rmdir "$MOUNTPOINT"

  echo "Environnement fermé."
  
}

case "$ACTION" in
    install) install_env ;; 
    open) open_env ;;
    close) close_env ;; 
    *) echo "Action inconnue : $ACTION" usage ;;
esac