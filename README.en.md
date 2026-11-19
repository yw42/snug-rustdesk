# Snug RustDesk

[简体中文](README.md) · English

Snug RustDesk is a macOS companion for self-hosted RustDesk. It creates virtual displays tailored to the controlling device and manages window layout and zoom on the host Mac. RustDesk handles connections, authentication, and streaming. The project is under development.

## Build and run

Use macOS 14 or later, Swift 6, and the Xcode command-line tools. Configure RustDesk on the host and the controlling device before starting.

```sh
scripts/snug check
scripts/snug app
```

Open `build/Snug RustDesk.app` and grant Accessibility access when prompted. Configure a display, start a companion session from the menu bar, and select the display in RustDesk. End the companion session from the menu bar to restore the original layout. RustDesk handles input in this build. The companion requests Screen Recording separately for screenshots. Development builds use ad-hoc signing by default and may need permission again after a rebuild.

Settings and recovery data live under `~/Library/Application Support/SnugRustDesk/`. Logs are in `~/Library/Logs/SnugRustDesk.log`. Distribution and in-app updates are disabled by default. See [.machine.env.example](.machine.env.example) for release settings.

[Product requirements](docs/PRODUCT.md) · [Technical design](docs/rustdesk-technical-design.md) · [Implementation checklist](docs/TODO-rustdesk.md)

## Credits and license

This project is derived from [zephyr4123/snug](https://github.com/zephyr4123/snug), which originated as [UUyc-companion by AoyamaShou](https://github.com/aoyamashou/UUyc-companion). [LICENSE](LICENSE) retains both copyright notices and the MIT license.
