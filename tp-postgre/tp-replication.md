---
tags: ["TP"]
aliases: ["TP3", "TP3 sur la réplication physique"]
---

# La réplication physique d'un cluster Postgres
---

> Eldar Kasmamytov p1712650
> (Je suis en monôme)

<br/>

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quelle est la différence entre une réplication logique et une réplication physique ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> 

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une réplication en WAL shipping ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> C'est une solution au problème de la réplication qui consiste à surveiller le serveur principale pour tout changement dans la base de données au travers les WALs. Elle nécéssite une architecture multi-nœuds dans laquelle chaque nœud est attribué d'un rôle :  
>  
> - Un seul nœud **Queen** (appelé également *read-write*, *master* ou *primary*)  
>   C'est le seul nœud pouvant accepter des requêtes en lécture **et** en écriture (*read-write*). Les transactions sont ensuite **répliquées** sur d'autres nœuds en leur fournissant les fichiers **WAL** de la Queen, d'où le nom de cette approche "WAL *Shipping*".  
>   <br/>
>     - Ces nœuds recevant les WAL de la Queen (et ainsi répliquant les transactions) sont appelés **Princess** (ou aussi *standby*, *secondary*). En cas de panne de la Queen, une des Princess prend le relais et devient une nouvelle Queen.  

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Une réplication synchrone peut-elle fonctionner en WAL shipping ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> D'après la documentation officielle, oui.  

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Quels sont les inconvénients d’une réplication synchrone ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> Elle peut relentir le cluster.  

## I. La réplication
---

**Les buts de cette partie :**  
  - Mettre en place une réplication streaming  
  - Modifier la réplication pour qu’elle devienne synchrone  

### 1.1 Réplication en mode "Streaming"

> 🤔 <span style="color: #8357e9; font-weight: bold;">Question:</span> Qu’est-ce qu’une réplication en mode “streaming” ?  
> 💡 <span style="color: #8357e9; font-weight: bold;">Réponse:</span> 

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

