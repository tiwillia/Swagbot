# Rails Openshift Template #
This template made from rails-example

The following changes have been implemented:
- Global YAML config file added (/config/application.yml)
    - See /config/application.yml.sample
- Added twitter's bootstrap
    - See https://github.com/seyhunak/twitter-bootstrap-rails

Paperclip configuration requires the following in your model:

has_attached_file :photo,
  :styles => {
    :thumb => "100x100#",
    :medium => "256x192" },
  :url => "/images/:id.:extension",
  :path => "#{CONFIG[:data_dir]}public/images/:id.:extension"

TODO
- holy shit
- getuser for grantor in editkarma is fucked up, creates a new user everytime.

