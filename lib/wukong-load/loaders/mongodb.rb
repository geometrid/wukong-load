require_relative('../loader')

module Wukong
  module Load

    # Loads data into MongoDB.
    #
    # Uses the 'mongo' gem to connect and write data.
    #
    # Allows loading records into a given database and collection.
    # Records can have fields `_database` and `_collection` which
    # override the given database and collection on a per-record
    # basis.
    #
    # Records can have an `_id` field which indicates an update, not
    # an insert.
    #
    # The names of these fields within each record (`_database`,
    # `_collection`, and `_id`) can be customized.
    class MongoDBLoader < Loader

      field :host,             String, :default => 'localhost', :doc => "MongoDB host"
      field :port,             Integer,:default => 27017, :doc => "Port on MongoDB host"
      field :database,         String, :default => 'wukong', :doc => "Default MongoDB database"
      field :collection,       String, :default => 'streaming_record', :doc => "Default MongoDB collection"
      field :database_field,   String, :default => '_database', :doc => "Name of field in each record overriding default MongoDB database"
      field :collection_field, String, :default => '_collection', :doc => "Name of field in each record overriding default MongoDB collection"
      field :id_field,         String, :default => '_id', :doc => "Name of field in each record providing ID of existing MongoDB record to update"

      description <<-EOF.gsub(/^ {8}/,'')
        Loads newline-separated, JSON-formatted records over STDIN
        into MongoDB.

          $ cat data.json | wu-load mongodb

        By default, wu-load attempts to write each input record to a
        local MongoDB server.

        Input records will be written to a default database and
        collection.  Each record can have _database and _collection
        fields to override this on a per-record basis.

        Records with an _id field will be trigger updates, the rest
        inserts.

        All other fields within a record are assumed to be the names
        of actual columns in the table.

        The fields used (_index, _collection, and _id) can be changed:

          $ cat data.json | wu-load mongodb --host=10.123.123.123 --database=web_events --collection=impressions --id_field=impression_id
      EOF
      
      # The Mongo::MongoClient we'll use for talking to MongoDB.
      attr_accessor :client

      # Creates the client connection.
      def setup
        begin
          require 'mongo'
        rescue => e
          raise Error.new("Please ensure that the 'mongo' gem is installed and available (in your Gemfile)")
        end
        h = host.gsub(%r{^http://},'')
        log.debug("Connecting to MongoDB server at #{h}:#{port}...")
        begin
          self.client = Mongo::MongoClient.new(h, port)
        rescue => e
          raise Error.new(e.message)
        end
      end

      # Load a single record into MongoDB.
      #
      # If the record has an ID, we'll issue an update, otherwise an
      # insert.
      #
      # @param [record] Hash
      def load record
        id = id_for(record)
        if id
          res = collection_for(record).update({:_id => id}, record, :upsert => true)
          if res['updatedExisting']
            log.info("Updated #{id}")
          else
            log.info("Inserted #{id}")
          end
        else
          res = collection_for(record).insert(record)
          log.info("Inserted #{res}")
        end
      end

      # :nodoc:
      def database_for record
        client[database_name_for(record)]
      end

      # :nodoc:
      def collection_for record
        database_for(record)[collection_name_for(record)]
      end

      # :nodoc:
      def database_name_for record
        record[database_field] || self.database
      end

      # :nodoc:
      def collection_name_for record
        record[collection_field] || self.collection
      end

      # :nodoc:
      def id_for record
        record[id_field]
      end
      
      register :mongodb_loader
      
    end
  end
end
