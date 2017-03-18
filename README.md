# Goals

* Use Opendap Hyrax [BES](http://docs.opendap.org/index.php/Hyrax)
  under [`systemd`](https://www.freedesktop.org/wiki/Software/systemd/)
  without SysV scripts.

* Take advantage of the `systemd`'s template feature to support multiple
  instances of BES (eg, dev, test, ops).


# Requirements

* [Vagrant](https://www.vagrantup.com/)
* `wget`


# Steps

* Fetch the BES RPMs and the OLFS webapp
  (the web interface is nicer than `bescmd`).
  Note: RPMs are from https://www.opendap.org/pub/binary/hyrax-1.13.3/centos7.1/,
  and the webapp is https://www.opendap.org/pub/olfs/olfs-1.16.2-webapp.tgz

```
$ ./fetch_hyrax_releases.bash
```

* Start the virtual machine.

```
$ vagrant up
[...]
==> default: LISTEN  0       5       127.0.0.1:10023     *:*                users:(("beslistener",pid=4028,fd=5))
==> default: LISTEN  0       5       127.0.0.1:10024     *:*                users:(("beslistener",pid=4062,fd=5))
==> default: LISTEN  0       5       127.0.0.1:10025     *:*                users:(("beslistener",pid=4096,fd=5))
==> default: LISTEN  0       100     :::8080             :::*               users:(("java",pid=4114,fd=49))
[...]
==> default: ==  http://localhost:8080/opendap-xyz_dev/   ==
==> default: ==  http://localhost:8080/opendap-xyz_test/  ==
==> default: ==  http://localhost:8080/opendap-xyz_ops/   ==
```

* Open the indicated URLs in a browser.
  There should be a marker file clearly identifying each data tree,
  letting us know that each BES is working.


# Various observations

* Be careful using hyphens (`-`) in `systemd` template instances.
  `%I` in `foo@.service` unit files replaces `-` with `/`,
  which can change the expected paths.
  For example, `bes@xyz-dev` results in `/var/log/bes-xyz/dev`
  instead of `/var/log/bes-xyz-dev`.

* Don't use `@` in the BES configuration path (eg, `/etc/bes@xyz-dev/bes.conf`)
  because `besdaemon` has unreasonable restrictions on the configuration path:

    The specified configuration file (-c option) is incorrectly formatted.
    Must be less than 255 characters and include the characters `[0-9A-z_./-]`

* `besdaemon` is frustratingly incompatible with `systemd` (cf `Type=forking`).
  Use `beslistener` directly instead.
