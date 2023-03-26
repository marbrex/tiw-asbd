---
tags: ["TP"]
aliases: ["TP3", "TP3 sur la réplication physique"]
---

# La réplication physique d'un cluster Postgres
---

> Eldar Kasmamytov p1712650
> (Je suis en monôme)

<br/>

## I. La réplication
---

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une réplication en WAL shipping ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> C'est une solution au problème de la réplication qui consiste à surveiller le serveur principale pour tout changement dans la base de données au travers les WALs. Elle nécéssite une architecture multi-nœuds dans laquelle chaque nœud est attribué d'un rôle :  
>  
> - Un seul nœud **Queen** (appelé également *read-write*, *master* ou *primary*)  
>   C'est le seul nœud pouvant accepter des requêtes en lécture **et** en écriture (*read-write*). Les transactions sont ensuite **répliquées** sur d'autres nœuds en leur fournissant les fichiers **WAL** de la Queen, d'où le nom de ce méchanisme "WAL *Shipping*".  
>   <br/>
>     - Ces nœuds recevant les WAL de la Queen (et ainsi répliquant les transactions) sont appelés **Princess** (ou aussi *standby*, *secondary*). En cas de panne de la Queen, une des Princess prend le relais et devient une nouvelle Queen.  

Il existe différentes approches pour la réplication, notamment *File-Based* et *Streaming*. Dans la suite, nous mettrons en place une réplication *Streaming*.  

- **Les buts de cette partie :**  
  - Mettre en place une réplication streaming  
  - Modifier la réplication pour qu’elle devienne synchrone  

