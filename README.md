# vblink
**vblink** is a tool that allows for sending Virtual Boy ROM files to a [Red Viper](https://github.com/skyfloogle/red-viper) instance over the network.
The protocol used is similar to that of [3dslink](https://github.com/devkitPro/3ds-hbmenu?tab=readme-ov-file#netloader), and has been integrated into [VUEngine Studio](https://www.vuengine.dev/) to allow easily testing homebrew.

## Usage
Press Y on the Red Viper main menu to enter vblink mode. Then, a ROM can be sent by running vblink as follows:
```sh
vblink --address 192.168.your.ip --file your_rom.vb
```
