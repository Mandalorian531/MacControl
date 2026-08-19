# MacControl

Moniteur natif pour Mac Apple Silicon : CPU P/E, RAM, disque, réseau, températures, ventilos, batterie, processus.

Pas sur l’App Store. Le code est public, le `.dmg` est dans les [Releases](https://github.com/Mandalorian531/MacControl/releases). Tu peux l’utiliser et le modifier pour toi. Tu ne peux pas le vendre.

Testée sur un Mac mini M4. Les autres M1–M5 (Air, Pro, iMac, Studio, Mini) passent par les mêmes APIs.

## Installer

1. Télécharge `MacControl.dmg` dans la dernière release.
2. Ouvre le DMG, glisse MacControl dans Applications.
3. Au premier lancement, clic droit sur l’app → Ouvrir. Gatekeeper râle parce que le binaire n’est pas notarié (pas de compte Developer). C’est normal.

Apple Silicon, macOS 14 ou plus. Intel : non.

## Ventilateur

La lecture passe par le SMC (`FNum`, puis chaque `Fn*`). Un Pro à deux ventilos les montre. Un Air sans ventilo le dit.

Le mode manuel écrit dans le SMC et demande le mot de passe admin une fois (helper dans `/usr/local/libexec`). Remets l’auto après : un régime trop bas fait monter le SoC.

## Compiler

```bash
./scripts/build.sh
./scripts/package-dmg.sh
open dist/MacControl.app
```

Command Line Tools suffisent. Xcode n’est pas requis.

```bash
make build
make dmg
```

## Licence

[PolyForm Noncommercial 1.0.0](LICENSE). Usage perso, étude, asso, école : ok. Vendre MacControl, le mettre dans un produit payant, ou le redistribuer contre de l’argent : non.
