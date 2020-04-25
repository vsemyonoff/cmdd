## ConnMan D-bus network state Dispatcher

Small service to monitor [`ConnMan`](https://01.org/connman) network state changes via
[`D-Bus`](https://www.freedesktop.org/wiki/Software/dbus) interface and execute corresponding shell scripts.

### Install

Arch Linux users can install the package directly from AUR.
Others should use [`CMake`](https://cmake.org) installation procedure:

```
$ wget https://github.com/vsemyonoff/cmdd/archive/v1.0.2.tar.gz
$ tar xvf v1.0.2.tar.gz
$ cd cmdd-1.0.2
$ mkdir build && cd build
$ cmake -DCMAKE_BUILD_TYPE=Release ..
$ cmake --build .
$ sudo cmake --install .
```

Be sure that [`sdbus-cpp`](https://github.com/Kistler-Group/sdbus-cpp) library installed before.

### Usage

`/etc/cmdd.conf.d` structure:

```
➤ tree /etc/cmdd.conf.d/
/etc/cmdd.conf.d/
├── idle.d
│   └── 00-info -> ../scripts/info
├── offline.d
│   └── 00-info -> ../scripts/info
├── online.d
│   ├── 00-info -> ../scripts/info
├── ready.d
│   └── 00-info -> ../scripts/info
└── scripts
    └── info
```

Place your script into `/etc/cmdd.conf.d/scripts`, then symlink it into corresponding subfolder.
Each script will obtain 2 arguments while executing: **`${1}`** - new `ConnMan` state
**`${2}`** - previous state.
