# Swagbot

Irc bot with a rails backend utilizing a postgresql database customized for openshift 

## Installation 

- This is designed for openshift, the easiest way to get this going is to run:
```
rhc app-create APP_NAME ruby-1.9 postgresql-9.2
```
- Then, run the below to push the code to the application:
```
cd etherpad
git remote add upstream -m master https://github.com/tiwillia/Swagbot.git
git pull -s recursive -X theirs upstream master
# Note that the git pull above can be used later on to pull updates to the application
git push
```
- Once the application is pushed, ssh to the application to fill out the configuration file:
```
rhc ssh APP_NAME
> vim ~/app-root/data/application.yml
> ctl_all restart
# The above command restarts the application to pull the changes to the configuration file.
> exit
```
- Navigate to the application's url from your browser and you are done!

## Usage

- After installing, navigate in your browser to the web interface. Click the 'bots' tab and you will be prompted to create a new bot. Fill in the form and your bot will be added. To start it, hit 'start' on the bot's screen.
- Each bot has a page where the databases are indexed and searchable.

## Additional notes

* Configuration file: ~/app-root/data/appication.yml
* Example configuration file in config/application.example.yml

