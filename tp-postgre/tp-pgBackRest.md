---
tags: ["TP"]
aliases: ["TP2", "TP2 sur la restauration de données"]
---

# La restauration de données avec l'outil pgBackRest dans PostgreSQL

> Eldar Kasmamytov
> p1712650

Installation
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

- **Q:** Qu’est-ce qu’une sauvegarde full ?  
- **R:** D'après la [documentation officielle](https://pgbackrest.org/user-guide.html#concept/backup) de **pgBackRest**, c'est une sauvegarde de la base de données entière. Elle ne dépend pas d'autres fichiers et il est donc toujours possible de la restaurer. La première sauvegarde de la BDD est toujours une sauvegarde full, afin de pouvoir effectuer des sauvegardes différentielles ou incrémentales plus tard.  

- **Q:** Qu’est-ce qu’une sauvegarde incrémentale ?  
- **R:** C'est une sauvegarde partielle, qui ne copie que les données qui ont été modifiées depuis la dérnière sauvegarde (qui peut être une autre sauvegarde incrémentale, différentielle ou complète). Par conséquent, elle dépend des sauvegardes précédentes, qui doivent être valides pour garantir une bonne restauration depuis une sauvegarde incrémentale.  

- **Q:** Quelle est la différence entre une sauvegarde incrémentale et une sauvegarde différentielle ?  
- **R:** Une sauvegarde différentielle ne dépend que de la dérnière sauvegarde complète, tandis que l'incrémentale nécéssite que **toutes** les sauvegardes précédentes soient valides. En général, une sauvegarde différentielle pèse plus qu'une sauvegarde incrémentale.  

- **Q:** Que signifie PITR ?  
- **R:** **P**oint **I**n **T**ime **R**ecovery, ou PITR, 