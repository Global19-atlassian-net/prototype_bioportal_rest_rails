require File.expand_path('../rdf_util', __FILE__)

# LinkedData API provides a framework for storing and retreiving data in an RDF triplestore, in this case 4store.
module LinkedData
  # Record forms the base of the interaction with the triplestore. CRUD methods may be broken out in separate modules later.
  class Record < OpenStruct
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include LinkedData::Queries::Record
    # Custom serializer
    include LinkedData::Serializer

    ####
    # Methods to adhere to ActiveModel API
    ####
    attr_accessor :attributes
    def initialize(attributes = {})
      @predicate_map = {}; @table = {}
      create_attributes
      table = attributes[:table].nil? ? @table : attributes[:table]
      super(table)
      @predicate_map = attributes[:predicate_map] unless attributes[:predicate_map].nil?
      if attributes[:create_from_results]
        set_attributes(attributes[:create_from_results])
      elsif attributes[:create_from_id]
        from_linked_data(self.class.prefix + attributes[:create_from_id])
      end
      @attributes = @table
    end

    def read_attribute_for_validation(key)
      @attributes[key]
    end

    ####
    # Custom methods for 4store interaction and object building
    ####

    # These values should be provided in the subclass and are required
    class << self; attr_reader :prefix, :rdf_type end

    # Internal usage
    class << self; attr_reader :predicate_map end

    # Convert the object to json using the fields set on each subclass.
    # We should only serialize the @table variable as other data on the object is essentially metadata.
    # @options options [:only] Array of Symbols providing a list of fields to serialize. If the string "all" is in the list then remove the restrictions.
    # @return [Hash] json hash
    def as_json(options = {})
      options[:only] = options[:only].nil? || options[:only].empty? ? serializable_fields_default : options[:only]
      options.extract!(:only) if options[:only] && options[:only].include?("all")
      options[:only].map! {|e| e.to_sym} if options[:only]
      @table.as_json(options)
    end

    # Return the list of predicates for the object type, including cardinality
    # @return [Hash] key String predicate => value Hash
    def self.predicates
      if !$PREDICATES.nil?
        @predicates = $PREDICATES
      else
        if @predicates.nil?
          rdf_type = @rdf_type.kind_of?(Array) ? @rdf_type : [@rdf_type]
          results = []
          rdf_type.each do |type|
            result = RDFUtil.query(PREDICATE_QUERY.gsub("%%RDF_TYPE%%", type))
            results.concat result unless result.nil?
          end
          @predicates = {}
          results.each do |result|
            predicate = RDFUtil.convert_xsd(result["p"]["type"], result["p"]["datatype"], result["p"]["value"])
            cardinality = RDFUtil.convert_xsd(result["c"]["type"], result["c"]["datatype"], result["c"]["value"])
            # puts result["s"]["value"], predicate, cardinality, "\n" if cardinality > 1
            if !@predicates[predicate].nil? && @predicates[predicate][:cardinality] < cardinality
              @predicates[predicate][:cardinality] = cardinality
            elsif @predicates[predicate].nil?
              @predicates[predicate] = {:cardinality => cardinality}
            end
          end
        end
      end
      $PREDICATES = @predicates
    end

    # Check whether an ontology with given id exists
    # @param [String] ontology id
    def self.exists?(id)
      results = RDFUtil.query("ASK WHERE { <%%ID%%> ?p ?o }".gsub("%%ID%%", "#{@prefix}#{id}"))
      results["boolean"]
    end

    protected

    # Create an object by running a series of describe queries
    # @param [Array] list of the object ids to use as the basis for the object. This is essentially a set of subject URIs.
    # @param [Array] list of predicate values where the predicate points to more information that should be included in the primary object.
    #    For example, if you want to get the triples for the latest version of an ontology using the #lastVersion predicate that is returned
    #    with an OntologyContainer, you can include the #lastVersion predicate as an embedded object and they will get merged.
    # @return [Record]
    def from_linked_data(ids = [], embed = [])
      results_converted = {}
      ids.each do |id|
        query = "DESCRIBE <#{id}>"
        results = RDFUtil.query(query)

        # TODO: This should not happen but it is, so we're going to make quash it for now
        next if results.empty?

        results_converted.merge! convert_describe_results(results, "#{id}")
      end

      # The value of the "embeds" list are predicates from the above objects whose values we should look up.
      embed.each do |predicate|
        id = results_converted[predicate].dup
        id = id.kind_of?(Array) ? id.shift : id
        query = "DESCRIBE <#{id}>"
        results = RDFUtil.query(query)
        converted = convert_describe_results(results, id)
        results_converted.merge! converted unless converted.nil?
      end

      set_attributes(results_converted)
    end

    # Given a URI, get the last segment
    # @param [String] predicate value
    def shorten_predicate(predicate)
      if predicate.include?("#")
        short_name = predicate.split("#").last
        @predicate_map[short_name] = predicate
      else
        short_name = predicate.split("/").last
        @predicate_map[short_name] = predicate
      end
      short_name
    end

    # Create a base set of attributes for the object using known predicates from 4store
    def create_attributes
      predicates = self.class.predicates
      predicates.each do |predicate, value|
        short_name = shorten_predicate(predicate)
        self.send("#{short_name}=", nil)
      end
    end

    # Given a result set, shorten the predicates to their last segment (after the # or last /)
    # Return a new object of the appropriate type
    # @param [Array] list of predicate => value pairs
    # @return [Record]
    def set_attributes(results)
      return if results.nil?
      results.each do |predicate, values|
        short_name = shorten_predicate(predicate)
        values_cardinality = self.class.predicates[predicate][:cardinality] == 1 ? values.shift : values
        self.send("#{short_name}=", values_cardinality)
      end
    end

    # Convert the results of a describe query into their appropriately typed objects
    # @param [Array] list of results
    # @param [String] URI of the object
    def convert_describe_results(results, object_id)
      self.class.convert_describe_results(results, object_id)
    end

    # (see #self.convert_describe_results)
    def self.convert_describe_results(results, object_id)
      return nil if results.empty?
      results_converted = {}
      results[object_id].each do |predicate, values|
        values_objs = []
        values.each {|value| values_objs << RDFUtil.convert_xsd(value["type"], value["datatype"], value["value"])}
        results_converted[predicate] = values_objs
      end
      results_converted
    end

  end
end