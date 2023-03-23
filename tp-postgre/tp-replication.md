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

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quelle est la différence entre une réplication logique et une réplication physique ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> 

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une réplication en WAL shipping ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> C'est une solution au problème de la réplication qui consiste à surveiller le serveur principale pour tout changement dans la base de données au travers les WALs. Elle nécéssite une architecture multi-nœuds dans laquelle chaque nœud est attribué d'un rôle :  
>  
> - Un seul nœud **Queen** (appelé également *read-write*, *master* ou *primary*)  
>   C'est le seul nœud pouvant accepter des requêtes en lécture **et** en écriture (*read-write*). Les transactions sont ensuite **répliquées** sur d'autres nœuds en leur fournissant les fichiers **WAL** de la Queen, d'où le nom de ce méchanisme "WAL *Shipping*".  
>   <br/>
>     - Ces nœuds recevant les WAL de la Queen (et ainsi répliquant les transactions) sont appelés **Princess** (ou aussi *standby*, *secondary*). En cas de panne de la Queen, une des Princess prend le relais et devient une nouvelle Queen.  

Il existe différentes approches qui implémentent WAL Shipping, notamment *File-Based* et *Streaming*. Dans la suite, nous mettrons en place une réplication *Streaming*.  

- **Les buts de cette partie :**  
  - Mettre en place une réplication streaming  
  - Modifier la réplication pour qu’elle devienne synchrone  

### 1.1 Réplication en mode "Streaming"

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une réplication en mode “streaming” ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> C'est une technique de réplication en Log Shipping permettant au serveur primaire (ou **Queen**) de diffuser/stream en direct (par exemple à travers une connexion SSH) les entrées de WAL aux serveurs secondaires (ou **Princess**) au moment quand elles sont générées, sans attendre que le fichier WAL (un segment de 16MB) soit rempli en entier.  

Nous allons utiliser l'outil [`pgBackRest`](https://pgbackrest.org/user-guide.html#replication) afin de mettre en place la réplication Streaming.  

#### 1.1.1 Mise en place d'une connexion SSH sans mot de passe

Pour permettre aux serveurs de communiquer entre eux, nous allons mettre en place une connexion SSH sans mot de passe.  

>❕**Remarque:** Il aurait également été possible d'utiliser d'autres types de connexion, par exemple TLS.  

- Sur la machine secondaire (**Princess**), créer une pair de clés SSH :  

  En tant qu'utilisateur `postgres` :  
  ```bash
  sudo su postgres
  ```
  S'assurer que le répertoire `.ssh` est présent, sinon le créer :  
  ```bash
  mkdir -m 750 -p /var/lib/postgresql/.ssh
  ```
  Générer une pair de clés RSA de 4096 octets (sans `passphrase`) :  
  ```bash
  ssh-keygen -f /var/lib/postgresql/.ssh/id_rsa \
    -t rsa -b 4096 -N ""
  ```

- Ajouter la clé publique de la Princess que nous venons de générer (`/var/lib/postgresql/.ssh/id_rsa.pub`) à la fin du fichier des clés autorisées de l'utilisateur `pgbackrest` sur la Queen (`/home/pgbackrest/.ssh/authorized_keys`).  

- De même, ajouter la clé publique de la Queen de l'utilisateur `pgbackrest` (`/home/pgbackrest/.ssh/id_rsa.pub`) à la fin du fichier des clés autorisées de la Princess (`/var/lib/postgresql/.ssh/authorized_keys`).  

- Vérifier si les deux machines peuvent se connecter l'une à l'autre via SSH.  

#### 1.1.2 Mise en place de la réplication en mode Streaming



<br/>

### 1.2 Réplication Synchrone

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Une réplication synchrone peut-elle fonctionner en WAL shipping ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> D'après la documentation officielle, oui.  

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quels sont les inconvénients d’une réplication synchrone ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> Elle peut relentir le cluster.  



<br/>

## II. Vérification
---

**Le but :** S'assurer que la réplication fonctionne correctement  

Nous allons essayer chacune des techniques suivantes :  

### 2.1 Regarder l’état de la réplication dans une [vue système](https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-REPLICATION-VIEW)



<br/>

### 2.2 Modifier des données sur la reine et vérifier la modification de ces données sur la princesse



<br/>

### 2.3 Changer de fichier WAL courant et vérifier le fichier WAL courant sur la princesse



<br/>

### 2.4 Pour la réplication synchrone, arrêter la princesse et essayer d’écrire sur la reine

