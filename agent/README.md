# featherfix-agent

A tiny Java agent (our own code, ~4 KB) that keeps Feather's **in-game menu** working if
`mc-webapp.feathermc.com` goes down. That menu is a web app; without it the game shows a
Cloudflare "Connection timed out" page instead of the menu.

At game start it checks `https://mc-webapp.feathermc.com/`. Only if that doesn't answer, it
rewrites that one string constant (as Feather's classes load) to the first of Feather's own
beta / dev web apps that does. If the release host is up, it does nothing.

`patch-feather.ps1` copies the jar to `%APPDATA%\.feather\featherfix-agent.jar` and makes the
launcher add `-javaagent:` for it (only when the file exists). Remove that file to turn it off.
Force a specific address with the JVM argument `-Dfeatherfix.webapp=https://...`.

Build (Java 8 bytecode, works on every version's Java):

```
javac --release 8 -d build/classes src/featherfix/WebappAgent.java
printf 'Premain-Class: featherfix.WebappAgent\n' > build/MANIFEST.MF
jar cfm featherfix-agent.jar build/MANIFEST.MF -C build/classes .
```
