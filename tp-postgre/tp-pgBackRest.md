---
tags: ["TP"]
aliases: ["TP2", "TP2 sur la restauration de données"]
---

# La restauration de données avec l'outil pgBackRest dans PostgreSQL
---

> Eldar Kasmamytov p1712650
> (Je suis en monôme)

## I. Installation
---

On commence par l'installation de **PostgreSQL** sur les 2 VMs. Nous allons l'installer depuis les repos apt officiels:  

```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'  
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -  
sudo apt-get update  
sudo apt-get -y install postgresql
```

L'outil **pgBackRest** est également [contenu](https://www.postgresql.org/download/products/1-administrationdevelopment-tools/) dans ces repos officiels, on peut donc l'installer avec:  

```bash
sudo apt install -y pgbackrest
```
<br/>

## II. Des données
---

D'après [la documentation officielle](https://www.postgresql.org/docs/15/pgbench.html) de **pgBench**, afin de pouvoir effectuer des tests, pgBench nécéssite une base de données déjà créée et quelques tables. On va, donc, les créer et les "peupler".

### 2.1 Création de BD et Initialisation des tables

- Tout d'abord il nous faut une base de données, qui va stocker ces tables et que l'on appelera `benchdb` :  
  - Se connecter en tant que l'utilisateur postgres :  
    ```bash
    sudo su postgres
    ```
  - Créer la base de données :  
    ```sql
    CREATE DATABASE benchdb;
    ```
    > On peut vérifier si la base de données à été bien créée avec `\l`

- Maintenant on va pouvoir utiliser l'outil `pgbench` pour créer et initialiser les tables avec un **scale factor de 10** (à executer dans le shell du système) :  
  ```bash
  pgbench -i -s 10 benchdb
  ```

### 2.2 Comptage des lignes

On se connecte à nouveau avec `psql` et après avoir executé les requêtes SQL ci-dessous pour les tables `pgbench_tellers` et `pgbench_accounts` respectivement :  

```sql
SELECT COUNT(*) FROM pgbench_tellers;
SELECT COUNT(*) FROM pgbench_accounts;
```

On obtient le nombre de lignes créées dans les tables :  
- `pgbench_tellers` = **100**
- `pgbench_accounts` = **1 000 000**
<br/>

## III. Restauration
---

### 3.1 Effectuez une sauvegarde full.
---

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une sauvegarde full ?
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> D'après la [documentation officielle](https://pgbackrest.org/user-guide.html#concept/backup) de **pgBackRest**, c'est une sauvegarde de la base de données entière. Elle ne dépend pas d'autres fichiers et il est donc toujours possible de la restaurer. La première sauvegarde de la BDD est toujours une sauvegarde full, afin de pouvoir effectuer des sauvegardes différentielles ou incrémentales plus tard.  

La [documentation officielle](https://pgbackrest.org/user-guide.html#quickstart) de **pgBackRest** contient une section "Quickstart", qui montre comment effectuer un Full Backup.

#### 3.1.1 Configuration

Tout d'abord, il faut s'assurer que pgBackRest connait où se situe le répertoire de données de PostgreSQL (le dossier de base des clusters), car en situation de restauration d'un cluster le processus PostgreSQL ne sera pas accessible pour que l'on puisse lui demander le chemin directement.  

Configurer le fichier `/etc/pgbackrest.conf`, en ajoutant les lignes suivantes :  
```conf
[main]
pg1-path=/var/lib/postgresql/15/main
```

> ❕**Remarque:** Le cluster PostgreSQL par défaut est appelé `main`, cependant la documentation de pgBackRest dit que c'est pas le meilleur nom pour une configuration Stanza, et que le nom plus approprié serait un nom qui décrit la fonction du cluster. Néanmoins, pour ce TP on va garder le nom par défaut (càd `main`).

#### 3.1.2 Créer un Repository

> ❕**Remarque:** Le repository peut déjà être présent par défaut.

Executer les commandes suivantes afin de créer un repository :  
```bash
sudo mkdir -p /var/lib/pgbackrest # créer le dossier
sudo chmod 750 /var/lib/pgbackrest # changer les droits: rwx r-x ---
sudo chown postgres:postgres /var/lib/pgbackrest # changer le propriétaire et le groupe
```

Compléter la configuration de pgBackRest, en ajoutant les lignes suivantes :  
```conf
[global]
repo1-path=/var/lib/pgbackrest
```

#### 3.1.3 Configurer l'archivage WAL

1) Ouvrir (par exemple, avec `nano` ou `vim`) le fichier de configuration `/etc/postgresql/[VERSION]/[CLUSTER]/postgresql.conf`.  
Ici, le chemin est `/etc/postgresql/15/main/postgresql.conf`.  

On va modifier quelques paramètres dans les 2 sections du fichier :  

