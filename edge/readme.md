# Beispiel für die Verwendung von OCI-Images mit Podman auf einem Beckhoff RT Linux (Debian based) mit TwinCAT Runtime

## Einleitung

Auf einer Beckhoff RT Linux Distribution (Debian based) soll neben dem TwinCAT Runtime System auch  Podman ausgeführt werden um OCI-Images auszuführen.

Es soll ein RabbitMQ-Container ausgeführt werden, der opc-ua pubsub messages empfängt, in eine queue umleitet und danach auf einen in der cloud laufenden mqtt-broker weiterleitet. Dafür wird das RabbitMQ Shovel Plugin verwendet.

Folgende Konfigurationen werden erstellt:
**enabled_plugins**: Enables the plugins. Writen as an erlang list of atoms ending with a period. In the folder  /etc/rabbitmq/enabled_plugins
- **rabbitmq.conf**: Main configuration file of the RabbitMQ-Server under /etc/rabbitmq/rabbitmq.conf
- **rabbitmq_definitions.json**: Konfiguration für den RabbitMQ-Server unter /etc/rabbitmq/rabbitmq_definitions.json

> Konfigurationen siehe auch [RabbitMQ Dokumentation configure](https://www.rabbitmq.com/docs/configure)

> Schema Definitions siehe auch [RabbitMQ Dokumentation schema definitions](https://www.rabbitmq.com/docs/definitions#import-on-boot)

Diese Anleitung ist angelehnt an den heise.de Artikel [IoT und Edge-Computing mit Podman](https://www.heise.de/hintergrund/IoT-und-Edge-Computing-mit-Podman-9826917.html?seite=all).

## Vorraussetzungen

> Folgende Anleitung ist für eine Debian Based Distribution. Für andere Distributionen können die Befehle abweichen. Die meisten Befehle verlangen sudo-Rechte.

```bash	
apt update
apt upgrade
# https://podman.io/docs/installation
apt-get -y install podman
```

## Podman

Podman ist ein Container-Manager, der ohne Daemon-Prozess arbeitet. Er ermöglicht die Ausführung von Kubernetes-Workloads. Dies ist ideal für IIoT und Edge-Cmputeing typeschen, ressourcenschwachen kleinstrechnern. Alle zur Verfügung gestellten Funktionen sind in einer [Support-Matrix](https://docs.podman.io/en/latest/markdown/podman-kube-play.1.html#podman-kube-play-support) in der Podman-Dokumentation aufgelistet. 

## Ausführung

```bash
# Starte pod
podman kube play edge.yaml
podman pod ps
```

RabbitMQ management ist nun erreichbar über die IP-Adresse auf port 15672 `http://[HOST-IP]:15672` mit dem user `guest` pw `guest`.

## Cleanup

```bash
# entferne den pod
podman kube down edge.yaml 
rmdir ./data
```
