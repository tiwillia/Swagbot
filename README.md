# Swagbot?

Irc bot with a rails backend utilizing a postgresql database customized for openshift

## Installation

- This is designed for openshift, the easiest way to get this going is to run:
```
rhc app-create APP_NAME ruby-1.9 postgresql-9.2 --from-code https://github.com/tiwillia/Swagbot.git
```

## Usage

- After installing, navigate in your browser to the web interface. Click the 'bots' tab and you will be prompted to create a new bot. Fill in the form and your bot will be added. To start it, hit 'start' on the bot's screen.
- Each bot has a page where the databases are indexed and searchable.

## Additional notes

* Configuration file: config/appication.yml
  * You will have to use application.example.yml and rename it to application.yml

### TODO
- Add more stats to the bot pages
