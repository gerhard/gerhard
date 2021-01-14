---
title: How do I debug my Cloud Foundry application?
summary:
authors: []
tags: []
categories: []
date: "2015-11-02T14:00:00Z"
slides:
  # see available slides. options in layouts/slides/baseof.html
---

## Cloud Foundry <br />From Zero To Hero
### [06 How do I debug my app?](#/0)

<p style="font-size: 50%; opacity: 0.2;">
  This content is copyright of CloudCredo. &copy; CloudCredo 2015. All rights reserved.
</p>

---

# [Feature](#/1)

```nohighlight
As a CF hero
I want to know what my CF app is doing
So that I can debug it
```

---

## [Push](#/2) a buggy app

```bash
# From the training home directory:
$ cd 06-debugging/debug-app
$ cf push

...

urls: debug-app-unerring-muddlehead.cfapps.io

...
```

<img src="/img/cf-zero-hero/500-index.png" style="background:none; border:none; box-shadow:none;" />

---

## [How do I](#/3) debug my app[?](#/3)

1. App logs
1. App events
1. App instrumentation
1. SSH access

---

## [1. App](#/4) logs

```bash
$ cf logs debug-app --recent

...

... [App/0] ERR ...  - RuntimeError - I am a bug, fix me:
... [App/0] ERR /home/vcap/app/config.ru:20:in `block in <class:Web>
```

```bash
$ cf logs debug-app # Tails app logs, CTRL + C to exit
```

---

## [Let's](#/5) fix the app

```bash
$ cf set-env debug-app FIXED true
$ cf restart debug-app
```

<img src="/img/cf-zero-hero/200-index.png" style="background:none; border:none; box-shadow:none;" />

---

## [2. App](#/6) events

```bash
$ cf events debug-app

... description
... index: 0, reason: CRASHED, exit_description: 2 error(s) ...
...
```

{{< speaker_note >}}
  Notice that the most recent event is at the top
{{< /speaker_note >}}

---

## [3. App](#/7) instrumentation

* New Relic
* AppDynamics

> Included in Java buildpack

---

## [New Relic](#/8) instrumentation

```bash
$ cf create-service newrelic standard newrelic
$ cf bind-service debug-app newrelic
$ cf env debug-app
# Find your New Relic license key
```

```bash
# From the training home directory:
$ cd 06-debugging/debug-app
# Replace YOUR-LICENSE-KEY
$ vim newrelic.yml
```

```bash
$ cf push
```

```bash
$ cf service newrelic
```

{{< speaker_note >}}
  Create a New Relic service instance

  Provide app with New Relic license key

  Find New Relic Dashboard URL

  Generate some load
{{< /speaker_note >}}

---

## [4.](#/9) SSH [access](#/9)

```bash
$ cf ssh debug-app
```

<img src="/img/cf-zero-hero/cf-ssh.png" style="background:none; border:none; box-shadow:none;" />

---

# <span style="color: #8FF541;">DELIVERED</span>

```nohighlight
As a CF hero
I want to know what my CF app is doing
So that I can debug it
```

---

## [Any](#/11) questions?

> Questions cannot be stupid. Answers can.

---

# CF SUPERHERO

  * Setup [Skylight](https://www.skylight.io/) for app
  * Setup [Opbeat](https://opbeat.com/) for app
  * Learn about [CF Logging and Metrics](http://www.cfsummit.com/sites/cfs2015/files/pages/files/cfsummit15_king.pdf)
  * Send app logs to [Papertrail](https://papertrailapp.com/)

```bash
$ cf cups logdrain -l syslog://YOUR-PAPERTRAIL-LOG-DESTINATION
$ cf bind-service debug-app logdrain
# Check your Papertrail Events, no need to restart the app
```

<p style="font-size: 50%; opacity: 0.2;">
  This content is copyright of CloudCredo. &copy; CloudCredo 2015. All rights reserved.
</p>
