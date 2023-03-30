---
tags: ["TP"]
aliases: ["TP1", "TP1 sur Déploiement Continu"]
---

Utilisation du Vault
---

- **Q**: Quels sont les **engines** que vous voyez ?  
- **R**:  
  - **cubbyhole**  
  - **kv**  
  - **ssh**  

- **Q**: Quel est le **path** du moteur **kv** ? Quelle version le moteur **kv** utilise ?  
- **R**: Path: `kv/` , Version: 2

- **Q**: Quelle métadonnée votre token possède ? Le token est valide combien de jours ?  
- **R**: 
  - **token_duration** vaut **768h**, donc le token est valide 768h / 24 = **32 jours**  

- **Q**: Quel préfixe j'ai ajouté à vos noms de groupes pour que vous puissiez écrire dans le moteur ssh et kv ?  
- **R**: Le préfixe ajouté est `asbd` suivi d'un tiret et le nom du groupe.  

- **Q 2.5 & 2.6**
  Les commandes: [CLI Reference - KV](https://developer.hashicorp.com/vault/docs/commands/kv)  
  
  - Pour **créer** un secret "**init**" dans le dossier "**kv/data/asbd-edgerunner**":  
  ```bash
  vault kv put kv/asbd-edgerunner/init unedonnee=mavaleursecrete
  ```
>   Remarque: dans la commande "**data**" est omis dans la v2 de Vault

  - Pour **lire** le secret:
  ```bash
  vault kv get kv/asbd-edgerunner/init
  ```

- **Q 3.2**
```bash
./vault write ssh/roles/asbd-edgerunner \
  key_type=otp \
  default_user=ubuntu \
  cidr_list=192.168.167.0/24,192.168.76.68/32
```

- **Q 3.3**
  La commande suivante affiche une erreur, car l'ip n'est pas dans le role.
  ```bash
  ./vault write ssh/creds/asbd-edgerunner ip=0.0.0.0
  ```

```bash
./vault write ssh/creds/asbd-edgerunner ip=192.168.76.68
```

```log
Key                Value
---                -----
lease_id           ssh/creds/asbd-edgerunner/111AW7dsmHTUaiY0fIJAP1Qt
lease_duration     768h
lease_renewable    false
ip                 192.168.76.68
key                cf6c950a-eaaa-4b08-e16f-219e9902b77e
key_type           otp
port               22
username           ubuntu
```