> ❕**Astuce:** Si vous utilisez `nano`, vous pouvez utiliser le hotkey <kbd>Ctrl</kbd> + <kbd>W</kbd> pour se vite déplacer dans le fichier.  

- WRITE-AHEAD LOG :
  - Settings :  
    - `wal_level = replica` (Valeur par défaut) : Indique quelles données sont écrites dans les WAL. `replica` permet d'écrire suffisamment de données pour l'archivage et la réplication. 
  - Archiving :
    - `archive_mode = on` : Activer la sauvegarde des WAL générés par PostgreSQL.
    - `archive_command = 'pgbackrest --stanza=main archive-push %p'` : La commande à executer pour archiver un segment du fichier WAL.
- REPLICATION :
  - Sending Servers :
    - `max_wal_senders = 10` : Le nombre maximum des processus WAL Sender simultanés.

2) Redémarrer le cluster pour appliquer les changements :  
```bash
sudo pg_ctlcluster 15 main restart
```

3) Configurer la commande `archive-push`, en ajoutant une option dans le fichier de configuration de pgBackRest (`/etc/pgbackrest.conf`) :  
```conf
[global:archive-push]
compress-level=3
```
Cela permettra d'augmenter la vitesse d'archivage sans affecter la compréssion utilisée pour les backups.

#### 3.1.4 Créer la Stanza

Maintenant, quand on a configuré la stanza pgBackRest, on peut l'initialiser :  

```bash
sudo -u postgres pgbackrest --stanza=main --log-level-console=info stanza-create
```

Si tout se passe bien, vous verrez un message de succès comme ceci :   

```log HL:"3"
2023-03-05 12:56:32.922 P00   INFO: stanza-create command begin 2.44: --exec-id=79250-859c74ff --log-level-console=info --pg1-path=/var/lib/postgresql/15/main --repo1-path=/var/lib/pgbackrest --stanza=main
2023-03-05 12:56:34.160 P00   INFO: stanza-create for stanza 'main' on repo1
2023-03-05 12:56:34.225 P00   INFO: stanza-create command end: completed successfully (1341ms)
```

#### 3.1.5 Vérifier la configuration

```bash
sudo -u postgres pgbackrest --stanza=main --log-level-console=info check
```

```log HL:"5"
2023-03-05 13:14:36.221 P00   INFO: check command begin 2.44: --exec-id=79737-bae9a741 --log-level-console=info --pg1-path=/var/lib/postgresql/15/main --repo1-path=/var/lib/pgbackrest --stanza=main
2023-03-05 13:14:36.873 P00   INFO: check repo1 configuration (primary)
2023-03-05 13:14:37.477 P00   INFO: check repo1 archive for WAL (primary)
2023-03-05 13:14:37.579 P00   INFO: WAL segment 00000001000000000000000A successfully archived to '/var/lib/pgbackrest/archive/main/15-1/0000000100000000/00000001000000000000000A-b79ff754bb69503411c7b768cd8822101cc870c9.gz' on repo1
2023-03-05 13:14:37.580 P00   INFO: check command end: completed successfully (1380ms)
```

#### 3.1.6 Effectuer un Full Backup

On va pouvoir finallement effectuer une sauvegarde complète (Full Backup) de notre cluster PostgreSQL :  
```bash
sudo -u postgres \
pgbackrest --stanza=main --type=full --log-level-console=info backup
```

Si tout se passe bien, vous devez voir un message de succès à la fin :  
```log HL:"3-5"
2023-03-05 13:18:42.860 P00   INFO: backup command begin 2.44: --exec-id=79762-45ee467d --log-level-console=info --pg1-path=/var/lib/postgresql/15/main --repo1-path=/var/lib/pgbackrest --stanza=main --type=full
...
2023-03-05 13:19:15.442 P00   INFO: backup command end: completed successfully (32585ms)
...
2023-03-05 13:19:15.480 P00   INFO: expire command end: completed successfully (37ms)
```

#### 3.1.7 Vérifier le Backup

Ensuite, on peut vérifier en afficher l'information sur les sauvegardes :  
```bash
sudo -u postgres pgbackrest info
```

```log HL:"8"
stanza: main
    status: ok
    cipher: none

    db (current)
        wal archive min/max (15): 000000010000000000000009/00000001000000000000000C

        full backup: 20230305-131843F
            timestamp start/stop: 2023-03-05 13:18:43 / 2023-03-05 13:19:15
            wal start/stop: 00000001000000000000000C / 00000001000000000000000C
            database size: 178.9MB, database backup size: 178.9MB
            repo1: backup set size: 11.9MB, backup size: 11.9MB
```
<br/>

### 3.2 Supprimez la totalité des lignes de la table `pgbench_tellers`.
---

Se connecter à la base de données `benchdb` en tant que l'utilisateur `postgres` :  
```bash
sudo su postgres
psql benchdb
```

