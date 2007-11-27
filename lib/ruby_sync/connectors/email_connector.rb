require 'ruby_sync'
require 'net/pop'
require 'net/smtp'


module RubySync::Connectors
  class EmailConnector < RubySync::Connectors::BaseConnector
  
          
            option :pop_server, :pop_port, :pop_user, :pop_password, :pop_delete
            pop_server 'localhost'
            pop_port 110
            pop_delete true
          
            option :smtp_server, :smtp_port, :smtp_user, :smtp_password, :smtp_domain
            smtp_domain = smtp_server 'localhost'
            smtp_port 25
            
          
            option :in_fields, :path_field, :out_fields
            in_fields [:from, :to, :subject]
            out_fields [:from, :to, :subject, :body]
            path_field :from
            
            
            # Return the value to be used as the source_path for the event given the
            # supplied row data.
            def path_for(data)
              if defined? path_field
                return data[path_field]
              end
              return nil
            end
                      
            ####### Configuration methods
          
            # Return the list of the fields available for this connector. Feel free to print an
            # informative message if you can't determine the available fields for the datastore.
            def self.fields
              get_in_fields | get_out_fields
            end
          
            # Return the string that will be inserted as the contents of the subclass created
            # when "rubysync connnector blah -t your_connector" is run.
            def self.sample_config
              return <<-END
                # In-coming email
                #
                pop_server 'localhost'
                #pop_port   110
                #pop_user   'change_me'
                #pop_password 'change_me'
                #pop_delete true
                
                # Out-going email
                #
                # smtp_server 'localhost'
                # smtp_domain 'localhost' # set this to your local domain
                # smtp_port 25
                # smtp_user 'change_me'
                # smtp_password 'change_me'
              
                # fields to scan for
                in_fields :from, :to, :subject
                path_field :from
                
              END
            end

            ####### Reading methods
          
            def each_change
              Net::POP3.start(pop_server, pop_port, pop_user, pop_password) do |pop|
                pop.each_mail do |mail|
                  values = parse_incoming(mail.pop, in_fields)
                  association_key = source_path = values[path_field]
                  yield RubySync::Event.modify(self, source_path, association_key, create_operations_for(values))
                  mail.delete if pop_delete
                end
              end
            end
          
            def parse_incoming(text, fields)
              values = {}
              fields.each do |field|
                pattern = /^#{field}:\s*(.+?)\s*$/i
                values[field] = text.scan(pattern).flatten
              end
              values
            end
          
            ######## Writing methods

          
            # Send an SMTP messaage
            def add(path, operations)
              record = perform_operations(operations)
              from = record[:from] or raise "Can't send email without specifying :from value"
              to = record[:to] or raise "Can't send email without specifying :to value"
              subject = record[:subject] || ''
              body = record[:body] || ''
              Net::SMTP::start(smtp_host, smtp_port, smtp_domain) do |smtp|
                message = "Subject: #{subject}\n\n#{body}"
                smtp.send_message message, from, to.as_array
              end
            end
          
            # Apply operations to alter database entry at path
            def modify(path, operations)
            end


            # Remove database entry at path
            def delete(path)
            end
            

  end
end