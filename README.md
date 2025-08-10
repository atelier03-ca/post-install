# A03 Flavored Linux Mint

Post installation script for our laptops

![Thumnail](./demo/THUMBNAIL.png)

### What does this script do?

* Installs STEM [packages](./.packages) & apps
* Configures device permissions for Arduino & micro:bit
* Configures theme, background and splash screen

### Target

* For Linux Mint 22.0 Wilma

### How to use

```sh
# Download and unzip
wget https://github.com/atelier03-ca/post-install/archive/refs/heads/master.zip -O post-install.zip
unzip post-install.zip

# Make it executable and Run
cd post-install-master
chmod +x install.sh
sudo ./install.sh
```