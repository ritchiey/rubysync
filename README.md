# RubySync

by [Ritchie Young][1] and [Nowhere Man][2]

## DESCRIPTION:

RubySync is a tool for synchronizing part or all of your directory,
database or application data with anything else. It's event driven
so it will happily sit there monitoring changes and passing them on.
Alternatively, you can run it in one-shot mode and simply sync A with B.

You can configure RubySync to perform transformations on the data as it
syncs. RubySync is designed both as a handy utility to pack into your
directory management toolkit or as a fully-fledged provisioning system
for your organization.

## FEATURES/PROBLEMS:

* Event-driven synchronization (if connector supports it) with fall-back to polling
* Ruby DSL for "configuration" style event processing
* Clean separation of connector details from data transformation
* Connectors available for CSV files, XML, LDAP and RDBMS (via ActiveRecord)
* Easy API for writing your own connectors

## SYNOPSIS:

  This sets up the skeleton of a configuration for importing comma delimited
  text files into a database. Note, if the application happens to be a Rails
  app then it can also export changes.

    rubysync create db_demo
    cd db_demo
    rubysync connector my_csv -t csv_file
    rubysync connector my_db -t active_record

  You would then edit the files:

    connectors/my_csv_connector.rb   ;where to get CSV files, field names, etc
    connectors/my_db_connector.rb    ;how to connect to your DB or Rails app.

  And enter:

    rubysync pipeline my -C my_csv -V my_db

  You would then edit the file pipelines/my_pipeline.rb to configure the
  policy for synchronizing between the two connectors.

  You may then execute the pipeline in one-shot mode:

    rubysync once my

## REQUIREMENTS:

* An RDBMS system if you want to sync one
* An LDAP server if you want to sync one

## INSTALL:

* `sudo gem install rubysync`

## LICENSE:

  See [LICENSE.txt][3], [MIT-LICENSE.txt][4] and [GPL-LICENSE.txt][5] files.

 [1]: https://github.com/ritchiey/rubysync/
 [2]: https://github.com/nowhereman/rubysync/
 [3]: LICENSE.txt
 [4]: MIT-LICENSE.txt
 [5]: GPL-LICENSE.txt

