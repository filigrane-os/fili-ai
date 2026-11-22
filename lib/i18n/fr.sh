# shellcheck shell=sh
# French catalog of the fili-ai launcher (bin/fili-ai): translates its English messages (see lib/i18n.sh). Same format as the
# one of the Filigrane scripts; a missing entry falls back to English.
_t_lookup() {
    case $1 in
    'WARNING') _t_fmt='AVERTISSEMENT' ;;
    'Local models (Codex CLI + Ollama, heavy)') _t_fmt='Modèles locaux (Codex CLI + Ollama, lourd)' ;;
    'No agent') _t_fmt='Aucun agent' ;;
    '%s %s already installed') _t_fmt='%s %s déjà installé' ;;
    'Downloading %s %s') _t_fmt='Téléchargement de %s %s' ;;
    'Download of %s failed') _t_fmt='téléchargement de %s échoué' ;;
    '%s missing from the %s archive') _t_fmt='%s absent de l'\''archive de %s' ;;
    'Codex: unsupported architecture %s') _t_fmt='Codex: architecture %s non prise en charge' ;;
    'opencode: unsupported architecture %s') _t_fmt='opencode: architecture %s non prise en charge' ;;
    'Ollama: unsupported architecture %s') _t_fmt='Ollama: architecture %s non prise en charge' ;;
    'Cannot find the latest %s version (network?)') _t_fmt='version de %s introuvable (réseau ?)' ;;
    'bubblewrap missing: sudo xbps-install bubblewrap') _t_fmt='bubblewrap absent: sudo xbps-install bubblewrap' ;;
    'Resource warning: Ollama downloads ~1.5 GB (~300 MB kept), then each model takes') _t_fmt='Avertissement ressources: Ollama télécharge ~1,5 Go (~300 Mo gardés), puis chaque modèle pèse' ;;
    'several GB of disk and RAM (gpt-oss:20b ~16 GB). It only runs while fili-ai does.') _t_fmt='plusieurs Go en disque et en RAM (gpt-oss:20b ~16 Go). Il ne tourne que pendant fili-ai.' ;;
    'Installing Claude Code failed (network?)') _t_fmt='installation de Claude Code échouée (réseau ?)' ;;
    'Claude Code already installed') _t_fmt='Claude Code déjà installé' ;;
    'Unknown agent: %s (%s)') _t_fmt='agent inconnu: %s (%s)' ;;
    'Agent: %s (%s)') _t_fmt='Agent: %s (%s)' ;;
    'Note: users/%s/config.env sets FILI_AI; change it too so ./bootstrap.sh keeps this choice.') _t_fmt='Note: users/%s/config.env fixe FILI_AI; le modifier aussi pour que ./bootstrap.sh garde ce choix.' ;;
    'Passwordless sudo for sv and xbps: run ./bootstrap.sh --system-only in %s') _t_fmt='sudo sans mot de passe pour sv et xbps: lancer ./bootstrap.sh --system-only dans %s' ;;
    'Passwordless sudo for sv and xbps is still active: ./bootstrap.sh --system-only removes it') _t_fmt='sudo sans mot de passe encore actif pour sv et xbps: ./bootstrap.sh --system-only le retire' ;;
    'AI agent:') _t_fmt='Agent IA:' ;;
    'Number [1]: ') _t_fmt='Numéro [1]: ' ;;
    'Invalid choice') _t_fmt='choix invalide' ;;
    'Ollama does not start (see %s/ollama.log)') _t_fmt='Ollama ne démarre pas (voir %s/ollama.log)' ;;
    'No AI agent chosen: fili-ai use <agent> (%s)') _t_fmt='aucun agent IA choisi: fili-ai use <agent> (%s)' ;;
    '%s stopped (code %s). Press Enter to close ') _t_fmt='%s s'\''est arrêté (code %s). Entrée pour fermer ' ;;
    'Model: %s') _t_fmt='Modèle: %s' ;;
    'default') _t_fmt='défaut' ;;
    'Working directory: %s') _t_fmt='Dossier de travail: %s' ;;
    'Filigrane repository: %s') _t_fmt='Dépôt Filigrane: %s' ;;
    'Options: %s') _t_fmt='Options: %s' ;;
    'Installed:') _t_fmt='Installés:' ;;
    'usage: fili-ai install <agent>') _t_fmt='usage: fili-ai install <agent>' ;;
    esac
}