Puis, supprimer tous les données de la table :  
```sql
DELETE FROM pgbench_tellers;
```

Enfin, vérifier que les données ont été bien supprimées et la table est désormais vide :  
```sql
SELECT COUNT(*) FROM pgbench_tellers;
```
Cette requête doit retourner Count = 0.
<br/>

### 3.3 Effectuez une sauvegarde incrémentale.
---

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une sauvegarde incrémentale ?
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> C'est une sauvegarde partielle, qui ne copie que les données qui ont été modifiées depuis la dérnière sauvegarde (qui peut être une autre sauvegarde incrémentale, différentielle ou complète). Par conséquent, elle dépend des sauvegardes précédentes, qui doivent être valides pour garantir une bonne restauration depuis une sauvegarde incrémentale.  

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quelle est la différence entre une sauvegarde incrémentale et une sauvegarde différentielle ?
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> Une sauvegarde différentielle ne dépend que de la dérnière sauvegarde complète, tandis que l'incrémentale nécéssite que **toutes** les sauvegardes précédentes soient valides. En général, une sauvegarde différentielle pèse plus qu'une sauvegarde incrémentale.  

Pour effectuer une sauvegarde incrémentale, on pourra réutiliser la commande précédente en changeant l'option `type` à `incr` :  
```bash
sudo -u postgres \
pgbackrest --stanza=main --type=incr --log-level-console=info backup
```

Comme pour la sauvegarde complète que l'on a faite, vous verrez un message de succès si tout se passe comme il faut.  

De plus, en affichant les informations des backups, on voit que notre sauvegarde incrémentale est apparue en-dessus de la complète.

```bash
sudo -u postgres pgbackrest info
```

```log
full backup: 20230305-131843F
...
incr backup: 20230305-131843F_20230305-134430I
    timestamp start/stop: 2023-03-05 13:44:30 / 2023-03-05 13:44:33
    wal start/stop: 00000001000000000000000E / 00000001000000000000000E
    database size: 178.8MB, database backup size: 160.3KB
    repo1: backup set size: 11.9MB, backup size: 14.6KB
    backup reference list: 20230305-131843F
```
<br/>

### 3.4 Supprimez les lignes de `pgbench_accounts` pour lesquelles la colonne `bid` vaut 2.
---

Se connecter à la base de données `benchdb` en tant que l'utilisateur `postgres` :  
```bash
sudo su postgres
psql benchdb
```

Avant de supprimer les lignes, on peut vérifier combien on en a actuellement :  
```sql
SELECT COUNT(*) FROM pgbench_accounts WHERE bid=2;
```
Ce qui nous retourne **Count = 100 000**

Ensuite, dans la table `pgbench_accounts`, supprimer les lignes en question :  
```sql
DELETE FROM pgbench_accounts WHERE bid=2;
```

En vérifiant à nouveau le nombre de lignes où `bid` vaut `2`, on obtient bien **Count = 0**. 
<br/>

### 3.5 Vérifiez le nombre de lignes dans la table `pgbench_accounts`
---

```sql
SELECT COUNT(*) FROM pgbench_accounts;
```

Logiquement, la commande ci-dessus doit nous retourner **Count = 900 000**, car au total on en avait **1 000 000**, moins les **100 000** que l'on vient de supprimer. Ce qui est bien le cas.
<br/>

### 3.6 Restaurez la base dans l’état dans lequel elle était avant l’étape 4.
---

**But:** On souhaite restaurer la base dans l'était de la dernière sauvegarde incrémentale.  
On peut l'atteindre de façons différentes.  

Nous allons commencer par :  
- La plus simple, la restauration par défaut,  
- Ensuite, nous allons voir une autre manière de le faire en précisant une sauvegarde exacte,  
- Et enfin, nous terminerons par une restauration PITR.

#### 3.6.1 Default Recovery - Le comportement par défaut de la commande `restore`

D'après la [section "Restore"](https://pgbackrest.org/user-guide.html#restore) de la documentation officielle de **pgBackRest**, la commande `restore`, par défaut, essaye de restaurer la dernière sauvegarde dans le premier Repository trouvé. Cela correspond bien à notre cas, car :  
- L'état dans lequel la base était avant l'étape 4 est la dernière sauvegarde de la base (la sauvegarde incrémentale) ; 
- Et nous avons un seul Repository `pgbackrest`.
Par conséquent, il est possible de se contenter par le comportement par défaut.

1) Arrêter le cluster PostgreSQL :  
```bash
sudo pg_ctlcluster 15 main stop
```

2) Supprimer tous les anciens fichiers dans le répértoire de données :  
```bash
sudo -u postgres find /var/lib/postgresql/15/main -mindepth 1 -delete
```

