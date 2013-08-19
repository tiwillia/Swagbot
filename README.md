Swagbot
=======

IRC bot written from scratch in Ruby

TODO:
- Add search methods for quotes and definitions
- Add the ability to see who gives the most karma
- Fix methods to provide for easier coding
- Consider adding a rails backend for control

Database implementation complete and tested. See the notes in ./migrate.rb to set up your postgres database correctly.

The master branch now simply has the database implemented, but not used. This way, we can each make a branch/fork if necessary to figure out how we are going to implement the methods using the activerecord database abstraction layer.

=======================

The database is backed by postgresql using the activerecord abstraction layer (without rails).
The table structure is:

User table:
id, user(string)

Karma table:
id, grantor_id(FK, int), recipient_id(FK, int), amount(integer)
Note: the grantor_id and recipient_id will be mapped back to the User table.
Note: each row will contain one karma operation, not the totals

Karam stats table:
id, user_id(FK, int), running_total(int)

Quotes table:
id, recorder_id(FK, int), quotee_id(FK, int), quote(text)

Definitions table:
id, definer_id(FK, int), word(string), definition(text)

Each type of data table will have its own model rb object. This allows us to create methods that can
for example, check if user exists, if not add them to the user table and grab their id.