### 1.1 Réplication en mode "Streaming"

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une réplication en mode “streaming” ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> C'est une technique de réplication permettant au serveur primaire (ou **Queen**) de diffuser/stream en direct les entrées de WAL aux serveurs secondaires (ou **Princess**) au moment quand elles sont générées, sans attendre que le fichier WAL (un segment de 16MB) soit rempli en entier.  
> [Lien vers la documentation officielle](https://www.postgresql.org/docs/15/warm-standby.html#STREAMING-REPLICATION)  

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quelle est la différence entre une réplication logique et une réplication physique ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> La réplication logique fonctionne en modèle qui peut être décrit comme *Publish / Subscribe*. Elle réplique les modifications des **objets** de base de données (tels que les tables) effectuées sur un serveur primaire (*Publisher*) vers un ou plusieurs serveurs qui lui sont abonnés (*Subscribers*). Les données répliquées peuvent être sélectionnées et même eventuellement traitées/transformées avant l'envoi. Cela permet une flexibilité et un plus petit volume de données transmis comparé à la réplication physique. La réplication logique permet également de répliquer les données sur une différente plateforme et/ou version de PostgreSQL, ce qui n'est pas possible avec la réplication physique.  
> 
> Tandis que la réplication physique réplique tous les **fichiers physiques** qui constituent un cluster PostgreSQL, y compris les fichiers WAL. La mise en place et le fonctionnement de la réplication physique est plus simple comparé à celle de la réplication logique. Elle est aussi plus performante, car fonctionne au niveau des blocks.  

#### 1.1.1 Mise en place de la réplication en mode Streaming

Nous allons mettre en place une réplication avec une seule Princess.  
Cf. [La documentation officielle sur la réplication en WAL Shipping de Postgres](https://www.postgresql.org/docs/15/warm-standby.html)

##### Configurer l'authentification

- Sur la **Queen**, créer un rôle dédié pour la réplication avec les privilèges "`REPLICATION`" et "`LOGIN`" :  

  > [`CREATE USER`](https://www.postgresql.org/docs/current/role-attributes.html) est équivalent à `CREATE ROLE` sauf qu'il inclut le privilège "`LOGIN`" par défaut.  

  ```bash
  sudo su postgres
  psql -c "create user replicator password 'jw8s0F4' replication;"
  ```

  Vous verrez un message de succès comme ceci si tout se passe bien :  

  ```log
  CREATE ROLE
  ```

- Toujours sur la **Queen**, ajouter une entrée dans le fichier `pg_hba.conf` afin de permettre à la Princess de se connecter en tant qu'utilisateur `replicator` à la *pseudo* base de donées `replication` :  

  ```bash
  sudo -u postgres sh -c 'echo \
    "host    replication     replicator      192.168.75.231/32           md5" \
    >> /etc/postgresql/15/main/pg_hba.conf'
  ```

  Il est également nécéssaire d'ajouter l'adresse IP de la Princess dans le paramètre [`listen_addresses`](https://www.postgresql.org/docs/15/runtime-config-connection.html#GUC-LISTEN-ADDRESSES) de la Queen (par défaut, la valeur est `localhost`). Dans ce TP, nous autoriserons toutes les connexions, càd `*`. Modifier la configuration `postgresql.conf` :  

  - Connections and Authentication :  
    - Connection Settings :  
      - `listen_addresses = '*'`

  Redémarrer le cluster Postgres pour que les changements soient pris en compte :  
  ```bash
  sudo pg_ctlcluster 15 main reload
  ```

- Sur la **Princess**, nous allons modifier le paramètre [`primary_conninfo`](https://www.postgresql.org/docs/15/runtime-config-replication.html#GUC-PRIMARY-CONNINFO) dans la configuration `postgresql.conf` :  

  - REPLICATION :  
    - Standby Servers :  
      - `primary_conninfo = 'host=192.168.75.149 port=5432 user=replicator'`

  Le mot de passe de `replicator` sera mis dans le fichier `~/.pgpass` :  

  ```bash
  echo "192.168.75.149:*:replication:replicator:jw8s0F4" >> ~/.pgpass
  chmod 600 ~/.pgpass
  ```

##### Mettre en place un repository partagé

Avant de commencer la réplication, il nous faut récupérer une des sauvegardes du serveur primaire (Queen) sur le secondaire (Princess).  Pour cela, nous allons mettre en place un répertoire de sauvegardes partagé, qui sera accéssible depuis le secondaire à travers une connexion NFS.  

Installer `nfs` sur les 2 machines. Pour faire simple, on installera le client et le serveur :  
```bash
sudo apt update
sudo apt install nfs-kernel-server
```

- Sur le serveur primaire (Queen) :  

  Ajouter une ligne au fichier `/etc/exports` :  
  ```bash
  sudo sh -c 'echo "/var/lib/pgbackrest    192.168.75.231(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports'
  ```

  Exporter :  
  ```bash
  sudo exportfs -a
  ```

  Redémarrer le service `nfs` :  
  ```bash
  sudo systemctl restart nfs-kernel-server
  ```

- Sur le serveur secondaire (Princess) :  

  Créer un dossier dans lequel on va mettre nos backups :  
  ```bash
  sudo mkdir -p /mnt/nfs/pgbackrest
  ```

  Monter le dossier distant avec les paramètres nécéssaires :  
  ```bash
  sudo mount -o rw,hard,intr,noatime,nolock,nocto 192.168.75.149:/var/lib/pgbackrest /mnt/nfs/pgbackrest
  ```

##### Configurer et lancer `pgBackRest` sur le serveur secondaire

>❕**Remarque:** Il est également possible de faire un *base backup* avec l'outil [`pg_basebackup`](https://www.postgresql.org/docs/15/continuous-archiving.html#BACKUP-BASE-BACKUP)  

Changer le chemin vers le répertoire de sauvegardes :  
```conf
[global]
repo1-path=/mnt/nfs/pgbackrest
```

Vérifier que les sauvegardes sont bien visibles par `pgBackRest` :  
```bash
sudo -iu postgres pgbackrest --stanza=main info
```

Lancer une restauration des backups :  
```bash
sudo pg_ctlcluster 15 main stop
sudo -u postgres pgbackrest --stanza=main --delta --type=standby restore
```

##### Démarrer le serveur secondaire en mode `standby`

Il est maintenant possible de créer la réplication sur la **Princess**. Pour ce faire, comme indiqué sur [la page officielle](https://www.postgresql.org/docs/15/warm-standby.html#STANDBY-SERVER-OPERATION), nous allons créer un fichier vide "`standby.signal`" dans le répertoire de données du cluster Postgres (ici, "`/var/lib/postgresql/15/main/`"), qui servira de *signal* à Postgres lors de son démarrage pour activer le mode "`standby`" (la réplication en Streaming).  

> Ce fichier est créé automatiquement si l'option `--type=standby` a été spécifiée dans la commande `restore` de `pgBackRest` !  

Sur la Princess :  

```bash
sudo su postgres
touch /var/lib/postgresql/15/main/standby.signal
```

Redémarrer le cluster Postgres :  

```
sudo pg_ctlcluster 15 main restart
```

Apres le redémarrage, le cluster doit être en mode `standby`.  

#### 1.1.2 Vérification de la réplication

Pour vérifier que la Princess est bien en mode `standby`, on peut afficher les logs de Postgres :  

```bash
sudo -u postgres cat /var/log/postgresql/postgresql-15-main.log
```

Le fichier `standby.signal` est bien pris en compte si vous voyez cette ligne dans les logs :  

```log
LOG:  entering standby mode
```

La réplication Streaming est bien mise en place si vous voyez un message comme ceci :  

```log
LOG:  started streaming WAL from primary at 0/F000000 on timeline 5
```

> Si vous voyez un message d'erreur dû à la connexion échouée :  
> ```log
> FATAL:  could not connect to the primary server
> ```
> Vérifiez que l'adresse IP de la Princess est bien inclu dans le paramètre `listen_addresses` de la Queen.  

> Si vous voyez ce message d'erreur :  
> ```log
> FATAL:  database system identifier differs between the primary and standby
> ```
> Veuillez vous assurer que le cluster Postgres sur la Princess a été restoré avec une sauvegarde de la Queen.  

<br/>

### 1.2 Réplication Synchrone

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Une réplication synchrone peut-elle fonctionner en WAL shipping ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> D'après la [documentation officielle](https://www.postgresql.org/docs/15/warm-standby.html#SYNCHRONOUS-REPLICATION), oui.  

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quels sont les inconvénients d’une réplication synchrone ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> Elle peut relentir le temps de réponse pour les requêtes, car une transaction doit attendre le retour du nombre minimum de serveurs *standby* synchrones (indiqué dans le paramètre `synchronous_standby_names`). En plus, la réplication synchrone est une contrainte supplémentaire lors de la configuration de la [haute disponibilité](https://www.postgresql.org/docs/15/warm-standby.html#SYNCHRONOUS-REPLICATION-HA), car on doit maintenir le minimum de serveurs *standby* en état opérationnel.  

[Lien](https://www.postgresql.org/docs/15/warm-standby.html#SYNCHRONOUS-REPLICATION) vers la documentation officielle en ligne.  

#### 1.2.1 Configuration

Une fois la réplication streaming est mise en place, on peut la rendre synchrone en mettant à jour la configuration (le paramètre [`synchronous_standby_names`](https://www.postgresql.org/docs/current/runtime-config-replication.html#GUC-SYNCHRONOUS-STANDBY-NAMES)) sur le serveur primaire (Queen) :  

  - REPLICATION :  
    - Primary Server :  
      - `synchronous_standby_names = '1 (standby1)'`

Le premier nombre (ici, `1`) correspond au nombre de serveurs `standby` synchrones dont le retour est nécéssaire afin de *commit* les transactions.  

Les noms des serveurs `standby` dans les paranthèses doivent correspondre au paramètre `application_name` dans le fichier `postgresql.conf` (ou "`*`" peut être utilisé pour *matcher* tout standby) :  

  - REPLICATION :  
    - Standby Servers :  
      - `application_name = 'standby1'`

Ou, vu que nous utilisons `pgBackRest`, le nom de notre standby peut être indiqué dans la configuration de `pgBackRest` :  

```conf
[main]
recovery-option=application_name=standby1
```

> Cette configuration ne s'applique qu'au cas d'un seul serveur `standby`. Si vous en avez plus, veuillez lire la [section](https://www.postgresql.org/docs/current/warm-standby.html#SYNCHRONOUS-REPLICATION-MULTIPLE-STANDBYS) correspondante de la documentation.  

Après avoir mis à jour la configuration, redémarrer le cluster :  

```bash
sudo pg_ctlcluster 15 main restart
```

<br/>

## II. Vérification
---

**Le but :** S'assurer que la réplication fonctionne correctement  

Nous allons essayer chacune des techniques suivantes :  

### 2.1 Regarder l’état de la réplication dans une [vue système](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-REPLICATION-VIEW)

Il est possible de vérifier la configuration en affichant le contenu de la vue `pg_stat_replication` :  

Se connecter à la base `postgres` en tant que `postgres` :  
```bash
sudo su postgres
psql
```

Exécuter la requête suivante :  
```SQL
SELECT * FROM pg_stat_replication;
```

Ce qui nous intéresse dans cette vue c'est les colonnes `state`, `sync_state` pour nos standbys :  

| ... | state | sync_state |
| --- | --- | --- |
| ... | streaming | sync |

<br/>

### 2.2 Modifier des données sur la reine et vérifier la modification de ces données sur la princesse

Sur les deux machines, se connecter à la base `benchdb` en tant que `postgres` :  
```bash
sudo -u postgres psql -d benchdb
```

Vérifier le nombre de lignes avant la suppression :  
```sql
SELECT COUNT(*) FROM pgbench_accounts WHERE bid=2;
```

```log
 count
--------
 100000
(1 row)
```

Sur la Queen, supprimer les lignes de `pgbench_accounts` pour lesquelles la colonne `bid` vaut 2 :  
```sql
DELETE FROM pgbench_accounts WHERE bid=2;
```

Sur la Princess, vérifier le nombre de lignes aprés la suppression :  
```sql
SELECT COUNT(*) FROM pgbench_accounts WHERE bid=2;
```

```log
 count
-------
     0
(1 row)
```

<br/>

### 2.3 Changer de fichier WAL courant et vérifier le fichier WAL courant sur la princesse

Nous allons utiliser la fonction d'administration [`pg_switch_wal`](https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-BACKUP) en tant que `postgres` afin de changer de fichier WAL :  

Sur la Queen, se connecter en tant que `postgres` :  
```bash
sudo -u postgres psql
```

Appeler la fonction :  
```sql
SELECT pg_switch_wal();
```

```log
 pg_switch_wal
---------------
 0/13208148
(1 row)
```

Sur la Princess, vérifier le fichier WAL courant :  
```bash
sudo -u postgres psql -c "SELECT pg_current_wal_lsn();"
```

<br/>

### 2.4 Pour la réplication synchrone, arrêter la princesse et essayer d’écrire sur la reine

Arrêter la Princess :  
```bash
sudo pg_ctlcluster 15 main stop
```

Faire une modification sur la Queen :  
```bash
sudo -u postgres psql -d benchdb -c "DELETE FROM pgbench_accounts WHERE bid=4;"
```

Cette transaction [ne sera pas *commit*](https://www.postgresql.org/docs/15/warm-standby.html#SYNCHRONOUS-REPLICATION-HA), car la Queen doit attendre la réponse du minimum de standbys (ici, `1`, comme configuré plus haut) et vu que la Princess est arrêtée, la Queen ne recevra jamais sa réponse.  

Pour que la transaction soit *commit*, nous devons démarrer la Princess.  

