# Waypipe in a container
This container runs an ssh server and has [waypipe](https://gitlab.freedesktop.org/mstoeckl/waypipe) installed. You can use it to run a graphical application on a remote machine for instance. This image is the bare minimum and nothing interesting is installed on it really. It is intended to serve as the base for other more useful images.

## One-liner
```bash
podman run --rm -p 9022:22 -v ssh:/ssh/ --name waypipe ghcr.io/ps-pat/waypipe:latest
```
where `ssh` is a directory containing the files listed in the next section. This will launch the latest build of the container and expose the ssh server on port 9022. You can log into it as user `user`
```bash
ssh -p 9022 user@localhost
```

Images are also available on [Dockerhub](https://hub.docker.com/r/patfou/container-waypipe).

## Authentication
By default, the container only accepts connection from user `user` and authentication via certificate authority (CA). This means that your user key must be signed with `user` as one of its principals. This is easily modified by building a custom image. In any case, the following three files are required:
1. `user_ca_key.pub`: user certificate
2. `host_ca_key`: host key
3. `host_ca_key-cert.pub`: host certificate

The easiest way to configure authentication is to mount those files in the `/ssh` directory.

### CA authentication crash course
There are many guides available on how to implement CA authentication for SSH. To save you the Google, here is my quick and dirty how-to.

You will need two certificates, which are really just ordinary ssh key. We refer to them as the **host** key and **user** key. The difference between keys and certificate is in their usage: keys are the thing presented to the host/client to perform the actual authentication while certificate are used to *sign* keys (and validate signatures).

#### Generating certificates
Certificates are keys and can be generated in the same way as any ssh key:
```bash
ssh-keygen -t ed25519 -f user_ca_key
ssh-keygen -t ed25519 -f host_ca_key
```
Keep generated files in a safe directory. The private keys (the one not ending in `.pub`) must be kept secret.

#### Signing user key
To enable authentication via your newly generated user key, you need to do two things:
1. sign your personal ssh key with the private ca **user** key;
2. make the container's server accept signed keys;

We assume that you already have a personal ssh key `~/.ssh/id_ed25519.pub`. Sign it with the following command:
```bash
ssh-keygen -s user_ca_key -I "personal" -n user ~/.ssh/id_ed25519.pub
```
The `-I` switch is used to specify key's identity. Feel free to change it to anything you like. `-n` switch is more critical. It has to contain the name of the user that is going to use the signed key. Since, by default, the only user in the container for which ssh authentication is enabled is `user̀`, the line above is sufficient. If you want to use the same key to log in other machines via other names, you can add them in a comma separated list:
```bash
ssh-keygen -s user_ca_key -I "personal" -n user,user2,user3 ~/.ssh/id_ed25519.pub
```
For references, those names are called the *principals* of the certificate.

Regarding point 2, making the container accept your user certificate is only a matter of mounting `user_ca_key.pub`into `/ssh`.

#### Signing host key
Signing the host key allows for automatic validation of the container's identity. Three things need to be done to make that happen:
1. generate a host key;
2. sign the host key with the **host** CA;
3. make the container's server present signed host key;
4. make the client accept signed host key.

Host key is generated as usual:
```bash
ssh-keygen -t ed25519 -f host_key
```

Next two steps sound very similar to the last section and they are. Sign the host key with:
```bash
ssh-keygen -s host_ca_key -I "container-waypipe" -h host_key.pub
```
There are two difference between this command and the one used for the private key. First, there is no need to specify a principal for the host key; this is why there is no `-n` switch. Second, notice the presence of the `-h` switch. This indicates that the key we are signing is going to be used as a host key.

For step 3, just mount `host_key` and the newly created `host_key-cert.pub` to `/ssh`. `host_key.pub` is not required.

Finally, step four require you to copy your public **host** CA to `/etc/ssh/ssh_known_hosts` on the client. Here's a one-liner:
```bash
echo "@cert-authority * $(cat host_ca_key.pub)" | sudo tee -a /etc/ssh/ssh_known_hosts > /dev/null
```
You should now be good to go. Of course, steps above can be customized; salvation lies within the results of a Google search. Also, obligatory reminder that it is always a good idea to copy-paste bash commands from some rando on the internet, especially those starting with `sudo`.
