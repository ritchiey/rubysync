rubysync
    by Ritchie Young
    http://rubysync.org

== DESCRIPTION:
  
RubySync is a tool for synchronizing part or all of your directory,
database or application data with anything else. It's event driven
so it will happily sit there monitoring changes and passing them on.
Alternatively, you can run it in one-shot mode and simply sync A with B.

You can configure RubySync to perform transformations on the data as it
syncs. RubySync is designed both as a handy utility to pack into your
directory management toolkit or as a fully-fledged provisioning system
for your organisation.


== FEATURES/PROBLEMS:
  

== SYNOPSIS:

  This sets up the skeleton of a configuration for importing comma delimited
  text files into a database. Note, if the application happens to be a Rails
  app then it can also export changes.

    $ rubysync create db_demo
    $ cd db_demo
    $ rubysync connector my_csv -t csv_file
    $ rubysync connector my_db -t active_record
  
  You would then edit the files:

    connectors/my_csv_connector.rb   ;where to get CSV files, field names, etc
    connectors/my_db_connector.rb    ;how to connect to your DB or Rails app.

  And enter:
    $ rubysync pipeline my -C my_csv -V my_db

  You would then edit the file pipelines/my_pipeline.rb to configure the
  policy for synchronizing between the two connectors.
                                        
  You may then execute the pipeline in one-shot mode (daemon mode is coming):

    $ rubysync once my

== REQUIREMENTS:

* An RDBMS system if you want to sync one
* An LDAP server if you want to sync one

== INSTALL:

* sudo gem install rubysync -y

== LICENSE:

 RubySync is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
 
 RubySync is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along with RubySync; if not, write to the
 Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
