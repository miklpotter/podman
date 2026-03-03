# Composing Podman for database 26ai
An easy way to build your own personal APEX environment? by using podman desktop, a compose file, and a structured approach we can build an environment within minutes.

This document show you how to do this, and has been tested directly on MacOS, but the principles and steps apply for Linux and Windows

## Install Podman desktop

* download Podman desktop from https://podman-desktop.io/
* follow the [install guide](https://podman-desktop.io/docs/installation)

Podman will prompt you to install the podman engine.
Enable the compose extension following this [guide](https://podman-desktop.io/docs/compose/setting-up-compose)

You can create the podman machine via desktop, or commandline.
if using the desktop, edit the machine to allocate at least 4Gb ( I recommend 6 or 8Gb). the default 2Gb memory *is not enough*

#### CLI commands to create machine

```sh
podman machine init
podman machine set --memory 4096
# podman machine set --memory 6144
# podman machine set --memory 8192
# podman machine stop
podman machine start
```

### Pull the containers NOW, save time.
pulling the containers can take some minutes, so why now pre-load them so you have your container images ready by the time you are set-up and ready to go?
```
podman pull container-registry.oracle.com/database/free:latest
podman pull container-registry.oracle.com/database/ords:latest
```

## Use podman compose
This example uses persistent volumes to allow your container to be rebuilt at-will. this lets you reconfigure the container as needed, WITHOUT losing the database or ORDS config.
I have used ~/opt/oracle as my base directory for all examples, if your chosen location differs ( eg in windows the path could look different), just edit the relevant lines to accomodate

if you are happy to use ~/opt/oracle to hold your podman related database and ords files....

Secrets are a feature of podman, but i have only succeeded in having them work for the Database container. ORDS container seems not to support use of secrets at all.  Therefore, for simplicity, I have used environment variables to supply the required passwords to the containers.

### Create custom directories
```
mkdir -p ~/opt/oracle/oradata
mkdir -p ~/opt/oracle/ords_config
mkdir -p ~/opt/oracle/ords_secrets
```

Note: if you machine is running with root privileges, it's likely you will need to change permissions on the oradata folder:

```sudo chown 54321 ~/opt/oracle/oradata```

ref: [FAQ](https://github.com/oracle/docker-images/blob/main/OracleDatabase/SingleInstance/FAQ.md#cannot-create-directory-error-when-using-volumes)

### Download and unzip latest APEX

```
cd ~/opt/oracle
curl -L -O https://download.oracle.com/otn_software/apex/apex-latest.zip
unzip apex-latest.zip
```

if you havent yet pulled the containers ( becuase you couldnt be bothered...) do it now.

```
podman pull container-registry.oracle.com/database/free:latest
podman pull container-registry.oracle.com/database/ords:latest
```

### Setup your environment variables

```
export ORACLE_PWD=password1
export ORDS_PUBLIC_USER_PWD=password2
```

Now your environment is configured, you can navigate to the directory where you are holding the yaml file, and start it up!

```podman compose -f compose-orcl.yaml up -d```

The -d option immediately detaches the command from your terminal,

### Final steps

You will need to configure the APEX internal admin account, so you can log in.

```
cd ~/opt/oracle/apex
connect to the DB as  sys as sysdba
eg: sql sys@@localhost:1521/freepdb1 as sysdba
SQL> @apxchpwd
```

