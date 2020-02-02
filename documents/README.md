## ConnMan D-bus network state Dispatcher
Small service to monitor `ConnMan` network state changes via `D-Bus` interface and execute corresponding shell scripts.

### Install
Arch users can install package from AUR, others should use `cmake` installation procedure:
```
$ wget https://github.com/vsemyonoff/cmdd/archive/v1.0.0.tar.gz
$ tar xvf v1.0.0.tar.gz
$ cd cmdd-1.0.0
$ mkdir build && cd build
$ cmake -DCMAKE_BUILD_TYPE=Release ..
$ cmake --build .
$ sudo cmake --install .
```

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
│   └── 50-msmtpq-flush -> ../scripts/msmtpq-flush
├── ready.d
│   └── 00-info -> ../scripts/info
└── scripts
    ├── info
    └── msmtpq-flush
```

Place your script into `/etc/cmdd.conf.d/scripts`, then symlink it into corresponding subfolder.
Each script will obtain 2 arguments while executing: __`${1}`__ - new `ConnMan` state
__`${2}`__ - previous state.