> ❕**Remarque:** Cet étape peut être facultatif, si on ajoutera l'option `--delta` dans la commande `restore`. Elle permet de détérminer quels fichiers peuvent être gardés et lesquels doivent être réstaurés.  
> Cf. [la documentation officielle de pgBackRest](https://pgbackrest.org/user-guide.html#restore/option-delta)

3) Restaurer la base dans l'était de la dernière sauvegarde, en utilisant les valeurs par défaut :  
```bash
sudo -u postgres pgbackrest --stanza=main restore
sudo pg_ctlcluster 15 main start # à nouveau démarrer le cluster PostgreSQL
```

#### 3.6.2 Utiliser une sauvegarde précise (avec l'option `--set`)

On peut restaurer une sauvegarde précise en utilisant son `id` (affiché à côté de son nom dans le résultat de la commande `info`) comme valeur pour l'option `--set`.  

1) Ainsi, pour restaurer notre sauvegarde incrémentale, on doit récupérer son `id` :  
```bash
sudo -u postgres pgbackrest info
```

```log
...
incr backup: 20230305-131843F_20230305-134430I
...
```

Ce qui nous intérèsse c'est `20230305-131843F_20230305-134430I`.  

2) D'abord, arrêter le cluster PostgreSQL :  
```bash
sudo pg_ctlcluster 15 main stop
```

3) Effectuer la restauration de la base :  
```bash
sudo -u postgres \
pgbackrest --stanza=main \
--set 20230305-131843F_20230305-134430I --delta \
--db-include=benchdb --type=immediate restore
```

4) Démarrer le cluster PostgreSQL :  
```bash
sudo pg_ctlcluster 15 main start
```

#### 3.6.3 Point-In-Time-Recovery

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Que signifie PITR ?
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> **P**oint **I**n **T**ime **R**ecovery, ou PITR, est un mécanisme permettant de restaurer un état de la base dans lequel elle était à un moment précis dans le temps, par exemple avec un Timestamp.  

1) On récupère le Timestamp désiré, càd celui de notre sauvegarde incrémentale :  
```bash
sudo -u postgres pgbackrest info
```

Ce qui nous intérèsse c'est `2023-03-05 13:44:33`.  

2) On ajoute notre Timezone :  
```sql
SELECT '2023-03-05 13:44:33'::timestamp AT TIME ZONE 'Europe/Paris';
```

Ce qui nous retourne **Timezone = 2023-03-05 13:44:33+01**, que l'on pourra ensuite utiliser pour restaurer les données :  

3) Restaurer :  
```bash
sudo -u postgres \
pgbackrest --stanza=main --delta \
  --type=time "--target=2023-03-05 13:44:33+01" \
  --target-action=promote restore
```

4) Démarrer le cluster PostgreSQL :  
```bash
sudo pg_ctlcluster 15 main start
```
<br/>

### 3.7 Vérifiez le nombre de lignes dans la table `pgbench_accounts`.
---

Se connecter à la base de données `benchdb` en tant que l'utilisateur `postgres` :  
```bash
sudo su postgres
psql benchdb
```

Vérifier le nombre de lignes dans la table où `bid` vaut `2` :  
```sql
SELECT COUNT(*) FROM pgbench_accounts WHERE bid=2;
```

Ce qui nous retourne **Count = 100 000**.
<br/>

### 3.8 Restaurez la base dans l’état dans lequel elle était avant l’étape 2.
---

**But:** On veut restaurer la sauvegarde complète (Full Backup).  

Nous allons utiliser la restauration d'une sauvegarde précise.

1) Récupérer l'`id` de la sauvegarde complète (Full Backup) :  
```bash
sudo -u postgres pgbackrest info
```

```log
...
full backup: 20230305-131843F
...
```

Ce qui nous intérèsse c'est `20230305-131843F`.  

2) Puis, arrêter le cluster PostgreSQL :  
```bash
sudo pg_ctlcluster 15 main stop
```

3) Ensuite, effectuer la restauration de la base :  
```bash
sudo -u postgres \
pgbackrest --stanza=main \
--set 20230305-131843F --delta \
--db-include=benchdb --type=immediate restore
```

4) Démarrer le cluster PostgreSQL :  
```bash
sudo pg_ctlcluster 15 main start
```

<br/>

### 3.9 Vérifiez le nombre de lignes dans les tables `pgbench_tellers` et `pgbench_accounts`.
---

Se connecter à la base de données `benchdb` en tant que l'utilisateur `postgres` :  
```bash
sudo su postgres
psql benchdb
```

Vérifier le nombre de lignes :  
```sql
SELECT COUNT(*) FROM pgbench_tellers; -- retourne Count = 100
SELECT COUNT(*) FROM pgbench_accounts; -- retourne Count = 1 000 000
```

<br/>
<br/>

## IV. Retrouver une erreur dans des WALs
---

