# Swagbot (or something...)

Irc bot with a rails backend utilizing a postgresql database

* Ruby version: 1.9.2/2.0

* System dependencies: Postgresql database

* Database creation:

* Database initialization: rake db:create; rake db:migrate

* Configuration file: config/appication.yml
  * You will have to use application.example.yml and rename it to application.yml
=======================
### TODO
* Sadly, a huge design necessity was missed. Multiple bots can be spun up, but they all use the same databases. I need to add numerous "has" and "belongs_to" relations to the bots database table and the others.
