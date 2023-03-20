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

**Les buts de cette partie :**  
  - Mettre en place une réplication streaming  
  - Modifier la réplication pour qu’elle devienne synchrone  

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

