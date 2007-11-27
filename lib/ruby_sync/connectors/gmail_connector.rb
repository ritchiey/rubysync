require 'contacts'

module RubySync::Connectors
  class GmailConnector < RubySync::Connectors::BaseConnector


            option :username, :password
          
          
            ####### Configuration methods
          
            # Return the list of the fields available for this connector. Feel free to print an
            # informative message if you can't determine the available fields for the datastore.
            def self.fields
              [:id, :name, :emails, :phones]
            end
          
            # Return the string that will be inserted as the contents of the subclass created
            # when "rubysync connnector blah -t your_connector" is run.
            def self.sample_config
              return <<-END
                # This connector uses the 'contacts' gem to retrieve contact information from
                # gmail then transforms it to a format suitable for RubySync.
                # Note: This is a read-only connector at present. It can't change your gmail
                # contacts.
              
                # Set your gmail username 
                username ''
              
                # Set your gmail password
                password ''
              END
            end

            ####### Reading methods
            
            def [](path)
              contact = contacts.detect {|c| c['Id']==path}
              (contact)? to_entry(contact) : nil
            end
          
            # Subclasses must override this to
            # interface with the external system and generate entries for every
            # entry in the scope passing the entry path (id) and its data (as a hash of arrays).
            def each_entry
              contacts and contacts.each do |contact|
                yield contact['Id'], to_entry(contact)
              end
            end
          
            ######## Writing methods

          
            # Apply operations to create database a entry at path
            def add(path, operations)
              raise "Not implemented. This is a read-only connector"
            end
          
            # Apply operations to alter database entry at path
            def modify(path, operations)
              raise "Not implemented. This is a read-only connector"
            end


            # Remove database entry at path
            def delete(path)
              raise "Not implemented. This is a read-only connector"
            end

      private

    def to_entry(contact)
      e = {}
      e[:id], e[:name] = contact.values_at "Id", "Name"
      emails = contact['Emails']
      phones = contact['Phones']
      e['emails'] = emails.map {|email| email['Address']} if emails
      e['phones'] = phones.map {|phone| phone['Number']} if phones
      e
    end

    
    def contacts
      unless @contacts
        c = Contacts.new('gmail', username, password)
        c.login
        @contacts = nil
        retries = 0
        until @contacts or retries > 5
          begin
            @contacts = c.contacts
          rescue NoMethodError
            sleep 1
          end
          retries += 1
        end
      end
      @contacts
    end


  end
end